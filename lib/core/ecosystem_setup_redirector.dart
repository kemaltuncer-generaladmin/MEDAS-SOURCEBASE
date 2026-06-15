import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import 'sourcebase_api_client.dart';

/// Opens the shared onboarding in edit mode for an already-set-up user. Profile
/// editing lives in the central screen, not in-app.
Future<bool> openEcosystemSetupEdit() async {
  final api = SourceBaseApiClient.shared;
  final token = await api.ecosystemAccessToken();
  return const EcosystemSetupRedirector().open(
    accessToken: token,
    userId: api.currentUserId,
    email: api.currentEmail,
    mode: 'edit',
  );
}

/// Opens the shared MedAsi ecosystem onboarding (medasi.com.tr/kurulum) for
/// SourceBase. Mirrors the Qlinik redirector: SourceBase keeps no in-app
/// ecosystem setup copy; missing profiles are completed centrally and the user
/// is returned afterwards.
class EcosystemSetupRedirector {
  const EcosystemSetupRedirector();

  static const String _setupUrl = 'https://medasi.com.tr/kurulum';

  Uri buildUrl({
    required String accessToken,
    required String userId,
    required String email,
    String mode = 'required',
  }) {
    // On web the return is a full navigation back to the live app; on mobile a
    // deep link into SourceBase.
    final returnUrl = kIsWeb
        ? 'https://sourcebase.medasi.com.tr/?setup=completed'
        : 'medasisourcebase://ecosystem-setup-complete';
    return Uri.parse(_setupUrl).replace(
      queryParameters: <String, String>{
        'source_app': 'sourcebase',
        'return_url': returnUrl,
        'mode': mode,
        if (userId.isNotEmpty) 'user_id': userId,
        if (email.isNotEmpty) 'email': email,
        if (accessToken.isNotEmpty) 'token': accessToken,
      },
    );
  }

  Future<bool> open({
    required String accessToken,
    required String userId,
    required String email,
    String mode = 'required',
  }) {
    return launchUrl(
      buildUrl(
        accessToken: accessToken,
        userId: userId,
        email: email,
        mode: mode,
      ),
      mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
      webOnlyWindowName: '_self',
    );
  }
}
