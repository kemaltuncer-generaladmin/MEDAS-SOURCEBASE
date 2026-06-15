import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ecosystem_setup_redirector.dart';
import '../../core/session_store.dart';
import '../../core/sourcebase_api_client.dart';
import '../../design_system/sb_button.dart';
import '../../design_system/sb_colors.dart';
import '../../design_system/sb_spacing.dart';
import '../../design_system/sb_typography.dart';

/// Required gate shown when a logged-in, verified SourceBase user has not yet
/// completed the shared MedAsi ecosystem onboarding. SourceBase keeps no in-app
/// onboarding copy: it sends the user to medasi.com.tr/kurulum and re-checks on
/// return. Open to every faculty — there is no discipline restriction.
class EcosystemSetupView extends StatefulWidget {
  const EcosystemSetupView({super.key});

  @override
  State<EcosystemSetupView> createState() => _EcosystemSetupViewState();
}

class _EcosystemSetupViewState extends State<EcosystemSetupView> {
  static const EcosystemSetupRedirector _redirector =
      EcosystemSetupRedirector();
  final SourceBaseApiClient _api = SourceBaseApiClient.shared;

  bool _hasOpened = false;
  bool _isOpening = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Only auto-open the browser when this is a genuine "needs setup" state.
      // If the status check failed, show a retry instead of bouncing the user.
      final session = context.read<SessionStore>();
      if (session.ecosystemError == null) _openSetup();
    });
  }

  Future<void> _openSetup({bool force = false}) async {
    if (_isOpening || (_hasOpened && !force)) return;
    setState(() {
      _isOpening = true;
      _error = null;
    });
    try {
      final token = await _api.ecosystemAccessToken();
      final opened = await _redirector.open(
        accessToken: token,
        userId: _api.currentUserId,
        email: _api.currentEmail,
      );
      if (!mounted) return;
      setState(() {
        _hasOpened = true;
        _error = opened
            ? null
            : 'Kurulum sayfası açılamadı. Bağlantıyı tekrar deneyebilirsin.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Kurulum sayfası açılamadı. Bağlantıyı tekrar deneyebilirsin.';
      });
    } finally {
      if (mounted) setState(() => _isOpening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionStore>();
    final message = _error ?? session.ecosystemError;

    return Scaffold(
      backgroundColor: SBColors.page,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(SBSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.open_in_new_rounded,
                      color: SBColors.blue, size: 44),
                  const SizedBox(height: SBSpacing.md),
                  Text(
                    'MedAsi Ekosistem Kurulumuna yönlendiriliyorsun',
                    textAlign: TextAlign.center,
                    style: SBTypography.heading2.copyWith(color: SBColors.navy),
                  ),
                  const SizedBox(height: SBSpacing.sm),
                  Text(
                    'Kurulumu tamamlayınca SourceBase’e geri döneceksin. '
                    'Döndüğünde profilini yeniden kontrol edeceğim.',
                    textAlign: TextAlign.center,
                    style: SBTypography.bodyMedium.copyWith(
                      color: SBColors.softText,
                    ),
                  ),
                  if (message != null) ...[
                    const SizedBox(height: SBSpacing.md),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: SBTypography.bodySmall.copyWith(color: SBColors.red),
                    ),
                  ],
                  const SizedBox(height: SBSpacing.lg),
                  SBButton(
                    _isOpening ? 'Açılıyor' : 'Kurulumu aç',
                    icon: 'arrow.up.right.square',
                    variant: SBButtonVariant.primary,
                    size: SBButtonSize.large,
                    fullWidth: true,
                    isLoading: _isOpening,
                    onPressed: () => _openSetup(force: true),
                  ),
                  const SizedBox(height: SBSpacing.sm),
                  SBButton(
                    'Tamamladım, kontrol et',
                    icon: 'arrow.clockwise',
                    variant: SBButtonVariant.secondary,
                    size: SBButtonSize.large,
                    fullWidth: true,
                    isLoading: session.ecosystemChecking,
                    onPressed: () => context
                        .read<SessionStore>()
                        .refreshEcosystemSetup(),
                  ),
                  const SizedBox(height: SBSpacing.sm),
                  SBButton(
                    'Oturumu kapat',
                    variant: SBButtonVariant.text,
                    onPressed: () => context.read<SessionStore>().signOut(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
