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
