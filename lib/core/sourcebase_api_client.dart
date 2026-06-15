import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SourceBaseConfig {
  const SourceBaseConfig({
    this.supabaseUrl = 'https://medasi.com.tr',
    this.supabaseAnonKey =
        'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJzdXBhYmFzZSIsImlhdCI6MTc3ODUyMDA2MCwiZXhwIjo0OTM0MTkzNjYwLCJyb2xlIjoiYW5vbiJ9.JwCrc4LMTYpQRTIcwBk4WaVOVUbpwN0fM1SMknmDClk',
    this.publicUrl = 'https://sourcebase.medasi.com.tr',
    this.mobileRedirectUrl = 'sourcebase://auth/callback',
  });

  final String supabaseUrl;
  final String supabaseAnonKey;
  final String publicUrl;
  final String mobileRedirectUrl;

  String get authRedirectTo => mobileRedirectUrl.trim().isNotEmpty
      ? mobileRedirectUrl
      : '${publicUrl.replaceFirst(RegExp(r'/$'), '')}/auth/callback';

  Uri authUri(String path, [Map<String, String>? query]) {
    return Uri.parse(
      '$supabaseUrl/auth/v1$path',
    ).replace(queryParameters: query);
  }

  Uri get sourcebaseFunctionUri =>
      Uri.parse('$supabaseUrl/functions/v1/sourcebase');
}

class SourceBaseApiException implements Exception {
  SourceBaseApiException(this.message, {this.code, this.status});

  final String message;
  final String? code;
  final int? status;

  bool get isUnauthorized =>
      status == 401 || code == 'UNAUTHORIZED' || code == 'AUTH_NOT_CONFIGURED';

  @override
  String toString() {
    final parts = [message];
    if (code != null) parts.add('code=$code');
    if (status != null) parts.add('status=$status');
    return parts.join(' ');
  }
}

class SourceBaseUser {
  SourceBaseUser({
    required this.id,
    required this.email,
    required this.emailConfirmed,
    required this.metadata,
  });

  final String id;
  final String email;
  final bool emailConfirmed;
  final Map<String, dynamic> metadata;

  factory SourceBaseUser.fromJson(Map<String, dynamic> json) {
    final metadata = json['user_metadata'] is Map
        ? Map<String, dynamic>.from(json['user_metadata'] as Map)
        : <String, dynamic>{};
    return SourceBaseUser(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      emailConfirmed:
          (json['email_confirmed_at']?.toString().isNotEmpty ?? false) ||
          (json['confirmed_at']?.toString().isNotEmpty ?? false),
      metadata: metadata,
    );
  }
}

class SourceBaseAuthSession {
  SourceBaseAuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;

