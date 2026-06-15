import 'package:flutter/foundation.dart';

import 'sourcebase_api_client.dart';

/// Live SourceBase session store backed by Supabase Auth.
class SessionStore extends ChangeNotifier {
  SessionStore._();

  static final SessionStore shared = SessionStore._();
  final SourceBaseApiClient _api = SourceBaseApiClient.shared;

  bool isInitialized = false;
  String? initializationError;
  bool isLoading = false;
  String? errorMessage;
  String? successMessage;

  bool _hasUser = false;
  bool _emailConfirmed = false;
  String _email = '';
  String _fullName = '';
  String faculty = '';
  String department = '';
  String classYear = '';
  String goal = '';

  // Shared MedAsi ecosystem onboarding (user_setup_profiles). SourceBase is
  // open to every faculty, so there is NO discipline gate here — we only check
  // whether the central onboarding has been completed at all.
  bool _ecosystemChecked = false; // a check finished successfully
  bool ecosystemChecking = false;
  bool? _ecosystemComplete; // null until known
  String? ecosystemError;

  bool get isLoggedIn => _hasUser;

  bool get needsEmailVerification => _hasUser && !_emailConfirmed;

  /// Central ecosystem onboarding already completed (a profile row exists).
  bool get ecosystemSetupComplete => _ecosystemComplete == true;

  /// Logged-in, verified user whose ecosystem onboarding is confirmed missing.
  bool get needsEcosystemSetup =>
      _hasUser &&
      _emailConfirmed &&
      _ecosystemChecked &&
      _ecosystemComplete == false;

  /// The ecosystem status is still being resolved (show a loading gate, not the
  /// redirect screen, so we never bounce a user who is actually set up).
  bool get ecosystemBusy =>
      ecosystemChecking || (!_ecosystemChecked && ecosystemError == null);

  /// Re-read the shared onboarding status from Supabase. Fails closed: on error
  /// the status stays unresolved and the gate surfaces a retry.
  Future<void> refreshEcosystemSetup() async {
    if (!_hasUser || !_emailConfirmed) {
      _ecosystemChecked = false;
      _ecosystemComplete = null;
      ecosystemError = null;
      return;
    }
    ecosystemChecking = true;
    ecosystemError = null;
    notifyListeners();
    try {
      _ecosystemComplete = await _api.hasEcosystemSetupProfile();
      _ecosystemChecked = true;
    } catch (error) {
      ecosystemError = _friendlyError(error);
    } finally {
      ecosystemChecking = false;
      notifyListeners();
    }
  }

  String get displayName {
    if (!_hasUser) return '';
    if (_fullName.isNotEmpty) return _fullName;
    return _email.split('@').first.isNotEmpty
        ? _email.split('@').first
        : 'Kullanıcı';
  }

  String get email => _email;

  Future<void> initialize() async {
    if (isInitialized) return;
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final user = await _api.initialize();
      _applyUser(user);
      isInitialized = true;
      initializationError = null;
    } catch (error) {
      initializationError = _friendlyError(error);
      errorMessage = initializationError;
    } finally {
      isLoading = false;
      notifyListeners();
    }

