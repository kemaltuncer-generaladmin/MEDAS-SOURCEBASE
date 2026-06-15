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