  bool get shouldRefresh =>
      DateTime.now().isAfter(expiresAt.subtract(const Duration(seconds: 60)));

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'expiresAt': expiresAt.toIso8601String(),
  };

  factory SourceBaseAuthSession.fromAuthResponse(Map<String, dynamic> json) {
    final expiresIn = _intValue(json['expires_in']) ?? 3600;
    final expiresAtEpoch = _intValue(json['expires_at']);
    final expiresAt = expiresAtEpoch != null
        ? DateTime.fromMillisecondsSinceEpoch(expiresAtEpoch * 1000)
        : DateTime.now().add(Duration(seconds: expiresIn));
    return SourceBaseAuthSession(
      accessToken: json['access_token']?.toString() ?? '',
      refreshToken: json['refresh_token']?.toString() ?? '',
      expiresAt: expiresAt,
    );
  }

  factory SourceBaseAuthSession.fromJson(Map<String, dynamic> json) {
    return SourceBaseAuthSession(
      accessToken: json['accessToken']?.toString() ?? '',
      refreshToken: json['refreshToken']?.toString() ?? '',
      expiresAt:
          DateTime.tryParse(json['expiresAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  static int? _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}

class SourceBaseApiClient {
  SourceBaseApiClient._({http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  static final SourceBaseApiClient shared = SourceBaseApiClient._();
  static const _sessionPrefsKey = 'sourcebase.auth.session.v1';

  final http.Client _http;
  final SourceBaseConfig config = const SourceBaseConfig();

  SourceBaseAuthSession? _session;
  SourceBaseUser? _currentUser;

  SourceBaseUser? get currentUser => _currentUser;
  bool get hasSession => _session?.accessToken.isNotEmpty == true;

  String get currentUserId => _currentUser?.id ?? '';
  String get currentEmail => _currentUser?.email ?? '';

  /// Fresh access token for handing to the shared ecosystem onboarding
  /// redirect (the `token` query param Core verifies).
  Future<String> ecosystemAccessToken() => _accessToken();

  /// True when the user already has a row in the shared ecosystem
  /// `user_setup_profiles` table (central onboarding completed). Throws on
  /// network/auth errors so the caller fails closed instead of silently
  /// skipping onboarding.
  Future<bool> hasEcosystemSetupProfile() async {
    final userId = currentUserId;
    if (userId.isEmpty) return false;
    final rows = await selectRows(
      'user_setup_profiles',
      query: {'select': 'user_id', 'user_id': 'eq.$userId', 'limit': '1'},
    );
    return rows.isNotEmpty;
  }

  Future<SourceBaseUser?> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionPrefsKey);
    if (raw == null || raw.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      _session = SourceBaseAuthSession.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      await _ensureFreshSession();
      _currentUser = await fetchCurrentUser();
      return _currentUser;
    } catch (_) {
      await clearSession();
      return null;
    }
  }

  Future<SourceBaseUser> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _authRequest(
      'POST',
      config.authUri('/token', {'grant_type': 'password'}),
      body: {'email': email.trim(), 'password': password},
    );
    await _setSessionFromResponse(response);
    _currentUser = SourceBaseUser.fromJson(_map(response['user'] ?? response));
    return _currentUser!;
  }

  Future<void> signUp({
    required String fullName,
    required String email,
    required String password,
    String? university,
    String? faculty,
  }) async {
    final userData = {
      'app_code': 'sourcebase',
      'display_name': fullName.trim(),
      'full_name': fullName.trim(),
      'signup_source': 'sourcebase',
      'ecosystem': 'medasi',
      if (university?.trim().isNotEmpty == true)
        'sourcebase_university': university!.trim(),
      if (faculty?.trim().isNotEmpty == true)
        'sourcebase_faculty': faculty!.trim(),
    };
    final response = await _authRequest(
      'POST',
      config.authUri('/signup', {'redirect_to': config.authRedirectTo}),
      body: {'email': email.trim(), 'password': password, 'data': userData},
    );
    if (responseContainsSession(response)) {
      await _setSessionFromResponse(response);
    }
    _currentUser = response['user'] is Map
        ? SourceBaseUser.fromJson(_map(response['user']))
        : SourceBaseUser(
            id: '',
            email: email.trim(),
            emailConfirmed: false,
            metadata: userData,
          );
  }

  Future<SourceBaseUser> verifyEmailOTP({
    required String email,
    required String token,
  }) async {
    final response = await _authRequest(
      'POST',
      config.authUri('/verify'),
      body: {'email': email.trim(), 'token': token.trim(), 'type': 'signup'},
    );
    await _setSessionFromResponse(response);
    _currentUser = SourceBaseUser.fromJson(_map(response['user'] ?? response));
    return _currentUser!;
  }

  Future<void> resendVerificationEmail({required String email}) async {
    await _authRequest(
      'POST',
      config.authUri('/resend'),
      body: {
        'type': 'signup',
        'email': email.trim(),
        'options': {'email_redirect_to': config.authRedirectTo},
      },
    );
  }

  Future<void> sendPasswordReset({required String email}) async {
    await _authRequest(
      'POST',
      config.authUri('/recover', {'redirect_to': config.authRedirectTo}),
      body: {'email': email.trim()},
    );
  }

  Future<SourceBaseUser> updatePassword(String password) async {
    final response = await _authRequest(
      'PUT',
      config.authUri('/user'),
      body: {'password': password},
      requiresUser: true,
    );
    _currentUser = SourceBaseUser.fromJson(_map(response['user'] ?? response));
    return _currentUser!;
  }

  Future<SourceBaseUser> updateProfile({
    String? fullName,
    String? faculty,
    String? department,
    String? classYear,
    String? goal,
  }) async {
    final existing = _currentUser?.metadata ?? {};
    final merged = Map<String, dynamic>.from(existing);
    if (fullName != null && fullName.trim().isNotEmpty) {
      merged['display_name'] = fullName.trim();
      merged['full_name'] = fullName.trim();
    }
    if (faculty != null) merged['sourcebase_faculty'] = faculty;
    if (department != null) merged['sourcebase_department'] = department;
    if (classYear != null) merged['sourcebase_class_year'] = classYear;
    if (goal != null) merged['sourcebase_goal'] = goal;
    merged['sourcebase_profile_completed'] = true;
    merged['sourcebase_profile_completed_at'] = DateTime.now()
        .toIso8601String();

    final response = await _authRequest(
      'PUT',
      config.authUri('/user'),
      body: {'data': merged},
      requiresUser: true,
    );
    _currentUser = SourceBaseUser.fromJson(_map(response['user'] ?? response));
    return _currentUser!;
  }

  Future<SourceBaseUser> fetchCurrentUser() async {
    final response = await _authRequest(
      'GET',
      config.authUri('/user'),
      requiresUser: true,
    );
    return SourceBaseUser.fromJson(_map(response));
  }

  Future<void> signOut() async {
    try {
      if (_session?.accessToken.isNotEmpty == true) {
        await _authRequest(
          'POST',
          config.authUri('/logout'),
          requiresUser: true,
        );
      }
    } finally {
      await clearSession();
    }
  }

  Future<void> clearSession() async {
    _session = null;
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionPrefsKey);
  }

  Future<Map<String, dynamic>> invoke(
    String action, {
    Map<String, dynamic> payload = const {},
    Duration timeout = const Duration(seconds: 90),
  }) async {
    final token = await _accessToken();
    final response = await _http
        .post(
          config.sourcebaseFunctionUri,
          headers: {
            'apikey': config.supabaseAnonKey,
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'action': action, 'payload': payload}),
        )
        .timeout(timeout);
    final json = _decodeResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _exceptionFromJson(json, response.statusCode);
    }
    if (json['ok'] == false) {
      final error = json['error'];
      if (error is Map) {
        throw SourceBaseApiException(
          error['message']?.toString() ?? 'SourceBase işlemi tamamlanamadı.',
          code: error['code']?.toString(),
          status: SourceBaseAuthSession._intValue(error['status']),
        );
      }
      throw SourceBaseApiException('SourceBase işlemi tamamlanamadı.');
    }
    return json;
  }

  Future<Map<String, dynamic>> purchaseMedasiCoin({
    required String productCode,
  }) async {
    final response = await invoke(
      'purchase_medasicoin',
      payload: {
        'product_code': productCode,
        'success_url': '${config.publicUrl}/store/success',
        'cancel_url': '${config.publicUrl}/store/cancel',
      },
    );
    return _map(response['data']);
  }

  /// Verify and redeem a Google Play purchase server-side. The backend
  /// validates [purchaseToken] against the Google Play Developer API (service
  /// account) and grants the MedasiCoin / storage entitlement idempotently.
  Future<Map<String, dynamic>> redeemPlayPurchase({
    required String productId,
    required String purchaseToken,
    bool isSubscription = false,
    String? orderId,
  }) async {
    final response = await invoke(
      isSubscription ? 'redeem_play_subscription' : 'redeem_play_purchase',
      payload: {
        'productId': productId,
        'purchaseToken': purchaseToken,
        'orderId': ?orderId,
        'packageName': 'com.medasi.sourcebase',
      },
    );
    return _map(response['data']);
  }

  Future<List<Map<String, dynamic>>> selectRows(
    String table, {
    String? schema,
    Map<String, String> query = const {},
  }) async {
    final token = await _accessToken();
    final uri = Uri.parse(
      '${config.supabaseUrl}/rest/v1/$table',
    ).replace(queryParameters: query);
    final response = await _http.get(
      uri,
      headers: {
        'apikey': config.supabaseAnonKey,
        'Authorization': 'Bearer $token',
        if (schema != null) ...{
          'Accept-Profile': schema,
          'Content-Profile': schema,
        },
      },
    );
    final decoded = response.body.trim().isEmpty
        ? null
        : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _exceptionFromJson(
        decoded is Map ? Map<String, dynamic>.from(decoded) : const {},
        response.statusCode,
      );
    }
    if (decoded is List) {
      return [
        for (final item in decoded)
          if (item is Map) Map<String, dynamic>.from(item),
      ];
    }
    if (decoded is Map && decoded['data'] is List) {
      return [
        for (final item in decoded['data'] as List)
          if (item is Map) Map<String, dynamic>.from(item),
      ];
    }
    return const [];
  }

  Future<void> uploadToSignedUrl({
    required String uploadUrl,
    required Map<String, String> headers,
    required Uint8List bytes,
  }) async {
    final response = await _http
        .put(Uri.parse(uploadUrl), headers: headers, body: bytes)
        .timeout(const Duration(minutes: 4));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SourceBaseApiException(
        response.body.trim().isEmpty
            ? 'Dosya depolama alanına yüklenemedi.'
            : response.body.trim(),
        status: response.statusCode,
      );
    }
  }

  Future<String> _accessToken() async {
    await _ensureFreshSession();
    final token = _session?.accessToken ?? '';
    if (token.isEmpty) {
      throw SourceBaseApiException(
        'Oturum bulunamadı. Lütfen tekrar giriş yap.',
        code: 'NO_SESSION',
        status: 401,
      );
    }
    return token;
  }

  Future<void> _ensureFreshSession() async {
    final session = _session;
    if (session == null || session.accessToken.isEmpty) return;
    if (!session.shouldRefresh) return;
    if (session.refreshToken.isEmpty) return;

    final response = await _authRequest(
      'POST',
      config.authUri('/token', {'grant_type': 'refresh_token'}),
      body: {'refresh_token': session.refreshToken},
    );
    await _setSessionFromResponse(response);
  }

  Future<void> _setSessionFromResponse(Map<String, dynamic> response) async {
    final session = SourceBaseAuthSession.fromAuthResponse(response);
    if (session.accessToken.isEmpty) return;
    _session = session;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionPrefsKey, jsonEncode(session.toJson()));
  }

  Future<Map<String, dynamic>> _authRequest(
    String method,
    Uri uri, {
    Map<String, dynamic>? body,
    bool requiresUser = false,
  }) async {
    final headers = {
      'apikey': config.supabaseAnonKey,
      'Authorization':
          'Bearer ${requiresUser ? await _accessToken() : (_session?.accessToken ?? config.supabaseAnonKey)}',
      'Content-Type': 'application/json',
    };

    final encodedBody = body == null ? null : jsonEncode(body);
    final response = switch (method) {
      'GET' => await _http.get(uri, headers: headers),
      'POST' => await _http.post(uri, headers: headers, body: encodedBody),
      'PUT' => await _http.put(uri, headers: headers, body: encodedBody),
      _ => throw ArgumentError('Unsupported method $method'),
    };
    final json = _decodeResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _exceptionFromJson(json, response.statusCode);
    }
    return json;
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    if (response.body.trim().isEmpty) return {};
    final decoded = jsonDecode(response.body);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return {'data': decoded};
  }

  SourceBaseApiException _exceptionFromJson(
    Map<String, dynamic> json,
    int status,
  ) {
    final source = json['error'] is Map
        ? Map<String, dynamic>.from(json['error'] as Map)
        : json;
    return SourceBaseApiException(
      source['message']?.toString() ??
          source['msg']?.toString() ??
          source['error_description']?.toString() ??
          'İşlem tamamlanamadı.',
      code: source['code']?.toString() ?? source['error']?.toString(),
      status: SourceBaseAuthSession._intValue(source['status']) ?? status,
    );
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
  }

  bool responseContainsSession(Map<String, dynamic> response) {
    return response['access_token'] != null ||
        response['refresh_token'] != null ||
        response['session'] is Map;
  }
}
