import 'package:url_launcher/url_launcher.dart';

/// Single source of truth for legal / external destinations, mirroring the
/// iOS `SBLegalLinks`. Used by settings and the store so every outbound link
/// opens the real live page instead of a placeholder.
class SBExternalLinks {
  SBExternalLinks._();

  static const String privacyUrl = 'https://medasi.com.tr/legal/privacy.html';
  static const String termsUrl = 'https://medasi.com.tr/legal/terms.html';

  /// Live SourceBase web app — used as the connected fallback for purchase
  /// flows that are not available through native in-app billing yet.
  static const String webStoreUrl = 'https://sourcebase.medasi.com.tr/store';
  static const String supportUrl = 'https://medasi.com.tr/iletisim';

  /// Opens [url] in the external browser / system handler. Returns true on
  /// success so callers can surface an accurate message.
  static Future<bool> open(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || url.trim().isEmpty) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
