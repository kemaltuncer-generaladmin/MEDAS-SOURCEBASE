import Foundation
import Supabase

public actor AuthBackend {
    public static let shared = AuthBackend()

    private var supabase: SupabaseClient?
    private var isInitialized = false
    private var initializationError: String?

    private var config: SourceBaseConfig?

    private init() {}

    public func isConfigured() -> Bool {
        config?.isConfigured ?? false
    }

    public func initialized() -> Bool {
        isInitialized
    }

    public func initError() -> String? {
        initializationError
    }

    public func googleEnabled() -> Bool {
        config?.googleOAuthEnabled ?? false
    }

    public func appleEnabled() -> Bool {
        config?.appleOAuthEnabled ?? false
    }

    public func currentUser() async -> User? {
        guard let supabase else { return nil }
        // The synchronous `currentUser` can be stale (nil) immediately after a
        // fresh signIn in supabase-swift v2 — the session is persisted through an
        // isolated store that the sync accessor doesn't see yet. Fall back to the
        // async `session` (loads/validates the stored session) so login reliably
        // resolves the user and the app navigates past the auth screen.
        if let user = supabase.auth.currentUser {
            return user
        }
        return try? await supabase.auth.session.user
    }

    public func currentUserNeedsProfile() async -> Bool {
        userNeedsProfile(await currentUser())
    }

    public func currentUserHasVerifiedEmail() async -> Bool {
        (await currentUser())?.emailConfirmedAt != nil
    }

    public func getClient() -> SupabaseClient? {
        return supabase
    }

    public func userNeedsProfile(_ user: User?) -> Bool {
        guard let user else { return false }
        let metadata = user.userMetadata
        let faculty = metadata["sourcebase_faculty"]?.stringValue ?? ""
        let department = metadata["sourcebase_department"]?.stringValue ?? ""
        let classYear = metadata["sourcebase_class_year"]?.stringValue ?? ""
        let goal = metadata["sourcebase_goal"]?.stringValue ?? ""
        return faculty.trimmingCharacters(in: .whitespaces).isEmpty
            || department.trimmingCharacters(in: .whitespaces).isEmpty
            || classYear.trimmingCharacters(in: .whitespaces).isEmpty
            || goal.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Initialize

    public func initialize(config: SourceBaseConfig) async throws {
        guard !isInitialized else { return }
        guard config.isConfigured else {
            initializationError = "Kimlik doğrulama yapılandırması başlatılamadı. Lütfen daha sonra tekrar dene."
            SBLog.auth.error("auth initialize rejected reason=not_configured")
            throw AuthError.notConfigured
        }

        self.config = config

        guard let url = URL(string: config.supabaseURL) else {
            initializationError = "Kimlik doğrulama yapılandırması başlatılamadı. Lütfen daha sonra tekrar dene."
            SBLog.auth.error("auth initialize rejected reason=invalid_url")
            throw AuthError.notConfigured
        }

        supabase = SupabaseClient(
            supabaseURL: url,
            supabaseKey: config.supabaseAnonKey
        )
        isInitialized = true
        initializationError = nil
        SBLog.auth.info("auth initialized")
    }

    // MARK: - Auth Actions

    public func signIn(email: String, password: String) async throws -> AuthResult {
        let auth = try authOrThrow()
        do {
            let session = try await auth.signIn(email: email.trimmingCharacters(in: .whitespaces), password: password)
            return .success("Giriş başarılı.", user: session.user)
        } catch {
            SBLog.auth.error("sign_in failed error=\(String(describing: error), privacy: .private)")
            throw error
        }
    }

    public func signUp(
        fullName: String,
        email: String,
        password: String,
        profile: SourceBaseProfile?
    ) async throws -> AuthResult {
        let auth = try authOrThrow()
        var userData: [String: AnyJSON] = [
            "app_code": .string(config?.appCode ?? "sourcebase"),
            "display_name": .string(fullName.trimmingCharacters(in: .whitespaces)),
            "full_name": .string(fullName.trimmingCharacters(in: .whitespaces)),
            "signup_source": .string(config?.appCode ?? "sourcebase"),
            "ecosystem": .string("medasi")
        ]

        if let profile {
            userData["sourcebase_faculty"] = .string(profile.faculty)
            userData["sourcebase_department"] = .string(profile.department)
            userData["sourcebase_class_year"] = .string(profile.classYear)
            userData["sourcebase_goal"] = .string(profile.goal)
            userData["sourcebase_profile_completed"] = .bool(true)
            userData["sourcebase_profile_completed_at"] = .string(
                ISO8601DateFormatter().string(from: Date())
            )
        }

        let redirectStr: String? = config?.authRedirectTo
        let redirectTo = redirectStr.flatMap { URL(string: $0) }
        do {
            _ = try await auth.signUp(
                email: email.trimmingCharacters(in: .whitespaces),
                password: password,
                data: userData,
                redirectTo: redirectTo
            )
            return .success("Doğrulama e-postası SourceBase bağlantısıyla gönderildi.")
        } catch {
            SBLog.auth.error("sign_up failed error=\(String(describing: error), privacy: .private)")
            throw error
        }
    }

    public func signInWithGoogle() async throws -> AuthResult {
        guard googleEnabled() else {
            SBLog.auth.error("oauth rejected provider=google reason=disabled")
            throw AuthError.providerNotEnabled("Bu giriş yöntemi şu anda aktif değil.")
        }
        let auth = try authOrThrow()
        let redirectStr: String? = config?.authRedirectTo
        let redirectTo = redirectStr.flatMap { URL(string: $0) }
        _ = try await auth.signInWithOAuth(
            provider: .google,
            redirectTo: redirectTo
        )
        return .success("Google girişi başlatıldı.")
    }

    public func signInWithApple() async throws -> AuthResult {
        guard appleEnabled() else {
            SBLog.auth.error("oauth rejected provider=apple reason=disabled")
            throw AuthError.providerNotEnabled("Bu giriş yöntemi şu anda aktif değil.")
        }
        let auth = try authOrThrow()
        let redirectStr2: String? = config?.authRedirectTo
        let redirectTo = redirectStr2.flatMap { URL(string: $0) }
        _ = try await auth.signInWithOAuth(
            provider: .apple,
            redirectTo: redirectTo
        )
        return .success("Apple girişi başlatıldı.")
    }

    public func updateSourceBaseProfile(_ profile: SourceBaseProfile) async throws -> AuthResult {
        let auth = try authOrThrow()
        guard auth.currentUser != nil else {
            throw AuthError.noSession
        }

        let currentMetadata = auth.currentUser?.userMetadata ?? [:]
        var merged = currentMetadata
        merged["sourcebase_faculty"] = .string(profile.faculty)
        merged["sourcebase_department"] = .string(profile.department)
        merged["sourcebase_class_year"] = .string(profile.classYear)
        merged["sourcebase_goal"] = .string(profile.goal)
        merged["sourcebase_profile_completed"] = .bool(true)
        merged["sourcebase_profile_completed_at"] = .string(ISO8601DateFormatter().string(from: Date()))

        _ = try await auth.update(user: UserAttributes(data: merged))
        return .success("SourceBase bilgilerin tamamlandı.")
    }

    /// Current user's SourceBase profile parsed from auth metadata (for AI personalization).
    public func currentProfile() -> SourceBaseProfile? {
        guard let metadata = supabase?.auth.currentUser?.userMetadata else { return nil }
        return SourceBaseProfile(
            faculty: metadata["sourcebase_faculty"]?.stringValue ?? "",
            department: metadata["sourcebase_department"]?.stringValue ?? "",
            classYear: metadata["sourcebase_class_year"]?.stringValue ?? "",
            goal: metadata["sourcebase_goal"]?.stringValue ?? ""
        )
    }

    public func updateAvatarURL(_ avatarURL: String) async throws -> AuthResult {
        let auth = try authOrThrow()
        guard auth.currentUser != nil else {
            throw AuthError.noSession
        }

        let currentMetadata = auth.currentUser?.userMetadata ?? [:]
        var merged = currentMetadata
        merged["avatar_url"] = .string(avatarURL)
        merged["picture"] = .string(avatarURL)

        _ = try await auth.update(user: UserAttributes(data: merged))
        return .success("Profil fotoğrafın güncellendi.")
    }

    public func resendSignupEmail(_ email: String) async throws -> AuthResult {
        let auth = try authOrThrow()
        let redirectStr: String? = config?.authRedirectTo
        let redirectTo = redirectStr.flatMap { URL(string: $0) }
        try await auth.resend(
            email: email.trimmingCharacters(in: .whitespaces),
            type: .signup,
            emailRedirectTo: redirectTo
        )
        return .success("Doğrulama e-postası yeniden gönderildi.")
    }

    public func sendPasswordReset(_ email: String) async throws -> AuthResult {
        let auth = try authOrThrow()
        let redirectStr: String? = config?.authRedirectTo
        let redirectTo = redirectStr.flatMap { URL(string: $0) }
        try await auth.resetPasswordForEmail(
            email.trimmingCharacters(in: .whitespaces),
            redirectTo: redirectTo
        )
        return .success("Şifre sıfırlama e-postası SourceBase bağlantısıyla gönderildi.")
    }

    public func updatePassword(_ password: String) async throws -> AuthResult {
        let auth = try authOrThrow()
        _ = try await auth.update(user: UserAttributes(password: password))
        return .success("Şifren güncellendi.")
    }

    public func verifyEmailOTP(email: String, token: String) async throws -> AuthResult {
        let auth = try authOrThrow()
        let response = try await auth.verifyOTP(
            email: email.trimmingCharacters(in: .whitespaces),
            token: token.trimmingCharacters(in: .whitespaces),
            type: .signup
        )
        return .success("E-posta doğrulaması tamamlandı.", user: response.user)
    }

    public func handleCallback(_ url: URL) async throws -> AuthCallbackResult {
        let auth = try authOrThrow()
        let fragmentParams = fragmentParameters(from: url)

        let errorDesc = url.queryParameters?["error_description"]
            ?? fragmentParams["error_description"]
        let errorCode = url.queryParameters?["error"] ?? fragmentParams["error"]

        if let desc = errorDesc ?? errorCode {
            SBLog.auth.error("auth callback failed code=\(errorCode ?? "unknown", privacy: .public) description=\(desc, privacy: .private)")
            throw AuthError.callbackFailed(desc)
        }

        var redirectType: String?

        let code = url.queryParameters?["code"] ?? fragmentParams["code"]
        if let code, !code.trimmingCharacters(in: .whitespaces).isEmpty {
            _ = try await auth.exchangeCodeForSession(authCode: code)
        } else if url.queryParameters?.keys.contains("access_token") == true {
            _ = try await auth.session(from: url)
        } else if fragmentParams.keys.contains("access_token"),
                  var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            components.queryItems = fragmentParams.map { URLQueryItem(name: $0.key, value: $0.value) }
            if let rebuiltURL = components.url {
                _ = try await auth.session(from: rebuiltURL)
            }
        }

        redirectType = url.queryParameters?["type"]
            ?? fragmentParams["type"]

        guard auth.currentUser != nil else {
            SBLog.auth.error("auth callback failed reason=no_session")
            throw AuthError.noSession
        }

        return AuthCallbackResult(redirectType: redirectType)
    }

    public func signOut() async throws {
        do {
            try await supabase?.auth.signOut()
        } catch {
            SBLog.auth.error("sign_out failed error=\(String(describing: error), privacy: .private)")
            throw error
        }
    }

    // MARK: - Private Helpers

    private func authOrThrow() throws -> AuthClient {
        guard let client = supabase else {
            throw AuthError.notConfigured
        }
        return client.auth
    }

    private func fragmentParameters(from url: URL) -> [String: String] {
        guard let fragment = url.fragment, !fragment.isEmpty else { return [:] }
        var components = URLComponents()
        let queryPart: String
        if fragment.contains("?") {
            queryPart = fragment.components(separatedBy: "?").dropFirst().joined(separator: "?")
        } else {
            queryPart = fragment
        }
        components.query = queryPart
        guard let queryItems = components.queryItems else { return [:] }
        var result: [String: String] = [:]
        for item in queryItems {
            result[item.name] = item.value ?? ""
        }
        return result
    }
}

// MARK: - Auth Errors

public enum AuthError: Error, Sendable {
    case notConfigured
    case noSession
    case providerNotEnabled(String)
    case callbackFailed(String)
}

extension URL {
    fileprivate var queryParameters: [String: String]? {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else { return nil }
        var result: [String: String] = [:]
        for item in queryItems {
            result[item.name] = item.value ?? ""
        }
        return result
    }
}

// MARK: - AnyJSON helpers

extension AnyJSON {
    var stringValue: String? {
        switch self {
        case .string(let value): return value
        case .integer(let value): return String(value)
        case .bool(let value): return String(value)
        case .double(let value): return String(value)
        default: return nil
        }
    }
}
