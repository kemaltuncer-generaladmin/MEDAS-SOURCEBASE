This file is a merged representation of a subset of the codebase, containing files not matching ignore patterns, combined into a single document by Repomix.
The content has been processed where security check has been disabled.

# File Summary

## Purpose
This file contains a packed representation of a subset of the repository's contents that is considered the most important context.
It is designed to be easily consumable by AI systems for analysis, code review,
or other automated processes.

## File Format
The content is organized as follows:
1. This summary section
2. Repository information
3. Directory structure
4. Repository files (if enabled)
5. Multiple file entries, each consisting of:
  a. A header with the file path (## File: path/to/file)
  b. The full contents of the file in a code block

## Usage Guidelines
- This file should be treated as read-only. Any changes should be made to the
  original repository files, not this packed version.
- When processing this file, use the file path to distinguish
  between different files in the repository.
- Be aware that this file may contain sensitive information. Handle it with
  the same level of security as you would the original repository.

## Notes
- Some files may have been excluded based on .gitignore rules and Repomix's configuration
- Binary files are not included in this packed representation. Please refer to the Repository Structure section for a complete list of file paths, including binary files
- Files matching these patterns are excluded: .env, .env.*, **/.env, **/.env.*, build/**, **/build/**, .dart_tool/**, **/.dart_tool/**, .claude/**, **/.claude/**, .agents/**, **/.agents/**, .artifacts/**, **/.artifacts/**, .verdent-artifacts/**, **/.verdent-artifacts/**, .xcodebuildmcp/**, **/.xcodebuildmcp/**, node_modules/**, **/node_modules/**, .build/**, **/.build/**, Pods/**, **/Pods/**, DerivedData/**, **/DerivedData/**
- Files matching patterns in .gitignore are excluded
- Files matching default ignore patterns are excluded
- Security check has been disabled - content may contain sensitive information

# Directory Structure
```
Sources/
  SourceBaseBackend/
    Auth/
      AuthBackend.swift
      AuthErrors.swift
      AuthModels.swift
    Config/
      SBLog.swift
      SourceBaseConfig.swift
    Drive/
      DriveAPI.swift
      DriveModels.swift
      DriveRepository.swift
      DriveUploadPayload.swift
      DriveUploadService.swift
      GeneratedContentModels.swift
      SBStudyDocument.swift
    Profile/
      ProfileRepository.swift
      StoreRepository.swift
Tests/
  SourceBaseBackendTests/
    AuthTests.swift
    DriveTests.swift
Package.swift
```

# Files

## File: Sources/SourceBaseBackend/Auth/AuthBackend.swift
```swift
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
```

## File: Sources/SourceBaseBackend/Auth/AuthErrors.swift
```swift
import Foundation

public struct AuthErrorMapping: Sendable {
    public static func friendlyError(
        _ error: Error,
        isConfigured: Bool,
        initializationError: String?
    ) -> String {
        if !isConfigured || initializationError != nil {
            return "Kimlik doğrulama yapılandırması eksik. Lütfen daha sonra tekrar dene."
        }

        let message = error.localizedDescription.lowercased()

        if message.contains("invalid login")
            || message.contains("invalid credentials")
            || message.contains("invalid_credentials") {
            return "E-posta veya şifre hatalı."
        }

        if message.contains("email not confirmed")
            || message.contains("email not verified") {
            return "E-postanı doğruladıktan sonra giriş yapabilirsin."
        }

        if message.contains("already registered")
            || message.contains("user already")
            || message.contains("user_already_exists") {
            return "Bu e-posta ile zaten bir hesap var."
        }

        if message.contains("weak password")
            || message.contains("password should")
            || message.contains("weak_password") {
            return "Şifre daha güçlü olmalı. En az 8 karakter kullan."
        }

        if message.contains("rate limit")
            || message.contains("too many")
            || message.contains("over_email_send_rate_limit") {
            return "Çok fazla deneme yapıldı. Lütfen biraz bekleyip tekrar dene."
        }

        if message.contains("giriş yöntemi")
            || message.contains("unsupported provider")
            || message.contains("provider is not enabled") {
            return "Bu giriş yöntemi şu anda aktif değil. E-posta ile giriş yapabilirsin."
        }

        if message.contains("otp")
            || message.contains("token")
            || message.contains("otp_expired") {
            return "Doğrulama kodu geçersiz veya süresi dolmuş."
        }

        if message.contains("no code detected")
            || message.contains("no access_token")
            || message.contains("session")
            || message.contains("oturum bulunamad") {
            return "Oturum doğrulanamadı. Lütfen tekrar giriş yap."
        }

        if message.contains("network")
            || message.contains("socket")
            || message.contains("connection") {
            return "Bağlantı kurulamadı. İnternetini kontrol edip tekrar dene."
        }

        return "İşlem tamamlanamadı. Lütfen bilgileri kontrol edip tekrar dene."
    }
}
```

## File: Sources/SourceBaseBackend/Auth/AuthModels.swift
```swift
import Foundation
import Supabase

public enum AuthResult: Sendable {
    case success(String, user: User? = nil)
    case failure(String)

    public var ok: Bool {
        if case .success = self { return true }
        return false
    }

    public var message: String? {
        if case .success(let msg, _) = self { return msg }
        return nil
    }

    public var error: String? {
        if case .failure(let err) = self { return err }
        return nil
    }

    public var user: User? {
        if case .success(_, let user) = self { return user }
        return nil
    }
}

public struct AuthCallbackResult: Sendable {
    public let redirectType: String?

    public var isPasswordRecovery: Bool {
        redirectType == "recovery" || redirectType == "passwordRecovery"
    }
}

public struct SourceBaseProfile: Sendable {
    public let faculty: String
    public let department: String
    /// e.g. "Dönem 3", "Mezun" — drives how deep/foundational AI output should be.
    public let classYear: String
    /// e.g. "TUS", "Dönem sınavları", "USMLE", "Genel tekrar" — drives AI focus.
    public let goal: String

    public init(
        faculty: String,
        department: String,
        classYear: String = "",
        goal: String = ""
    ) {
        self.faculty = faculty.trimmingCharacters(in: .whitespaces)
        self.department = department.trimmingCharacters(in: .whitespaces)
        self.classYear = classYear.trimmingCharacters(in: .whitespaces)
        self.goal = goal.trimmingCharacters(in: .whitespaces)
    }

    public func metadata() -> [String: Any] {
        [
            "sourcebase_faculty": faculty,
            "sourcebase_department": department,
            "sourcebase_class_year": classYear,
            "sourcebase_goal": goal,
            "sourcebase_profile_completed": true,
            "sourcebase_profile_completed_at": ISO8601DateFormatter().string(from: Date())
        ]
    }

    /// Compact persona string fed to the AI so every generation is tailored to the
    /// student's level and exam target.
    public var studentContext: String {
        var parts: [String] = []
        if !department.isEmpty { parts.append(department) }
        if !classYear.isEmpty { parts.append(classYear) }
        if !goal.isEmpty { parts.append("hedef: \(goal)") }
        if !faculty.isEmpty { parts.append(faculty) }
        return parts.joined(separator: " · ")
    }
}
```

## File: Sources/SourceBaseBackend/Config/SBLog.swift
```swift
import OSLog

public enum SBLog {
    public static let auth = Logger(subsystem: "tr.com.medasi.sourcebase", category: "auth")
    public static let drive = Logger(subsystem: "tr.com.medasi.sourcebase", category: "drive")
    public static let store = Logger(subsystem: "tr.com.medasi.sourcebase", category: "store")
}
```

## File: Sources/SourceBaseBackend/Config/SourceBaseConfig.swift
```swift
import Foundation

public struct SourceBaseConfig: Sendable {
    public let supabaseURL: String
    public let supabaseAnonKey: String
    public let publicURL: String
    public let mobileRedirectURL: String
    public let googleOAuthEnabled: Bool
    public let appleOAuthEnabled: Bool
    public let appCode: String

    public init(
        supabaseURL: String,
        supabaseAnonKey: String,
        publicURL: String = "",
        mobileRedirectURL: String = "",
        googleOAuthEnabled: Bool = false,
        appleOAuthEnabled: Bool = false,
        appCode: String = "sourcebase"
    ) {
        self.supabaseURL = supabaseURL
        self.supabaseAnonKey = supabaseAnonKey
        self.publicURL = publicURL
        self.mobileRedirectURL = mobileRedirectURL
        self.googleOAuthEnabled = googleOAuthEnabled
        self.appleOAuthEnabled = appleOAuthEnabled
        self.appCode = appCode
    }

    public var isConfigured: Bool {
        !supabaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !supabaseAnonKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var authRedirectTo: String {
        let normalized = publicURL.hasSuffix("/")
            ? String(publicURL.dropLast())
            : publicURL
        let cleaned = mobileRedirectURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleaned.isEmpty {
            return cleaned
        }
        return "\(normalized)/auth/callback"
    }

    // Baked-in defaults (mirror the Flutter app). The Supabase anon key is a
    // public client token and is safe to ship in the binary. Environment
    // variables override these in development; on-device / TestFlight builds
    // have no environment, so the defaults must be valid.
    public enum Defaults {
        public static let supabaseURL = "https://medasi.com.tr"
        public static let supabaseAnonKey = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJzdXBhYmFzZSIsImlhdCI6MTc3ODUyMDA2MCwiZXhwIjo0OTM0MTkzNjYwLCJyb2xlIjoiYW5vbiJ9.JwCrc4LMTYpQRTIcwBk4WaVOVUbpwN0fM1SMknmDClk"
        public static let publicURL = "https://sourcebase.medasi.com.tr"
        public static let mobileRedirectURL = "sourcebase://auth/callback"
    }

    public static func fromEnvironment() -> SourceBaseConfig {
        let env = ProcessInfo.processInfo.environment
        func value(_ key: String, default fallback: String) -> String {
            let v = (env[key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return v.isEmpty ? fallback : v
        }
        return SourceBaseConfig(
            supabaseURL: value("SOURCEBASE_SUPABASE_URL", default: Defaults.supabaseURL),
            supabaseAnonKey: value("SOURCEBASE_SUPABASE_ANON_KEY", default: Defaults.supabaseAnonKey),
            publicURL: value("SOURCEBASE_PUBLIC_URL", default: Defaults.publicURL),
            mobileRedirectURL: value("SOURCEBASE_MOBILE_REDIRECT_URL", default: Defaults.mobileRedirectURL),
            googleOAuthEnabled: env["SOURCEBASE_GOOGLE_OAUTH_ENABLED"] == "true",
            appleOAuthEnabled: env["SOURCEBASE_APPLE_OAUTH_ENABLED"] == "true"
        )
    }
}
```

## File: Sources/SourceBaseBackend/Drive/DriveAPI.swift
```swift
import Foundation
import Supabase

public struct DriveAPIError: Error, Sendable, LocalizedError, CustomStringConvertible {
    public let message: String
    public let code: String?
    public let status: Int?

    public init(message: String, code: String? = nil, status: Int? = nil) {
        self.message = message
        self.code = code
        self.status = status
    }

    public var isUnauthorized: Bool {
        status == 401 || code == "UNAUTHORIZED" || code == "AUTH_NOT_CONFIGURED"
    }

    public var errorDescription: String? { message }

    public var description: String {
        var parts = [message]
        if let code { parts.append("code=\(code)") }
        if let status { parts.append("status=\(status)") }
        return parts.joined(separator: " ")
    }
}

public struct DriveAPI: Sendable {
    private let client: SupabaseClient

    public init(client: SupabaseClient) {
        self.client = client
    }

    // MARK: - Core invoke

    public func invoke(
        _ action: String,
        payload: [String: AnyJSON] = [:],
        timeoutSeconds: UInt64 = 90
    ) async throws -> [String: AnyJSON] {
        let body = AnyJSON.object([
            "action": .string(action),
            "payload": .object(payload)
        ])

        do {
            let data: [String: AnyJSON] = try await withDriveAPITimeout(seconds: timeoutSeconds) {
                try await client.functions.invoke(
                    "sourcebase",
                    options: FunctionInvokeOptions(body: body)
                )
            }

            if let ok = data["ok"], case .bool(false) = ok {
                let errorInfo = data["error"]
                var message = "SourceBase request failed."
                var code: String?
                var status: Int?

                if case .object(let errorDict) = errorInfo {
                    message = errorDict["message"]?.stringValue ?? "SourceBase request failed."
                    code = errorDict["code"]?.stringValue
                    status = errorDict["status"].flatMap { v -> Int? in
                        if case .integer(let i) = v { return i }
                        return Int(v.stringValue ?? "")
                    }
                }

                SBLog.drive.error("edge action failed action=\(action, privacy: .public) code=\(code ?? "none", privacy: .public) status=\(status ?? 0, privacy: .public)")
                throw DriveAPIError(message: message, code: code, status: status)
            }

            return data
        } catch let error as DriveAPIError {
            throw error
        } catch FunctionsError.httpError(let status, let data) {
            SBLog.drive.error("edge http error action=\(action, privacy: .public) status=\(status, privacy: .public)")
            throw Self.httpError(status: status, data: data)
        } catch {
            SBLog.drive.error("edge invoke threw action=\(action, privacy: .public) error=\(String(describing: error), privacy: .private)")
            throw error
        }
    }

    static func httpError(status: Int, data: Data) -> DriveAPIError {
        let fallback = HTTPURLResponse.localizedString(forStatusCode: status)
        guard !data.isEmpty else {
            return DriveAPIError(message: fallback, code: nil, status: status)
        }

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let errorDict = json["error"] as? [String: Any]
            let source = errorDict ?? json
            let message = source["message"] as? String
                ?? json["message"] as? String
                ?? fallback
            let code = source["code"] as? String
                ?? json["code"] as? String
            let parsedStatus = source["status"] as? Int
                ?? json["status"] as? Int
                ?? status
            return DriveAPIError(message: message, code: code, status: parsedStatus)
        }

        let body = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return DriveAPIError(message: body?.isEmpty == false ? body! : fallback, code: nil, status: status)
    }

    // MARK: - Upload

    public func createUploadSession(_ draft: DriveUploadDraft) async throws -> StorageUploadSession {
        let payload = Self.uploadSessionPayload(for: draft)
        let response = try await invoke("create_upload_session", payload: payload)
        guard case .object(let dataDict) = response["data"] else {
            throw DriveAPIError(message: "Upload session response is empty.", code: nil, status: nil)
        }
        let jsonData = try JSONEncoder().encode(dataDict)
        return try JSONDecoder().decode(StorageUploadSession.self, from: jsonData)
    }

    static func uploadSessionPayload(for draft: DriveUploadDraft) -> [String: AnyJSON] {
        var payload: [String: AnyJSON] = [
            "fileName": .string(draft.fileName),
            "contentType": .string(draft.contentType),
            "sizeBytes": .integer(draft.sizeBytes),
            "courseId": .string(draft.courseId),
            "sectionId": .string(draft.sectionId)
        ]
        payload.merge(documentProcessingPolicy(fileName: draft.fileName, contentType: draft.contentType)) { current, _ in current }
        return payload
    }

    public func completeUpload(
        objectName: String,
        courseId: String,
        sectionId: String,
        fileName: String,
        contentType: String,
        sizeBytes: Int,
        extractedText: String? = nil,
        pageCount: Int? = nil,
        extractionMetadata: ExtractionMetadata? = nil
    ) async throws -> [String: AnyJSON] {
        let payload = Self.completeUploadPayload(
            objectName: objectName,
            courseId: courseId,
            sectionId: sectionId,
            fileName: fileName,
            contentType: contentType,
            sizeBytes: sizeBytes,
            extractedText: extractedText,
            pageCount: pageCount,
            extractionMetadata: extractionMetadata
        )
        return try await invoke("complete_upload", payload: payload)
    }

    static func completeUploadPayload(
        objectName: String,
        courseId: String,
        sectionId: String,
        fileName: String,
        contentType: String,
        sizeBytes: Int,
        extractedText: String? = nil,
        pageCount: Int? = nil,
        extractionMetadata: ExtractionMetadata? = nil
    ) -> [String: AnyJSON] {
        var payload: [String: AnyJSON] = [
            "objectName": .string(objectName),
            "courseId": .string(courseId),
            "sectionId": .string(sectionId),
            "fileName": .string(fileName),
            "contentType": .string(contentType),
            "sizeBytes": .integer(sizeBytes)
        ]
        if let extractedText {
            payload["extractedText"] = .string(extractedText)
        }
        if let pageCount {
            payload["pageCount"] = .integer(pageCount)
        }
        if let metadata = extractionMetadata {
            payload["extractionMetadata"] = .object([
                "charCount": .integer(metadata.charCount),
                "wordCount": .integer(metadata.wordCount),
                "extractedAt": .string(ISO8601DateFormatter().string(from: metadata.extractedAt))
            ])
        }
        payload.merge(Self.documentProcessingPolicy(fileName: fileName, contentType: contentType)) { current, _ in current }
        return payload
    }

    private static func documentProcessingPolicy(fileName: String, contentType: String) -> [String: AnyJSON] {
        let normalized = "\(fileName) \(contentType)".lowercased()
        let isDocument = [
            ".pdf", "application/pdf",
            ".ppt", ".pptx", "presentation",
            ".doc", ".docx", "wordprocessing", "msword"
        ].contains { normalized.contains($0) }
        guard isDocument else { return [:] }

        let extraction = "extract_all_pages_slides_and_doc_sections_preserve_page_numbers_headings_tables_figures"
        let ocr = "run_ocr_when_pdf_or_slide_page_is_scanned_image_based_or_low_text_density"
        let readiness = "do_not_mark_ready_until_text_or_ocr_text_is_available_or_explicit_failure_is_returned"
        return [
            "extractionPolicy": .string(extraction),
            "extraction_policy": .string(extraction),
            "ocrPolicy": .string(ocr),
            "ocr_policy": .string(ocr),
            "ocrRequiredWhenSparse": .string("true"),
            "ocr_required_when_sparse": .string("true"),
            "ocrLanguageHints": .string("tr,en,medical"),
            "ocr_language_hints": .string("tr,en,medical"),
            "documentReadinessPolicy": .string(readiness),
            "document_readiness_policy": .string(readiness),
            "largeDocumentExtractionPolicy": .string("chunk_extract_then_index_full_document_not_first_pages_only"),
            "large_document_extraction_policy": .string("chunk_extract_then_index_full_document_not_first_pages_only")
        ]
    }

    public func runtimeConfig() async throws -> [String: AnyJSON] {
        try await invoke("runtime_config")
    }

    // MARK: - Course

    public func createCourse(
        _ title: String,
        iconName: String? = nil,
        colorHex: String? = nil
    ) async throws -> [String: AnyJSON] {
        var payload: [String: AnyJSON] = ["title": .string(title)]
        if let iconName, !iconName.isEmpty { payload["iconName"] = .string(iconName) }
        if let colorHex, !colorHex.isEmpty { payload["colorHex"] = .string(colorHex) }
        return try await invoke("create_course", payload: payload)
    }

    public func createSection(
        courseId: String,
        title: String,
        iconName: String? = nil,
        colorHex: String? = nil
    ) async throws -> [String: AnyJSON] {
        var payload: [String: AnyJSON] = [
            "courseId": .string(courseId),
            "title": .string(title)
        ]
        if let iconName, !iconName.isEmpty { payload["iconName"] = .string(iconName) }
        if let colorHex, !colorHex.isEmpty { payload["colorHex"] = .string(colorHex) }
        return try await invoke("create_section", payload: payload)
    }

    public func renameCourse(courseId: String, title: String) async throws -> [String: AnyJSON] {
        try await invoke("rename_course", payload: [
            "courseId": .string(courseId),
            "title": .string(title)
        ])
    }

    public func renameSection(sectionId: String, title: String) async throws -> [String: AnyJSON] {
        try await invoke("rename_section", payload: [
            "sectionId": .string(sectionId),
            "title": .string(title)
        ])
    }

    public func deleteCourse(_ courseId: String) async throws -> [String: AnyJSON] {
        try await invoke("delete_course", payload: ["courseId": .string(courseId)])
    }

    public func deleteSection(_ sectionId: String) async throws -> [String: AnyJSON] {
        try await invoke("delete_section", payload: ["sectionId": .string(sectionId)])
    }

    // MARK: - File Actions

    public func renameFile(fileId: String, title: String) async throws -> [String: AnyJSON] {
        try await invoke("rename_file", payload: [
            "fileId": .string(fileId),
            "title": .string(title)
        ])
    }

    public func moveFiles(fileIds: [String], courseId: String, sectionId: String) async throws -> [String: AnyJSON] {
        try await invoke("move_files", payload: [
            "fileIds": .array(fileIds.map { .string($0) }),
            "courseId": .string(courseId),
            "sectionId": .string(sectionId)
        ])
    }

    public func moveGeneratedOutput(outputId: String, courseId: String, sectionId: String) async throws -> [String: AnyJSON] {
        try await invoke("move_generated_output", payload: [
            "outputId": .string(outputId),
            "courseId": .string(courseId),
            "sectionId": .string(sectionId)
        ])
    }

    public func deleteFiles(_ fileIds: [String]) async throws -> [String: AnyJSON] {
        try await invoke("delete_files", payload: [
            "fileIds": .array(fileIds.map { .string($0) })
        ])
    }

    public func retryFileProcessing(_ fileId: String) async throws -> [String: AnyJSON] {
        try await invoke("retry_file_processing", payload: ["fileId": .string(fileId)])
    }

    public func addToCollection(fileId: String, outputId: String? = nil, collection: String? = nil) async throws -> [String: AnyJSON] {
        var payload: [String: AnyJSON] = [
            "fileIds": .array([.string(fileId)])
        ]
        if let outputId, !outputId.trimmingCharacters(in: .whitespaces).isEmpty {
            payload["outputId"] = .string(outputId.trimmingCharacters(in: .whitespaces))
        }
        if let collection, !collection.trimmingCharacters(in: .whitespaces).isEmpty {
            payload["collection"] = .string(collection.trimmingCharacters(in: .whitespaces))
        }
        return try await invoke("add_to_collection", payload: payload)
    }

    // MARK: - Generated Outputs

    public func createGeneratedOutput(
        fileId: String,
        kind: GeneratedKind,
        itemCount: Int? = nil,
        jobId: String? = nil
    ) async throws -> [String: AnyJSON] {
        try await createGeneratedOutputByKind(
            fileId: fileId,
            kind: kind.rawValue,
            itemCount: itemCount,
            jobId: jobId
        )
    }

    public func createGeneratedOutputByKind(
        fileId: String,
        kind: String,
        itemCount: Int? = nil,
        jobId: String? = nil
    ) async throws -> [String: AnyJSON] {
        var payload: [String: AnyJSON] = [
            "fileId": .string(fileId),
            "kind": .string(kind)
        ]
        if let itemCount {
            payload["itemCount"] = .integer(itemCount)
        }
        if let jobId, !jobId.trimmingCharacters(in: .whitespaces).isEmpty {
            payload["jobId"] = .string(jobId.trimmingCharacters(in: .whitespaces))
        }
        return try await invoke("create_generated_output", payload: payload)
    }

    // MARK: - Generation Jobs

    public func createGenerationJob(
        fileId: String,
        jobType: String,
        sourceIds: [String]? = nil,
        count: Int? = nil,
        qualityTier: String? = nil,
        options: [String: String]? = nil
    ) async throws -> [String: AnyJSON] {
        let payload = Self.generationJobPayload(
            fileId: fileId,
            jobType: jobType,
            sourceIds: sourceIds,
            count: count,
            qualityTier: qualityTier,
            options: options
        )
        return try await invoke("create_generation_job", payload: payload)
    }

    static func generationJobPayload(
        fileId: String,
        jobType: String,
        sourceIds: [String]? = nil,
        count: Int? = nil,
        qualityTier: String? = nil,
        options: [String: String]? = nil
    ) -> [String: AnyJSON] {
        var payload: [String: AnyJSON] = [
            "fileId": .string(fileId),
            "jobType": .string(jobType)
        ]
        if let sourceIds, !sourceIds.isEmpty {
            payload["sourceIds"] = .array(sourceIds.map { .string($0) })
        }
        if let count {
            payload["count"] = .integer(count)
        }

        for (key, value) in premiumGenerationOptions(
            jobType: jobType,
            qualityTier: qualityTier,
            options: options
        ) {
            payload[key] = .string(value)
        }

        return payload
    }

    private static func premiumGenerationOptions(
        jobType: String,
        qualityTier: String?,
        options: [String: String]?
    ) -> [String: String] {
        var enriched = cleanGenerationOptions(options)
        let requestedTier = firstNonEmpty(
            qualityTier,
            enriched["qualityTier"],
            enriched["quality_tier"]
        )
        let tier = normalizedGenerationQualityTier(requestedTier)
        let economy = tier == "economy"
        let standard = tier == "standard"
        let profile: String = {
            if economy { return "sourcebase_premium_efficient_generation_v3" }
            if standard { return "sourcebase_premium_balanced_generation_v3" }
            return "sourcebase_premium_plus_generation_v3"
        }()

        enriched["qualityTier"] = tier
        enriched["quality_tier"] = tier
        enriched["generationQualityProfile"] = profile
        enriched["generation_quality_profile"] = profile
        enriched["generationSchemaVersion"] = profile
        enriched["generation_schema_version"] = profile

        let modelPolicy = premiumModelPolicy(for: jobType, tier: tier)
        let minimumDepth = premiumMinimumDepth(for: jobType, tier: tier)
        let lengthPolicy = premiumOutputLengthPolicy(for: jobType, tier: tier)

        enriched["modelPolicy"] = modelPolicy
        enriched["model_policy"] = modelPolicy
        enriched["minimumDepth"] = minimumDepth
        enriched["minimum_depth"] = minimumDepth
        enriched["outputLengthPolicy"] = lengthPolicy
        enriched["output_length_policy"] = lengthPolicy

        enriched["qualityGate"] = "reject_thin_generic_single_paragraph_or_source_detached_output"
        enriched["quality_gate"] = "reject_thin_generic_single_paragraph_or_source_detached_output"
        enriched["reasoningPolicy"] = "source_grounded_clinical_reasoning_before_final_answer"
        enriched["reasoning_policy"] = "source_grounded_clinical_reasoning_before_final_answer"
        enriched["sourceGroundingPolicy"] = "strict_source_grounded_mark_source_gap_no_fabrication"
        enriched["source_grounding_policy"] = "strict_source_grounded_mark_source_gap_no_fabrication"
        enriched["sourceReadPolicy"] = "read_full_extracted_document_not_first_excerpt"
        enriched["source_read_policy"] = "read_full_extracted_document_not_first_excerpt"
        enriched["sourceCoveragePolicy"] = premiumSourceCoveragePolicy(for: jobType)
        enriched["source_coverage_policy"] = premiumSourceCoveragePolicy(for: jobType)
        enriched["sourceChunkPolicy"] = "adaptive_full_document_chunk_map_reduce_for_long_sources"
        enriched["source_chunk_policy"] = "adaptive_full_document_chunk_map_reduce_for_long_sources"
        enriched["largeSourcePolicy"] = "10_pages_read_all_200_pages_chunk_index_all_sections_then_synthesize"
        enriched["large_source_policy"] = "10_pages_read_all_200_pages_chunk_index_all_sections_then_synthesize"
        enriched["ocrPolicy"] = "use_ocr_text_for_scanned_pdf_or_low_text_density_slide_pages_before_generation"
        enriched["ocr_policy"] = "use_ocr_text_for_scanned_pdf_or_low_text_density_slide_pages_before_generation"
        enriched["modelRouterPolicy"] = premiumModelRouterPolicy(for: jobType)
        enriched["model_router_policy"] = premiumModelRouterPolicy(for: jobType)
        enriched["preferredModelTier"] = premiumPreferredModelTier(for: jobType, tier: tier)
        enriched["preferred_model_tier"] = premiumPreferredModelTier(for: jobType, tier: tier)
        enriched["modelUpgradeAllowed"] = "true"
        enriched["model_upgrade_allowed"] = "true"
        enriched["pedagogyPolicy"] = "high_yield_active_recall_misconception_first"
        enriched["pedagogy_policy"] = "high_yield_active_recall_misconception_first"
        enriched["learningSciencePolicy"] = premiumLearningSciencePolicy(for: jobType)
        enriched["learning_science_policy"] = premiumLearningSciencePolicy(for: jobType)
        enriched["retrievalPracticePolicy"] = "force_commit_before_answer_with_self_check_or_questions"
        enriched["retrieval_practice_policy"] = "force_commit_before_answer_with_self_check_or_questions"
        enriched["spacedReviewPolicy"] = "include_today_24h_72h_7d_review_prompts_when_applicable"
        enriched["spaced_review_policy"] = "include_today_24h_72h_7d_review_prompts_when_applicable"
        enriched["clinicalReasoningPolicy"] = "problem_representation_differential_justification_red_flags_and_management_frame"
        enriched["clinical_reasoning_policy"] = "problem_representation_differential_justification_red_flags_and_management_frame"
        enriched["studentOutcomeContract"] = premiumStudentOutcomeContract(for: jobType)
        enriched["student_outcome_contract"] = premiumStudentOutcomeContract(for: jobType)
        enriched["antiCrutchPolicy"] = "do_not_skip_reasoning_do_not_spoonfeed_final_answer_without_check_step"
        enriched["anti_crutch_policy"] = "do_not_skip_reasoning_do_not_spoonfeed_final_answer_without_check_step"
        enriched["clinicalSafetyPolicy"] = "educational_not_diagnostic_warn_on_uncertain_or_unsafe_claims"
        enriched["clinical_safety_policy"] = "educational_not_diagnostic_warn_on_uncertain_or_unsafe_claims"
        enriched["languagePolicy"] = "clear_turkish_medical_student_level_no_filler"
        enriched["language_policy"] = "clear_turkish_medical_student_level_no_filler"
        enriched["structurePolicy"] = premiumStructurePolicy(for: jobType)
        enriched["structure_policy"] = premiumStructurePolicy(for: jobType)
        enriched["mustInclude"] = premiumMustInclude(for: jobType)
        enriched["must_include"] = premiumMustInclude(for: jobType)
        enriched["qualityChecklist"] = premiumQualityChecklist(for: jobType)
        enriched["quality_checklist"] = premiumQualityChecklist(for: jobType)
        enriched["studyWorkspaceSchema"] = premiumStudyWorkspaceSchema(for: jobType)
        enriched["study_workspace_schema"] = premiumStudyWorkspaceSchema(for: jobType)
        enriched["renderingContract"] = premiumRenderingContract(for: jobType)
        enriched["rendering_contract"] = premiumRenderingContract(for: jobType)
        if enriched["outputContract"] == nil {
            enriched["outputContract"] = premiumOutputContract(for: jobType)
        }
        if enriched["output_contract"] == nil {
            enriched["output_contract"] = enriched["outputContract"] ?? premiumOutputContract(for: jobType)
        }
        enriched["resultRouteContract"] = "create_or_reuse_generated_output_then_route_to_study_output"
        enriched["result_route_contract"] = "create_or_reuse_generated_output_then_route_to_study_output"
        enriched["ctaContract"] = "primary_cta_opens_typed_study_output_secondary_cta_returns_to_source_or_queue"
        enriched["cta_contract"] = "primary_cta_opens_typed_study_output_secondary_cta_returns_to_source_or_queue"
        enriched["finalQualityReview"] = "verify_not_plain_text_verify_schema_fields_verify_source_grounding_verify_mobile_renderability"
        enriched["final_quality_review"] = "verify_not_plain_text_verify_schema_fields_verify_source_grounding_verify_mobile_renderability"
        enriched["thinOutputRecovery"] = "if_output_is_short_or_generic_expand_before_returning"
        enriched["thin_output_recovery"] = "if_output_is_short_or_generic_expand_before_returning"
        enriched["reviewBeforeReturn"] = "true"
        enriched["review_before_return"] = "true"

        switch normalizedGenerationJobType(jobType) {
        case "podcast":
            enriched["audioAssetRequired"] = enriched["audioAssetRequired"] ?? "true"
            enriched["audio_asset_required"] = enriched["audio_asset_required"] ?? "true"
            enriched["audioFormat"] = enriched["audioFormat"] ?? "m4a_or_mp3_exportable"
            enriched["audio_format"] = enriched["audio_format"] ?? "m4a_or_mp3_exportable"
        case "infographic":
            let imageModel = premiumImageModel(for: tier)
            let imageQuality = premiumImageQuality(for: tier)
            enriched["visualAssetRequired"] = enriched["visualAssetRequired"] ?? "true"
            enriched["visual_asset_required"] = enriched["visual_asset_required"] ?? "true"
            enriched["assetFallbackPolicy"] = enriched["assetFallbackPolicy"] ?? "structured_text_blocks_when_image_unavailable"
            enriched["asset_fallback_policy"] = enriched["asset_fallback_policy"] ?? "structured_text_blocks_when_image_unavailable"
            enriched["imageModelPolicy"] = imageModel
            enriched["image_model_policy"] = imageModel
            enriched["gptImageModel"] = imageModel
            enriched["gpt_image_model"] = imageModel
            enriched["openaiImageModel"] = imageModel
            enriched["openai_image_model"] = imageModel
            enriched["imageQuality"] = imageQuality
            enriched["image_quality"] = imageQuality
            enriched["visualReadabilityPolicy"] = enriched["visualReadabilityPolicy"] ?? "large_clear_labels_mobile_readable_no_tiny_text"
            enriched["visual_readability_policy"] = enriched["visual_readability_policy"] ?? "large_clear_labels_mobile_readable_no_tiny_text"
        default:
            break
        }

        if enriched["backendQualityBrief"] == nil {
            enriched["backendQualityBrief"] = premiumBackendBrief(for: jobType)
        }
        if enriched["backend_quality_brief"] == nil {
            enriched["backend_quality_brief"] = premiumBackendBrief(for: jobType)
        }

        return enriched
    }

    private static func cleanGenerationOptions(_ options: [String: String]?) -> [String: String] {
        guard let options else { return [:] }
        return options.reduce(into: [String: String]()) { partial, pair in
            let key = pair.key.trimmingCharacters(in: .whitespacesAndNewlines)
            let value = pair.value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty, !value.isEmpty else { return }
            partial[key] = value
        }
    }

    private static func firstNonEmpty(_ values: String?...) -> String? {
        values
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }

    private static func normalizedGenerationQualityTier(_ rawValue: String?) -> String {
        let value = rawValue?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        if value.contains("economy")
            || value.contains("economic")
            || value.contains("ekonomik")
            || value.contains("ucuz")
            || value.contains("cost_saver") {
            return "economy"
        }
        if value.contains("standard")
            || value.contains("standart") {
            return "standard"
        }
        return "premium"
    }

    private static func premiumImageModel(for tier: String) -> String {
        switch tier {
        case "economy":
            return "gpt-image-1-mini"
        case "standard":
            return "gpt-image-1.5"
        default:
            return "gpt-image-2"
        }
    }

    private static func premiumImageQuality(for tier: String) -> String {
        switch tier {
        case "economy":
            return "low"
        case "standard":
            return "standard"
        default:
            return "premium"
        }
    }

    private static func premiumModelPolicy(for jobType: String, tier: String = "premium") -> String {
        if tier == "economy" {
            return premiumEfficientModelPolicy(for: jobType)
        }
        if tier == "standard" {
            return premiumBalancedModelPolicy(for: jobType)
        }
        switch normalizedGenerationJobType(jobType) {
        case "quiz", "question":
            return "premium_latest_long_context_assessment_quality_first"
        case "clinical_scenario":
            return "premium_latest_long_context_clinical_reasoning_first"
        case "infographic":
            return "premium_latest_long_context_visual_quality_first"
        case "podcast":
            return "premium_latest_long_context_longform_learning_quality"
        case "flashcard":
            return "premium_latest_long_context_active_recall_quality_first"
        case "comparison", "table":
            return "premium_latest_long_context_matrix_reasoning_first"
        case "summary", "exam_morning_summary":
            return "premium_latest_long_context_summary_synthesis_first"
        case "learning_plan":
            return "premium_latest_long_context_adaptive_study_planning"
        default:
            return "premium_latest_long_context_structured_reasoning_first"
        }
    }

    private static func premiumEfficientModelPolicy(for jobType: String) -> String {
        switch normalizedGenerationJobType(jobType) {
        case "quiz", "question":
            return "premium_efficient_long_context_assessment_quality_first"
        case "clinical_scenario":
            return "premium_efficient_long_context_clinical_reasoning_first"
        case "infographic":
            return "premium_efficient_long_context_visual_quality_first"
        case "podcast":
            return "premium_efficient_long_context_longform_learning_quality"
        case "flashcard":
            return "premium_efficient_long_context_active_recall_quality_first"
        case "comparison", "table":
            return "premium_efficient_long_context_matrix_reasoning_first"
        case "summary", "exam_morning_summary":
            return "premium_efficient_long_context_summary_synthesis_first"
        case "learning_plan":
            return "premium_efficient_long_context_adaptive_study_planning"
        default:
            return "premium_efficient_long_context_structured_reasoning_first"
        }
    }

    private static func premiumBalancedModelPolicy(for jobType: String) -> String {
        switch normalizedGenerationJobType(jobType) {
        case "quiz", "question":
            return "premium_balanced_long_context_assessment_quality_first"
        case "clinical_scenario":
            return "premium_balanced_long_context_clinical_reasoning_first"
        case "infographic":
            return "premium_balanced_long_context_visual_quality_first"
        case "podcast":
            return "premium_balanced_long_context_longform_learning_quality"
        case "flashcard":
            return "premium_balanced_long_context_active_recall_quality_first"
        case "comparison", "table":
            return "premium_balanced_long_context_matrix_reasoning_first"
        case "summary", "exam_morning_summary":
            return "premium_balanced_long_context_summary_synthesis_first"
        case "learning_plan":
            return "premium_balanced_long_context_adaptive_study_planning"
        default:
            return "premium_balanced_long_context_structured_reasoning_first"
        }
    }

    private static func premiumSourceCoveragePolicy(for jobType: String) -> String {
        switch normalizedGenerationJobType(jobType) {
        case "comparison", "table":
            return "all_selected_sources_all_sections_tables_middle_end_and_conclusions"
        case "quiz", "question":
            return "all_testable_objectives_tables_figures_common_misconceptions_and_edge_cases"
        case "flashcard":
            return "all_core_concepts_definitions_mechanisms_tables_figures_and_common_mistakes"
        case "algorithm":
            return "all_decision_points_thresholds_exceptions_red_flags_and_actions"
        case "clinical_scenario":
            return "full_case_relevant_source_findings_labs_decisions_differential_and_safety_limits"
        case "podcast":
            return "full_source_episode_arc_beginning_middle_end_tables_and_recap"
        case "infographic":
            return "full_source_visual_hierarchy_warnings_main_message_and_text_fallback"
        case "learning_plan":
            return "full_source_objectives_weak_points_sessions_reviews_and_gap_closure"
        case "mind_map":
            return "full_source_branches_cross_links_confusions_and_clinical_ties"
        default:
            return "full_source_beginning_middle_end_headings_tables_conclusions_red_flags_and_self_check"
        }
    }

    private static func premiumModelRouterPolicy(for jobType: String) -> String {
        switch normalizedGenerationJobType(jobType) {
        case "comparison", "table", "clinical_scenario", "podcast", "infographic":
            return "route_large_or_sparse_sources_to_long_context_high_reasoning_model"
        default:
            return "route_to_long_context_reasoning_when_source_or_quality_requires_it"
        }
    }

    private static func premiumPreferredModelTier(for jobType: String, tier: String = "premium") -> String {
        if tier == "economy" {
            return "latest_premium_efficient_long_context"
        }
        if tier == "standard" {
            return "latest_premium_balanced_long_context"
        }
        switch normalizedGenerationJobType(jobType) {
        case "comparison", "table", "clinical_scenario", "podcast", "infographic":
            return "latest_premium_high_reasoning_long_context"
        default:
            return "latest_premium_reasoning_long_context"
        }
    }

    private static func premiumMinimumDepth(for jobType: String, tier: String = "premium") -> String {
        if tier == "economy" {
            switch normalizedGenerationJobType(jobType) {
            case "comparison", "table":
                return "efficient_full_source_matrix_deep"
            case "clinical_scenario":
                return "efficient_clinical_deep_with_differential"
            case "quiz", "question":
                return "efficient_assessment_deep_with_distractor_rationales"
            case "infographic":
                return "efficient_visual_detailed_with_text_fallback"
            case "podcast":
                return "efficient_longform_deep_segmented"
            default:
                return "premium_efficient_deep_with_gap_analysis"
            }
        }
        if tier == "standard" {
            switch normalizedGenerationJobType(jobType) {
            case "comparison", "table":
                return "balanced_full_source_matrix_deep"
            case "clinical_scenario":
                return "balanced_clinical_deep_with_differential"
            case "quiz", "question":
                return "balanced_assessment_deep_with_distractor_rationales"
            case "infographic":
                return "balanced_visual_detailed_with_text_fallback"
            case "podcast":
                return "balanced_longform_deep_segmented"
            default:
                return "premium_balanced_deep"
            }
        }
        switch normalizedGenerationJobType(jobType) {
        case "clinical_scenario":
            return "clinical_deep_with_differential"
        case "quiz", "question":
            return "assessment_deep_with_distractor_rationales"
        case "infographic":
            return "visual_detailed_with_text_fallback"
        case "podcast":
            return "longform_deep_segmented"
        case "comparison", "table":
            return "full_source_matrix_deep"
        default:
            return "premium_deep"
        }
    }

    private static func premiumOutputLengthPolicy(for jobType: String, tier: String = "premium") -> String {
        if tier == "economy" {
            switch normalizedGenerationJobType(jobType) {
            case "flashcard", "quiz", "question":
                return "complete_set_compact_explanations_not_short"
            case "podcast":
                return "compact_longform_complete_not_padded"
            default:
                return "compact_structured_but_complete"
            }
        }
        if tier == "standard" {
            switch normalizedGenerationJobType(jobType) {
            case "flashcard", "quiz", "question":
                return "complete_set_balanced_explanations_not_short"
            case "podcast":
                return "balanced_longform_complete_not_padded"
            default:
                return "balanced_comprehensive_structured_not_short"
            }
        }
        switch normalizedGenerationJobType(jobType) {
        case "podcast":
            return "longform_comprehensive_not_padded"
        case "flashcard", "quiz", "question":
            return "complete_set_not_short"
        default:
            return "comprehensive_structured_not_short"
        }
    }

    private static func premiumStructurePolicy(for jobType: String) -> String {
        switch normalizedGenerationJobType(jobType) {
        case "flashcard":
            return "atomic_cards_grouped_by_concept_with_hint_and_common_mistake"
        case "quiz", "question":
            return "five_choice_questions_hidden_answer_rationales_and_traps"
        case "summary", "exam_morning_summary":
            return "scan_ready_sections_tables_red_flags_and_quick_check"
        case "algorithm":
            return "mobile_decision_nodes_with_red_flags_and_exit_actions"
        case "comparison", "table":
            return "full_source_same_criteria_matrix_with_source_coverage_refs_distinguishing_clues_and_exam_traps"
        case "clinical_scenario":
            return "case_stem_findings_differential_decision_points_feedback"
        case "learning_plan":
            return "time_blocks_spaced_repetition_measurement_and_gap_closure"
        case "podcast":
            return "episode_segments_spoken_script_recap_and_recall_prompts"
        case "infographic":
            return "visual_blocks_main_message_warnings_source_note_text_fallback"
        case "mind_map":
            return "central_concept_branches_links_confusions_and_clinical_ties"
        default:
            return "clear_sections_key_takeaways_and_recovery_prompts"
        }
    }

    private static func premiumMustInclude(for jobType: String) -> String {
        switch normalizedGenerationJobType(jobType) {
        case "flashcard":
            return "front,back,hint,explanation,common_mistake,concept_group"
        case "quiz", "question":
            return "5_options,single_correct_answer,wrong_option_rationales,source_grounded_explanation,qlinik_candidate_schema"
        case "summary", "exam_morning_summary":
            return "high_yield_points,common_confusions,red_flags,mini_table,final_self_check"
        case "algorithm":
            return "entry_criteria,decision_nodes,yes_no_or_step_flow,warning_points,exit_actions"
        case "comparison", "table":
            return "source_coverage,minimum_8_aligned_criteria_or_source_gap,source_refs,distinguishing_clues,clinical_exam_traps,short_takeaway"
        case "clinical_scenario":
            return "patient_snapshot,critical_findings,differential_diagnosis,decision_points,teaching_feedback"
        case "learning_plan":
            return "time_blocks,spaced_review,mini_assessment,gap_closure_tasks"
        case "podcast":
            return "segments,spoken_script,key_repeats,recap,source_limits"
        case "infographic":
            return "main_message,at_least_5_blocks,warnings,source_note,structured_text_fallback"
        case "mind_map":
            return "central_concept,at_least_4_branches,child_nodes,confusions,cross_links"
        default:
            return "source_summary,key_points,misconceptions,next_action"
        }
    }

    private static func premiumQualityChecklist(for jobType: String) -> String {
        let common = "source_grounded;no_hallucination;not_generic;clinically_safe;mobile_scannable;active_recall;spaced_review_prompt;source_gap_visible"
        switch normalizedGenerationJobType(jobType) {
        case "quiz", "question":
            return "\(common);5_options;answer_hidden_until_solution;all_distractors_explained"
        case "flashcard":
            return "\(common);atomic_cards;active_recall;common_mistake_per_cluster"
        case "clinical_scenario":
            return "\(common);differential_reasoning;red_flags;feedback"
        case "infographic":
            return "\(common);visual_or_text_fallback;at_least_5_blocks"
        case "comparison", "table":
            return "\(common);full_source_read;minimum_8_criteria_or_gap;source_refs;not_intro_only"
        default:
            return "\(common);full_source_read;enough_depth_for_paid_output"
        }
    }

    private static func premiumBackendBrief(for jobType: String) -> String {
        "Produce a premium SourceBase output for \(normalizedGenerationJobType(jobType)): read the full extracted document, never rely only on the intro or first excerpt, use OCR text for scanned or low-text-density pages, and for long decks/documents chunk-map-reduce across beginning, middle, end, tables, figures, headings, and conclusions. Route to a long-context reasoning model when the source is large or the first pass is thin. Identify gaps and likely misconceptions, stay strictly grounded in the source, mark missing evidence instead of inventing, and return typed JSON blocks for the interactive study workspace. Every output must help a medical student actively retrieve, review later, and connect facts to clinical reasoning: include recall prompts, common traps, review timing, source gaps, and when relevant problem representation, differential diagnosis, diagnostic justification, red flags, and management framing. Expand the result before returning if it feels thin, generic, single-paragraph, or impossible to render as visual study cards."
    }

    private static func premiumLearningSciencePolicy(for jobType: String) -> String {
        switch normalizedGenerationJobType(jobType) {
        case "flashcard":
            return "retrieval_practice_atomic_cards_spaced_review_common_mistake_feedback"
        case "quiz", "question":
            return "test_enhanced_learning_five_choice_commitment_rationales_error_correction"
        case "clinical_scenario":
            return "case_based_clinical_reasoning_problem_representation_differential_justification_feedback"
        case "learning_plan":
            return "spaced_practice_interleaving_retrieval_checkpoints_gap_closure"
        case "podcast":
            return "dual_coding_audio_recap_retrieval_pauses_and_later_review_prompts"
        case "infographic", "mind_map":
            return "dual_coding_visual_hierarchy_active_recall_and_common_confusion_links"
        default:
            return "spaced_practice_retrieval_practice_interleaving_elaboration_dual_coding_concrete_examples"
        }
    }

    private static func premiumStudentOutcomeContract(for jobType: String) -> String {
        switch normalizedGenerationJobType(jobType) {
        case "flashcard":
            return "student_can_cover_answer_recall_explain_common_mistake_and_schedule_next_review"
        case "quiz", "question":
            return "student_commits_to_answer_receives_rationale_reviews_wrong_options_and_knows_weak_topic"
        case "clinical_scenario":
            return "student_forms_problem_representation_lists_differential_justifies_top_diagnosis_and_names_red_flags"
        case "learning_plan":
            return "student_knows_what_to_do_today_next_24h_72h_7d_and_how_to_measure_progress"
        case "comparison", "table":
            return "student_can_distinguish_entities_by_same_criteria_exam_traps_source_refs_and_red_flags"
        case "algorithm":
            return "student_can_enter_from_symptom_or_finding_follow_decisions_and_stop_at_red_flags"
        case "podcast":
            return "student_can_list_key_points_after_listening_answer_recall_prompts_and_export_audio"
        case "infographic":
            return "student_can_scan_main_message_warnings_blocks_and_quick_check_without_plain_text_dump"
        case "mind_map":
            return "student_can_explain_central_concept_branches_cross_links_and_common_confusions"
        default:
            return "student_can_study_actively_review_later_identify_gaps_and_verify_source_grounding"
        }
    }

    private static func premiumStudyWorkspaceSchema(for jobType: String) -> String {
        switch normalizedGenerationJobType(jobType) {
        case "flashcard":
            return "cards[{front,back,hint,explanation,difficulty,concept_group,common_mistake}],summary,source_gaps"
        case "quiz", "question":
            return "questions[{text,options[5],correct_index,explanation,option_rationales[5],topic,difficulty,tags}],summary,source_gaps"
        case "summary", "exam_morning_summary":
            return "summary,high_yield_points,must_know,commonly_confused,red_flags,mini_table{headers,rows},clinicalDecisionFlow,self_check,next_review_prompts,source_gaps"
        case "algorithm":
            return "starting_point,decision_nodes[{title,detail,yes,no,substeps}],action_steps,critical_thresholds,red_flags,exam_tips,source_gaps"
        case "comparison", "table":
            return "title,summary,source_coverage,headers,criteria,rows[{criterion,values,distinguishing_tip,exam_trap,source_refs}],distinguishing_tips,clinical_notes,commonly_confused,red_flags,short_takeaway,source_gaps"
        case "clinical_scenario":
            return "patientInfo,chiefComplaint,caseStem,physicalExam,labsImaging,problemRepresentation,findings,differentialDiagnosis,diagnosticJustification,decision_nodes,questions,red_flags,teachingPoints,examTips"
        case "learning_plan":
            return "duration,sessions[{title,estimatedMinutes,activities}],startToday,dailyGoals,checklist,reviewDays,next_review_prompts,weakPoints,objectives,questionFlashcardSuggestions"
        case "podcast":
            return "title,durationLabel,audio_url_optional,segments[{title,text,durationLabel}],recap,active_recall_prompts,source_limits"
        case "infographic":
            return "title,main_message,image_url_optional,sections[{heading,bullets}],warnings,red_flags,source_note,quick_check"
        case "mind_map":
            return "centralTopic,summary,branches[{label,children,tags}],criticalConnections,commonly_confused,clinicalTusTips,source_gaps"
        default:
            return "summary,sections,high_yield_points,red_flags,self_check,source_gaps"
        }
    }

    private static func premiumRenderingContract(for jobType: String) -> String {
        "Return structured JSON for SourceBase interactive study surfaces, not plain prose. The app renders Learn, Flow, and Check layers; include enough typed fields to populate visual cards, tables, timelines, decision nodes, and active-recall controls for \(normalizedGenerationJobType(jobType)). Shallow first-excerpt answers, underfilled cards, and generic two-row tables must be expanded or rejected before return."
    }

    private static func premiumOutputContract(for jobType: String) -> String {
        switch normalizedGenerationJobType(jobType) {
        case "flashcard":
            return "Return cards[{front,back,hint,explanation,difficulty,concept_group,common_mistake}], summary, source_gaps. Minimum 20 atomic cards unless source is genuinely smaller and source_gaps explains why."
        case "quiz", "question":
            return "Return questions[{text,options[5],correct_index,explanation,option_rationales[5],topic,difficulty,tags}], summary, source_gaps. Every distractor must be plausible and explained."
        case "summary", "exam_morning_summary":
            return "Return summary, high_yield_points, must_know, commonly_confused, red_flags, mini_table{headers,rows}, clinicalDecisionFlow, self_check, next_review_prompts, source_gaps. Never return a single paragraph only."
        case "algorithm":
            return "Return starting_point, decision_nodes[{title,detail,yes,no,substeps}], action_steps, critical_thresholds, red_flags, exam_tips, notes, source_gaps."
        case "comparison", "table":
            return "Return title, summary, source_coverage, headers, rows[{criterion,values,distinguishing_tip,exam_trap,source_refs}], distinguishing_tips, clinical_notes, commonly_confused, red_flags, short_takeaway, source_gaps. At least 8 aligned criteria or explain the source gap."
        case "clinical_scenario":
            return "Return patientInfo, chiefComplaint, caseStem, physicalExam, labsImaging, problemRepresentation, findings, differentialDiagnosis, diagnosticJustification, decision_nodes, questions, red_flags, teachingPoints, examTips."
        case "learning_plan":
            return "Return duration, sessions[{title,estimatedMinutes,activities}], startToday, dailyGoals, checklist, reviewDays, next_review_prompts, weakPoints, objectives, questionFlashcardSuggestions."
        case "podcast":
            return "Return title, durationLabel, audio_url when available, segments[{title,text,durationLabel}], recap, active_recall_prompts, source_limits. If audio is delayed, full transcript is still required."
        case "infographic":
            return "Return title, main_message, image_url when available, sections[{heading,bullets}], warnings, red_flags, source_note, quick_check. If image fails, structured text blocks are required."
        case "mind_map":
            return "Return centralTopic, summary, branches[{label,children,tags}], criticalConnections, commonly_confused, clinicalTusTips, source_gaps."
        default:
            return "Return structured SourceBase study JSON with summary, typed sections, active recall, source gaps, and no plain prose only."
        }
    }

    private static func normalizedGenerationJobType(_ jobType: String) -> String {
        jobType
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
    }

    public func getJobStatus(_ jobId: String) async throws -> [String: AnyJSON] {
        try await invoke("get_job_status", payload: ["jobId": .string(jobId)])
    }

    public func processGenerationJob(_ jobId: String) async throws -> [String: AnyJSON] {
        // The server processes generation synchronously inside this call and the
        // edge worker stays alive up to ~5 min. Keep the connection open well past
        // any realistic generation (text/image/podcast-TTS) so the worker is never
        // killed for idleness mid-generation and we receive the real result.
        try await invoke("process_generation_job", payload: ["jobId": .string(jobId)], timeoutSeconds: 320)
    }

    public func getGeneratedContent(_ jobId: String) async throws -> [String: AnyJSON] {
        try await invoke("get_generated_content", payload: ["jobId": .string(jobId)])
    }

    public func estimateGenerationCost(
        jobType: String,
        sourceTextLength: Int? = nil,
        count: Int? = nil,
        qualityTier: String? = nil,
        options: [String: String]? = nil
    ) async throws -> [String: AnyJSON] {
        let payload = Self.estimateGenerationCostPayload(
            jobType: jobType,
            sourceTextLength: sourceTextLength,
            count: count,
            qualityTier: qualityTier,
            options: options
        )
        return try await invoke("estimate_generation_cost", payload: payload)
    }

    static func estimateGenerationCostPayload(
        jobType: String,
        sourceTextLength: Int? = nil,
        count: Int? = nil,
        qualityTier: String? = nil,
        options: [String: String]? = nil
    ) -> [String: AnyJSON] {
        var payload: [String: AnyJSON] = ["jobType": .string(jobType)]
        if let sourceTextLength {
            payload["sourceTextLength"] = .integer(sourceTextLength)
        }
        if let count {
            payload["count"] = .integer(count)
        }

        for (key, value) in premiumGenerationOptions(
            jobType: jobType,
            qualityTier: qualityTier,
            options: options
        ) {
            payload[key] = .string(value)
        }

        return payload
    }

    public func listUserJobs(limit: Int? = nil) async throws -> [String: AnyJSON] {
        var payload: [String: AnyJSON] = [:]
        if let limit {
            payload["limit"] = .integer(limit)
        }
        return try await invoke("list_user_jobs", payload: payload)
    }

    public func cancelJob(_ jobId: String) async throws -> [String: AnyJSON] {
        try await invoke("cancel_job", payload: ["jobId": .string(jobId)])
    }

    public func retryJob(_ jobId: String) async throws -> [String: AnyJSON] {
        try await invoke("retry_job", payload: ["jobId": .string(jobId)])
    }

    public func purchaseMedasiCoin(
        productCode: String,
        successURL: String,
        cancelURL: String
    ) async throws -> [String: AnyJSON] {
        try await invoke("purchase_medasicoin", payload: [
            "product_code": .string(productCode),
            "success_url": .string(successURL),
            "cancel_url": .string(cancelURL)
        ])
    }

    /// Redeem a verified StoreKit 2 transaction on the backend.
    /// Returns the updated wallet balance in MC.
    public func redeemAppStorePurchase(
        transactionId: String,
        productId: String,
        jws: String
    ) async throws -> Double {
        let response = try await invoke("redeem_appstore_purchase", payload: [
            "transactionId": .string(transactionId),
            "productId": .string(productId),
            "jws": .string(jws)
        ])
        // Extract wallet_balance from response data
        if case .object(let data) = response["data"],
           let balanceValue = data["wallet_balance"] {
            switch balanceValue {
            case .double(let d): return d
            case .integer(let i): return Double(i)
            case .string(let s): return Double(s) ?? 0
            default: break
            }
        }
        return 0
    }

    // MARK: - Storage quota / subscriptions

    /// Current storage usage + effective quota (free 25 GB + active subscriptions).
    public func storageStatus() async throws -> SBStorageStatus {
        let response = try await invoke("get_storage_status", payload: [:])
        return Self.parseStorageStatus(response["data"])
    }

    /// Redeem a verified StoreKit 2 storage subscription; returns the updated quota.
    public func redeemStorageSubscription(jws: String) async throws -> SBStorageStatus {
        let response = try await invoke("redeem_storage_subscription", payload: [
            "jws": .string(jws)
        ])
        return Self.parseStorageStatus(response["data"])
    }

    private static func parseStorageStatus(_ data: AnyJSON?) -> SBStorageStatus {
        guard let dict = data?.dictValue else { return .empty }
        func bytes(_ key: String) -> Int {
            if let i = dict[key]?.intValue { return i }
            if let d = dict[key]?.doubleValue { return Int(d) }
            return 0
        }
        let plans = (dict["plans"]?.arrayValue ?? []).compactMap { item -> SBStoragePlan? in
            guard let row = item.dictValue else { return nil }
            let code = row["product_code"]?.stringValue ?? ""
            guard !code.isEmpty else { return nil }
            let bonus = row["bonus_bytes"]?.intValue ?? row["bonus_bytes"]?.doubleValue.map(Int.init) ?? 0
            return SBStoragePlan(productCode: code, bonusBytes: bonus, expiresAt: row["expires_at"]?.stringValue)
        }
        let base = bytes("baseBytes")
        let bonus = bytes("bonusBytes")
        let total = bytes("totalBytes")
        return SBStorageStatus(
            usedBytes: bytes("usedBytes"),
            baseBytes: base,
            bonusBytes: bonus,
            totalBytes: total > 0 ? total : base + bonus,
            plans: plans
        )
    }

    // MARK: - Study Sessions

    public func sourcebaseQuestionSession(outputId: String) async throws -> [String: AnyJSON] {
        try await invoke("sourcebase_question_session", payload: [
            "outputId": .string(outputId)
        ])
    }

    public func submitSourcebaseQuestionAnswer(
        outputId: String,
        questionId: String,
        selectedIndex: Int,
        elapsedSeconds: Int? = nil
    ) async throws -> [String: AnyJSON] {
        let payload = Self.questionAnswerPayload(
            outputId: outputId,
            questionId: questionId,
            selectedIndex: selectedIndex,
            elapsedSeconds: elapsedSeconds
        )
        return try await invoke("submit_sourcebase_question_answer", payload: payload)
    }

    public static func questionAnswerPayload(
        outputId: String,
        questionId: String,
        selectedIndex: Int,
        elapsedSeconds: Int? = nil
    ) -> [String: AnyJSON] {
        var payload: [String: AnyJSON] = [
            "outputId": .string(outputId),
            "questionId": .string(questionId),
            "selectedIndex": .integer(selectedIndex)
        ]
        if let elapsedSeconds {
            payload["elapsedSeconds"] = .integer(elapsedSeconds)
        }
        return payload
    }

    // MARK: - Generated Assets

    public func generatedAssetURL(assetPath: String, outputId: String? = nil) async throws -> [String: AnyJSON] {
        var payload: [String: AnyJSON] = ["assetPath": .string(assetPath)]
        if let outputId, !outputId.trimmingCharacters(in: .whitespaces).isEmpty {
            payload["outputId"] = .string(outputId)
        }
        return try await invoke("get_generated_asset_url", payload: payload)
    }

    // MARK: - Profile Assets & Support

    public func createProfileAvatarUploadSession(
        fileName: String,
        contentType: String,
        sizeBytes: Int
    ) async throws -> StorageUploadSession {
        let response = try await invoke(
            "create_profile_avatar_upload_session",
            payload: Self.profileAvatarUploadPayload(
                fileName: fileName,
                contentType: contentType,
                sizeBytes: sizeBytes
            )
        )
        guard case .object(let dataDict) = response["data"] else {
            throw DriveAPIError(message: "Avatar upload session response is empty.", code: nil, status: nil)
        }
        let jsonData = try JSONEncoder().encode(dataDict)
        return try JSONDecoder().decode(StorageUploadSession.self, from: jsonData)
    }

    public static func profileAvatarUploadPayload(
        fileName: String,
        contentType: String,
        sizeBytes: Int
    ) -> [String: AnyJSON] {
        [
            "fileName": .string(fileName),
            "contentType": .string(contentType),
            "sizeBytes": .integer(sizeBytes)
        ]
    }

    public func completeProfileAvatarUpload(objectName: String) async throws -> [String: AnyJSON] {
        try await invoke("complete_profile_avatar_upload", payload: [
            "objectName": .string(objectName)
        ])
    }

    public func submitSupportForm(
        topic: String,
        email: String,
        message: String
    ) async throws -> [String: AnyJSON] {
        try await invoke("submit_support_form", payload: Self.supportFormPayload(
            topic: topic,
            email: email,
            message: message
        ))
    }

    public static func supportFormPayload(
        topic: String,
        email: String,
        message: String
    ) -> [String: AnyJSON] {
        [
            "topic": .string(topic.trimmingCharacters(in: .whitespacesAndNewlines)),
            "email": .string(email.trimmingCharacters(in: .whitespacesAndNewlines)),
            "message": .string(message.trimmingCharacters(in: .whitespacesAndNewlines))
        ]
    }

    // MARK: - Central AI

    public func centralAiChat(
        _ message: String,
        context: String? = nil,
        fileIds: [String]? = nil
    ) async throws -> [String: AnyJSON] {
        var payload: [String: AnyJSON] = ["message": .string(message)]

        if let context, !context.trimmingCharacters(in: .whitespaces).isEmpty {
            payload["context"] = .string(context.trimmingCharacters(in: .whitespaces))
        }
        if let fileIds {
            let clean = Array(Set(fileIds
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            ))
            if !clean.isEmpty {
                payload["fileIds"] = .array(clean.map { .string($0) })
            }
        }

        return try await invoke("central_ai_chat", payload: payload)
    }

    public func requestAccountDeletion() async throws -> [String: AnyJSON] {
        try await invoke("request_account_deletion")
    }
}

private struct DriveAPITimeoutError: Error, LocalizedError {
    var errorDescription: String? {
        "SourceBase request timed out."
    }
}

private func withDriveAPITimeout<T: Sendable>(
    seconds: UInt64 = 90,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        group.addTask {
            try await Task.sleep(nanoseconds: seconds * 1_000_000_000)
            throw DriveAPITimeoutError()
        }
        guard let result = try await group.next() else {
            throw DriveAPITimeoutError()
        }
        group.cancelAll()
        return result
    }
}
```

## File: Sources/SourceBaseBackend/Drive/DriveModels.swift
```swift
import Foundation
import Supabase

public struct ExtractionMetadata: Sendable, Codable {
    public let charCount: Int
    public let wordCount: Int
    public let extractedAt: Date

    public init(charCount: Int, wordCount: Int, extractedAt: Date) {
        self.charCount = charCount
        self.wordCount = wordCount
        self.extractedAt = extractedAt
    }
}

// MARK: - Enums

public enum DriveFileKind: String, Codable, Sendable, CaseIterable {
    case pdf, pptx, docx, ppt, doc, zip
}

public enum DriveItemStatus: String, Codable, Sendable {
    case completed, processing, uploading, failed, draft
}

public enum GenerationJobPhase: String, Codable, Sendable, Equatable {
    case queued, running, completed, failed

    public init(rawStatus: String) {
        let normalized = rawStatus
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
            .lowercased()

        switch normalized {
        case "completed", "complete", "ready", "succeeded", "success", "done", "finished", "processed", "generated":
            self = .completed
        case "failed", "error", "errored", "cancelled", "canceled", "timeout", "timed_out", "expired":
            self = .failed
        case "queued", "pending", "draft", "created", "scheduled", "waiting":
            self = .queued
        case "running", "processing", "in_progress", "inprogress", "started", "working", "generating":
            self = .running
        default:
            self = .running
        }
    }

    public var isActive: Bool {
        self == .queued || self == .running
    }

    public var driveStatus: DriveItemStatus {
        switch self {
        case .completed: return .completed
        case .failed: return .failed
        case .queued: return .draft
        case .running: return .processing
        }
    }
}

public enum GeneratedKind: String, Codable, Sendable, CaseIterable {
    case flashcard, question, summary, algorithm, comparison
    case examMorningSummary = "exam_morning_summary"
    case clinicalScenario = "clinical_scenario"
    case learningPlan = "learning_plan"
    case podcast, table, infographic
    case mindMap = "mindMap"

    public var jobType: String? {
        switch self {
        case .flashcard: return "flashcard"
        case .question: return "quiz"
        case .summary: return "summary"
        case .examMorningSummary: return "exam_morning_summary"
        case .algorithm: return "algorithm"
        case .comparison, .table: return "comparison"
        case .clinicalScenario: return "clinical_scenario"
        case .learningPlan: return "learning_plan"
        case .podcast: return "podcast"
        case .infographic: return "infographic"
        case .mindMap: return "mind_map"
        }
    }

    public var defaultCount: Int? {
        switch self {
        case .flashcard: return 20
        case .question: return 10
        case .clinicalScenario, .examMorningSummary, .learningPlan, .mindMap: return 1
        default: return nil
        }
    }

    public var titleLabel: String {
        switch self {
        case .flashcard: return "Flashcard Seti"
        case .question: return "Soru Seti"
        case .summary: return "Özet"
        case .examMorningSummary: return "Sınav Sabahı Özeti"
        case .algorithm: return "Algoritma"
        case .comparison: return "Karşılaştırma"
        case .clinicalScenario: return "Klinik Senaryo"
        case .learningPlan: return "Öğrenme Planı"
        case .podcast: return "Podcast"
        case .table: return "Tablo"
        case .infographic: return "İnfografik"
        case .mindMap: return "Zihin Haritası"
        }
    }
}

// MARK: - Data Models

public struct DriveWorkspaceData: Codable, Sendable {
    public let courses: [DriveCourse]
    public let recentFiles: [DriveFile]
    public let uploads: [UploadTask]
    public let collections: [CollectionBundle]

    public init(
        courses: [DriveCourse],
        recentFiles: [DriveFile],
        uploads: [UploadTask],
        collections: [CollectionBundle]
    ) {
        self.courses = courses
        self.recentFiles = recentFiles
        self.uploads = uploads
        self.collections = collections
    }

    public static let empty = DriveWorkspaceData(
        courses: [], recentFiles: [], uploads: [], collections: []
    )

    public var primaryCourse: DriveCourse? {
        courses.first
    }

    public var primarySection: DriveSection? {
        primaryCourse?.sections.first
    }

    public var primaryFile: DriveFile? {
        primarySection?.files.first
    }
}

public struct DriveDestination: Codable, Sendable, Equatable {
    public let courseId: String
    public let sectionId: String
    public let courseTitle: String
    public let sectionTitle: String

    public init(courseId: String, sectionId: String, courseTitle: String, sectionTitle: String) {
        self.courseId = courseId
        self.sectionId = sectionId
        self.courseTitle = courseTitle
        self.sectionTitle = sectionTitle
    }

    public var isUsable: Bool {
        !courseId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !sectionId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

public struct DriveCourse: Codable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let iconName: String
    public let iconColorHex: String
    public let iconBackgroundHex: String
    public let status: DriveItemStatus
    public let sections: [DriveSection]
    public let updatedLabel: String
    public let description: String

    public var fileCount: Int {
        sections.reduce(0) { $0 + $1.files.count }
    }

    public init(
        id: String,
        title: String,
        iconName: String,
        iconColorHex: String,
        iconBackgroundHex: String,
        status: DriveItemStatus,
        sections: [DriveSection],
        updatedLabel: String,
        description: String
    ) {
        self.id = id
        self.title = title
        self.iconName = iconName
        self.iconColorHex = iconColorHex
        self.iconBackgroundHex = iconBackgroundHex
        self.status = status
        self.sections = sections
        self.updatedLabel = updatedLabel
        self.description = description
    }

    enum CodingKeys: String, CodingKey {
        case id, title, iconName, iconColorHex, iconBackgroundHex, status, sections, updatedLabel, description
    }
}

public struct DriveSection: Codable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let status: DriveItemStatus
    public let files: [DriveFile]
    /// Generated study outputs that were explicitly saved INTO this section
    /// ("Bölüme kaydet"). They live alongside `files` and are shown as
    /// first-class, file-like items in the section browser.
    public let savedOutputs: [GeneratedOutput]
    public let iconName: String
    public let iconColorHex: String

    public init(
        id: String,
        title: String,
        status: DriveItemStatus,
        files: [DriveFile],
        savedOutputs: [GeneratedOutput] = [],
        iconName: String = "folder",
        iconColorHex: String = "#0A5BFF"
    ) {
        self.id = id
        self.title = title
        self.status = status
        self.files = files
        self.savedOutputs = savedOutputs
        self.iconName = iconName
        self.iconColorHex = iconColorHex
    }

    enum CodingKeys: String, CodingKey {
        case id, title, status, files, savedOutputs, iconName, iconColorHex
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        status = try c.decode(DriveItemStatus.self, forKey: .status)
        files = try c.decode([DriveFile].self, forKey: .files)
        savedOutputs = try c.decodeIfPresent([GeneratedOutput].self, forKey: .savedOutputs) ?? []
        iconName = try c.decodeIfPresent(String.self, forKey: .iconName) ?? "folder"
        iconColorHex = try c.decodeIfPresent(String.self, forKey: .iconColorHex) ?? "#0A5BFF"
    }
}

public struct DriveFile: Codable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let kind: DriveFileKind
    public let sizeLabel: String
    public let pageLabel: String
    public let updatedLabel: String
    public let courseTitle: String
    public let sectionTitle: String
    public let status: DriveItemStatus
    public let statusMessage: String?
    public let tag: String?
    public let featured: Bool
    public let selected: Bool
    public let generated: [GeneratedOutput]

    public var isReadyForGeneration: Bool {
        status == .completed
    }

    public init(
        id: String,
        title: String,
        kind: DriveFileKind,
        sizeLabel: String,
        pageLabel: String,
        updatedLabel: String,
        courseTitle: String,
        sectionTitle: String,
        status: DriveItemStatus,
        statusMessage: String?,
        tag: String?,
        featured: Bool,
        selected: Bool,
        generated: [GeneratedOutput]
    ) {
        self.id = id
        self.title = title
        self.kind = kind
        self.sizeLabel = sizeLabel
        self.pageLabel = pageLabel
        self.updatedLabel = updatedLabel
        self.courseTitle = courseTitle
        self.sectionTitle = sectionTitle
        self.status = status
        self.statusMessage = statusMessage
        self.tag = tag
        self.featured = featured
        self.selected = selected
        self.generated = generated
    }

    enum CodingKeys: String, CodingKey {
        case id, title, kind, sizeLabel, pageLabel, updatedLabel
        case courseTitle, sectionTitle, status, statusMessage, tag
        case featured, selected, generated
    }
}

/// One active storage subscription a user has purchased (App Store auto-renewable).
public struct SBStoragePlan: Codable, Sendable, Equatable, Identifiable {
    public let productCode: String
    public let bonusBytes: Int
    public let expiresAt: String?

    public var id: String { productCode + "-" + (expiresAt ?? "") }

    public init(productCode: String, bonusBytes: Int, expiresAt: String?) {
        self.productCode = productCode
        self.bonusBytes = bonusBytes
        self.expiresAt = expiresAt
    }
}

/// A user's storage usage + quota snapshot. `baseBytes` is the free tier (25 GB);
/// `bonusBytes` is the sum of active storage subscriptions; `totalBytes` is the
/// effective quota enforced server-side at upload time.
public struct SBStorageStatus: Codable, Sendable, Equatable {
    public let usedBytes: Int
    public let baseBytes: Int
    public let bonusBytes: Int
    public let totalBytes: Int
    public let plans: [SBStoragePlan]

    public var availableBytes: Int { max(0, totalBytes - usedBytes) }
    public var usedFraction: Double {
        totalBytes > 0 ? min(1, max(0, Double(usedBytes) / Double(totalBytes))) : 0
    }
    public var isNearlyFull: Bool { usedFraction >= 0.9 }
    /// Used storage exceeds the current quota (e.g. after a subscription expired
    /// or was downgraded). Existing files stay; new uploads are blocked.
    public var isOverQuota: Bool { totalBytes > 0 && usedBytes > totalBytes }

    public init(usedBytes: Int, baseBytes: Int, bonusBytes: Int, totalBytes: Int, plans: [SBStoragePlan]) {
        self.usedBytes = usedBytes
        self.baseBytes = baseBytes
        self.bonusBytes = bonusBytes
        self.totalBytes = totalBytes
        self.plans = plans
    }

    public static let empty = SBStorageStatus(usedBytes: 0, baseBytes: 0, bonusBytes: 0, totalBytes: 0, plans: [])
}

public struct GeneratedOutput: Codable, Identifiable, Sendable {
    public let id: String
    public let sourceFileId: String
    public let kind: GeneratedKind
    public let rawType: String
    public let title: String
    public let detail: String
    public let content: AnyJSON?
    public let contentText: String?
    public let updatedLabel: String
    public let status: String
    public let itemCount: Int
    public let jobId: String?

    public var isReady: Bool {
        GenerationJobPhase(rawStatus: status) == .completed
    }

    public init(
        id: String,
        sourceFileId: String,
        kind: GeneratedKind,
        rawType: String,
        title: String,
        detail: String,
        content: AnyJSON? = nil,
        contentText: String? = nil,
        updatedLabel: String,
        status: String,
        itemCount: Int,
        jobId: String?
    ) {
        self.id = id
        self.sourceFileId = sourceFileId
        self.kind = kind
        self.rawType = rawType
        self.title = title
        self.detail = detail
        self.content = content
        self.contentText = contentText
        self.updatedLabel = updatedLabel
        self.status = status
        self.itemCount = itemCount
        self.jobId = jobId
    }

    enum CodingKeys: String, CodingKey {
        case id, sourceFileId, kind, rawType, title, detail, content, contentText
        case updatedLabel, status, itemCount, jobId
    }
}

public struct UploadTask: Codable, Sendable {
    public let file: DriveFile
    public let status: DriveItemStatus
    public let progress: Double
    public let errorLabel: String?

    public init(
        file: DriveFile,
        status: DriveItemStatus,
        progress: Double,
        errorLabel: String?
    ) {
        self.file = file
        self.status = status
        self.progress = progress
        self.errorLabel = errorLabel
    }

    enum CodingKeys: String, CodingKey {
        case file, status, progress, errorLabel
    }
}

public struct CollectionBundle: Codable, Sendable {
    public let file: DriveFile
    public let outputs: [GeneratedOutput]
    public let subject: String
    public let previewKind: GeneratedKind

    public init(
        file: DriveFile,
        outputs: [GeneratedOutput],
        subject: String,
        previewKind: GeneratedKind
    ) {
        self.file = file
        self.outputs = outputs
        self.subject = subject
        self.previewKind = previewKind
    }

    enum CodingKeys: String, CodingKey {
        case file, outputs, subject, previewKind
    }
}

public struct GenerationJobSnapshot: Codable, Identifiable, Sendable, Equatable {
    public let id: String
    public let sourceFileId: String
    public let sourceTitle: String
    public let kind: GeneratedKind
    public let status: String
    public let progress: Double
    public let errorMessage: String?
    public let outputId: String?
    public let jobId: String?

    public init(
        id: String,
        sourceFileId: String,
        sourceTitle: String,
        kind: GeneratedKind,
        status: String,
        progress: Double,
        errorMessage: String? = nil,
        outputId: String? = nil,
        jobId: String? = nil
    ) {
        self.id = id
        self.sourceFileId = sourceFileId
        self.sourceTitle = sourceTitle
        self.kind = kind
        self.status = status
        self.progress = progress
        self.errorMessage = errorMessage
        self.outputId = outputId
        self.jobId = jobId
    }
}

public struct DriveUploadDraft: Codable, Sendable {
    public let fileName: String
    public let contentType: String
    public let sizeBytes: Int
    public let courseId: String
    public let sectionId: String

    public init(fileName: String, contentType: String, sizeBytes: Int, courseId: String, sectionId: String) {
        self.fileName = fileName
        self.contentType = contentType
        self.sizeBytes = sizeBytes
        self.courseId = courseId
        self.sectionId = sectionId
    }

    public func toJSON() -> [String: String] {
        [
            "fileName": fileName,
            "contentType": contentType,
            "sizeBytes": String(sizeBytes),
            "courseId": courseId,
            "sectionId": sectionId
        ]
    }
}

public struct StorageUploadSession: Codable, Sendable {
    public let uploadURL: String
    public let objectName: String
    public let bucket: String
    public let headers: [String: String]
    public let expiresAt: Date

    public init(
        uploadURL: String,
        objectName: String,
        bucket: String,
        headers: [String: String],
        expiresAt: Date
    ) {
        self.uploadURL = uploadURL
        self.objectName = objectName
        self.bucket = bucket
        self.headers = headers
        self.expiresAt = expiresAt
    }

    public var isUsable: Bool {
        !uploadURL.trimmingCharacters(in: .whitespaces).isEmpty
            && !objectName.trimmingCharacters(in: .whitespaces).isEmpty
            && expiresAt.timeIntervalSinceNow > 45
    }

    enum CodingKeys: String, CodingKey {
        case uploadURL = "uploadUrl"
        case objectName
        case bucket
        case headers
        case expiresAt
    }

    /// Dynamic key so we can also look up snake_case aliases (e.g. `upload_url`,
    /// `expires_at`) without force-unwrapping a fixed `CodingKeys` case.
    private struct AnyKey: CodingKey {
        let stringValue: String
        init(_ stringValue: String) { self.stringValue = stringValue }
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { nil }
        init?(intValue: Int) { nil }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let alt = try decoder.container(keyedBy: AnyKey.self)

        uploadURL = try container.decodeIfPresent(String.self, forKey: .uploadURL)
            ?? alt.decodeIfPresent(String.self, forKey: AnyKey("upload_url"))
            ?? ""

        objectName = try container.decodeIfPresent(String.self, forKey: .objectName)
            ?? alt.decodeIfPresent(String.self, forKey: AnyKey("object_name"))
            ?? ""

        bucket = try container.decodeIfPresent(String.self, forKey: .bucket) ?? ""

        let rawHeaders = try container.decodeIfPresent([String: String].self, forKey: .headers) ?? [:]
        headers = rawHeaders

        // expiresAt may arrive as an ISO8601 string (with or without fractional
        // seconds, e.g. Deno's `new Date().toISOString()` → "2026-06-04T12:00:00.000Z")
        // or as a numeric epoch. Parse defensively so a valid session is never
        // discarded just because of date formatting.
        // Use `try?` so a numeric value doesn't throw a typeMismatch before the
        // epoch fallback below has a chance to handle it.
        if let dateString = (try? container.decodeIfPresent(String.self, forKey: .expiresAt))
            ?? (try? alt.decodeIfPresent(String.self, forKey: AnyKey("expires_at")))
            ?? nil,
            !dateString.isEmpty {
            expiresAt = Self.parseExpiry(dateString)
        } else if let epoch = (try? container.decodeIfPresent(Double.self, forKey: .expiresAt))
            ?? (try? alt.decodeIfPresent(Double.self, forKey: AnyKey("expires_at")))
            ?? nil {
            // Heuristic: values larger than ~year 2300 in seconds are milliseconds.
            expiresAt = Date(timeIntervalSince1970: epoch > 10_000_000_000 ? epoch / 1000 : epoch)
        } else {
            expiresAt = .distantPast
        }
    }

    static func parseExpiry(_ raw: String) -> Date {
        let dateString = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !dateString.isEmpty else { return .distantPast }

        let isoWithFractional = ISO8601DateFormatter()
        isoWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let parsed = isoWithFractional.date(from: dateString) { return parsed }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let parsed = iso.date(from: dateString) { return parsed }

        // Fall back to plain formats without timezone designators.
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ",
            "yyyy-MM-dd'T'HH:mm:ssZZZZZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSS",
            "yyyy-MM-dd'T'HH:mm:ss"
        ]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        for format in formats {
            formatter.dateFormat = format
            if let parsed = formatter.date(from: dateString) { return parsed }
        }

        return .distantPast
    }
}
```

## File: Sources/SourceBaseBackend/Drive/DriveRepository.swift
```swift
import Foundation
import Supabase

public struct RepositoryError: Error, Sendable {
    public let message: String
}

enum DriveFileMapping {
    static func kind(from row: [String: AnyJSON]) -> DriveFileKind {
        let candidates = [
            row.stringValue(for: "file_type"),
            row.stringValue(for: "mime_type"),
            row.stringValue(for: "content_type"),
            row.stringValue(for: "original_filename"),
            row.stringValue(for: "file_name"),
            row.stringValue(for: "filename"),
            row.stringValue(for: "title")
        ].compactMap { $0 }

        for candidate in candidates {
            if let kind = kind(from: candidate) { return kind }
        }
        return .docx
    }

    static func kind(from text: String) -> DriveFileKind? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "pdf", "application/pdf":
            return .pdf
        case "ppt", "application/vnd.ms-powerpoint":
            return .ppt
        case "pptx", "application/vnd.openxmlformats-officedocument.presentationml.presentation":
            return .pptx
        case "doc", "application/msword":
            return .doc
        case "docx", "application/vnd.openxmlformats-officedocument.wordprocessingml.document":
            return .docx
        case "zip", "application/zip", "application/x-zip-compressed":
            return .zip
        default:
            let ext = DriveUploadService.normalizedExtension(normalized)
            if !ext.isEmpty, ext != normalized {
                return kind(from: ext)
            }
            return nil
        }
    }

    static func pageLabel(
        kind: DriveFileKind,
        status: DriveItemStatus,
        pageCount: Int,
        slideCount: Int
    ) -> String {
        if kind == .ppt || kind == .pptx {
            let count = slideCount > 0 ? slideCount : pageCount
            if count > 0 { return "\(count) slayt" }
            switch status {
            case .completed: return "Slayt bilgisi yok"
            case .processing: return "Slaytlar işleniyor"
            case .uploading: return "Yükleniyor"
            case .failed: return "Slaytlar okunamadı"
            case .draft: return "Beklemede"
            }
        }

        if pageCount > 0 { return "\(pageCount) sayfa" }
        switch status {
        case .completed: return "Sayfa bilgisi yok"
        case .processing: return "İşleniyor"
        case .uploading: return "Yükleniyor"
        case .failed: return "İşlenemedi"
        case .draft: return "Beklemede"
        }
    }

    static func statusMessage(
        row: [String: AnyJSON],
        kind: DriveFileKind,
        status: DriveItemStatus,
        sizeBytes: Int
    ) -> String? {
        if status == .completed { return "Kaynak üretime hazır." }
        if sizeBytes <= 0 { return "Dosya boş görünüyor. 0 KB dosyalar kaynak olarak kullanılamaz." }
        if status == .processing {
            if kind == .ppt || kind == .pptx {
                return "Slayt metinleri çıkarılıyor. İşlem tamamlanınca üretim için kullanılabilir."
            }
            return "Dosya metni çıkarılıyor. İşlem tamamlanınca üretim için kullanılabilir."
        }
        if status == .uploading { return "Yükleme devam ediyor. Tamamlanmadan üretim başlatılamaz." }
        if status == .draft { return "Kaynak henüz üretime hazır değil." }
        guard status == .failed else { return nil }

        let metadata = row["metadata"]?.dictValue ?? [:]
        let code = firstText(
            metadata,
            keys: ["extractionErrorCode", "extraction_error_code", "errorCode", "error_code", "parseErrorCode", "parse_error_code"]
        ).uppercased()
        let message = firstText(
            metadata,
            keys: ["extractionError", "extraction_error", "errorMessage", "error_message", "parseError", "parse_error", "reason"]
        )
        let lower = "\(code) \(message)".lowercased()

        if lower.contains("encrypt") || lower.contains("password") || lower.contains("protected")
            || lower.contains("şifre") || lower.contains("sifre") || lower.contains("parola") {
            if kind == .pdf {
                return "Bu PDF şifreli görünüyor. Şifre korumasını kaldırıp tekrar yükleyebilirsin."
            }
            return "Bu dosya şifreli görünüyor. Korumasını kaldırıp tekrar yükleyebilirsin."
        }
        if lower.contains("corrupt") || lower.contains("damaged") || lower.contains("malformed")
            || lower.contains("bozuk") || lower.contains("okunamıyor") || lower.contains("unreadable") {
            return "Dosya bozuk ya da okunamıyor. Dosyayı yeniden kaydedip tekrar yükleyebilirsin."
        }
        if lower.contains("scanned") || lower.contains("ocr") || lower.contains("no text")
            || lower.contains("taranmış") || lower.contains("taranmis") || lower.contains("metin bulunamad") {
            return "Bu PDF taranmış/görsel tabanlı görünüyor. Metin çıkarılamadı; OCR desteği gerekir."
        }
        if kind == .ppt || lower.contains("file_type_limited_support") && lower.contains("ppt") {
            return "Eski PPT dosyaları sınırlı desteklenir. Dosyayı PPTX olarak kaydedip tekrar yükleyebilirsin."
        }
        if kind == .doc || lower.contains("file_type_limited_support") && lower.contains("doc") {
            return "Eski DOC dosyaları sınırlı desteklenir. Dosyayı DOCX olarak kaydedip tekrar yükleyebilirsin."
        }
        if lower.contains("file_text_empty") {
            return "Dosyadan okunabilir metin çıkarılamadı. İçeriği kontrol edip tekrar yükleyebilirsin."
        }
        if lower.contains("file_type_unsupported") {
            return "Bu dosya türü desteklenmiyor. \(DriveUploadService.supportedExtensionsDisplay) yükleyebilirsin."
        }
        if lower.contains("file_object_missing") {
            return "Yüklenen dosya depolama alanında bulunamadı. Tekrar yükleyebilirsin."
        }
        if lower.contains("file_object_empty") {
            return "Yüklenen dosya boş görünüyor. Dolu bir dosya yükleyebilirsin."
        }
        if !message.isEmpty { return message }
        return "Dosya işlenemedi. Dosyayı kontrol edip tekrar yükleyebilirsin."
    }

    private static func firstText(_ row: [String: AnyJSON], keys: [String]) -> String {
        for key in keys {
            if let value = row.stringValue(for: key), !value.isEmpty { return value }
        }
        return ""
    }
}

public struct DriveRepository: Sendable {
    private let api: DriveAPI

    public init(api: DriveAPI) {
        self.api = api
    }

    // MARK: - Workspace

    public func loadWorkspace() async throws -> DriveWorkspaceData {
        let response = try await api.invoke("drive_bootstrap")
        guard case .object(let dataDict) = response["data"] else {
            throw RepositoryError(message: "Drive workspace response is empty.")
        }

        let rawCourses = dataDict["courses"]?.arrayValue ?? []
        let rawSections = dataDict["sections"]?.arrayValue ?? []
        let rawFiles = dataDict["files"]?.arrayValue ?? []
        let rawOutputs = dataDict["generatedOutputs"]?.arrayValue
            ?? dataDict["generated_outputs"]?.arrayValue
            ?? []
        let rawUploads = dataDict["uploads"]?.arrayValue
            ?? dataDict["uploadTasks"]?.arrayValue
            ?? dataDict["upload_tasks"]?.arrayValue
            ?? []

        let courseRows = rawCourses.compactMap { $0.dictValue }
        let sectionRows = rawSections.compactMap { $0.dictValue }
        let fileRows = rawFiles.compactMap { $0.dictValue }
        let outputRows = rawOutputs.compactMap { $0.dictValue }
        let uploadRows = rawUploads.compactMap { $0.dictValue }

        let courses: [DriveCourse]
        if courseRows.isEmpty, !fileRows.isEmpty {
            let files = fileRows.map {
                fileFromRow(
                    $0,
                    courseTitle: $0.stringValue(for: "course_title") ?? "Drive",
                    sectionTitle: $0.stringValue(for: "section_title") ?? "Kaynaklar",
                    allOutputs: outputRows
                )
            }
            courses = [
                DriveCourse(
                    id: "uncategorized",
                    title: "Drive",
                    iconName: "folder",
                    iconColorHex: "#0A5BFF",
                    iconBackgroundHex: "#EDF4FF",
                    status: .completed,
                    sections: [
                        DriveSection(
                            id: "uncategorized-section",
                            title: "Kaynaklar",
                            status: .completed,
                            files: files
                        )
                    ],
                    updatedLabel: "Bugün",
                    description: "Drive kaynakların burada listelenir."
                )
            ]
        } else {
            courses = courseRows.map { courseFromRow($0, allSections: sectionRows, allFiles: fileRows, allOutputs: outputRows) }
        }
        let allFiles = courses.flatMap { $0.sections.flatMap { $0.files } }
        let recent = Array(allFiles.prefix(5))

        let collections = allFiles
            .filter { !$0.generated.isEmpty }
            .map { file in
                CollectionBundle(
                    file: file,
                    outputs: file.generated,
                    subject: file.courseTitle,
                    previewKind: file.generated.first?.kind ?? .summary
                )
            }

        return DriveWorkspaceData(
            courses: courses,
            recentFiles: recent,
            uploads: uploadRows
                .map { uploadTaskFromRow($0, allFiles: allFiles, allOutputs: outputRows) }
                .sorted { $0.file.updatedLabel < $1.file.updatedLabel },
            collections: collections
        )
    }

    // MARK: - Upload

    public func createUploadSession(_ draft: DriveUploadDraft) async throws -> StorageUploadSession {
        let session = try await api.createUploadSession(draft)
        guard session.isUsable else {
            throw RepositoryError(message: "Yükleme bağlantısı alınamadı. Tekrar deneyebilirsin.")
        }
        return session
    }

    public func completeUpload(
        file: PickedDriveFile,
        objectName: String,
        courseId: String,
        sectionId: String,
        courseTitle: String,
        sectionTitle: String,
        extractedText: String? = nil,
        pageCount: Int? = nil,
        extractionMetadata: ExtractionMetadata? = nil
    ) async throws -> DriveFile {
        let response = try await api.completeUpload(
            objectName: objectName,
            courseId: courseId,
            sectionId: sectionId,
            fileName: file.name,
            contentType: file.contentType,
            sizeBytes: file.sizeBytes,
            extractedText: extractedText,
            pageCount: pageCount,
            extractionMetadata: extractionMetadata
        )
        guard let row = requiredDataRow(from: response, message: "Yüklenen dosya kaydı alınamadı.") else {
            throw RepositoryError(message: "Yüklenen dosya kaydı alınamadı.")
        }
        let uploaded = fileFromRow(row, courseTitle: courseTitle, sectionTitle: sectionTitle, allOutputs: [])
        if uploaded.status == .failed {
            throw RepositoryError(message: uploaded.statusMessage ?? "Dosya yüklendi ancak işleme kuyruğuna alınamadı.")
        }
        return uploaded
    }

    // MARK: - Course CRUD

    public func createCourse(
        _ title: String,
        iconName: String? = nil,
        colorHex: String? = nil
    ) async throws -> DriveCourse {
        let response = try await api.createCourse(title, iconName: iconName, colorHex: colorHex)
        guard let row = requiredDataRow(from: response, message: "Ders oluşturulamadı.") else {
            throw RepositoryError(message: "Ders oluşturulamadı.")
        }
        return courseFromRow(row, allSections: [], allFiles: [], allOutputs: [])
    }

    public func createSection(
        courseId: String,
        title: String,
        iconName: String? = nil,
        colorHex: String? = nil
    ) async throws -> DriveSection {
        let response = try await api.createSection(courseId: courseId, title: title, iconName: iconName, colorHex: colorHex)
        guard let row = requiredDataRow(from: response, message: "Bölüm oluşturulamadı.") else {
            throw RepositoryError(message: "Bölüm oluşturulamadı.")
        }
        return sectionFromRow(row, allFiles: [], courseTitle: nil, allOutputs: [])
    }

    public func renameCourse(courseId: String, title: String) async throws -> DriveCourse {
        let response = try await api.renameCourse(courseId: courseId, title: title)
        guard let row = requiredDataRow(from: response, message: "Ders yeniden adlandırılamadı.") else {
            throw RepositoryError(message: "Ders yeniden adlandırılamadı.")
        }
        return courseFromRow(row, allSections: [], allFiles: [], allOutputs: [])
    }

    public func renameSection(sectionId: String, title: String) async throws -> DriveSection {
        let response = try await api.renameSection(sectionId: sectionId, title: title)
        guard let row = requiredDataRow(from: response, message: "Bölüm yeniden adlandırılamadı.") else {
            throw RepositoryError(message: "Bölüm yeniden adlandırılamadı.")
        }
        return sectionFromRow(row, allFiles: [], courseTitle: nil, allOutputs: [])
    }

    public func deleteCourse(_ courseId: String) async throws {
        _ = try await api.deleteCourse(courseId)
    }

    public func deleteSection(_ sectionId: String) async throws {
        _ = try await api.deleteSection(sectionId)
    }

    // MARK: - File Actions

    public func renameFile(
        fileId: String,
        title: String,
        courseTitle: String = "",
        sectionTitle: String = ""
    ) async throws -> DriveFile? {
        let response = try await api.renameFile(fileId: fileId, title: title)
        guard let row = dataRow(from: response), !row.isEmpty else { return nil }
        return fileFromRow(
            row,
            courseTitle: row.stringValue(for: "course_title") ?? courseTitle,
            sectionTitle: row.stringValue(for: "section_title") ?? sectionTitle,
            allOutputs: []
        )
    }

    public func moveFiles(fileIds: [String], courseId: String, sectionId: String) async throws {
        guard !fileIds.isEmpty else { return }
        _ = try await api.moveFiles(fileIds: fileIds, courseId: courseId, sectionId: sectionId)
    }

    public func moveGeneratedOutput(outputId: String, courseId: String, sectionId: String) async throws {
        guard !outputId.isEmpty else { return }
        _ = try await api.moveGeneratedOutput(outputId: outputId, courseId: courseId, sectionId: sectionId)
    }

    public func deleteFiles(_ fileIds: [String]) async throws {
        guard !fileIds.isEmpty else { return }
        _ = try await api.deleteFiles(fileIds)
    }

    public func retryFileProcessing(_ fileId: String) async throws {
        _ = try await api.retryFileProcessing(fileId)
    }

    public func addToCollection(fileId: String, outputId: String? = nil, collection: String? = nil) async throws {
        _ = try await api.addToCollection(fileId: fileId, outputId: outputId, collection: collection)
    }

    // MARK: - Generation

    public func createGeneratedOutput(
        file: DriveFile,
        kind: GeneratedKind,
        options: [String: String]? = nil,
        sourceIds: [String]? = nil
    ) async throws -> GeneratedOutput {
        var itemCount: Int?
        var jobId: String?
        var generatedContent: AnyJSON?

        if let jobType = kind.jobType {
            let requestedCount = options?["count"].flatMap(Int.init) ?? kind.defaultCount
            let jobResponse = try await api.createGenerationJob(
                fileId: file.id,
                jobType: jobType,
                sourceIds: sourceIds,
                count: requestedCount,
                qualityTier: options?["qualityTier"],
                options: options
            )
            let dataDict = jobResponse["data"]?.dictValue
            jobId = dataDict?["jobId"]?.stringValue
            guard let jid = jobId, !jid.isEmpty else {
                throw RepositoryError(message: "Üretim işi başlatılamadı.")
            }
            try await processGenerationJobWithRecovery(jid)
            guard let content = try await waitForGeneratedContent(jobId: jid) else {
                throw RepositoryError(message: "Üretim tamamlandı ancak içerik alınamadı.")
            }
            generatedContent = content
            itemCount = contentItemCount(content)
        }

        let response = try await api.createGeneratedOutput(
            fileId: file.id,
            kind: kind,
            itemCount: itemCount,
            jobId: jobId
        )
        guard let row = requiredDataRow(from: response, message: "Üretilen içerik kaydı alınamadı.") else {
            throw RepositoryError(message: "Üretilen içerik kaydı alınamadı.")
        }
        return outputFromRow(row, contentOverride: generatedContent)
    }

    public func startGenerationJob(
        file: DriveFile,
        kind: GeneratedKind,
        options: [String: String]? = nil,
        sourceIds: [String]? = nil
    ) async throws -> GenerationJobSnapshot {
        guard let jobType = kind.jobType else {
            throw RepositoryError(message: "\(kind.titleLabel) için backend job type henüz aktif değil.")
        }

        let requestedCount = options?["count"].flatMap(Int.init) ?? kind.defaultCount
        let jobResponse = try await api.createGenerationJob(
            fileId: file.id,
            jobType: jobType,
            sourceIds: sourceIds,
            count: requestedCount,
            qualityTier: options?["qualityTier"],
            options: options
        )
        let dataDict = jobResponse["data"]?.dictValue
        let jobId = dataDict?["jobId"]?.stringValue
            ?? dataDict?["job_id"]?.stringValue
            ?? dataDict?["id"]?.stringValue
        guard let jobId, !jobId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RepositoryError(message: "Üretim işi başlatılamadı.")
        }

        let rawStatus = dataDict?["status"]?.stringValue ?? "queued"
        let phase = GenerationJobPhase(rawStatus: rawStatus)
        let outputId = dataDict?["outputId"]?.stringValue
            ?? dataDict?["output_id"]?.stringValue
            ?? dataDict?["generatedOutputId"]?.stringValue
            ?? dataDict?["generated_output_id"]?.stringValue

        Task.detached(priority: .userInitiated) { [api] in
            do {
                try await Self.processGenerationJobWithRecovery(jobId, api: api)
            } catch {
                SBLog.drive.error("background generation process failed jobId=\(jobId, privacy: .public) error=\(String(describing: error), privacy: .private)")
            }
        }

        return GenerationJobSnapshot(
            id: jobId,
            sourceFileId: file.id,
            sourceTitle: file.title,
            kind: kind,
            status: phase.rawValue,
            progress: normalizedProgress(dataDict?["progress"]?.doubleValue, phase: phase),
            errorMessage: dataDict?["errorMessage"]?.stringValue ?? dataDict?["error_message"]?.stringValue,
            outputId: outputId,
            jobId: jobId
        )
    }

    public func finalizeGenerationJob(
        file: DriveFile,
        kind: GeneratedKind,
        jobId: String
    ) async throws -> GeneratedOutput? {
        guard let content = try await generatedContentIfReady(jobId: jobId) else {
            return nil
        }

        let response = try await api.createGeneratedOutput(
            fileId: file.id,
            kind: kind,
            itemCount: contentItemCount(content),
            jobId: jobId
        )
        guard let row = requiredDataRow(from: response, message: "Üretilen içerik kaydı alınamadı.") else {
            throw RepositoryError(message: "Üretilen içerik kaydı alınamadı.")
        }
        return outputFromRow(row, contentOverride: content)
    }

    public func generatedContentIfReady(jobId: String) async throws -> AnyJSON? {
        let statusResponse = try await api.getJobStatus(jobId)
        let statusData = statusResponse["data"]?.dictValue
        let status = statusData?["status"]?.stringValue ?? ""
        let phase = GenerationJobPhase(rawStatus: status)

        switch phase {
        case .completed:
            let contentResponse = try await api.getGeneratedContent(jobId)
            guard let content = generatedContentPayload(from: contentResponse) else {
                throw RepositoryError(message: "Üretim tamamlandı ancak içerik alınamadı.")
            }
            return content
        case .failed:
            let message = statusData?["errorMessage"]?.stringValue
                ?? statusData?["error_message"]?.stringValue
                ?? "Üretim başarısız."
            throw RepositoryError(message: message)
        case .queued, .running:
            return nil
        }
    }

    public func createGeneratedOutputByKind(
        fileId: String,
        kind: String,
        itemCount: Int? = nil,
        jobId: String? = nil
    ) async throws -> GeneratedOutput {
        let response = try await api.createGeneratedOutputByKind(
            fileId: fileId,
            kind: kind,
            itemCount: itemCount,
            jobId: jobId
        )
        guard let row = requiredDataRow(from: response, message: "Üretilen içerik kaydı alınamadı.") else {
            throw RepositoryError(message: "Üretilen içerik kaydı alınamadı.")
        }
        return outputFromRow(row)
    }

    public func estimateGenerationCost(
        kind: GeneratedKind,
        sourceTextLength: Int? = nil,
        count: Int? = nil,
        qualityTier: String? = nil,
        options: [String: String]? = nil
    ) async throws -> [String: AnyJSON] {
        guard let jobType = kind.jobType else {
            throw RepositoryError(message: "\(kind.titleLabel) için backend job type henüz aktif değil.")
        }
        return try await api.estimateGenerationCost(
            jobType: jobType,
            sourceTextLength: sourceTextLength,
            count: count,
            qualityTier: qualityTier,
            options: options
        )
    }

    public func listUserJobs(limit: Int? = nil) async throws -> [GenerationJobSnapshot] {
        let response = try await api.listUserJobs(limit: limit)
        let data = response["data"]?.dictValue
        let rows = response["data"]?.arrayValue
            ?? data?["jobs"]?.arrayValue
            ?? data?["rows"]?.arrayValue
            ?? []
        return rows.compactMap(\.dictValue).map(generationJobFromRow)
    }

    public func cancelJob(_ jobId: String) async throws {
        _ = try await api.cancelJob(jobId)
    }

    public func retryJob(_ jobId: String) async throws {
        _ = try await api.retryJob(jobId)
    }

    public func requestAccountDeletion() async throws {
        _ = try await api.requestAccountDeletion()
    }

    public func purchaseMedasiCoin(
        productCode: String,
        successURL: String,
        cancelURL: String
    ) async throws -> [String: AnyJSON] {
        try await api.purchaseMedasiCoin(
            productCode: productCode,
            successURL: successURL,
            cancelURL: cancelURL
        )
    }

    // MARK: - Private: JSON Mapping Helpers

    private func dataRow(from response: [String: AnyJSON]) -> [String: AnyJSON]? {
        guard let data = response["data"]?.dictValue else { return nil }
        if let row = data["row"]?.dictValue { return row }
        if data["id"] != nil { return data }
        return nil
    }

    private func requiredDataRow(from response: [String: AnyJSON], message: String) -> [String: AnyJSON]? {
        guard let row = dataRow(from: response), !row.isEmpty else { return nil }
        return row
    }

    private func waitForGeneratedContent(jobId: String) async throws -> AnyJSON? {
        let maxAttempts = 150 // 300s (150 x 2s) — matches the edge worker wall-clock so podcast+TTS and large sources finish; timeout still points users to Queue.
        for _ in 0..<maxAttempts {
            let statusResponse = try await api.getJobStatus(jobId)
            let statusData = statusResponse["data"]?.dictValue
            let status = statusData?["status"]?.stringValue ?? ""
            let phase = GenerationJobPhase(rawStatus: status)

            if phase == .completed {
                let contentResponse = try await api.getGeneratedContent(jobId)
                guard let content = generatedContentPayload(from: contentResponse) else {
                    throw RepositoryError(message: "Üretim tamamlandı ancak içerik alınamadı.")
                }
                return content
            }

            if phase == .failed {
                let message = statusData?["errorMessage"]?.stringValue
                    ?? statusData?["error_message"]?.stringValue
                    ?? "Üretim başarısız."
                throw RepositoryError(message: message)
            }

            try await Task.sleep(nanoseconds: 2_000_000_000)
        }
        throw RepositoryError(message: "Üretim zaman aşımına uğradı. Arka planda devam ediyorsa Kuyruk ekranından takip edebilirsin.")
    }

    private func processGenerationJobWithRecovery(_ jobId: String) async throws {
        try await Self.processGenerationJobWithRecovery(jobId, api: api)
    }

    private static func processGenerationJobWithRecovery(_ jobId: String, api: DriveAPI) async throws {
        do {
            _ = try await api.processGenerationJob(jobId)
            return
        } catch {
            // A client-side timeout/disconnect does NOT mean the job failed: the edge
            // worker keeps generating server-side for up to ~5 min. Only a *failed* DB
            // status is a real failure worth retrying — never cancel a job that may
            // still be running (cancelling is what turned recoverable jobs into the
            // "Üretim yarıda kaldı" / cancelled state users were seeing).
            if try await generationJobCanContinue(jobId, api: api) { return }

            for delay in [UInt64(1_500_000_000), UInt64(2_500_000_000)] {
                _ = try? await api.retryJob(jobId)
                try? await Task.sleep(nanoseconds: delay)
                do {
                    _ = try await api.processGenerationJob(jobId)
                    return
                } catch {
                    if try await generationJobCanContinue(jobId, api: api) { return }
                }
            }
            throw RepositoryError(message: "Üretim tamamlanamadı. Kuyruktan tekrar deneyebilirsin.")
        }
    }

    private static func generationJobCanContinue(_ jobId: String, api: DriveAPI) async throws -> Bool {
        let statusResponse = try await api.getJobStatus(jobId)
        let statusData = statusResponse["data"]?.dictValue
        let status = (statusData?["status"]?.stringValue ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return GenerationJobPhase(rawStatus: status) != .failed
    }

    private func generatedContentPayload(from response: [String: AnyJSON]) -> AnyJSON? {
        guard let data = response["data"] else {
            return response["content"] ?? response["result"] ?? response["output"]
        }
        if let dataDict = data.dictValue {
            return dataDict["content"]
                ?? dataDict["result"]
                ?? dataDict["output"]
                ?? dataDict["generatedContent"]
                ?? dataDict["generated_content"]
        }
        return data
    }

    // MARK: - Private: Row Mappers

    private func courseFromRow(
        _ row: [String: AnyJSON],
        allSections: [[String: AnyJSON]],
        allFiles: [[String: AnyJSON]],
        allOutputs: [[String: AnyJSON]] = []
    ) -> DriveCourse {
        let id = row.stringValue(for: "id") ?? ""
        let title = row.stringValue(for: "title") ?? "Yeni Ders"
        let updatedAt = row.stringValue(for: "updated_at") ?? row.stringValue(for: "created_at") ?? ""
        let sections = allSections
            .filter { $0.stringValue(for: "course_id") == id }
            .map { sectionFromRow($0, allFiles: allFiles, courseTitle: title, allOutputs: allOutputs) }

        let iconName = row.stringValue(for: "icon_name") ?? "book.closed"
        let colorHex = metadataText(from: row["metadata"], key: "colorHex") ?? "#0A5BFF"

        return DriveCourse(
            id: id,
            title: title,
            iconName: iconName,
            iconColorHex: colorHex,
            iconBackgroundHex: colorHex,
            status: statusFromText(row.stringValue(for: "status") ?? "active"),
            sections: sections,
            updatedLabel: "Son güncelleme \(dateLabel(updatedAt))",
            description: metadataText(from: row["metadata"], key: "description")
                ?? "\(title) dersine ait tüm içerikler, bölümler halinde düzenlenmiştir."
        )
    }

    private func sectionFromRow(
        _ row: [String: AnyJSON],
        allFiles: [[String: AnyJSON]],
        courseTitle: String?,
        allOutputs: [[String: AnyJSON]] = []
    ) -> DriveSection {
        let id = row.stringValue(for: "id") ?? ""
        let title = row.stringValue(for: "title") ?? "Yeni Bölüm"
        let files = allFiles
            .filter { $0.stringValue(for: "section_id") == id }
            .map { fileFromRow($0, courseTitle: courseTitle ?? "", sectionTitle: title, allOutputs: allOutputs) }

        // Outputs that were explicitly saved into this section ("Bölüme kaydet")
        // surface as first-class, file-like items alongside the section's files.
        let savedOutputs = allOutputs
            .filter { $0.stringValue(for: "section_id") == id }
            .map { outputFromRow($0) }

        let iconName = metadataText(from: row["metadata"], key: "iconName") ?? "folder"
        let colorHex = metadataText(from: row["metadata"], key: "colorHex") ?? "#0A5BFF"

        return DriveSection(
            id: id,
            title: title,
            status: statusFromText(row.stringValue(for: "status") ?? "active"),
            files: files,
            savedOutputs: savedOutputs,
            iconName: iconName,
            iconColorHex: colorHex
        )
    }

    private func fileFromRow(
        _ row: [String: AnyJSON],
        courseTitle: String,
        sectionTitle: String,
        allOutputs: [[String: AnyJSON]]
    ) -> DriveFile {
        let id = row.stringValue(for: "id") ?? ""
        let status = fileStatusFromRow(row)
        let kind = kindFromRow(row)
        let pageCount = firstInt(
            row,
            keys: ["page_count", "pageCount", "pages", "num_pages", "total_pages"]
        ) ?? 0
        let slideCount = firstInt(
            row,
            keys: ["slide_count", "slideCount", "slides", "num_slides", "total_slides"]
        ) ?? 0
        let sizeBytes = row["size_bytes"]?.intValue ?? 0

        return DriveFile(
            id: id,
            title: row.stringValue(for: "title") ?? row.stringValue(for: "original_filename") ?? "",
            kind: kind,
            sizeLabel: sizeLabel(sizeBytes),
            pageLabel: pageLabelForFile(
                kind: kind,
                status: status,
                pageCount: pageCount,
                slideCount: slideCount
            ),
            updatedLabel: dateLabel(row.stringValue(for: "updated_at") ?? row.stringValue(for: "created_at") ?? ""),
            courseTitle: courseTitle,
            sectionTitle: sectionTitle,
            status: status,
            statusMessage: fileStatusMessage(row: row, kind: kind, status: status, sizeBytes: sizeBytes),
            tag: row.stringValue(for: "tag"),
            featured: false,
            selected: false,
            generated: allOutputs
                .filter { $0.stringValue(for: "source_file_id") == id }
                .map { outputFromRow($0) }
        )
    }

    private func outputFromRow(_ row: [String: AnyJSON], contentOverride: AnyJSON? = nil) -> GeneratedOutput {
        let rawType = row.stringValue(for: "output_type") ?? row.stringValue(for: "kind") ?? ""
        let kind = generatedKindFromText(rawType)
        let metadata = row["metadata"]?.dictValue ?? [:]
        let content: AnyJSON? = contentOverride ?? metadata["content"] ?? row["content"]
        let itemCount = row["item_count"]?.intValue ?? 0
        let status = row.stringValue(for: "status") ?? "ready"

        return GeneratedOutput(
            id: row.stringValue(for: "id") ?? "",
            sourceFileId: row.stringValue(for: "source_file_id") ?? "",
            kind: kind,
            rawType: rawType,
            title: row.stringValue(for: "title") ?? kind.titleLabel,
            detail: generatedOutputDetail(rawType: rawType, status: status, itemCount: itemCount, content: content),
            content: content,
            contentText: generatedContentText(content),
            updatedLabel: dateLabel(row.stringValue(for: "updated_at") ?? row.stringValue(for: "created_at") ?? ""),
            status: status,
            itemCount: itemCount,
            jobId: metadata.stringValue(for: "jobId")
                ?? metadata.stringValue(for: "job_id")
                ?? row.stringValue(for: "job_id")
        )
    }

    private func uploadTaskFromRow(
        _ row: [String: AnyJSON],
        allFiles: [DriveFile],
        allOutputs: [[String: AnyJSON]]
    ) -> UploadTask {
        let fileRow = row["file"]?.dictValue ?? row
        let fileId = fileRow.stringValue(for: "id")
            ?? fileRow.stringValue(for: "file_id")
            ?? row.stringValue(for: "file_id")
            ?? row.stringValue(for: "fileId")
            ?? ""
        let existingFile = allFiles.first { $0.id == fileId }
        let file = existingFile ?? fileFromRow(
            fileRow,
            courseTitle: fileRow.stringValue(for: "course_title") ?? row.stringValue(for: "course_title") ?? "Drive",
            sectionTitle: fileRow.stringValue(for: "section_title") ?? row.stringValue(for: "section_title") ?? "Kaynaklar",
            allOutputs: allOutputs
        )
        let statusText = row.stringValue(for: "status")
            ?? row.stringValue(for: "ai_status")
            ?? fileRow.stringValue(for: "ai_status")
            ?? fileRow.stringValue(for: "status")
            ?? file.status.rawValue
        let rawProgress = row["progress"]?.doubleValue
            ?? row["processing_progress"]?.doubleValue
            ?? row["upload_progress"]?.doubleValue
        let status = statusFromText(statusText)
        let progress = normalizedProgress(rawProgress, status: status)
        let errorLabel = row.stringValue(for: "errorLabel")
            ?? row.stringValue(for: "error_label")
            ?? row.stringValue(for: "errorMessage")
            ?? row.stringValue(for: "error_message")
            ?? file.statusMessage

        return UploadTask(file: file, status: status, progress: progress, errorLabel: errorLabel)
    }

    private func generationJobFromRow(_ row: [String: AnyJSON]) -> GenerationJobSnapshot {
        let id = row.stringValue(for: "id")
            ?? row.stringValue(for: "jobId")
            ?? row.stringValue(for: "job_id")
            ?? ""
        let rawKind = row.stringValue(for: "jobType")
            ?? row.stringValue(for: "job_type")
            ?? row.stringValue(for: "output_type")
            ?? row.stringValue(for: "kind")
            ?? "summary"
        let rawStatus = row.stringValue(for: "status") ?? "queued"
        let outputId = row.stringValue(for: "outputId")
            ?? row.stringValue(for: "output_id")
            ?? row.stringValue(for: "generatedOutputId")
            ?? row.stringValue(for: "generated_output_id")
        let rawPhase = GenerationJobPhase(rawStatus: rawStatus)
        let phase: GenerationJobPhase = outputId?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false && rawPhase != .failed
            ? .completed
            : rawPhase
        return GenerationJobSnapshot(
            id: id,
            sourceFileId: row.stringValue(for: "sourceFileId")
                ?? row.stringValue(for: "source_file_id")
                ?? row.stringValue(for: "fileId")
                ?? row.stringValue(for: "file_id")
                ?? "",
            sourceTitle: row.stringValue(for: "sourceTitle")
                ?? row.stringValue(for: "source_title")
                ?? row.stringValue(for: "fileTitle")
                ?? row.stringValue(for: "file_title")
                ?? "Drive kaynağı",
            kind: generatedKindFromText(rawKind),
            status: phase.rawValue,
            progress: normalizedProgress(row["progress"]?.doubleValue, phase: phase),
            errorMessage: row.stringValue(for: "errorMessage") ?? row.stringValue(for: "error_message"),
            outputId: outputId,
            jobId: row.stringValue(for: "jobId") ?? row.stringValue(for: "job_id") ?? id
        )
    }

    // MARK: - Private: Status & Kind Parsing

    private func statusFromText(_ text: String) -> DriveItemStatus {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "completed", "complete", "uploaded", "ready", "active", "succeeded", "success", "done", "finished", "processed": return .completed
        case "processing", "pending", "running", "in_progress", "in-progress", "started", "working", "generating": return .processing
        case "uploading": return .uploading
        case "failed", "error", "errored", "cancelled", "canceled", "timeout", "timed_out": return .failed
        case "draft", "queued", "created", "scheduled", "waiting": return .draft
        default: return .failed
        }
    }

    private func fileStatusFromRow(_ row: [String: AnyJSON]) -> DriveItemStatus {
        let aiStatus = row.stringValue(for: "ai_status") ?? ""
        let storageStatus = row.stringValue(for: "status") ?? ""
        if row["size_bytes"]?.intValue ?? 0 <= 0 { return .failed }
        if !aiStatus.isEmpty { return statusFromText(aiStatus) }
        if storageStatus.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "uploaded" {
            return .processing
        }
        return statusFromText(storageStatus)
    }

    private func kindFromRow(_ row: [String: AnyJSON]) -> DriveFileKind {
        DriveFileMapping.kind(from: row)
    }

    private func firstInt(_ row: [String: AnyJSON], keys: [String]) -> Int? {
        for key in keys {
            if let value = row[key]?.intValue { return value }
        }
        return nil
    }

    private func normalizedProgress(_ raw: Double?, status: DriveItemStatus) -> Double {
        if let raw {
            if raw > 1 { return min(max(raw / 100, 0), 1) }
            return min(max(raw, 0), 1)
        }
        switch status {
        case .completed: return 1
        case .failed: return 1
        case .uploading: return 0.35
        case .processing: return 0.65
        case .draft: return 0.05
        }
    }

    private func normalizedProgress(_ raw: Double?, phase: GenerationJobPhase) -> Double {
        normalizedProgress(raw, status: phase.driveStatus)
    }

    private func generatedKindFromText(_ text: String) -> GeneratedKind {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "-", with: "_")
            .lowercased()
        switch normalized {
        case "flashcard", "flashcards": return .flashcard
        case "question", "questions", "quiz": return .question
        case "algorithm": return .algorithm
        case "comparison": return .comparison
        case "table": return .table
        case "podcast", "podcast_summary", "podcastsummary": return .podcast
        case "infographic": return .infographic
        case "mind_map", "mindmap": return .mindMap
        case "exam_morning_summary", "exammorningsummary": return .examMorningSummary
        case "clinical_scenario", "clinicalscenario": return .clinicalScenario
        case "learning_plan", "learningplan": return .learningPlan
        case "summary": return .summary
        default: return .summary
        }
    }

    private func isSupportedGeneratedOutputType(_ rawType: String) -> Bool {
        let normalized = rawType.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "-", with: "_")
            .lowercased()
        return switch normalized {
        case "flashcard", "flashcards", "question", "questions", "quiz",
             "summary", "exam_morning_summary", "exammorningsummary",
             "algorithm", "comparison", "table", "podcast", "podcast_summary",
             "podcastsummary", "infographic", "mind_map", "mindmap",
             "clinical_scenario", "clinicalscenario",
             "learning_plan", "learningplan": true
        default: false
        }
    }

    // MARK: - Private: Labels

    private func dateLabel(_ raw: String) -> String {
        guard let parsed = ISO8601DateFormatter().date(from: raw)
                ?? dateFromFlexible(raw) else {
            return raw.isEmpty ? "Bugün" : raw
        }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dateDay = calendar.startOfDay(for: parsed)

        if dateDay == today { return "Bugün" }
        if dateDay == calendar.date(byAdding: .day, value: -1, to: today) { return "Dün" }

        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: parsed)
    }

    private func dateFromFlexible(_ raw: String) -> Date? {
        let formatter = DateFormatter()
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd"
        ]
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: raw) { return date }
        }
        return nil
    }

    private func sizeLabel(_ bytes: Int) -> String {
        if bytes <= 0 { return "-" }
        let mb = Double(bytes) / (1024.0 * 1024.0)
        if mb >= 1 { return String(format: "%.1f MB", mb) }
        return "\(bytes / 1024) KB"
    }

    private func pageLabelForFile(
        kind: DriveFileKind,
        status: DriveItemStatus,
        pageCount: Int,
        slideCount: Int
    ) -> String {
        DriveFileMapping.pageLabel(
            kind: kind,
            status: status,
            pageCount: pageCount,
            slideCount: slideCount
        )
    }

    private func fileStatusMessage(
        row: [String: AnyJSON],
        kind: DriveFileKind,
        status: DriveItemStatus,
        sizeBytes: Int
    ) -> String? {
        DriveFileMapping.statusMessage(row: row, kind: kind, status: status, sizeBytes: sizeBytes)
    }

    private func generatedOutputDetail(
        rawType: String,
        status: String,
        itemCount: Int,
        content: AnyJSON?
    ) -> String {
        let normalizedStatus = status.trimmingCharacters(in: .whitespaces).lowercased()
        if normalizedStatus == "failed" || normalizedStatus == "error" {
            return "Üretim tamamlanamadı"
        }
        if !isSupportedGeneratedOutputType(rawType) {
            return "Sonuç oluşturuldu ancak bu görünüm henüz desteklenmiyor."
        }
        let preview = generatedContentPreview(content)
        if itemCount > 0 && !preview.isEmpty { return "\(itemCount) öğe • \(preview)" }
        if itemCount > 0 { return "\(itemCount) öğe" }
        if !preview.isEmpty { return preview }
        if normalizedStatus == "ready" || normalizedStatus == "completed" {
            return "Sonuç oluşturuldu"
        }
        return "Sonuç oluşturuldu ancak bu görünüm henüz desteklenmiyor."
    }

    private func generatedContentPreview(_ content: AnyJSON?) -> String {
        let text = firstGeneratedText(content).replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )
        if text.isEmpty { return "" }
        return text.count > 120 ? String(text.prefix(120)) + "..." : text
    }

    private func generatedContentText(_ content: AnyJSON?) -> String? {
        guard let content else { return nil }
        let text = readableContent(content)
            .replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    private func readableContent(_ value: AnyJSON, key: String? = nil, depth: Int = 0) -> String {
        switch value {
        case .null:
            return ""
        case .bool(let bool):
            return bool ? "Evet" : "Hayır"
        case .integer(let int):
            return String(int)
        case .double(let double):
            return String(double)
        case .string(let string):
            return string.trimmingCharacters(in: .whitespacesAndNewlines)
        case .array(let array):
            return array
                .map { item in
                    let text = readableContent(item, depth: depth + 1)
                    guard !text.isEmpty else { return "" }
                    if text.contains("\n") || depth > 0 {
                        return "- \(text.replacingOccurrences(of: "\n", with: "\n  "))"
                    }
                    return "- \(text)"
                }
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
        case .object(let dict):
            let orderedKeys = orderedContentKeys(dict)
            return orderedKeys
                .map { itemKey in
                    guard let child = dict[itemKey] else { return "" }
                    let text = readableContent(child, key: itemKey, depth: depth + 1)
                    guard !text.isEmpty else { return "" }
                    let label = contentLabel(for: itemKey)
                    if child.arrayValue != nil || child.objectValue != nil {
                        return "\(label)\n\(text)"
                    }
                    return "\(label): \(text)"
                }
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
        }
    }

    private func orderedContentKeys(_ dict: [String: AnyJSON]) -> [String] {
        let preferred = [
            "title", "summary", "front", "back", "question", "answer", "explanation",
            "description", "body", "text", "fullText", "cards", "flashcards",
            "questions", "options", "rows", "columns", "sections", "steps",
            "nodes", "branches", "segments", "chapters", "days", "tasks",
            "must_know", "commonly_confused", "clinical_tus_tips", "self_check"
        ]
        var seen = Set<String>()
        var keys: [String] = []
        for key in preferred where dict[key] != nil {
            keys.append(key)
            seen.insert(key)
        }
        keys.append(contentsOf: dict.keys.filter { !seen.contains($0) }.sorted())
        return keys
    }

    private func contentLabel(for key: String) -> String {
        let replacements: [String: String] = [
            "fullText": "Metin",
            "must_know": "Mutlaka Bil",
            "commonly_confused": "Sık Karışanlar",
            "clinical_tus_tips": "Klinik İpuçları",
            "self_check": "Kontrol",
            "front": "Ön",
            "back": "Arka"
        ]
        if let replacement = replacements[key] { return replacement }
        let spaced = key
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
        return spaced
            .split(separator: " ")
            .map { word in word.prefix(1).uppercased() + word.dropFirst() }
            .joined(separator: " ")
    }

    private func firstGeneratedText(_ value: AnyJSON?) -> String {
        guard let value else { return "" }
        switch value {
        case .string(let s): return s.trimmingCharacters(in: .whitespaces)
        case .array(let arr):
            for item in arr {
                let text = firstGeneratedText(item)
                if !text.isEmpty { return text }
            }
            return ""
        case .object(let dict):
            let primaryKeys = ["title", "front", "question", "summary", "fullText",
                               "answer", "description", "body", "text", "prompt"]
            for key in primaryKeys {
                let text = firstGeneratedText(dict[key])
                if !text.isEmpty { return text }
            }
            let secondaryKeys = ["cards", "flashcards", "questions", "bulletPoints",
                                 "must_know", "commonly_confused", "clinical_tus_tips",
                                 "self_check", "steps", "rows", "segments", "chapters",
                                 "days", "nodes", "branches", "sections"]
            for key in secondaryKeys {
                let text = firstGeneratedText(dict[key])
                if !text.isEmpty { return text }
            }
            return ""
        default:
            return ""
        }
    }

    private func contentItemCount(_ content: AnyJSON?) -> Int {
        guard let content else { return 1 }
        if case .array(let arr) = content { return arr.count }
        if case .object(let dict) = content {
            let countKeys = ["cards", "flashcards", "questions", "bulletPoints",
                             "must_know", "commonly_confused", "clinical_tus_tips",
                             "self_check", "steps", "rows", "segments", "chapters",
                             "days", "nodes", "branches", "sections",
                             "teachingPoints", "objectives", "sessions"]
            for key in countKeys {
                if let val = dict[key], case .array(let arr) = val, !arr.isEmpty {
                    return arr.count
                }
            }
        }
        return 1
    }

    private func metadataText(from raw: AnyJSON?, key: String) -> String? {
        guard case .object(let dict) = raw else { return nil }
        return dict[key]?.stringValue
    }
}

// MARK: - AnyJSON Dictionary Helpers

extension [String: AnyJSON] {
    func stringValue(for key: String) -> String? {
        self[key]?.stringValue
    }
}

extension AnyJSON {
    var dictValue: [String: AnyJSON]? {
        if case .object(let d) = self { return d }
        return nil
    }

    var arrayValue: [AnyJSON]? {
        if case .array(let a) = self { return a }
        return nil
    }

    var intValue: Int? {
        switch self {
        case .integer(let v): return v
        case .double(let v): return Int(v)
        case .string(let v): return Int(v)
        default: return nil
        }
    }

    var doubleValue: Double? {
        switch self {
        case .integer(let v): return Double(v)
        case .double(let v): return v
        case .string(let v): return Double(v)
        default: return nil
        }
    }
}
```

## File: Sources/SourceBaseBackend/Drive/DriveUploadPayload.swift
```swift
import Foundation

public struct PickedDriveFile: Sendable {
    public let name: String
    public let contentType: String
    public let sizeBytes: Int
    public let data: Data?
    public let fileURL: URL?

    public init(name: String, contentType: String, sizeBytes: Int, data: Data) {
        self.name = name
        self.contentType = contentType
        self.sizeBytes = sizeBytes
        self.data = data
        self.fileURL = nil
    }

    public init(name: String, contentType: String, sizeBytes: Int, fileURL: URL) {
        self.name = name
        self.contentType = contentType
        self.sizeBytes = sizeBytes
        self.data = nil
        self.fileURL = fileURL
    }

    public var hasSupportedExtension: Bool {
        DriveUploadService.isSupportedFileName(name)
    }

    public var hasReadableContent: Bool {
        sizeBytes > 0 && (data?.isEmpty == false || fileURL != nil)
    }
}
```

## File: Sources/SourceBaseBackend/Drive/DriveUploadService.swift
```swift
import Foundation

public enum UploadError: Error, Sendable {
    case uploadFailed(statusCode: Int?)
    case timeout
    case noData
}

public struct DriveUploadService: Sendable {

    public init() {}

    public func uploadBytes(
        uploadURL: String,
        headers: [String: String],
        file: PickedDriveFile
    ) async throws {
        guard let url = URL(string: uploadURL) else {
            throw UploadError.uploadFailed(statusCode: nil)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"

        var hasContentType = false
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
            if key.lowercased() == "content-type" {
                hasContentType = true
            }
        }

        if !hasContentType && !file.contentType.trimmingCharacters(in: .whitespaces).isEmpty {
            request.setValue(file.contentType, forHTTPHeaderField: "Content-Type")
        }

        request.setValue(String(file.sizeBytes), forHTTPHeaderField: "Content-Length")
        request.timeoutInterval = 120

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForResource = 120
        config.timeoutIntervalForRequest = 120
        let session = URLSession(configuration: config)

        let response: URLResponse
        if let fileURL = file.fileURL {
            let didAccess = fileURL.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    fileURL.stopAccessingSecurityScopedResource()
                }
            }
            (_, response) = try await session.upload(for: request, fromFile: fileURL)
        } else if let data = file.data {
            (_, response) = try await session.upload(for: request, from: data)
        } else {
            throw UploadError.noData
        }
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw UploadError.uploadFailed(
                statusCode: (response as? HTTPURLResponse)?.statusCode
            )
        }
    }

    public static func contentTypeFor(_ fileName: String) -> String {
        switch normalizedExtension(fileName) {
        case "pdf":
            return "application/pdf"
        case "ppt":
            return "application/vnd.ms-powerpoint"
        case "pptx":
            return "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        case "doc":
            return "application/msword"
        case "docx":
            return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "jpg", "jpeg":
            return "image/jpeg"
        case "png":
            return "image/png"
        case "webp":
            return "image/webp"
        default:
            return "application/octet-stream"
        }
    }

    public static let allowedExtensions = ["pdf", "pptx", "docx", "ppt", "doc"]
    public static let supportedExtensionsDisplay = "PDF, PPTX, DOCX, PPT veya DOC"
    public static let primarySupportedExtensionsDisplay = "PDF, PPTX veya DOCX"
    public static let maxSizeBytes: Int = 25 * 1024 * 1024 // 25 MB (matches server MAX_UPLOAD_BYTES)

    public static func isSupportedFileName(_ fileName: String) -> Bool {
        allowedExtensions.contains(normalizedExtension(fileName))
    }

    public static func normalizedExtension(_ fileName: String) -> String {
        URL(fileURLWithPath: fileName).pathExtension.lowercased()
    }
}
```

## File: Sources/SourceBaseBackend/Drive/GeneratedContentModels.swift
```swift
import Foundation
import Supabase

public struct SBFlashcard: Identifiable, Sendable, Equatable {
    public let id: String
    public let front: String
    public let back: String
    public let explanation: String
    public let difficulty: String
    public let hint: String

    public init(
        id: String = UUID().uuidString,
        front: String,
        back: String,
        explanation: String = "",
        difficulty: String = "",
        hint: String = ""
    ) {
        self.id = id
        self.front = front
        self.back = back
        self.explanation = explanation
        self.difficulty = difficulty
        self.hint = hint
    }
}

public struct SBQlinikQuestion: Identifiable, Sendable, Equatable {
    public let id: String
    public let subject: String
    public let topic: String
    public let difficulty: String
    public let text: String
    public let options: [String]
    public let correctIndex: Int
    public let explanation: String
    public let optionRationales: [String]
    public let tags: [String]
    public let isUserGenerated: Bool

    public init(
        id: String = UUID().uuidString,
        subject: String,
        topic: String,
        difficulty: String,
        text: String,
        options: [String],
        correctIndex: Int,
        explanation: String,
        optionRationales: [String] = [],
        tags: [String] = [],
        isUserGenerated: Bool = true
    ) {
        self.id = id
        self.subject = subject
        self.topic = topic
        self.difficulty = difficulty
        self.text = text
        self.options = options
        self.correctIndex = correctIndex
        self.explanation = explanation
        self.optionRationales = optionRationales
        self.tags = tags
        self.isUserGenerated = isUserGenerated
    }

    public var isQlinikCompatibleFiveChoice: Bool {
        options.count == 5
            && correctIndex >= 0
            && correctIndex < options.count
            && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !explanation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && options.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}

public struct SBQuestionPrompt: Identifiable, Sendable, Equatable {
    public let id: String
    public let subject: String
    public let topic: String
    public let difficulty: String
    public let text: String
    public let options: [String]
    public let tags: [String]

    public init(
        id: String,
        subject: String = "Kullanıcı Kaynağı",
        topic: String = "SourceBase",
        difficulty: String = "medium",
        text: String,
        options: [String],
        tags: [String] = []
    ) {
        self.id = id
        self.subject = subject
        self.topic = topic
        self.difficulty = difficulty
        self.text = text
        self.options = options
        self.tags = tags
    }

    public var isFiveChoice: Bool {
        options.count == 5
            && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && options.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}

public struct SBQuestionAnswerFeedback: Sendable, Equatable {
    public let questionId: String
    public let selectedIndex: Int
    public let isCorrect: Bool
    public let correctIndex: Int?
    public let explanation: String
    public let optionRationales: [String]

    public init(
        questionId: String,
        selectedIndex: Int,
        isCorrect: Bool,
        correctIndex: Int? = nil,
        explanation: String = "",
        optionRationales: [String] = []
    ) {
        self.questionId = questionId
        self.selectedIndex = selectedIndex
        self.isCorrect = isCorrect
        self.correctIndex = correctIndex
        self.explanation = explanation
        self.optionRationales = optionRationales
    }
}

public struct SBStudySection: Identifiable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let items: [String]

    public init(id: String = UUID().uuidString, title: String, items: [String]) {
        self.id = id
        self.title = title
        self.items = items
    }
}

public struct SBStudyTable: Sendable, Equatable {
    public let headers: [String]
    public let rows: [[String]]

    public init(headers: [String], rows: [[String]]) {
        self.headers = headers
        self.rows = rows
    }
}

public struct SBStudyTemplateContent: Sendable, Equatable {
    public let title: String
    public let summary: String
    public let sections: [SBStudySection]
    public let table: SBStudyTable?

    public init(title: String, summary: String = "", sections: [SBStudySection], table: SBStudyTable? = nil) {
        self.title = title
        self.summary = summary
        self.sections = sections
        self.table = table
    }
}

public struct SBPodcastSegment: Identifiable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let text: String
    public let durationLabel: String

    public init(id: String = UUID().uuidString, title: String, text: String, durationLabel: String = "") {
        self.id = id
        self.title = title
        self.text = text
        self.durationLabel = durationLabel
    }
}

public struct SBPodcastContent: Sendable, Equatable {
    public let title: String
    public let durationLabel: String
    public let audioURL: URL?
    public let assetPath: String?
    public let segments: [SBPodcastSegment]

    public init(title: String, durationLabel: String = "", audioURL: URL? = nil, assetPath: String? = nil, segments: [SBPodcastSegment]) {
        self.title = title
        self.durationLabel = durationLabel
        self.audioURL = audioURL
        self.assetPath = assetPath
        self.segments = segments
    }
}

public struct SBInfographicContent: Sendable, Equatable {
    public let title: String
    public let imageURL: URL?
    public let assetPath: String?
    public let blocks: [String]

    public init(title: String, imageURL: URL? = nil, assetPath: String? = nil, blocks: [String]) {
        self.title = title
        self.imageURL = imageURL
        self.assetPath = assetPath
        self.blocks = blocks
    }
}

public extension GeneratedOutput {
    var flashcards: [SBFlashcard] {
        GeneratedContentParser.flashcards(from: content, fallbackText: contentText)
    }

    var qlinikQuestions: [SBQlinikQuestion] {
        GeneratedContentParser.questions(from: content)
    }

    var qlinikCompatibleQuestions: [SBQlinikQuestion] {
        let questions = qlinikQuestions
        guard !questions.isEmpty,
              questions.allSatisfy(\.isQlinikCompatibleFiveChoice) else { return [] }
        return questions
    }

    var studyTemplateContent: SBStudyTemplateContent {
        GeneratedContentParser.studyTemplate(from: content, fallbackTitle: title, fallbackText: contentText)
    }

    var podcastContent: SBPodcastContent {
        GeneratedContentParser.podcast(from: content, fallbackTitle: title, fallbackText: contentText)
    }

    var infographicContent: SBInfographicContent {
        GeneratedContentParser.infographic(from: content, fallbackTitle: title, fallbackText: contentText)
    }

    /// Canonical systematic document used by BOTH the study screen and the PDF.
    var studyDocument: SBStudyDocument {
        GeneratedContentParser.document(
            for: kind,
            from: content,
            fallbackTitle: title,
            fallbackText: contentText
        )
    }
}

public enum GeneratedContentParser {
    public static func questionPrompts(from response: [String: AnyJSON]) -> [SBQuestionPrompt] {
        let root = objectPayload(from: response)
        let rawQuestions = array(in: root, keys: ["questions", "items"]) ?? arrayValue(root)
        return rawQuestions?.enumerated().compactMap { index, value -> SBQuestionPrompt? in
            guard let dict = objectValue(value) else { return nil }
            let text = firstString(dict, keys: ["text", "question", "stem"])
            let options = stringArray(dict["options"])
            guard !text.isEmpty, options.count == 5 else { return nil }
            return SBQuestionPrompt(
                id: firstString(dict, keys: ["id", "questionId", "question_id"]).nilIfEmpty ?? "question-\(index)",
                subject: firstString(dict, keys: ["subject"]).nilIfEmpty ?? "Kullanıcı Kaynağı",
                topic: firstString(dict, keys: ["topic"]).nilIfEmpty ?? "SourceBase",
                difficulty: normalizedDifficulty(firstString(dict, keys: ["difficulty"])),
                text: text,
                options: options,
                tags: stringArray(dict["tags"])
            )
        } ?? []
    }

    public static func questionAnswerFeedback(from response: [String: AnyJSON], fallbackQuestionId: String, selectedIndex: Int) -> SBQuestionAnswerFeedback {
        let root = objectValue(objectPayload(from: response)) ?? response
        let isCorrect = boolValue(root["isCorrect"] ?? root["is_correct"] ?? root["correct"]) ?? false
        let correctIndex = firstInt(root, keys: ["correctIndex", "correct_index", "correctAnswerIndex", "correct_answer_index", "answerIndex", "answer_index"])
        return SBQuestionAnswerFeedback(
            questionId: firstString(root, keys: ["questionId", "question_id", "id"]).nilIfEmpty ?? fallbackQuestionId,
            selectedIndex: intValue(root["selectedIndex"] ?? root["selected_index"]) ?? selectedIndex,
            isCorrect: isCorrect,
            correctIndex: correctIndex,
            explanation: firstString(root, keys: ["explanation", "rationale"]),
            optionRationales: stringArray(root["optionRationales"] ?? root["option_rationales"])
        )
    }

    public static func flashcards(from content: AnyJSON?, fallbackText: String? = nil) -> [SBFlashcard] {
        let rawCards = array(in: content, keys: ["cards", "flashcards"]) ?? arrayValue(content)
        let cards = rawCards?.enumerated().compactMap { index, value -> SBFlashcard? in
            guard let dict = objectValue(value) else {
                let text = cleanFlashcardText(stringValue(value))
                return text.isEmpty ? nil : SBFlashcard(id: "card-\(index)", front: text, back: "")
            }
            let front = cleanFlashcardText(firstString(dict, keys: ["front", "question", "prompt", "term", "title"]))
            let back = cleanFlashcardText(firstString(dict, keys: ["back", "answer", "definition", "text"]))
            guard !front.isEmpty || !back.isEmpty else { return nil }
            return SBFlashcard(
                id: firstString(dict, keys: ["id"]).nilIfEmpty ?? "card-\(index)",
                front: front.isEmpty ? "Kart \(index + 1)" : front,
                back: back,
                explanation: cleanFlashcardText(firstString(dict, keys: ["explanation", "rationale", "note"])),
                difficulty: firstString(dict, keys: ["difficulty"]),
                hint: cleanFlashcardText(firstString(dict, keys: ["hint", "ipucu"]))
            )
        } ?? []

        if !cards.isEmpty { return cards }
        let fallback = cleanFlashcardText(fallbackText ?? "")
        guard !fallback.isEmpty else { return [] }
        return [SBFlashcard(front: fallback.components(separatedBy: "\n").first ?? "Kart", back: fallback)]
    }

    public static func questions(from content: AnyJSON?) -> [SBQlinikQuestion] {
        let rawQuestions = array(in: content, keys: ["questions", "items"]) ?? arrayValue(content)
        return rawQuestions?.enumerated().compactMap { index, value -> SBQlinikQuestion? in
            guard let dict = objectValue(value) else { return nil }
            let options = stringArray(dict["options"])
            let rationales = stringArray(dict["option_rationales"] ?? dict["optionRationales"])
            let text = firstString(dict, keys: ["text", "question", "stem"])
            guard !text.isEmpty, !options.isEmpty else { return nil }
            return SBQlinikQuestion(
                id: firstString(dict, keys: ["id"]).nilIfEmpty ?? "question-\(index)",
                subject: firstString(dict, keys: ["subject"]).nilIfEmpty ?? "Kullanıcı Kaynağı",
                topic: firstString(dict, keys: ["topic"]).nilIfEmpty ?? "SourceBase",
                difficulty: normalizedDifficulty(firstString(dict, keys: ["difficulty"])),
                text: text,
                options: options,
                correctIndex: firstInt(dict, keys: ["correct_index", "correctIndex", "correctAnswerIndex", "correct_answer_index", "answerIndex", "answer_index", "correctOptionIndex", "correct_option_index"]) ?? -1,
                explanation: firstString(dict, keys: ["explanation", "rationale"]),
                optionRationales: rationales,
                tags: stringArray(dict["tags"]),
                isUserGenerated: boolValue(dict["is_user_generated"] ?? dict["isUserGenerated"]) ?? true
            )
        } ?? []
    }

    public static func studyTemplate(
        from content: AnyJSON?,
        fallbackTitle: String,
        fallbackText: String? = nil
    ) -> SBStudyTemplateContent {
        let dict = objectValue(content)
        let title = dict.flatMap { firstString($0, keys: ["title", "name"]).nilIfEmpty } ?? fallbackTitle
        let summary = dict.map { firstString($0, keys: ["summary", "description", "overview"]) } ?? ""
        var sections: [SBStudySection] = []

        if let dict {
            let keys = [
                "must_know", "commonly_confused", "clinical_tus_tips", "red_flags",
                "self_check", "decision_nodes", "branches", "thresholds", "action_steps",
                "distinguishing_tips", "clinical_notes", "steps", "nodes", "sections",
                "teachingPoints", "teaching_points", "objectives", "learningObjectives",
                "learning_objectives", "days", "tasks", "redFlags", "clinicalTips",
                "clinical_tips", "highYieldPoints", "high_yield_points", "pitfalls",
                "keyTakeaways", "key_takeaways"
            ]
            for key in keys {
                let items = sectionItems(dict[key])
                if !items.isEmpty {
                    sections.append(SBStudySection(title: label(for: key), items: items))
                }
            }
        }

        if sections.isEmpty {
            let fallbackItems = (fallbackText ?? "")
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            sections.append(SBStudySection(title: "Çalışma Notları", items: fallbackItems.isEmpty ? ["Bu çalışma ekranı için kaynak içeriği henüz hazırlanmadı."] : fallbackItems))
        }

        return SBStudyTemplateContent(
            title: title,
            summary: summary,
            sections: sections,
            table: table(from: dict)
        )
    }

    public static func podcast(from content: AnyJSON?, fallbackTitle: String, fallbackText: String? = nil) -> SBPodcastContent {
        let dict = objectValue(content)
        let title = dict.flatMap { firstString($0, keys: ["title", "name"]).nilIfEmpty } ?? fallbackTitle
        let duration = dict.map { firstString($0, keys: ["duration", "durationLabel", "duration_label"]) } ?? ""
        let audioText = dict.map {
            firstString(
                $0,
                keys: [
                    "audio_url", "audioUrl", "audioFileUrl", "audio_file_url",
                    "mp3_url", "mp3Url", "m4a_url", "m4aUrl",
                    "storageUrl", "storage_url", "publicUrl", "public_url",
                    "assetUrl", "asset_url", "url"
                ]
            )
        } ?? ""
        let segmentsRaw = dict.flatMap { array(in: .object($0), keys: ["segments", "chapters"]) } ?? []
        let segments = segmentsRaw.enumerated().compactMap { index, value -> SBPodcastSegment? in
            guard let item = objectValue(value) else {
                let text = stringValue(value)
                return text.isEmpty ? nil : SBPodcastSegment(id: "segment-\(index)", title: "Bölüm \(index + 1)", text: text)
            }
            let text = firstString(item, keys: ["text", "script", "body", "content"])
            guard !text.isEmpty else { return nil }
            return SBPodcastSegment(
                id: firstString(item, keys: ["id"]).nilIfEmpty ?? "segment-\(index)",
                title: firstString(item, keys: ["title", "heading"]).nilIfEmpty ?? "Bölüm \(index + 1)",
                text: text,
                durationLabel: firstString(item, keys: ["duration", "durationLabel", "duration_label"])
            )
        }
        let fallback = fallbackText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return SBPodcastContent(
            title: title,
            durationLabel: duration,
            audioURL: absoluteRemoteURL(from: audioText),
            assetPath: dict.flatMap(podcastAssetPath),
            segments: segments.isEmpty && !fallback.isEmpty
                ? [SBPodcastSegment(title: "Transkript", text: fallback)]
                : segments
        )
    }

    public static func infographic(from content: AnyJSON?, fallbackTitle: String, fallbackText: String? = nil) -> SBInfographicContent {
        let dict = objectValue(content)
        let title = dict.flatMap { firstString($0, keys: ["title", "headline"]).nilIfEmpty } ?? fallbackTitle
        return SBInfographicContent(
            title: title,
            imageURL: dict.flatMap(infographicImageURL),
            assetPath: dict.flatMap(infographicAssetPath),
            blocks: dict.map { infographicBlocks(from: $0, fallbackText: fallbackText) }
                ?? fallbackLines(fallbackText)
        )
    }

    // MARK: - Systematic document builder

    /// Build the canonical per-kind document. Maps each output type's real JSON
    /// fields (see edge fn `ai-generation-provider.ts`) into typed blocks. Reuses the lenient
    /// helpers below so partial / legacy payloads still render.
    public static func document(
        for kind: GeneratedKind,
        from content: AnyJSON?,
        fallbackTitle: String,
        fallbackText: String?
    ) -> SBStudyDocument {
        let dict = objectValue(content)
        let title = dict.flatMap { firstString($0, keys: ["title", "name", "headline", "centralTopic"]).nilIfEmpty } ?? fallbackTitle
        var blocks: [SBStudyBlock] = []
        var summary = dict.map { firstString($0, keys: ["summary", "overview", "description", "fullText"]) } ?? ""

        func callout(_ t: String, _ key: String, _ style: SBCalloutStyle) {
            let items = sectionItems(dict?[key])
            if !items.isEmpty { blocks.append(.calloutList(id: "\(kind.rawValue)-\(key)", title: t, items: items, style: style)) }
        }
        func calloutAny(_ t: String, keys: [String], style: SBCalloutStyle, id: String) {
            guard let dict else { return }
            let items = keys.lazy.map { sectionItems(dict[$0]) }.first { !$0.isEmpty } ?? []
            if !items.isEmpty { blocks.append(.calloutList(id: "\(kind.rawValue)-\(id)", title: t, items: items, style: style)) }
        }
        func steps(_ t: String, _ key: String) {
            let items = sectionItems(dict?[key])
            if !items.isEmpty { blocks.append(.steps(id: "\(kind.rawValue)-\(key)", title: t, items: items)) }
        }

        switch kind {
        case .flashcard:
            let cards = flashcards(from: content, fallbackText: fallbackText)
            if !cards.isEmpty { blocks.append(.cards(id: "cards", cards: cards)) }
            callout("Kaynakta Eksik Kalanlar", "source_gaps", .redFlag)

        case .question:
            let qs = questions(from: content)
            if !qs.isEmpty { blocks.append(.quiz(id: "quiz", questions: qs)) }
            callout("Kaynakta Eksik Kalanlar", "source_gaps", .redFlag)

        case .summary:
            callout("Ana Konular", "mainTopics", .plain)
            callout("Yüksek Verimli Noktalar", "high_yield_points", .mustKnow)
            callout("Yüksek Verimli Noktalar", "highYieldPoints", .mustKnow)
            callout("Önemli Maddeler", "bulletPoints", .mustKnow)
            callout("Mutlaka Bil", "mustKnow", .mustKnow)
            callout("Mutlaka Bil", "must_know", .mustKnow)
            callout("Kırmızı Bayraklar", "redFlags", .redFlag)
            callout("Kırmızı Bayraklar", "red_flags", .redFlag)
            callout("Sık Karışanlar", "commonlyConfused", .confused)
            callout("Sık Karışanlar", "commonly_confused", .confused)
            if let t = table(from: dict) { blocks.append(.table(id: "mini_table", title: "Mini Tablo", table: t)) }
            steps("Klinik Karar Akışı", "clinicalDecisionFlow")
            steps("Klinik Karar Akışı", "clinical_decision_flow")
            callout("Sınav Tuzakları", "examTraps", .tip)
            callout("Sınav Tuzakları", "exam_traps", .tip)
            callout("Anahtar Terimler", "keyTerms", .tip)
            callout("Kaynakta Eksik Kalanlar", "source_gaps", .redFlag)
            let sc = qaPairs(dict?["self_check"] ?? dict?["quick_check"])
            if !sc.isEmpty { blocks.append(.qa(id: "self_check", title: "Kendini Kontrol Et", pairs: sc)) }

        case .examMorningSummary:
            callout("Mutlaka Bil", "must_know", .mustKnow)
            callout("Sık Karışanlar", "commonly_confused", .confused)
            callout("Klinik / TUS İpuçları", "clinical_tus_tips", .tip)
            callout("Kırmızı Bayraklar", "red_flags", .redFlag)
            steps("Algoritma Akışı", "algorithm_flow")
            if let t = table(from: dict) { blocks.append(.table(id: "mini_table", title: "Hızlı Tablo", table: t)) }
            let sc = qaPairs(dict?["self_check"])
            if !sc.isEmpty { blocks.append(.qa(id: "self_check", title: "Kendini Kontrol Et", pairs: sc)) }
            callout("Kaynakta Eksik Kalanlar", "source_gaps", .redFlag)

        case .algorithm:
            if let start = dict.flatMap({ firstString($0, keys: ["starting_point", "startingPoint", "entry", "entry_point", "entryPoint"]).nilIfEmpty }) {
                blocks.append(.paragraph(id: "start", text: "Başlangıç: \(start)"))
            }
            let nodes = decisionNodes(dict?["decision_nodes"] ?? dict?["decisionNodes"] ?? dict?["nodes"])
            if !nodes.isEmpty { blocks.append(.decisions(id: "decision_nodes", title: "Karar Düğümleri", nodes: nodes)) }
            let actionItems = sectionItems(dict?["action_steps"] ?? dict?["actionSteps"] ?? dict?["steps"])
            if !actionItems.isEmpty { blocks.append(.steps(id: "algorithm-actions", title: "Eylem Adımları", items: actionItems)) }
            callout("Akış Dalları", "branches", .plain)
            callout("Kritik Eşikler", "critical_thresholds", .mustKnow)
            callout("Kritik Eşikler", "criticalThresholds", .mustKnow)
            callout("Kırmızı Bayraklar", "red_flags", .redFlag)
            callout("Kırmızı Bayraklar", "redFlags", .redFlag)
            callout("Sınav İpuçları", "exam_tips", .tip)
            callout("Sınav İpuçları", "examTips", .tip)
            callout("Notlar", "notes", .plain)
            callout("Kaynakta Eksik Kalanlar", "source_gaps", .redFlag)
            callout("Kaynakta Eksik Kalanlar", "sourceGaps", .redFlag)

        case .comparison, .table:
            if let t = comparisonTable(from: dict) ?? table(from: dict) {
                blocks.append(.table(id: "comparison", title: "Karşılaştırma", table: t))
            }
            callout("Ayırt Edici İpuçları", "distinguishing_tips", .tip)
            callout("Klinik Notlar", "clinical_notes", .plain)
            callout("Sık Karışanlar", "commonly_confused", .confused)
            callout("Kırmızı Bayraklar", "red_flags", .redFlag)
            callout("Kısa Sonuç", "short_takeaway", .mustKnow)
            callout("Kaynakta Eksik Kalanlar", "source_gaps", .redFlag)

        case .clinicalScenario:
            let kv = [
                ("Hasta", dict.map { firstString($0, keys: ["patientInfo", "patient_info", "patient", "patientSnapshot", "patient_snapshot"]) } ?? ""),
                ("Başvuru Şikayeti", dict.map { firstString($0, keys: ["chiefComplaint", "chief_complaint", "complaint"]) } ?? ""),
                ("Karar Noktası", dict.map { firstString($0, keys: ["decisionPoint", "decision_point"]) } ?? "")
            ].filter { !$0.1.isEmpty }.map { SBKeyValue(key: $0.0, value: $0.1) }
            if !kv.isEmpty { blocks.append(.keyValues(id: "patient", title: "Vaka Bilgisi", pairs: kv)) }
            if let stem = dict.flatMap({ firstString($0, keys: ["caseStem", "case_stem", "history", "case", "scenario"]).nilIfEmpty }) {
                blocks.append(.paragraph(id: "stem", text: stem))
            }
            callout("Fizik Muayene", "physicalExam", .plain)
            callout("Fizik Muayene", "physical_exam", .plain)
            callout("Lab / Görüntüleme", "labsImaging", .plain)
            callout("Lab / Görüntüleme", "labs_imaging", .plain)
            callout("Bulgular", "findings", .mustKnow)
            callout("Problem Temsili", "problemRepresentation", .mustKnow)
            callout("Problem Temsili", "problem_representation", .mustKnow)
            callout("Ayırıcı Tanı", "differentialDiagnosis", .confused)
            callout("Ayırıcı Tanı", "differential_diagnosis", .confused)
            callout("Tanısal Gerekçe", "diagnosticJustification", .tip)
            callout("Tanısal Gerekçe", "diagnostic_justification", .tip)
            let nodes = decisionNodes(dict?["decision_nodes"] ?? dict?["decisionNodes"])
            if !nodes.isEmpty { blocks.append(.decisions(id: "clinical_decision_nodes", title: "Karar Noktaları", nodes: nodes)) }
            callout("Kırmızı Bayraklar", "red_flags", .redFlag)
            callout("Kırmızı Bayraklar", "redFlags", .redFlag)
            let qa = qaPairs(dict?["questions"])
            if !qa.isEmpty { blocks.append(.qa(id: "questions", title: "Sorular", pairs: qa)) }
            callout("Öğrenme Hedefleri", "learningObjective", .objective)
            callout("Öğrenme Hedefleri", "learning_objective", .objective)
            callout("Öğretim Noktaları", "teachingPoints", .tip)
            callout("Öğretim Noktaları", "teaching_points", .tip)
            callout("Sınav İpuçları", "examTips", .tip)
            callout("Sınav İpuçları", "exam_tips", .tip)

        case .learningPlan:
            if let dur = dict.flatMap({ firstString($0, keys: ["duration"]).nilIfEmpty }) {
                blocks.append(.paragraph(id: "duration", text: "Süre: \(dur)"))
            }
            let sessions = timelineEntries(dict?["sessions"] ?? dict?["study_sessions"] ?? dict?["studySessions"])
            if !sessions.isEmpty { blocks.append(.timeline(id: "sessions", title: "Çalışma Oturumları", entries: sessions)) }
            callout("Bugün Başla", "startToday", .mustKnow)
            callout("Bugün Başla", "start_today", .mustKnow)
            callout("Günlük Hedefler", "dailyGoals", .objective)
            callout("Günlük Hedefler", "daily_goals", .objective)
            steps("Yapılacaklar", "checklist")
            callout("Tekrar Günleri", "reviewDays", .plain)
            callout("Tekrar Günleri", "review_days", .plain)
            callout("Zayıf Noktalar", "weakPoints", .redFlag)
            callout("Zayıf Noktalar", "weak_points", .redFlag)
            callout("Hedefler", "objectives", .objective)
            callout("Soru / Flashcard Önerileri", "questionFlashcardSuggestions", .tip)
            callout("Soru / Flashcard Önerileri", "question_flashcard_suggestions", .tip)

        case .podcast:
            let p = podcast(from: content, fallbackTitle: title, fallbackText: fallbackText)
            blocks.append(.audio(id: "audio", url: p.audioURL, segments: p.segments))
            callout("Kısa Özet", "recap", .mustKnow)
            callout("Aktif Hatırlama", "active_recall_prompts", .tip)
            callout("Kaynak Sınırları", "source_limits", .redFlag)
            if summary.isEmpty { summary = p.durationLabel }

        case .infographic:
            let info = infographic(from: content, fallbackTitle: title, fallbackText: fallbackText)
            if let imageURL = info.imageURL {
                blocks.append(.image(id: "image", url: imageURL, caption: info.title))
            }
            callout("Ana Mesaj", "main_message", .mustKnow)
            callout("Ana Mesaj", "mainMessage", .mustKnow)
            // Section bullets (heading + bullets[]) become callout lists.
            let sectionStartCount = blocks.count
            if let sections = array(in: content, keys: ["sections"]) {
                for (i, value) in sections.enumerated() {
                    guard let obj = objectValue(value) else { continue }
                    let heading = firstString(obj, keys: ["heading", "title"]).nilIfEmpty ?? "Bölüm \(i + 1)"
                    let bullets = sectionItems(obj["bullets"] ?? obj["items"])
                    if !bullets.isEmpty { blocks.append(.calloutList(id: "info-\(i)", title: heading, items: bullets, style: .plain)) }
                }
            }
            if blocks.count == sectionStartCount, !info.blocks.isEmpty {
                blocks.append(.calloutList(id: "info-blocks", title: "Öne Çıkanlar", items: info.blocks, style: .plain))
            }
            callout("Uyarılar", "warnings", .redFlag)
            callout("Kırmızı Bayraklar", "red_flags", .redFlag)
            callout("Kırmızı Bayraklar", "redFlags", .redFlag)
            callout("Kaynak Notu", "source_note", .plain)
            callout("Kaynak Notu", "sourceNote", .plain)
            let quickCheck = qaPairs(dict?["quick_check"])
            if !quickCheck.isEmpty {
                blocks.append(.qa(id: "quick_check", title: "Hızlı Kontrol", pairs: quickCheck))
            } else {
                calloutAny(
                    "Hızlı Kontrol",
                    keys: ["quick_check", "quickCheck", "self_check", "selfCheck"],
                    style: .objective,
                    id: "quick-check"
                )
            }

        case .mindMap:
            if let center = dict.flatMap({ firstString($0, keys: ["centralTopic", "central_topic", "topic"]).nilIfEmpty }) {
                blocks.append(.paragraph(id: "center", text: "Merkez Konu: \(center)"))
            }
            let branches = mindBranches(dict?["branches"])
            if !branches.isEmpty { blocks.append(.mindBranches(id: "branches", title: "Dallar", branches: branches)) }
            callout("Kritik Bağlantılar", "criticalConnections", .mustKnow)
            callout("Kritik Bağlantılar", "critical_connections", .mustKnow)
            callout("Sık Karışanlar", "commonly_confused", .confused)
            callout("Klinik / TUS İpuçları", "clinicalTusTips", .tip)
            callout("Klinik / TUS İpuçları", "clinical_tus_tips", .tip)
            callout("Kaynakta Eksik Kalanlar", "source_gaps", .redFlag)
        }

        calloutAny(
            "Sonraki Tekrar",
            keys: ["next_review_prompts", "nextReviewPrompts", "review_prompts", "reviewPrompts", "spaced_review_prompts", "spacedReviewPrompts"],
            style: .objective,
            id: "next-review"
        )

        if blocks.isEmpty {
            let fallback = fallbackDocumentParts(for: kind, fallbackText: fallbackText)
            if summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                summary = fallback.summary
            }
            blocks.append(contentsOf: fallback.blocks)
        }

        // Universal fallback: never show an empty screen.
        if blocks.isEmpty && summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let template = studyTemplate(from: content, fallbackTitle: fallbackTitle, fallbackText: fallbackText)
            summary = template.summary
            for s in template.sections where !s.items.isEmpty {
                blocks.append(.calloutList(id: s.id, title: s.title, items: s.items, style: .plain))
            }
            if let t = template.table { blocks.append(.table(id: "fallback-table", title: "Tablo", table: t)) }
        }

        let subtitle = dict.flatMap { firstString($0, keys: ["duration", "patientInfo", "sourceName", "infographic_type"]).nilIfEmpty } ?? ""
        return SBStudyDocument(kind: kind, title: title, subtitle: subtitle, summary: summary, blocks: blocks)
    }

    private static func decisionNodes(_ value: AnyJSON?) -> [SBDecisionNode] {
        guard let raw = arrayValue(value) else { return [] }
        return raw.enumerated().compactMap { index, item in
            guard let d = objectValue(item) else { return nil }
            let title = firstString(d, keys: ["title", "label", "question", "node"])
            guard !title.isEmpty else { return nil }
            return SBDecisionNode(
                id: firstString(d, keys: ["id"]).nilIfEmpty ?? "node-\(index)",
                title: title,
                detail: firstString(d, keys: ["description", "detail", "meaning"]),
                yes: firstString(d, keys: ["yes", "ifYes", "evet"]),
                no: firstString(d, keys: ["no", "ifNo", "hayir", "hayır"]),
                substeps: stringArray(d["substeps"] ?? d["subSteps"])
            )
        }
    }

    private static func qaPairs(_ value: AnyJSON?) -> [SBQAPair] {
        guard let raw = arrayValue(value) else { return [] }
        return raw.enumerated().compactMap { index, item in
            guard let d = objectValue(item) else {
                let text = stringValue(item)
                return text.isEmpty ? nil : SBQAPair(question: text, answer: "")
            }
            let q = firstString(d, keys: ["question", "q", "prompt"])
            guard !q.isEmpty else { return nil }
            return SBQAPair(
                id: firstString(d, keys: ["id"]).nilIfEmpty ?? "qa-\(index)",
                question: q,
                answer: firstString(d, keys: ["answer", "a", "response"]),
                explanation: firstString(d, keys: ["explanation", "rationale", "detail"])
            )
        }
    }

    private static func timelineEntries(_ value: AnyJSON?) -> [SBTimelineEntry] {
        guard let raw = arrayValue(value) else { return [] }
        return raw.enumerated().compactMap { index, item in
            guard let d = objectValue(item) else {
                let text = stringValue(item)
                return text.isEmpty ? nil : SBTimelineEntry(title: text, items: [])
            }
            let title = firstString(d, keys: ["title", "day", "label", "name"]).nilIfEmpty ?? "Oturum \(index + 1)"
            let minutes = firstInt(d, keys: ["estimatedMinutes", "minutes", "estimated_minutes"])
            let meta = minutes.map { "\($0) dk" } ?? firstString(d, keys: ["duration", "meta"])
            return SBTimelineEntry(
                id: firstString(d, keys: ["id"]).nilIfEmpty ?? "session-\(index)",
                title: title,
                meta: meta,
                items: stringArray(d["activities"] ?? d["tasks"] ?? d["items"])
            )
        }
    }

    private static func mindBranches(_ value: AnyJSON?) -> [SBMindBranch] {
        guard let raw = arrayValue(value) else { return [] }
        return raw.enumerated().compactMap { index, item in
            guard let d = objectValue(item) else { return nil }
            let label = firstString(d, keys: ["label", "title", "name", "topic"])
            guard !label.isEmpty else { return nil }
            return SBMindBranch(
                id: firstString(d, keys: ["id"]).nilIfEmpty ?? "branch-\(index)",
                label: label,
                children: stringArray(d["children"] ?? d["subbranches"] ?? d["sub_branches"] ?? d["items"]),
                tags: stringArray(d["tags"])
            )
        }
    }

    private static func podcastAssetPath(from dict: [String: AnyJSON]) -> String? {
        for key in [
            "audio", "asset", "media", "file", "output",
            "audios", "assets", "mediaAssets", "media_assets",
            "files", "outputs", "generatedAudio", "generated_audio"
        ] {
            if let path = generatedAssetPath(from: dict[key]) { return path }
        }

        return generatedAssetPath(
            from: firstString(
                dict,
                keys: [
                    "storageObjectName", "storage_object_name",
                    "objectName", "object_name",
                    "assetPath", "asset_path",
                    "storagePath", "storage_path",
                    "storageUrl", "storage_url",
                    "path"
                ]
            )
        )
    }

    private static func cleanFlashcardText(_ raw: String) -> String {
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return "" }

        if let regex = try? NSRegularExpression(pattern: #"\{\{c\d+::(.*?)(?:::[^{}]*)?\}\}"#) {
            let nsText = cleaned as NSString
            let matches = regex.matches(in: cleaned, range: NSRange(location: 0, length: nsText.length))
            if !matches.isEmpty {
                var mutable = cleaned
                for match in matches.reversed() {
                    guard match.numberOfRanges > 1,
                          match.range(at: 1).location != NSNotFound,
                          let whole = Range(match.range(at: 0), in: mutable),
                          let inner = Range(match.range(at: 1), in: mutable) else { continue }
                    mutable.replaceSubrange(whole, with: String(mutable[inner]))
                }
                cleaned = mutable
            }
        }

        return cleaned
            .replacingOccurrences(of: #"\{\{c\d+::"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "}}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func infographicImageURL(from dict: [String: AnyJSON]) -> URL? {
        let direct = firstString(
            dict,
            keys: [
                "image_url", "imageUrl", "storageUrl", "storage_url",
                "publicUrl", "public_url", "assetUrl", "asset_url",
                "cdnUrl", "cdn_url", "secureUrl", "secure_url",
                "signedUrl", "signed_url", "downloadUrl", "download_url",
                "fileUrl", "file_url", "mediaUrl", "media_url", "url"
            ]
        )
        if let url = remoteImageURL(from: direct) { return url }
        for key in [
            "image", "asset", "visual", "media", "file", "output",
            "images", "assets", "visuals", "mediaAssets", "media_assets",
            "files", "outputs", "generatedImages", "generated_images"
        ] {
            if let url = remoteImageURL(from: dict[key]) { return url }
        }
        return nil
    }

    private static func infographicAssetPath(from dict: [String: AnyJSON]) -> String? {
        for key in [
            "image", "asset", "visual", "media", "file", "output",
            "images", "assets", "visuals", "mediaAssets", "media_assets",
            "files", "outputs", "generatedImages", "generated_images"
        ] {
            if let path = generatedAssetPath(from: dict[key]) { return path }
        }

        return generatedAssetPath(
            from: firstString(
                dict,
                keys: [
                    "storageObjectName", "storage_object_name",
                    "objectName", "object_name",
                    "assetPath", "asset_path",
                    "storagePath", "storage_path",
                    "storageUrl", "storage_url",
                    "path"
                ]
            )
        )
    }

    private static func remoteImageURL(from value: AnyJSON?) -> URL? {
        if let array = arrayValue(value) {
            for item in array {
                if let url = remoteImageURL(from: item) { return url }
            }
            return nil
        }
        if let dict = objectValue(value) {
            let direct = firstString(
                dict,
                keys: [
                    "url", "src", "image_url", "imageUrl", "storageUrl",
                    "storage_url", "publicUrl", "public_url", "assetUrl", "asset_url",
                    "cdnUrl", "cdn_url", "secureUrl", "secure_url",
                    "signedUrl", "signed_url", "downloadUrl", "download_url",
                    "fileUrl", "file_url", "mediaUrl", "media_url"
                ]
            )
            if let url = remoteImageURL(from: direct) { return url }

            for key in dict.keys.sorted() {
                let normalized = key.lowercased()
                guard normalized.contains("image")
                    || normalized.contains("asset")
                    || normalized.contains("visual")
                    || normalized.contains("media")
                    || normalized.contains("url") else { continue }
                if let url = remoteImageURL(from: dict[key]) { return url }
            }
            return nil
        }
        return remoteImageURL(from: stringValue(value))
    }

    private static func generatedAssetPath(from value: AnyJSON?) -> String? {
        if let array = arrayValue(value) {
            for item in array {
                if let path = generatedAssetPath(from: item) { return path }
            }
            return nil
        }

        if let dict = objectValue(value) {
            let direct = firstString(
                dict,
                keys: [
                    "storageObjectName", "storage_object_name",
                    "objectName", "object_name",
                    "assetPath", "asset_path",
                    "storagePath", "storage_path",
                    "storageUrl", "storage_url",
                    "path"
                ]
            )
            if let path = generatedAssetPath(from: direct) { return path }

            for key in dict.keys.sorted() {
                let normalized = key.lowercased()
                guard normalized.contains("storage")
                    || normalized.contains("object")
                    || normalized.contains("asset")
                    || normalized.contains("image")
                    || normalized.contains("path") else { continue }
                if let path = generatedAssetPath(from: dict[key]) { return path }
            }
            return nil
        }

        return generatedAssetPath(from: stringValue(value))
    }

    private static func generatedAssetPath(from raw: String) -> String? {
        let trimmed = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "<>()[]{}\"'`"))
        guard !trimmed.isEmpty else { return nil }

        if trimmed.hasPrefix("sourcebase/users/"), trimmed.contains("/generated/") {
            return trimmed
        }

        if let url = URL(string: trimmed),
           let scheme = url.scheme?.lowercased(),
           scheme != "http",
           scheme != "https" {
            let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if path.hasPrefix("sourcebase/users/"), path.contains("/generated/") {
                return path
            }
        }

        return nil
    }

    private static func remoteImageURL(from raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let url = absoluteRemoteURL(from: trimmed) { return url }
        return embeddedRemoteImageURL(in: trimmed)
    }

    private static func absoluteRemoteURL(from raw: String) -> URL? {
        let trimmed = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "<>()[]{}\"'`"))
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http" else {
            return nil
        }
        return url
    }

    private static func embeddedRemoteImageURL(in text: String) -> URL? {
        let patterns = [
            "!\\[[^\\]]*\\]\\((https?://[^\\s\\)]+)\\)",
            "https?://[^\\s<>\\\"'\\)\\]]+"
        ]
        let nsText = text as NSString
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
            for match in matches {
                let range = match.numberOfRanges > 1 ? match.range(at: 1) : match.range(at: 0)
                guard range.location != NSNotFound else { continue }
                let candidate = nsText.substring(with: range)
                guard let url = absoluteRemoteURL(from: candidate) else { continue }
                if pattern.hasPrefix("!") || looksLikeImageURL(url) {
                    return url
                }
            }
        }
        return nil
    }

    private static func looksLikeImageURL(_ url: URL) -> Bool {
        let lower = url.absoluteString.lowercased()
        return [".png", ".jpg", ".jpeg", ".webp", ".gif"].contains { lower.contains($0) }
            || lower.contains("image")
            || lower.contains("infographic")
            || lower.contains("asset")
            || lower.contains("cdn")
            || lower.contains("storage")
    }

    private static func infographicBlocks(from dict: [String: AnyJSON], fallbackText: String?) -> [String] {
        var blocks: [String] = []
        for key in [
            "blocks", "sections", "items", "cards", "panels",
            "contentBlocks", "content_blocks", "infoBlocks", "info_blocks",
            "highlights", "facts"
        ] {
            blocks.append(contentsOf: infographicBlockItems(dict[key]))
        }
        if blocks.isEmpty {
            for key in [
                "summary", "overview", "description", "mainMessage", "main_message",
                "message", "warnings", "red_flags", "redFlags", "quick_check",
                "quickCheck", "self_check", "sourceNote", "source_note"
            ] {
                blocks.append(contentsOf: sectionItems(dict[key]))
            }
        }
        if blocks.isEmpty {
            blocks = fallbackLines(fallbackText)
        }
        return uniqueStrings(blocks)
    }

    private static func infographicBlockItems(_ value: AnyJSON?) -> [String] {
        guard let value else { return [] }
        if let array = arrayValue(value) {
            return array.flatMap { item -> [String] in
                guard let dict = objectValue(item) else {
                    let text = stringValue(item).trimmingCharacters(in: .whitespacesAndNewlines)
                    return text.isEmpty ? [] : [text]
                }

                let title = firstString(dict, keys: ["heading", "title", "label", "name"])
                let body = firstString(dict, keys: ["text", "body", "content", "detail", "description", "caption", "note"])
                let bullets = sectionItems(
                    dict["bullets"]
                        ?? dict["items"]
                        ?? dict["points"]
                        ?? dict["facts"]
                        ?? dict["warnings"]
                )

                var items: [String] = []
                if !body.isEmpty {
                    items.append(title.isEmpty ? body : "\(title): \(body)")
                }
                if !bullets.isEmpty {
                    items.append(contentsOf: title.isEmpty ? bullets : bullets.map { "\(title): \($0)" })
                }
                if items.isEmpty, !title.isEmpty {
                    items.append(title)
                }
                return items
            }
        }

        if let dict = objectValue(value) {
            return dict.keys.sorted().flatMap { key -> [String] in
                let items = infographicBlockItems(dict[key])
                guard !items.isEmpty else { return [] }
                let title = label(for: key)
                return items.map { item in
                    item.hasPrefix("\(title):") ? item : "\(title): \(item)"
                }
            }
        }

        let text = stringValue(value).trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? [] : [text]
    }

    private static func fallbackLines(_ fallbackText: String?) -> [String] {
        let fallback = fallbackText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !fallback.isEmpty else { return [] }
        let lines = fallback
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return lines.count > 1 ? lines : [fallback]
    }

    private static func fallbackDocumentParts(for kind: GeneratedKind, fallbackText: String?) -> (summary: String, blocks: [SBStudyBlock]) {
        let items = fallbackLines(fallbackText)
        guard !items.isEmpty else { return ("", []) }
        let summary = items.first ?? ""
        let remaining = Array(items.dropFirst())
        let bodyItems = remaining.isEmpty ? items : remaining

        switch kind {
        case .flashcard:
            return (
                summary,
                [.cards(id: "fallback-cards", cards: [
                    SBFlashcard(front: summary, back: bodyItems.joined(separator: "\n"))
                ])]
            )
        case .question:
            return (
                summary,
                [.calloutList(id: "fallback-question", title: "Soru Taslağı", items: bodyItems, style: .objective)]
            )
        case .summary:
            return (
                summary,
                [.calloutList(id: "fallback-summary", title: "Yüksek Verimli Notlar", items: bodyItems, style: .mustKnow)]
            )
        case .examMorningSummary:
            return (
                summary,
                [.calloutList(id: "fallback-exam-morning", title: "Sınav Sabahı Notları", items: bodyItems, style: .mustKnow)]
            )
        case .algorithm:
            return (
                summary,
                [.steps(id: "fallback-algorithm", title: "Akış Adımları", items: bodyItems)]
            )
        case .comparison, .table:
            let rows = bodyItems.enumerated().map { item in ["Kriter \(item.offset + 1)", item.element] }
            return (
                summary,
                [.table(id: "fallback-comparison", title: "Karşılaştırma", table: SBStudyTable(headers: ["Kriter", "Kaynak Notu"], rows: rows))]
            )
        case .clinicalScenario:
            return (
                summary,
                [
                    .paragraph(id: "fallback-clinical-stem", text: summary),
                    .calloutList(id: "fallback-clinical-points", title: "Klinik Noktalar", items: bodyItems, style: .tip)
                ]
            )
        case .learningPlan:
            return (
                summary,
                [.timeline(id: "fallback-plan", title: "Çalışma Oturumları", entries: bodyItems.enumerated().map { item in
                    SBTimelineEntry(title: "Oturum \(item.offset + 1)", items: [item.element])
                })]
            )
        case .podcast:
            return (
                summary,
                [.audio(id: "fallback-podcast", url: nil, segments: [
                    SBPodcastSegment(title: "Transkript", text: items.joined(separator: "\n"))
                ])]
            )
        case .infographic:
            return (
                summary,
                [.calloutList(id: "fallback-infographic", title: "İnfografik Blokları", items: bodyItems, style: .plain)]
            )
        case .mindMap:
            return (
                summary,
                [.mindBranches(id: "fallback-mind-map", title: "Dallar", branches: [
                    SBMindBranch(label: summary, children: bodyItems)
                ])]
            )
        }
    }

    private static func uniqueStrings(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.compactMap { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            let key = trimmed.lowercased()
            guard seen.insert(key).inserted else { return nil }
            return trimmed
        }
    }

    /// Comparison schema: `rows: [{label, values[]}]` + `headers[]`.
    private static func comparisonTable(from dict: [String: AnyJSON]?) -> SBStudyTable? {
        guard let dict else { return nil }
        let headers = stringArray(dict["headers"] ?? dict["columns"])
        guard let rawRows = arrayValue(dict["rows"]) else { return nil }
        let rows: [[String]] = rawRows.compactMap { row in
            guard let obj = objectValue(row) else { return nil }
            let label = firstString(obj, keys: ["label", "feature", "criterion"])
            let values = stringArray(obj["values"])
            guard !label.isEmpty || !values.isEmpty else { return nil }
            return ([label] + values).filter { !$0.isEmpty }
        }
        guard !rows.isEmpty else { return nil }
        return SBStudyTable(headers: headers, rows: rows)
    }

    private static func table(from dict: [String: AnyJSON]?) -> SBStudyTable? {
        guard let dict else { return nil }
        let nestedTable = objectValue(dict["mini_table"] ?? dict["miniTable"] ?? dict["table"])
        let tableSource = nestedTable ?? dict
        let headers = stringArray(tableSource["headers"] ?? tableSource["columns"])
        guard let rawRows = array(in: .object(tableSource), keys: ["rows", "items"]) else { return nil }
        let rows: [[String]] = rawRows.compactMap { row in
            if let array = arrayValue(row) {
                return array.map { stringValue($0) }.filter { !$0.isEmpty }
            }
            if let object = objectValue(row) {
                if headers.isEmpty {
                    return object.keys.sorted().map { stringValue(object[$0]) }.filter { !$0.isEmpty }
                }
                return headers.map { stringValue(object[$0]) }
            }
            let text = stringValue(row)
            return text.isEmpty ? nil : [text]
        }
        guard !rows.isEmpty else { return nil }
        return SBStudyTable(headers: headers, rows: rows)
    }

    private static func sectionItems(_ value: AnyJSON?) -> [String] {
        guard let value else { return [] }
        if let array = arrayValue(value) {
            return array.flatMap { item -> [String] in
                if let dict = objectValue(item) {
                    let title = firstString(dict, keys: ["title", "label", "criterion", "from", "if"])
                    let body = firstString(dict, keys: ["text", "value", "detail", "description", "then", "to", "tip", "note"])
                    let combined = [title, body].filter { !$0.isEmpty }.joined(separator: ": ")
                    return combined.isEmpty ? [] : [combined]
                }
                let text = stringValue(item)
                return text.isEmpty ? [] : [text]
            }
        }
        if let dict = objectValue(value) {
            return dict.keys.sorted().compactMap { key in
                let text = stringValue(dict[key])
                return text.isEmpty ? nil : "\(label(for: key)): \(text)"
            }
        }
        let text = stringValue(value)
        return text.isEmpty ? [] : [text]
    }

    private static func array(in value: AnyJSON?, keys: [String]) -> [AnyJSON]? {
        guard let dict = objectValue(value) else { return nil }
        for key in keys {
            if let array = arrayValue(dict[key]) { return array }
        }
        return nil
    }

    private static func objectPayload(from response: [String: AnyJSON]) -> AnyJSON? {
        if case .object(let data)? = response["data"] {
            return .object(data)
        }
        return .object(response)
    }

    private static func firstString(_ dict: [String: AnyJSON], keys: [String]) -> String {
        for key in keys {
            let text = stringValue(dict[key]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty { return text }
        }
        return ""
    }

    private static func stringArray(_ value: AnyJSON?) -> [String] {
        guard let array = arrayValue(value) else { return [] }
        return array.map { stringValue($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    private static func objectValue(_ value: AnyJSON?) -> [String: AnyJSON]? {
        guard case .object(let dict) = value else { return nil }
        return dict
    }

    private static func arrayValue(_ value: AnyJSON?) -> [AnyJSON]? {
        guard case .array(let array) = value else { return nil }
        return array
    }

    private static func stringValue(_ value: AnyJSON?) -> String {
        guard let value else { return "" }
        switch value {
        case .string(let string): return string
        case .integer(let int): return String(int)
        case .double(let double): return String(double)
        case .bool(let bool): return bool ? "true" : "false"
        default: return ""
        }
    }

    private static func intValue(_ value: AnyJSON?) -> Int? {
        guard let value else { return nil }
        switch value {
        case .integer(let int): return int
        case .double(let double): return Int(double)
        case .string(let string): return Int(string)
        default: return nil
        }
    }

    private static func firstInt(_ dict: [String: AnyJSON], keys: [String]) -> Int? {
        for key in keys {
            if let int = intValue(dict[key]) { return int }
        }
        return nil
    }

    private static func boolValue(_ value: AnyJSON?) -> Bool? {
        guard let value else { return nil }
        switch value {
        case .bool(let bool): return bool
        case .string(let string): return Bool(string)
        default: return nil
        }
    }

    private static func normalizedDifficulty(_ raw: String) -> String {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if ["easy", "kolay"].contains(normalized) { return "easy" }
        if ["hard", "zor", "very hard", "çok zor", "cok zor"].contains(normalized) { return "hard" }
        return "medium"
    }

    private static func label(for key: String) -> String {
        let labels = [
            "must_know": "Mutlaka Bil",
            "commonly_confused": "Sık Karışanlar",
            "clinical_tus_tips": "Klinik İpuçları",
            "red_flags": "Kırmızı Bayraklar",
            "self_check": "Kendini Kontrol Et",
            "decision_nodes": "Karar Düğümleri",
            "branches": "Akış Dalları",
            "thresholds": "Eşikler",
            "action_steps": "Eylem Adımları",
            "distinguishing_tips": "Ayırt Edici İpuçları",
            "clinical_notes": "Klinik Notlar",
            "steps": "Adımlar",
            "nodes": "Düğümler",
            "sections": "Bölümler",
            "teachingPoints": "Öğretici Noktalar",
            "teaching_points": "Öğretici Noktalar",
            "objectives": "Hedefler",
            "learningObjectives": "Öğrenme Hedefleri",
            "learning_objectives": "Öğrenme Hedefleri",
            "days": "Günler",
            "tasks": "Görevler",
            "redFlags": "Kırmızı Bayraklar",
            "clinicalTips": "Klinik İpuçları",
            "clinical_tips": "Klinik İpuçları",
            "highYieldPoints": "Yüksek Verimli Noktalar",
            "high_yield_points": "Yüksek Verimli Noktalar",
            "pitfalls": "Tuzak Noktalar",
            "keyTakeaways": "Ana Çıkarımlar",
            "key_takeaways": "Ana Çıkarımlar"
        ]
        if let label = labels[key] { return label }
        return key
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
```

## File: Sources/SourceBaseBackend/Drive/SBStudyDocument.swift
```swift
import Foundation

// MARK: - Systematic study document
//
// Every AI output type is parsed into ONE canonical document of typed blocks.
// Both the SwiftUI study screen and the native PDF exporter render this same
// document, so the on-screen template and the exported PDF can never drift
// apart ("sistematik iste → sistematiğe göre oturt → PDF de aynı sistematiğe
// göre"). Per-kind distinctiveness comes from the block composition + accent /
// icon resolved in the iOS layer (which owns the design tokens). This file is
// pure data: no SwiftUI, no colors.

/// Semantic emphasis for a list block. The iOS layer maps each style to a
/// design-token color + icon; the PDF maps it to a colored callout.
public enum SBCalloutStyle: String, Sendable, Equatable, Codable {
    case plain        // neutral bullet list
    case mustKnow     // high-yield, must-know
    case redFlag      // danger / critical
    case tip          // clinical / exam tip
    case confused     // commonly confused
    case objective    // learning objective
}

public struct SBDecisionNode: Identifiable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let detail: String
    public let yes: String
    public let no: String
    public let substeps: [String]

    public init(id: String = UUID().uuidString, title: String, detail: String = "", yes: String = "", no: String = "", substeps: [String] = []) {
        self.id = id
        self.title = title
        self.detail = detail
        self.yes = yes
        self.no = no
        self.substeps = substeps
    }
}

public struct SBKeyValue: Identifiable, Sendable, Equatable {
    public let id: String
    public let key: String
    public let value: String

    public init(id: String = UUID().uuidString, key: String, value: String) {
        self.id = id
        self.key = key
        self.value = value
    }
}

public struct SBQAPair: Identifiable, Sendable, Equatable {
    public let id: String
    public let question: String
    public let answer: String
    public let explanation: String

    public init(id: String = UUID().uuidString, question: String, answer: String, explanation: String = "") {
        self.id = id
        self.question = question
        self.answer = answer
        self.explanation = explanation
    }
}

public struct SBTimelineEntry: Identifiable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let meta: String          // e.g. "30 dk", "Gün 1"
    public let items: [String]

    public init(id: String = UUID().uuidString, title: String, meta: String = "", items: [String]) {
        self.id = id
        self.title = title
        self.meta = meta
        self.items = items
    }
}

public struct SBMindBranch: Identifiable, Sendable, Equatable {
    public let id: String
    public let label: String
    public let children: [String]
    public let tags: [String]

    public init(id: String = UUID().uuidString, label: String, children: [String], tags: [String] = []) {
        self.id = id
        self.label = label
        self.children = children
        self.tags = tags
    }
}

/// One renderable block. `id` makes it usable directly in SwiftUI `ForEach`.
public enum SBStudyBlock: Identifiable, Sendable, Equatable {
    case paragraph(id: String, text: String)
    case calloutList(id: String, title: String, items: [String], style: SBCalloutStyle)
    case steps(id: String, title: String, items: [String])
    case decisions(id: String, title: String, nodes: [SBDecisionNode])
    case table(id: String, title: String, table: SBStudyTable)
    case keyValues(id: String, title: String, pairs: [SBKeyValue])
    case qa(id: String, title: String, pairs: [SBQAPair])
    case timeline(id: String, title: String, entries: [SBTimelineEntry])
    case mindBranches(id: String, title: String, branches: [SBMindBranch])
    case cards(id: String, cards: [SBFlashcard])
    case quiz(id: String, questions: [SBQlinikQuestion])
    case image(id: String, url: URL?, caption: String)
    case audio(id: String, url: URL?, segments: [SBPodcastSegment])

    public var id: String {
        switch self {
        case let .paragraph(id, _),
             let .calloutList(id, _, _, _),
             let .steps(id, _, _),
             let .decisions(id, _, _),
             let .table(id, _, _),
             let .keyValues(id, _, _),
             let .qa(id, _, _),
             let .timeline(id, _, _),
             let .mindBranches(id, _, _),
             let .cards(id, _),
             let .quiz(id, _),
             let .image(id, _, _),
             let .audio(id, _, _):
            return id
        }
    }
}

/// The full systematic document for one generated output.
public struct SBStudyDocument: Sendable, Equatable {
    public let kind: GeneratedKind
    public let title: String
    public let subtitle: String
    public let summary: String
    public let blocks: [SBStudyBlock]

    public init(kind: GeneratedKind, title: String, subtitle: String = "", summary: String = "", blocks: [SBStudyBlock]) {
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.summary = summary
        self.blocks = blocks
    }

    /// True when the document has no meaningful body (only a placeholder).
    public var isEffectivelyEmpty: Bool {
        blocks.isEmpty && summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
```

## File: Sources/SourceBaseBackend/Profile/ProfileRepository.swift
```swift
import Foundation
import Supabase

public struct ProfileSnapshot: Sendable {
    public let displayName: String
    public let email: String
    public let faculty: String
    public let department: String
    public let className: String
    public let walletBalance: Double?
    public let courseCount: Int
    public let fileCount: Int
    public let generatedCount: Int
    public let collectionCount: Int
    public let avatarURL: String?

    public init(
        displayName: String,
        email: String,
        faculty: String,
        department: String,
        className: String,
        walletBalance: Double?,
        courseCount: Int,
        fileCount: Int,
        generatedCount: Int,
        collectionCount: Int,
        avatarURL: String? = nil
    ) {
        self.displayName = displayName
        self.email = email
        self.faculty = faculty
        self.department = department
        self.className = className
        self.walletBalance = walletBalance
        self.courseCount = courseCount
        self.fileCount = fileCount
        self.generatedCount = generatedCount
        self.collectionCount = collectionCount
        self.avatarURL = avatarURL
    }

    public static let empty = ProfileSnapshot(
        displayName: "", email: "", faculty: "", department: "",
        className: "", walletBalance: nil, courseCount: 0,
        fileCount: 0, generatedCount: 0, collectionCount: 0,
        avatarURL: nil
    )
}

public struct ProfileRepository: Sendable {
    private let client: SupabaseClient

    public init(client: SupabaseClient) {
        self.client = client
    }

    public func loadProfile(
        userId: String,
        workspace: DriveWorkspaceData
    ) async throws -> ProfileSnapshot {
        let row = await loadProfileRow(userId: userId)
        let user = client.auth.currentUser
        let metadata = user?.userMetadata ?? [:]
        let walletBalance = await loadWalletBalance(userId: userId, profileRow: row)

        return ProfileSnapshot(
            displayName: metadata["display_name"]?.stringValue
                ?? metadata["full_name"]?.stringValue
                ?? row?.displayName
                ?? row?.fullName
                ?? user?.email ?? "",
            email: user?.email ?? "",
            faculty: metadata["sourcebase_faculty"]?.stringValue
                ?? row?.sourcebaseFaculty
                ?? row?.faculty
                ?? "",
            department: metadata["sourcebase_department"]?.stringValue
                ?? row?.sourcebaseDepartment
                ?? row?.department
                ?? "",
            className: metadata["sourcebase_class"]?.stringValue
                ?? row?.sourcebaseClass
                ?? row?.classYear
                ?? row?.grade
                ?? "",
            walletBalance: walletBalance,
            courseCount: workspace.courses.count,
            fileCount: workspace.courses.reduce(0) { $0 + $1.fileCount },
            generatedCount: workspace.courses.reduce(0) { sum, course in
                sum + course.sections.reduce(0) { secSum, section in
                    secSum + section.files.reduce(0) { fileSum, file in
                        fileSum + file.generated.count
                    }
                }
            },
            collectionCount: workspace.collections.count,
            avatarURL: metadata["avatar_url"]?.stringValue
                ?? metadata["picture"]?.stringValue
                ?? row?.avatarURL
        )
    }

    public func uploadProfileAvatar(
        data: Data,
        fileName: String,
        contentType: String
    ) async throws -> String {
        let api = DriveAPI(client: client)
        let file = PickedDriveFile(
            name: fileName,
            contentType: contentType,
            sizeBytes: data.count,
            data: data
        )
        let session = try await api.createProfileAvatarUploadSession(
            fileName: fileName,
            contentType: contentType,
            sizeBytes: data.count
        )
        try await DriveUploadService().uploadBytes(
            uploadURL: session.uploadURL,
            headers: session.headers,
            file: file
        )
        let response = try await api.completeProfileAvatarUpload(objectName: session.objectName)
        let dataDict = response["data"]?.dictValue
        let avatarURL = dataDict?["avatarUrl"]?.stringValue
            ?? dataDict?["avatar_url"]?.stringValue
            ?? dataDict?["publicUrl"]?.stringValue
            ?? ""
        guard !avatarURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RepositoryError(message: "Profil fotoğrafı bağlantısı alınamadı.")
        }
        return avatarURL
    }

    private func loadProfileRow(userId: String) async -> ProfileRow? {
        do {
            let rows: [ProfileRow] = try await client
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .execute()
                .value
            return rows.first
        } catch {
            return nil
        }
    }

    private func loadWalletBalance(userId: String, profileRow: ProfileRow?) async -> Double? {
        if let balance = await loadWalletBalanceFromEntitlements(userId: userId) {
            return balance
        }
        return profileRow?.bestBalance
    }

    private func loadWalletBalanceFromEntitlements(userId: String) async -> Double? {
        do {
            let rows: [WalletEntitlementRow] = try await client
                .from("wallet_entitlements")
                .select("remaining_coin_amount")
                .eq("user_id", value: userId)
                .eq("status", value: "active")
                .gt("expires_at", value: Date().ISO8601Format())
                .execute()
                .value
            return rows.reduce(0) { $0 + $1.remainingCoinAmount }
        } catch {
            return nil
        }
    }
}

private struct ProfileRow: Decodable, Sendable {
    let displayName: String?
    let fullName: String?
    let faculty: String?
    let department: String?
    let sourcebaseFaculty: String?
    let sourcebaseDepartment: String?
    let sourcebaseClass: String?
    let classYear: String?
    let grade: String?
    let avatarURL: String?
    let creditBalance: Double?
    let walletBalance: Double?
    let medasiCoinBalance: Double?
    let coinBalance: Double?

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case fullName = "full_name"
        case faculty
        case department
        case sourcebaseFaculty = "sourcebase_faculty"
        case sourcebaseDepartment = "sourcebase_department"
        case sourcebaseClass = "sourcebase_class"
        case classYear = "class_year"
        case grade
        case avatarURL = "avatar_url"
        case creditBalance = "credit_balance"
        case walletBalance = "wallet_balance"
        case medasiCoinBalance = "medasicoin_balance"
        case coinBalance = "coin_balance"
    }

    var bestBalance: Double? {
        let balances = [medasiCoinBalance, walletBalance, coinBalance, creditBalance]
        for case let balance? in balances where balance != 0 {
            return balance
        }
        return balances.contains { $0 == 0 } ? 0 : nil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        fullName = try container.decodeIfPresent(String.self, forKey: .fullName)
        faculty = try container.decodeIfPresent(String.self, forKey: .faculty)
        department = try container.decodeIfPresent(String.self, forKey: .department)
        sourcebaseFaculty = try container.decodeIfPresent(String.self, forKey: .sourcebaseFaculty)
        sourcebaseDepartment = try container.decodeIfPresent(String.self, forKey: .sourcebaseDepartment)
        sourcebaseClass = try container.decodeIfPresent(String.self, forKey: .sourcebaseClass)
        classYear = try container.decodeIfPresent(String.self, forKey: .classYear)
        grade = try container.decodeIfPresent(String.self, forKey: .grade)
        avatarURL = try container.decodeIfPresent(String.self, forKey: .avatarURL)
        creditBalance = Self.decodeDouble(container, .creditBalance)
        walletBalance = Self.decodeDouble(container, .walletBalance)
        medasiCoinBalance = Self.decodeDouble(container, .medasiCoinBalance)
        coinBalance = Self.decodeDouble(container, .coinBalance)
    }

    private static func decodeDouble(_ container: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Double? {
        if let value = try? container.decode(Double.self, forKey: key) {
            return value
        }
        if let value = try? container.decode(String.self, forKey: key) {
            return Double(value)
        }
        return nil
    }
}

private struct WalletEntitlementRow: Decodable, Sendable {
    let remainingCoinAmount: Double

    enum CodingKeys: String, CodingKey {
        case remainingCoinAmount = "remaining_coin_amount"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        remainingCoinAmount = Self.decodeDouble(container, .remainingCoinAmount)
            ?? 0
    }

    private static func decodeDouble(_ container: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Double? {
        if let value = try? container.decode(Int.self, forKey: key) {
            return Double(value)
        }
        if let value = try? container.decode(Double.self, forKey: key) {
            return value
        }
        if let value = try? container.decode(String.self, forKey: key) {
            return Double(value)
        }
        return nil
    }
}
```

## File: Sources/SourceBaseBackend/Profile/StoreRepository.swift
```swift
import Foundation
import Supabase

public struct StoreProductSnapshot: Sendable {
    public let code: String
    public let coin: Int
    public let priceCents: Int
    public let title: String
    public let description: String
    public let currency: String
    public let sortOrder: Int

    public init(
        code: String,
        coin: Int,
        priceCents: Int,
        title: String,
        description: String,
        currency: String,
        sortOrder: Int
    ) {
        self.code = code
        self.coin = coin
        self.priceCents = priceCents
        self.title = title
        self.description = description
        self.currency = currency
        self.sortOrder = sortOrder
    }
}

public struct StoreRepository: Sendable {
    private let client: SupabaseClient

    public init(client: SupabaseClient) {
        self.client = client
    }

    public func loadProducts() async throws -> [StoreProductSnapshot] {
        let attempts: [ProductTableAttempt] = [
            ProductTableAttempt(table: "store_products", schema: nil, filterKey: "is_active", filterValue: .bool(true)),
            ProductTableAttempt(table: "products", schema: nil, filterKey: "status", filterValue: .string("published")),
            ProductTableAttempt(table: "store_products", schema: "sourcebase", filterKey: "is_active", filterValue: .bool(true)),
            ProductTableAttempt(table: "products", schema: "sourcebase", filterKey: "status", filterValue: .string("published"))
        ]

        var lastError: Error?
        for attempt in attempts {
            do {
                let rows = try await loadRows(attempt)
                let snapshots = rows.map { $0.toSnapshot() }
                let products = snapshots
                    .filter { product in
                        !product.code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            && product.coin > 0
                    }
                    .sorted { lhs, rhs in
                        lhs.sortOrder == rhs.sortOrder
                            ? lhs.coin < rhs.coin
                            : lhs.sortOrder < rhs.sortOrder
                    }
                if !products.isEmpty {
                    return products
                }
            } catch {
                lastError = error
            }
        }

        if let lastError {
            throw lastError
        }
        return []
    }

    public func purchaseMedasiCoin(
        productCode: String,
        successURL: String,
        cancelURL: String
    ) async throws -> [String: AnyJSON] {
        try await DriveRepository(api: DriveAPI(client: client)).purchaseMedasiCoin(
            productCode: productCode,
            successURL: successURL,
            cancelURL: cancelURL
        )
    }

    private func loadRows(_ attempt: ProductTableAttempt) async throws -> [StoreProductRow] {
        let builder = attempt.schema.map { client.schema($0).from(attempt.table) }
            ?? client.from(attempt.table)

        switch attempt.filterValue {
        case .bool(let value):
            return try await builder
                .select()
                .eq(attempt.filterKey, value: value)
                .execute()
                .value
        case .string(let value):
            return try await builder
                .select()
                .eq(attempt.filterKey, value: value)
                .execute()
                .value
        }
    }
}

private struct ProductTableAttempt: Sendable {
    enum FilterValue: Sendable {
        case bool(Bool)
        case string(String)
    }

    let table: String
    let schema: String?
    let filterKey: String
    let filterValue: FilterValue
}

private struct StoreProductRow: Decodable, Sendable {
    let code: String?
    let slug: String?
    let productCode: String?
    let coins: Int
    let priceCents: Int
    let title: String?
    let name: String?
    let description: String?
    let currency: String?
    let sortOrder: Int
    let metadata: [String: AnyJSON]

    enum CodingKeys: String, CodingKey {
        case code
        case slug
        case productCode = "product_code"
        case coins
        case coin
        case coinAmount = "coin_amount"
        case amount
        case mcAmount = "mc_amount"
        case medasiCoinAmount = "medasicoin_amount"
        case priceCents = "price_cents"
        case price
        case unitAmount = "unit_amount"
        case title
        case name
        case description
        case currency
        case sortOrder = "sort_order"
        case metadata
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decodeIfPresent(String.self, forKey: .code)
        slug = try container.decodeIfPresent(String.self, forKey: .slug)
        productCode = try container.decodeIfPresent(String.self, forKey: .productCode)
        metadata = (try? container.decodeIfPresent([String: AnyJSON].self, forKey: .metadata)) ?? [:]
        coins = Self.decodeInt(container, .coins)
            ?? Self.decodeInt(container, .coin)
            ?? Self.decodeInt(container, .coinAmount)
            ?? Self.decodeInt(container, .mcAmount)
            ?? Self.decodeInt(container, .medasiCoinAmount)
            ?? Self.decodeInt(container, .amount)
            ?? Self.metadataInt(metadata, "coin_amount")
            ?? Self.metadataInt(metadata, "coins")
            ?? Self.metadataInt(metadata, "medasicoin_amount")
            ?? 0
        priceCents = Self.decodeInt(container, .priceCents)
            ?? Self.decodePriceAsCents(container, .price)
            ?? Self.decodeInt(container, .unitAmount)
            ?? Self.metadataInt(metadata, "price_cents")
            ?? 0
        title = try container.decodeIfPresent(String.self, forKey: .title)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        currency = try container.decodeIfPresent(String.self, forKey: .currency)
        sortOrder = Self.decodeInt(container, .sortOrder) ?? Self.metadataInt(metadata, "sort_order") ?? 99
    }

    func toSnapshot() -> StoreProductSnapshot {
        StoreProductSnapshot(
            code: productCode ?? code ?? slug ?? "",
            coin: coins,
            priceCents: priceCents,
            title: title ?? name ?? Self.metadataString(metadata, "title") ?? "\(coins) MC Paketi",
            description: description ?? Self.metadataString(metadata, "description") ?? "MC onaylı ödeme sonrası hesabınıza eklenir.",
            currency: currency ?? Self.metadataString(metadata, "currency") ?? "TRY",
            sortOrder: sortOrder
        )
    }

    private static func decodeInt(_ container: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Int? {
        if let value = try? container.decode(Int.self, forKey: key) {
            return value
        }
        if let value = try? container.decode(Double.self, forKey: key) {
            return Int(value)
        }
        if let value = try? container.decode(String.self, forKey: key) {
            return Int(value)
        }
        return nil
    }

    private static func decodePriceAsCents(_ container: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Int? {
        if let value = try? container.decode(Int.self, forKey: key) {
            return value
        }
        if let value = try? container.decode(Double.self, forKey: key) {
            return Int((value * 100).rounded())
        }
        if let value = try? container.decode(String.self, forKey: key),
           let numeric = Double(value.replacingOccurrences(of: ",", with: ".")) {
            return Int((numeric * 100).rounded())
        }
        return nil
    }

    private static func metadataInt(_ metadata: [String: AnyJSON], _ key: String) -> Int? {
        guard let value = metadata[key] else { return nil }
        switch value {
        case .integer(let raw): return raw
        case .double(let raw): return Int(raw)
        case .string(let raw): return Int(raw)
        default: return nil
        }
    }

    private static func metadataString(_ metadata: [String: AnyJSON], _ key: String) -> String? {
        guard let value = metadata[key] else { return nil }
        switch value {
        case .string(let raw): return raw.trimmingCharacters(in: .whitespacesAndNewlines)
        case .integer(let raw): return String(raw)
        case .double(let raw): return String(raw)
        default: return nil
        }
    }
}
```

## File: Tests/SourceBaseBackendTests/AuthTests.swift
```swift
import XCTest
@testable import SourceBaseBackend

final class AuthTests: XCTestCase {
    func testConfigIsConfigured() {
        let config = SourceBaseConfig(
            supabaseURL: "https://example.supabase.co",
            supabaseAnonKey: "test-anon-key"
        )
        XCTAssertTrue(config.isConfigured)
    }

    func testConfigNotConfiguredWithEmptyValues() {
        let config = SourceBaseConfig(
            supabaseURL: "",
            supabaseAnonKey: ""
        )
        XCTAssertFalse(config.isConfigured)
    }

    func testConfigNotConfiguredWithMissingKey() {
        let config = SourceBaseConfig(
            supabaseURL: "https://example.supabase.co",
            supabaseAnonKey: ""
        )
        XCTAssertFalse(config.isConfigured)
    }

    func testAuthRedirectToUsesMobileRedirect() {
        let config = SourceBaseConfig(
            supabaseURL: "https://example.supabase.co",
            supabaseAnonKey: "key",
            publicURL: "https://sourcebase.example.com",
            mobileRedirectURL: "sourcebase://auth/callback"
        )
        XCTAssertEqual(config.authRedirectTo, "sourcebase://auth/callback")
    }

    func testAuthRedirectToWithoutMobile() {
        let config = SourceBaseConfig(
            supabaseURL: "https://example.supabase.co",
            supabaseAnonKey: "key",
            publicURL: "https://sourcebase.example.com"
        )
        XCTAssertEqual(config.authRedirectTo, "https://sourcebase.example.com/auth/callback")
    }

    func testAuthResultSuccess() {
        let result = AuthResult.success("Test success")
        XCTAssertTrue(result.ok)
        XCTAssertEqual(result.message, "Test success")
        XCTAssertNil(result.error)
    }

    func testAuthResultFailure() {
        let result = AuthResult.failure("Test error")
        XCTAssertFalse(result.ok)
        XCTAssertEqual(result.error, "Test error")
        XCTAssertNil(result.message)
    }

    func testAuthCallbackResultPasswordRecovery() {
        let result = AuthCallbackResult(redirectType: "recovery")
        XCTAssertTrue(result.isPasswordRecovery)
    }

    func testAuthCallbackResultNormal() {
        let result = AuthCallbackResult(redirectType: "signup")
        XCTAssertFalse(result.isPasswordRecovery)
    }

    func testSourceBaseProfileMetadata() {
        let profile = SourceBaseProfile(
            faculty: "Tıp",
            department: "Kardiyoloji",
            classYear: "3. sınıf",
            goal: "TUS"
        )
        let metadata = profile.metadata()
        XCTAssertEqual(metadata["sourcebase_faculty"] as? String, "Tıp")
        XCTAssertEqual(metadata["sourcebase_department"] as? String, "Kardiyoloji")
        XCTAssertEqual(metadata["sourcebase_class_year"] as? String, "3. sınıf")
        XCTAssertEqual(metadata["sourcebase_goal"] as? String, "TUS")
        XCTAssertEqual(metadata["sourcebase_profile_completed"] as? Bool, true)
        XCTAssertNotNil(metadata["sourcebase_profile_completed_at"])
        XCTAssertEqual(profile.studentContext, "Kardiyoloji · 3. sınıf · hedef: TUS · Tıp")
    }

    func testFriendlyErrorInvalidCredentials() {
        let error = NSError(domain: "", code: 0, userInfo: [
            NSLocalizedDescriptionKey: "Invalid login credentials"
        ])
        let result = AuthErrorMapping.friendlyError(error, isConfigured: true, initializationError: nil)
        XCTAssertEqual(result, "E-posta veya şifre hatalı.")
    }

    func testFriendlyErrorWeakPassword() {
        let error = NSError(domain: "", code: 0, userInfo: [
            NSLocalizedDescriptionKey: "Password should be stronger"
        ])
        let result = AuthErrorMapping.friendlyError(error, isConfigured: true, initializationError: nil)
        XCTAssertEqual(result, "Şifre daha güçlü olmalı. En az 8 karakter kullan.")
    }

    func testFriendlyErrorNetwork() {
        let error = NSError(domain: "", code: 0, userInfo: [
            NSLocalizedDescriptionKey: "Network connection failed"
        ])
        let result = AuthErrorMapping.friendlyError(error, isConfigured: true, initializationError: nil)
        XCTAssertEqual(result, "Bağlantı kurulamadı. İnternetini kontrol edip tekrar dene.")
    }

    func testFriendlyErrorNotConfigured() {
        let error = NSError(domain: "", code: 0, userInfo: [
            NSLocalizedDescriptionKey: "Any error"
        ])
        let result = AuthErrorMapping.friendlyError(error, isConfigured: false, initializationError: "test error")
        XCTAssertEqual(result, "Kimlik doğrulama yapılandırması eksik. Lütfen daha sonra tekrar dene.")
    }
}
```

## File: Tests/SourceBaseBackendTests/DriveTests.swift
```swift
import XCTest
import Supabase
@testable import SourceBaseBackend

final class DriveTests: XCTestCase {
    private func string(_ value: AnyJSON?) -> String? {
        guard case .string(let string) = value else { return nil }
        return string
    }

    // MARK: - Models

    func testDriveWorkspaceDataEmpty() {
        let workspace = DriveWorkspaceData.empty
        XCTAssertTrue(workspace.courses.isEmpty)
        XCTAssertTrue(workspace.recentFiles.isEmpty)
        XCTAssertNil(workspace.primaryCourse)
    }

    func testUploadDraftToJSON() {
        let draft = DriveUploadDraft(
            fileName: "test.pdf",
            contentType: "application/pdf",
            sizeBytes: 1024,
            courseId: "course-1",
            sectionId: "section-1"
        )
        let json = draft.toJSON()
        XCTAssertEqual(json["fileName"], "test.pdf")
        XCTAssertEqual(json["courseId"], "course-1")
    }

    func testUploadSessionPayloadKeepsSizeAsInteger() {
        let draft = DriveUploadDraft(
            fileName: "test.pdf",
            contentType: "application/pdf",
            sizeBytes: 1024,
            courseId: "course-1",
            sectionId: "section-1"
        )

        let payload = DriveAPI.uploadSessionPayload(for: draft)
        guard case .integer(let sizeBytes) = payload["sizeBytes"] else {
            return XCTFail("sizeBytes must be sent as a JSON integer.")
        }

        XCTAssertEqual(sizeBytes, 1024)
        XCTAssertEqual(string(payload["ocr_required_when_sparse"]), "true")
        XCTAssertTrue(string(payload["ocr_policy"])?.contains("low_text_density") == true)
        XCTAssertTrue(string(payload["large_document_extraction_policy"])?.contains("not_first_pages_only") == true)
    }

    func testDriveAPIHTTPErrorParsesEdgeErrorBody() throws {
        let body = try JSONSerialization.data(withJSONObject: [
            "ok": false,
            "error": [
                "code": "INVALID_UPLOAD",
                "message": "Dosya yükleme isteği geçersiz.",
                "status": 400
            ]
        ])

        let error = DriveAPI.httpError(status: 400, data: body)
        XCTAssertEqual(error.message, "Dosya yükleme isteği geçersiz.")
        XCTAssertEqual(error.code, "INVALID_UPLOAD")
        XCTAssertEqual(error.status, 400)
    }

    func testStorageUploadSessionUsable() {
        let session = StorageUploadSession(
            uploadURL: "https://storage.medasi.com.tr/medasistorage/sourcebase/users/user-1/uploads/2026/06/source-1-test.pdf?X-Amz-Algorithm=AWS4-HMAC-SHA256",
            objectName: "sourcebase/users/user-1/uploads/2026/06/source-1-test.pdf",
            bucket: "medasistorage",
            headers: [:],
            expiresAt: Date().addingTimeInterval(300)
        )
        XCTAssertTrue(session.isUsable)
    }

    func testStorageUploadSessionNotUsable() {
        let session = StorageUploadSession(
            uploadURL: "",
            objectName: "",
            bucket: "",
            headers: [:],
            expiresAt: Date()
        )
        XCTAssertFalse(session.isUsable)
    }

    func testStorageUploadSessionNearExpiryNotUsable() {
        let session = StorageUploadSession(
            uploadURL: "https://storage.medasi.com.tr/medasistorage/sourcebase/users/user-1/uploads/2026/06/source-1-test.pdf?X-Amz-Algorithm=AWS4-HMAC-SHA256",
            objectName: "sourcebase/users/user-1/uploads/2026/06/source-1-test.pdf",
            bucket: "medasistorage",
            headers: [:],
            expiresAt: Date().addingTimeInterval(10)
        )
        XCTAssertFalse(session.isUsable)
    }

    func testCompleteUploadPayloadIncludesClientExtractionContract() {
        let extractedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let payload = DriveAPI.completeUploadPayload(
            objectName: "sourcebase/users/user-1/uploads/2026/06/source-1-test.pdf",
            courseId: "course-1",
            sectionId: "section-1",
            fileName: "test.pdf",
            contentType: "application/pdf",
            sizeBytes: 2_048,
            extractedText: "Sayfa 1\nKlinik kaynak metni",
            pageCount: 12,
            extractionMetadata: ExtractionMetadata(
                charCount: 27,
                wordCount: 5,
                extractedAt: extractedAt
            )
        )

        XCTAssertEqual(string(payload["extractedText"]), "Sayfa 1\nKlinik kaynak metni")
        guard case .integer(let pageCount) = payload["pageCount"] else {
            return XCTFail("pageCount must be sent as an integer.")
        }
        XCTAssertEqual(pageCount, 12)
        guard case .object(let metadata) = payload["extractionMetadata"] else {
            return XCTFail("extractionMetadata must be sent as an object.")
        }
        guard case .integer(let charCount) = metadata["charCount"],
              case .integer(let wordCount) = metadata["wordCount"] else {
            return XCTFail("Client extraction counts must be JSON integers.")
        }
        XCTAssertEqual(charCount, 27)
        XCTAssertEqual(wordCount, 5)
        XCTAssertEqual(string(metadata["extractedAt"]), ISO8601DateFormatter().string(from: extractedAt))
        XCTAssertEqual(string(payload["ocr_required_when_sparse"]), "true")
    }

    func testStorageUploadSessionDecodesFractionalSecondExpiry() throws {
        // Deno's `new Date().toISOString()` always includes milliseconds.
        let future = ISO8601DateFormatter()
        future.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let expiry = future.string(from: Date().addingTimeInterval(300))

        let json = try JSONSerialization.data(withJSONObject: [
            "uploadUrl": "https://storage.medasi.com.tr/medasistorage/sourcebase/users/user-1/uploads/2026/06/source-1-test.pdf?X-Amz-Algorithm=AWS4-HMAC-SHA256",
            "objectName": "sourcebase/users/user-1/uploads/2026/06/source-1-test.pdf",
            "bucket": "medasistorage",
            "headers": [:],
            "expiresAt": expiry
        ])

        let session = try JSONDecoder().decode(StorageUploadSession.self, from: json)
        XCTAssertTrue(session.isUsable, "Fractional-second ISO8601 expiry must parse, not fall back to distantPast.")
    }

    func testStorageUploadSessionDecodesNumericEpochExpiry() throws {
        let epoch = Date().addingTimeInterval(300).timeIntervalSince1970
        let json = try JSONSerialization.data(withJSONObject: [
            "uploadUrl": "https://storage.medasi.com.tr/medasistorage/sourcebase/users/user-1/uploads/2026/06/source-1-test.pdf?X-Amz-Algorithm=AWS4-HMAC-SHA256",
            "objectName": "sourcebase/users/user-1/uploads/2026/06/source-1-test.pdf",
            "bucket": "medasistorage",
            "headers": [:],
            "expiresAt": epoch
        ])

        let session = try JSONDecoder().decode(StorageUploadSession.self, from: json)
        XCTAssertTrue(session.isUsable)
    }

    func testDriveDestinationRequiresCourseAndSection() {
        XCTAssertTrue(DriveDestination(
            courseId: "course-1",
            sectionId: "section-1",
            courseTitle: "Anatomi",
            sectionTitle: "Kas"
        ).isUsable)

        XCTAssertFalse(DriveDestination(
            courseId: "course-1",
            sectionId: "",
            courseTitle: "Anatomi",
            sectionTitle: ""
        ).isUsable)
    }

    func testPickedDriveFileCanBeURLBacked() throws {
        let url = URL(fileURLWithPath: "/tmp/sourcebase-test.pdf")
        let file = PickedDriveFile(
            name: "sourcebase-test.pdf",
            contentType: "application/pdf",
            sizeBytes: 42,
            fileURL: url
        )

        XCTAssertTrue(file.hasSupportedExtension)
        XCTAssertTrue(file.hasReadableContent)
        XCTAssertNil(file.data)
        XCTAssertEqual(file.fileURL, url)
    }

    func testPickedDriveFileSupportedExtensions() {
        for name in ["document.pdf", "deck.pptx", "legacy.PPT", "notes.docx", "legacy.DOC"] {
            let file = PickedDriveFile(
                name: name,
                contentType: DriveUploadService.contentTypeFor(name),
                sizeBytes: 100,
                data: Data([1, 2, 3])
            )
            XCTAssertTrue(file.hasSupportedExtension, "\(name) should be accepted by extension.")
            XCTAssertTrue(file.hasReadableContent)
        }
    }

    func testPickedDriveFileUnsupportedExtension() {
        let file = PickedDriveFile(
            name: "image.png",
            contentType: "image/png",
            sizeBytes: 100,
            data: Data()
        )
        XCTAssertFalse(file.hasSupportedExtension)
        XCTAssertFalse(file.hasReadableContent)
    }

    // MARK: - Enums

    func testGeneratedKindJobType() {
        XCTAssertEqual(GeneratedKind.flashcard.jobType, "flashcard")
        XCTAssertEqual(GeneratedKind.question.jobType, "quiz")
        XCTAssertEqual(GeneratedKind.summary.jobType, "summary")
        XCTAssertEqual(GeneratedKind.examMorningSummary.jobType, "exam_morning_summary")
        XCTAssertEqual(GeneratedKind.clinicalScenario.jobType, "clinical_scenario")
        XCTAssertEqual(GeneratedKind.learningPlan.jobType, "learning_plan")
        XCTAssertEqual(GeneratedKind.podcast.jobType, "podcast")
        XCTAssertEqual(GeneratedKind.infographic.jobType, "infographic")
        XCTAssertEqual(GeneratedKind.mindMap.jobType, "mind_map")
    }

    func testGeneratedKindDefaultCount() {
        XCTAssertEqual(GeneratedKind.flashcard.defaultCount, 20)
        XCTAssertEqual(GeneratedKind.question.defaultCount, 10)
        XCTAssertNil(GeneratedKind.summary.defaultCount)
    }

    func testGenerationJobPayloadAddsPremiumQualityContract() {
        let payload = DriveAPI.generationJobPayload(
            fileId: "file-1",
            jobType: "quiz",
            sourceIds: ["file-1", "file-2"],
            count: 10,
            qualityTier: "standard",
            options: [
                " modelPolicy ": "balanced_default",
                "schema": "qlinik_public_review_v1",
                "blank": "   "
            ]
        )

        XCTAssertEqual(string(payload["quality_tier"]), "standard")
        XCTAssertEqual(string(payload["qualityTier"]), "standard")
        XCTAssertEqual(string(payload["modelPolicy"]), "premium_balanced_long_context_assessment_quality_first")
        XCTAssertEqual(string(payload["sourceReadPolicy"]), "read_full_extracted_document_not_first_excerpt")
        XCTAssertEqual(string(payload["preferred_model_tier"]), "latest_premium_balanced_long_context")
        XCTAssertTrue(string(payload["ocrPolicy"])?.contains("low_text_density") == true)
        XCTAssertEqual(string(payload["minimum_depth"]), "balanced_assessment_deep_with_distractor_rationales")
        XCTAssertEqual(string(payload["outputLengthPolicy"]), "complete_set_balanced_explanations_not_short")
        XCTAssertEqual(string(payload["schema"]), "qlinik_public_review_v1")
        XCTAssertNil(payload["blank"])
        XCTAssertTrue(string(payload["qualityChecklist"])?.contains("all_distractors_explained") == true)
        XCTAssertTrue(string(payload["must_include"])?.contains("wrong_option_rationales") == true)
        XCTAssertTrue(string(payload["studyWorkspaceSchema"])?.contains("option_rationales") == true)
        XCTAssertTrue(string(payload["renderingContract"])?.contains("interactive study surfaces") == true)

        guard case .array(let sourceIds) = payload["sourceIds"] else {
            return XCTFail("sourceIds must remain part of the generation job payload.")
        }
        XCTAssertEqual(sourceIds.compactMap { string($0) }, ["file-1", "file-2"])
    }

    func testInfographicGenerationPayloadMapsQualityToGptImageModels() {
        let economy = DriveAPI.generationJobPayload(
            fileId: "file-1",
            jobType: "infographic",
            qualityTier: "economy"
        )
        let standard = DriveAPI.generationJobPayload(
            fileId: "file-1",
            jobType: "infographic",
            qualityTier: "standard"
        )
        let premium = DriveAPI.generationJobPayload(
            fileId: "file-1",
            jobType: "infographic",
            qualityTier: "premium"
        )

        XCTAssertEqual(string(economy["qualityTier"]), "economy")
        XCTAssertEqual(string(economy["gptImageModel"]), "gpt-image-1-mini")
        XCTAssertEqual(string(economy["image_quality"]), "low")
        XCTAssertEqual(string(standard["quality_tier"]), "standard")
        XCTAssertEqual(string(standard["imageModelPolicy"]), "gpt-image-1.5")
        XCTAssertEqual(string(standard["openai_image_model"]), "gpt-image-1.5")
        XCTAssertEqual(string(standard["imageQuality"]), "standard")
        XCTAssertEqual(string(premium["qualityTier"]), "premium")
        XCTAssertEqual(string(premium["image_model_policy"]), "gpt-image-2")
        XCTAssertEqual(string(premium["gpt_image_model"]), "gpt-image-2")
        XCTAssertEqual(string(premium["imageQuality"]), "premium")
        XCTAssertEqual(string(premium["assetFallbackPolicy"]), "structured_text_blocks_when_image_unavailable")
    }

    func testEstimateGenerationCostPayloadUsesSamePremiumQualityContract() {
        let payload = DriveAPI.estimateGenerationCostPayload(
            jobType: "summary",
            sourceTextLength: 2400,
            count: nil,
            qualityTier: nil,
            options: ["quality_tier": "standard"]
        )

        XCTAssertEqual(string(payload["quality_tier"]), "standard")
        XCTAssertEqual(string(payload["model_policy"]), "premium_balanced_long_context_summary_synthesis_first")
        XCTAssertEqual(string(payload["modelUpgradeAllowed"]), "true")
        XCTAssertTrue(string(payload["source_coverage_policy"])?.contains("full_source") == true)
        XCTAssertTrue(string(payload["backendQualityBrief"])?.contains("first excerpt") == true)
        XCTAssertEqual(string(payload["minimumDepth"]), "premium_balanced_deep")
        XCTAssertTrue(string(payload["study_workspace_schema"])?.contains("mini_table") == true)
        XCTAssertTrue(string(payload["rendering_contract"])?.contains("Learn, Flow, and Check") == true)
        guard case .integer(let sourceTextLength) = payload["sourceTextLength"] else {
            return XCTFail("sourceTextLength must remain an integer for cost estimation.")
        }
        XCTAssertEqual(sourceTextLength, 2400)
    }

    func testComparisonGenerationPayloadRequiresFullSourceMatrix() {
        let payload = DriveAPI.generationJobPayload(
            fileId: "file-1",
            jobType: "comparison",
            sourceIds: ["file-1", "file-2"],
            qualityTier: nil,
            options: nil
        )

        XCTAssertEqual(string(payload["model_policy"]), "premium_latest_long_context_matrix_reasoning_first")
        XCTAssertEqual(string(payload["preferredModelTier"]), "latest_premium_high_reasoning_long_context")
        XCTAssertTrue(string(payload["structurePolicy"])?.contains("full_source_same_criteria_matrix") == true)
        XCTAssertTrue(string(payload["must_include"])?.contains("minimum_8_aligned_criteria") == true)
        XCTAssertTrue(string(payload["studyWorkspaceSchema"])?.contains("source_refs") == true)
        XCTAssertTrue(string(payload["qualityChecklist"])?.contains("not_intro_only") == true)
    }

    func testGenerationJobPayloadKeepsExplicitEconomyButRaisesQualityFloor() {
        let payload = DriveAPI.generationJobPayload(
            fileId: "file-1",
            jobType: "flashcard",
            count: 20,
            qualityTier: "economy",
            options: nil
        )

        XCTAssertEqual(string(payload["quality_tier"]), "economy")
        XCTAssertEqual(string(payload["modelPolicy"]), "premium_efficient_long_context_active_recall_quality_first")
        XCTAssertEqual(string(payload["minimumDepth"]), "premium_efficient_deep_with_gap_analysis")
        XCTAssertEqual(string(payload["preferredModelTier"]), "latest_premium_efficient_long_context")
        XCTAssertEqual(string(payload["generationQualityProfile"]), "sourcebase_premium_efficient_generation_v3")
        XCTAssertEqual(string(payload["qualityGate"]), "reject_thin_generic_single_paragraph_or_source_detached_output")
    }

    func testGenerationJobPayloadPreservesOutputContractAndMediaAssetRequirements() {
        let podcast = DriveAPI.generationJobPayload(
            fileId: "file-1",
            jobType: "podcast",
            options: [
                "outputContract": "custom typed podcast contract",
                "audioAssetRequired": "true"
            ]
        )
        let infographic = DriveAPI.generationJobPayload(
            fileId: "file-2",
            jobType: "infographic",
            options: [
                "output_contract": "custom typed infographic contract"
            ]
        )

        XCTAssertEqual(string(podcast["outputContract"]), "custom typed podcast contract")
        XCTAssertEqual(string(podcast["output_contract"]), "custom typed podcast contract")
        XCTAssertEqual(string(podcast["audioAssetRequired"]), "true")
        XCTAssertEqual(string(podcast["audio_format"]), "m4a_or_mp3_exportable")
        XCTAssertEqual(string(podcast["resultRouteContract"]), "create_or_reuse_generated_output_then_route_to_study_output")
        XCTAssertEqual(string(podcast["retrievalPracticePolicy"]), "force_commit_before_answer_with_self_check_or_questions")
        XCTAssertEqual(string(podcast["spaced_review_policy"]), "include_today_24h_72h_7d_review_prompts_when_applicable")
        XCTAssertTrue(string(podcast["learningSciencePolicy"])?.contains("dual_coding_audio") == true)
        XCTAssertTrue(string(podcast["studentOutcomeContract"])?.contains("export_audio") == true)
        XCTAssertTrue(string(podcast["finalQualityReview"])?.contains("verify_not_plain_text") == true)

        XCTAssertEqual(string(infographic["output_contract"]), "custom typed infographic contract")
        XCTAssertEqual(string(infographic["visualAssetRequired"]), "true")
        XCTAssertEqual(string(infographic["assetFallbackPolicy"]), "structured_text_blocks_when_image_unavailable")
        XCTAssertTrue(string(infographic["learning_science_policy"])?.contains("dual_coding_visual") == true)
        XCTAssertTrue(string(infographic["student_outcome_contract"])?.contains("quick_check") == true)
        XCTAssertTrue(string(infographic["cta_contract"])?.contains("primary_cta_opens_typed_study_output") == true)
    }

    func testInfographicParserFlattensSectionsAndIgnoresRelativeImagePath() {
        let content: AnyJSON = .object([
            "title": .string("Hipertansiyon İnfografiği"),
            "imageUrl": .string("generated/infographic.png"),
            "sections": .array([
                .object([
                    "heading": .string("Ana mesaj"),
                    "bullets": .array([
                        .string("Kan basıncı ölçümünü doğru manşonla doğrula."),
                        .string("Risk faktörlerini aynı vizitte sınıflandır.")
                    ])
                ]),
                .object([
                    "title": .string("Uyarılar"),
                    "items": .array([
                        .string("Acil bulguda gecikmeden ileri değerlendirme gerekir.")
                    ])
                ])
            ])
        ])

        let infographic = GeneratedContentParser.infographic(
            from: content,
            fallbackTitle: "Fallback"
        )

        XCTAssertEqual(infographic.title, "Hipertansiyon İnfografiği")
        XCTAssertNil(infographic.imageURL, "Relative asset paths should not be handed to AsyncImage as remote URLs.")
        XCTAssertEqual(infographic.blocks.count, 3)
        XCTAssertTrue(infographic.blocks.contains("Ana mesaj: Kan basıncı ölçümünü doğru manşonla doğrula."))
        XCTAssertTrue(infographic.blocks.contains("Uyarılar: Acil bulguda gecikmeden ileri değerlendirme gerekir."))
    }

    func testInfographicParserAcceptsNestedPublicImageURL() {
        let content: AnyJSON = .object([
            "headline": .string("Görsel Özet"),
            "image": .object([
                "publicUrl": .string("https://cdn.example.com/sourcebase/infographic.png")
            ]),
            "blocks": .array([.string("Kısa klinik not")])
        ])

        let infographic = GeneratedContentParser.infographic(
            from: content,
            fallbackTitle: "Fallback"
        )

        XCTAssertEqual(infographic.imageURL?.absoluteString, "https://cdn.example.com/sourcebase/infographic.png")
        XCTAssertEqual(infographic.blocks, ["Kısa klinik not"])
    }

    func testInfographicParserAcceptsMarkdownAndAssetArrayImageURLs() {
        let markdownContent: AnyJSON = .object([
            "title": .string("Klinik Görsel"),
            "visual": .string("![infografik](https://cdn.example.com/sourcebase/clinical-info.webp)"),
            "quick_check": .array([.string("Kırmızı bayrağı görmeden cevaba geçme.")])
        ])
        let arrayContent: AnyJSON = .object([
            "title": .string("Klinik Görsel"),
            "assets": .array([
                .object([
                    "cdn_url": .string("https://assets.example.com/generated/clinical-info.png")
                ])
            ]),
            "blocks": .array([.string("Ana mesajı 20 saniyede tara.")])
        ])

        let markdown = GeneratedContentParser.infographic(
            from: markdownContent,
            fallbackTitle: "Fallback"
        )
        let array = GeneratedContentParser.infographic(
            from: arrayContent,
            fallbackTitle: "Fallback"
        )

        XCTAssertEqual(markdown.imageURL?.absoluteString, "https://cdn.example.com/sourcebase/clinical-info.webp")
        XCTAssertEqual(markdown.blocks, ["Kırmızı bayrağı görmeden cevaba geçme."])
        XCTAssertEqual(array.imageURL?.absoluteString, "https://assets.example.com/generated/clinical-info.png")
        XCTAssertEqual(array.blocks, ["Ana mesajı 20 saniyede tara."])
    }

    func testMediaParsersExposePrivateGeneratedAssetPaths() {
        let infographicContent: AnyJSON = .object([
            "title": .string("Klinik Görsel"),
            "image": .object([
                "storageObjectName": .string("sourcebase/users/user-1/generated/infographics/job-1.png"),
                "storageUrl": .string("s3://medasistorage/sourcebase/users/user-1/generated/infographics/job-1.png")
            ]),
            "blocks": .array([.string("Ana mesajı görselde göster.")])
        ])
        let podcastContent: AnyJSON = .object([
            "title": .string("Klinik Podcast"),
            "audio": .object([
                "storageObjectName": .string("sourcebase/users/user-1/generated/podcasts/job-1.m4a"),
                "storageUrl": .string("s3://medasistorage/sourcebase/users/user-1/generated/podcasts/job-1.m4a")
            ]),
            "segments": .array([.string("Kalp yetmezliği anlatımı.")])
        ])

        let infographic = GeneratedContentParser.infographic(
            from: infographicContent,
            fallbackTitle: "Fallback"
        )
        let podcast = GeneratedContentParser.podcast(
            from: podcastContent,
            fallbackTitle: "Fallback"
        )
        let ignored = GeneratedContentParser.infographic(
            from: .object(["assetPath": .string("generated/missing.png")]),
            fallbackTitle: "Fallback"
        )

        XCTAssertEqual(infographic.assetPath, "sourcebase/users/user-1/generated/infographics/job-1.png")
        XCTAssertEqual(podcast.assetPath, "sourcebase/users/user-1/generated/podcasts/job-1.m4a")
        XCTAssertNil(podcast.audioURL)
        XCTAssertNil(ignored.assetPath)
    }

    func testFlashcardParserHidesClozeMarkup() {
        let content: AnyJSON = .object([
            "cards": .array([
                .object([
                    "front": .string("Beta bloker {{c1::kalp hızını azaltır::ipucu}}"),
                    "back": .string("Yanıt: {{c2::kontraktilite azalır}}"),
                    "hint": .string("{{c3::sempatik tonus}}")
                ])
            ])
        ])

        let card = GeneratedContentParser.flashcards(from: content).first

        XCTAssertEqual(card?.front, "Beta bloker kalp hızını azaltır")
        XCTAssertEqual(card?.back, "Yanıt: kontraktilite azalır")
        XCTAssertEqual(card?.hint, "sempatik tonus")
    }

    func testInfographicDocumentDoesNotCreateEmptyImageBlockWithoutRemoteURL() {
        let content: AnyJSON = .object([
            "title": .string("Metin İnfografik"),
            "assetPath": .string("generated/missing.png"),
            "blocks": .array([.string("Birinci blok"), .string("İkinci blok")])
        ])

        let document = GeneratedContentParser.document(
            for: .infographic,
            from: content,
            fallbackTitle: "Fallback",
            fallbackText: nil
        )

        XCTAssertFalse(document.blocks.contains { block in
            if case .image = block { return true }
            return false
        })
        XCTAssertTrue(document.blocks.contains { block in
            if case let .calloutList(_, title, items, _) = block {
                return title == "Öne Çıkanlar" && items == ["Birinci blok", "İkinci blok"]
            }
            return false
        })
    }

    func testQlinikQuestionParserRequiresFiveChoices() {
        let content: AnyJSON = .object([
            "questions": .array([
                .object([
                    "id": .string("q1"),
                    "subject": .string("Dahiliye"),
                    "topic": .string("Kardiyoloji"),
                    "difficulty": .string("medium"),
                    "text": .string("En olası tanı hangisidir?"),
                    "options": .array([
                        .string("A seçeneği"),
                        .string("B seçeneği"),
                        .string("C seçeneği"),
                        .string("D seçeneği"),
                        .string("E seçeneği")
                    ]),
                    "correct_index": .integer(2),
                    "explanation": .string("Klinik bulgular C seçeneğini destekler."),
                    "option_rationales": .array([
                        .string("A dışlanır"),
                        .string("B dışlanır"),
                        .string("C doğru"),
                        .string("D dışlanır"),
                        .string("E dışlanır")
                    ])
                ])
            ])
        ])

        let questions = GeneratedContentParser.questions(from: content)
        XCTAssertEqual(questions.count, 1)
        XCTAssertTrue(questions[0].isQlinikCompatibleFiveChoice)
    }

    func testQlinikQuestionParserAcceptsAnswerIndexAliases() {
        let content: AnyJSON = .object([
            "questions": .array([
                .object([
                    "text": .string("Hangi yaklaşım doğrudur?"),
                    "options": .array([
                        .string("A"),
                        .string("B"),
                        .string("C"),
                        .string("D"),
                        .string("E")
                    ]),
                    "correctAnswerIndex": .integer(3),
                    "explanation": .string("D doğru cevaptır.")
                ])
            ])
        ])

        let questions = GeneratedContentParser.questions(from: content)
        XCTAssertEqual(questions.first?.correctIndex, 3)
        XCTAssertTrue(questions.first?.isQlinikCompatibleFiveChoice == true)
    }

    func testQlinikQuestionParserRejectsNonFiveChoiceSetForCompatibility() {
        let output = GeneratedOutput(
            id: "out-1",
            sourceFileId: "file-1",
            kind: .question,
            rawType: "question",
            title: "Soru",
            detail: "1 öğe",
            content: .object([
                "questions": .array([
                    .object([
                        "text": .string("Eksik seçenekli soru"),
                        "options": .array([.string("A"), .string("B"), .string("C"), .string("D")]),
                        "correctIndex": .integer(0),
                        "explanation": .string("Açıklama")
                    ])
                ])
            ]),
            updatedLabel: "Bugün",
            status: "ready",
            itemCount: 1,
            jobId: "job-1"
        )

        XCTAssertEqual(output.qlinikQuestions.count, 1)
        XCTAssertTrue(output.qlinikCompatibleQuestions.isEmpty)
    }

    func testQuestionAnswerPayloadDoesNotSendCorrectAnswer() {
        let payload = DriveAPI.questionAnswerPayload(
            outputId: "out-1",
            questionId: "q1",
            selectedIndex: 3,
            elapsedSeconds: 12
        )

        XCTAssertNotNil(payload["selectedIndex"])
        XCTAssertNil(payload["correctIndex"])
        XCTAssertNil(payload["correct_index"])
    }

    func testQuestionSessionParserBuildsPublicPromptWithoutAnswer() {
        let response: [String: AnyJSON] = [
            "data": .object([
                "questions": .array([
                    .object([
                        "id": .string("q1"),
                        "subject": .string("Dahiliye"),
                        "topic": .string("Kardiyoloji"),
                        "text": .string("En olası tanı hangisidir?"),
                        "options": .array([.string("A"), .string("B"), .string("C"), .string("D"), .string("E")]),
                        "correct_index": .integer(2),
                        "explanation": .string("Bu alan public prompt modeline alınmaz.")
                    ])
                ])
            ])
        ]

        let prompts = GeneratedContentParser.questionPrompts(from: response)
        XCTAssertEqual(prompts.count, 1)
        XCTAssertTrue(prompts[0].isFiveChoice)
        XCTAssertEqual(prompts[0].id, "q1")
        XCTAssertEqual(prompts[0].options.count, 5)
    }

    func testQuestionAnswerFeedbackParsesAfterSubmit() {
        let response: [String: AnyJSON] = [
            "data": .object([
                "questionId": .string("q1"),
                "selectedIndex": .integer(1),
                "isCorrect": .bool(false),
                "correctIndex": .integer(3),
                "explanation": .string("D doğru cevaptır."),
                "optionRationales": .array([.string("A değil"), .string("B değil")])
            ])
        ]

        let feedback = GeneratedContentParser.questionAnswerFeedback(
            from: response,
            fallbackQuestionId: "fallback",
            selectedIndex: 1
        )

        XCTAssertEqual(feedback.questionId, "q1")
        XCTAssertFalse(feedback.isCorrect)
        XCTAssertEqual(feedback.correctIndex, 3)
        XCTAssertEqual(feedback.explanation, "D doğru cevaptır.")
    }

    func testQuestionAnswerFeedbackAcceptsCorrectAnswerIndexAlias() {
        let response: [String: AnyJSON] = [
            "data": .object([
                "question_id": .string("q2"),
                "selected_index": .integer(2),
                "is_correct": .bool(true),
                "correct_answer_index": .integer(2),
                "explanation": .string("C doğru cevaptır.")
            ])
        ]

        let feedback = GeneratedContentParser.questionAnswerFeedback(
            from: response,
            fallbackQuestionId: "fallback",
            selectedIndex: 0
        )

        XCTAssertEqual(feedback.questionId, "q2")
        XCTAssertEqual(feedback.selectedIndex, 2)
        XCTAssertEqual(feedback.correctIndex, 2)
        XCTAssertTrue(feedback.isCorrect)
    }

    func testGeneratedOutputReadyStatusIsCaseInsensitive() {
        let output = GeneratedOutput(
            id: "out-ready",
            sourceFileId: "file-1",
            kind: .summary,
            rawType: "SUMMARY",
            title: "Özet",
            detail: "Hazır",
            updatedLabel: "Bugün",
            status: "SUCCEEDED",
            itemCount: 1,
            jobId: "job-1"
        )

        XCTAssertTrue(output.isReady)
    }

    func testGeneratedKindTitleLabel() {
        XCTAssertEqual(GeneratedKind.flashcard.titleLabel, "Flashcard Seti")
        XCTAssertEqual(GeneratedKind.question.titleLabel, "Soru Seti")
        XCTAssertEqual(GeneratedKind.summary.titleLabel, "Özet")
        XCTAssertEqual(GeneratedKind.examMorningSummary.titleLabel, "Sınav Sabahı Özeti")
        XCTAssertEqual(GeneratedKind.algorithm.titleLabel, "Algoritma")
        XCTAssertEqual(GeneratedKind.comparison.titleLabel, "Karşılaştırma")
        XCTAssertEqual(GeneratedKind.clinicalScenario.titleLabel, "Klinik Senaryo")
        XCTAssertEqual(GeneratedKind.learningPlan.titleLabel, "Öğrenme Planı")
        XCTAssertEqual(GeneratedKind.podcast.titleLabel, "Podcast")
        XCTAssertEqual(GeneratedKind.table.titleLabel, "Tablo")
        XCTAssertEqual(GeneratedKind.infographic.titleLabel, "İnfografik")
        XCTAssertEqual(GeneratedKind.mindMap.titleLabel, "Zihin Haritası")
    }

    func testDriveFileKindAllCases() {
        let all = DriveFileKind.allCases
        XCTAssertTrue(all.contains(.pdf))
        XCTAssertTrue(all.contains(.pptx))
        XCTAssertTrue(all.contains(.docx))
        XCTAssertTrue(all.contains(.ppt))
        XCTAssertTrue(all.contains(.doc))
        XCTAssertTrue(all.contains(.zip))
    }

    func testGeneratedKindAllCases() {
        let all = GeneratedKind.allCases
        XCTAssertEqual(all.count, 12)
    }

    // MARK: - Upload Service

    func testContentTypeForExtensions() {
        XCTAssertEqual(DriveUploadService.contentTypeFor("file.pdf"), "application/pdf")
        XCTAssertEqual(DriveUploadService.contentTypeFor("file.ppt"), "application/vnd.ms-powerpoint")
        XCTAssertEqual(
            DriveUploadService.contentTypeFor("file.pptx"),
            "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        )
        XCTAssertEqual(DriveUploadService.contentTypeFor("file.doc"), "application/msword")
        XCTAssertEqual(
            DriveUploadService.contentTypeFor("file.docx"),
            "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        )
        XCTAssertEqual(DriveUploadService.contentTypeFor("file.unknown"), "application/octet-stream")
    }

    func testProfileAvatarUploadPayloadKeepsSizeAsInteger() {
        let payload = DriveAPI.profileAvatarUploadPayload(
            fileName: "avatar.jpg",
            contentType: "image/jpeg",
            sizeBytes: 2048
        )
        guard case .integer(let sizeBytes) = payload["sizeBytes"] else {
            return XCTFail("sizeBytes must be sent as a JSON integer.")
        }
        XCTAssertEqual(sizeBytes, 2048)
    }

    func testSupportFormPayloadTrimsFields() {
        let payload = DriveAPI.supportFormPayload(
            topic: "  Ödeme  ",
            email: "  user@example.com  ",
            message: "  Merhaba destek  "
        )
        XCTAssertEqual(stringPayloadValue(payload["topic"]), "Ödeme")
        XCTAssertEqual(stringPayloadValue(payload["email"]), "user@example.com")
        XCTAssertEqual(stringPayloadValue(payload["message"]), "Merhaba destek")
    }

    func testAllowedExtensions() {
        XCTAssertEqual(DriveUploadService.allowedExtensions, ["pdf", "pptx", "docx", "ppt", "doc"])
        XCTAssertEqual(DriveUploadService.supportedExtensionsDisplay, "PDF, PPTX, DOCX, PPT veya DOC")
    }

    func testSupportedFileNameValidationUsesRealExtension() {
        XCTAssertTrue(DriveUploadService.isSupportedFileName("Ders Notu.PPT"))
        XCTAssertTrue(DriveUploadService.isSupportedFileName("Kardiyoloji.v2.docx"))
        XCTAssertFalse(DriveUploadService.isSupportedFileName("pptx.png"))
    }

    func testDriveFileMappingKeepsLegacyPPTDistinctFromPPTX() {
        XCTAssertEqual(DriveFileMapping.kind(from: "application/vnd.ms-powerpoint"), .ppt)
        XCTAssertEqual(DriveFileMapping.kind(from: "slides.PPT"), .ppt)
        XCTAssertEqual(DriveFileMapping.kind(from: "slides.pptx"), .pptx)
        XCTAssertEqual(DriveFileMapping.kind(from: [
            "original_filename": .string("komite-slayt.PPT")
        ]), .ppt)
    }

    func testDriveFileMappingUsesSlideLabelsForPresentations() {
        XCTAssertEqual(
            DriveFileMapping.pageLabel(kind: .pptx, status: .completed, pageCount: 0, slideCount: 42),
            "42 slayt"
        )
        XCTAssertEqual(
            DriveFileMapping.pageLabel(kind: .pptx, status: .completed, pageCount: 12, slideCount: 0),
            "12 slayt"
        )
        XCTAssertEqual(
            DriveFileMapping.pageLabel(kind: .ppt, status: .failed, pageCount: 0, slideCount: 0),
            "Slaytlar okunamadı"
        )
        XCTAssertEqual(
            DriveFileMapping.pageLabel(kind: .pdf, status: .completed, pageCount: 9, slideCount: 0),
            "9 sayfa"
        )
    }

    func testDriveFileMappingExplainsExtractionFailures() {
        let encryptedPDF: [String: AnyJSON] = [
            "metadata": .object(["error_code": .string("FILE_ENCRYPTED_PDF")])
        ]
        XCTAssertEqual(
            DriveFileMapping.statusMessage(row: encryptedPDF, kind: .pdf, status: .failed, sizeBytes: 10),
            "Bu PDF şifreli görünüyor. Şifre korumasını kaldırıp tekrar yükleyebilirsin."
        )

        let corruptFile: [String: AnyJSON] = [
            "metadata": .object(["parseError": .string("corrupt package")])
        ]
        XCTAssertEqual(
            DriveFileMapping.statusMessage(row: corruptFile, kind: .docx, status: .failed, sizeBytes: 10),
            "Dosya bozuk ya da okunamıyor. Dosyayı yeniden kaydedip tekrar yükleyebilirsin."
        )

        let scannedPDF: [String: AnyJSON] = [
            "metadata": .object(["extractionErrorCode": .string("FILE_SCANNED_PDF_OCR_REQUIRED")])
        ]
        XCTAssertEqual(
            DriveFileMapping.statusMessage(row: scannedPDF, kind: .pdf, status: .failed, sizeBytes: 10),
            "Bu PDF taranmış/görsel tabanlı görünüyor. Metin çıkarılamadı; OCR desteği gerekir."
        )

        XCTAssertEqual(
            DriveFileMapping.statusMessage(row: [:], kind: .ppt, status: .failed, sizeBytes: 10),
            "Eski PPT dosyaları sınırlı desteklenir. Dosyayı PPTX olarak kaydedip tekrar yükleyebilirsin."
        )
        XCTAssertEqual(
            DriveFileMapping.statusMessage(row: [:], kind: .doc, status: .failed, sizeBytes: 10),
            "Eski DOC dosyaları sınırlı desteklenir. Dosyayı DOCX olarak kaydedip tekrar yükleyebilirsin."
        )
    }

    func testMaxSizeBytes() {
        XCTAssertEqual(DriveUploadService.maxSizeBytes, 25 * 1024 * 1024)
    }

    // MARK: - API Error

    func testDriveAPIErrorUnauthorized() {
        let error = DriveAPIError(message: "Unauthorized", code: "UNAUTHORIZED", status: 401)
        XCTAssertTrue(error.isUnauthorized)
    }

    func testDriveAPIErrorNotUnauthorized() {
        let error = DriveAPIError(message: "Bad request", code: "BAD_REQUEST", status: 400)
        XCTAssertFalse(error.isUnauthorized)
    }

    // MARK: - Repository Error

    func testRepositoryError() {
        let error = RepositoryError(message: "Test error message")
        XCTAssertEqual(error.message, "Test error message")
    }

    private func stringPayloadValue(_ value: AnyJSON?) -> String? {
        guard case .string(let string) = value else { return nil }
        return string
    }

    // MARK: - Profile

    func testProfileSnapshotEmpty() {
        let snapshot = ProfileSnapshot.empty
        XCTAssertTrue(snapshot.displayName.isEmpty)
        XCTAssertNil(snapshot.walletBalance)
        XCTAssertEqual(snapshot.courseCount, 0)
    }
}
```

## File: Package.swift
```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SourceBaseBackend",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SourceBaseBackend", targets: ["SourceBaseBackend"])
    ],
    dependencies: [
        .package(url: "https://github.com/supabase/supabase-swift", from: "2.0.0")
    ],
    targets: [
        .target(
            name: "SourceBaseBackend",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift")
            ],
            path: "Sources/SourceBaseBackend"
        ),
        .testTarget(
            name: "SourceBaseBackendTests",
            dependencies: ["SourceBaseBackend"],
            path: "Tests/SourceBaseBackendTests"
        )
    ]
)
```