    if (_hasUser && _emailConfirmed) {
      await refreshEcosystemSetup();
    }
  }

  Future<bool> signIn({required String email, required String password}) async {
    isLoading = true;
    errorMessage = null;
    successMessage = null;
    notifyListeners();

    if (email.trim().isEmpty || password.isEmpty) {
      errorMessage = 'E-posta veya şifre hatalı.';
      isLoading = false;
      notifyListeners();
      return false;
    }

    try {
      final user = await _api.signIn(email: email, password: password);
      _applyUser(user);
      if (_hasUser && _emailConfirmed) {
        await refreshEcosystemSetup();
      }
      successMessage = 'Giriş başarılı.';
      return true;
    } catch (error) {
      errorMessage = _friendlyError(error);
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signUp({
    required String fullName,
    required String email,
    required String password,
    String? university,
    String? faculty,
  }) async {
    isLoading = true;
    errorMessage = null;
    successMessage = null;
    notifyListeners();

    try {
      await _api.signUp(
        fullName: fullName,
        email: email,
        password: password,
        university: university,
        faculty: faculty,
      );
      _hasUser = true;
      _emailConfirmed = false;
      _email = email.trim();
      _fullName = fullName.trim();
      this.faculty = faculty?.trim() ?? '';
      department = '';
      classYear = '';
      goal = '';
      successMessage = 'Doğrulama kodu e-posta adresine gönderildi.';
    } catch (error) {
      errorMessage = _friendlyError(error);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> verifyEmailOTP({
    required String email,
    required String token,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    if (token.trim().length < 6) {
      errorMessage = 'Doğrulama kodu geçersiz. Kontrol edip tekrar dene.';
      isLoading = false;
      notifyListeners();
      return false;
    }

    try {
      final user = await _api.verifyEmailOTP(email: email, token: token);
      _applyUser(user);
      if (_hasUser && _emailConfirmed) {
        await refreshEcosystemSetup();
      }
      successMessage = 'E-posta doğrulandı.';
      return true;
    } catch (error) {
      errorMessage = _friendlyError(error);
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> resendVerificationEmail({required String email}) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _api.resendVerificationEmail(email: email);
      successMessage = 'Doğrulama e-postası yeniden gönderildi.';
    } catch (error) {
      errorMessage = _friendlyError(error);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateProfile({
    String? fullName,
    String? faculty,
    String? department,
    String? classYear,
    String? goal,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final user = await _api.updateProfile(
        fullName: fullName,
        faculty: faculty,
        department: department,
        classYear: classYear,
        goal: goal,
      );
      _applyUser(user);
      successMessage = 'Profil güncellendi.';
      return true;
    } catch (error) {
      errorMessage = _friendlyError(error);
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendPasswordReset({required String email}) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _api.sendPasswordReset(email: email);
      successMessage =
          'Şifre sıfırlama bağlantısı e-posta adresine gönderildi.';
    } catch (error) {
      errorMessage = _friendlyError(error);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updatePassword(String password) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    if (password.length < 8) {
      errorMessage = 'Şifre en az 8 karakter olmalı.';
      isLoading = false;
      notifyListeners();
      return false;
    }

    try {
      final user = await _api.updatePassword(password);
      _applyUser(user);
      successMessage = 'Şifre güncellendi.';
      return true;
    } catch (error) {
      errorMessage = _friendlyError(error);
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    isLoading = true;
    notifyListeners();

    try {
      await _api.signOut();
    } finally {
      _applyUser(null);
      errorMessage = null;
      successMessage = null;
      isLoading = false;
      notifyListeners();
    }
  }

  void clearMessages() {
    errorMessage = null;
    successMessage = null;
    notifyListeners();
  }

  void _applyUser(SourceBaseUser? user) {
    _hasUser = user != null;
    _emailConfirmed = user?.emailConfirmed ?? false;
    _email = user?.email ?? '';
    final metadata = user?.metadata ?? {};
    _fullName =
        (metadata['full_name'] ??
                metadata['display_name'] ??
                metadata['name'] ??
                '')
            .toString();
    faculty = (metadata['sourcebase_faculty'] ?? '').toString();
    department = (metadata['sourcebase_department'] ?? '').toString();
    classYear = (metadata['sourcebase_class_year'] ?? '').toString();
    goal = (metadata['sourcebase_goal'] ?? '').toString();
    // The ecosystem status belongs to the previous identity; re-check on demand.
    _ecosystemChecked = false;
    _ecosystemComplete = null;
    ecosystemChecking = false;
    ecosystemError = null;
  }

  String _friendlyError(Object error) {
    if (error is SourceBaseApiException) {
      if (error.isUnauthorized) {
        return 'Oturum süresi doldu. Lütfen tekrar giriş yap.';
      }
      return error.message;
    }
    return 'İşlem tamamlanamadı. Lütfen tekrar dene.';
  }
}
