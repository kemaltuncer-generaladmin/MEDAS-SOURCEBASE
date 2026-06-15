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
