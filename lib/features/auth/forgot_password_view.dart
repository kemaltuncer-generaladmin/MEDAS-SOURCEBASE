import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_router.dart';
import '../../core/session_store.dart';
import '../../design_system/sb_button.dart';
import '../../design_system/sb_colors.dart';
import '../../design_system/sb_error_state.dart';
import '../../design_system/sb_icons.dart';
import '../../design_system/sb_spacing.dart';
import '../../design_system/sb_typography.dart';
import 'auth_components.dart';

/// Port of ForgotPasswordView.
class ForgotPasswordView extends StatefulWidget {
  const ForgotPasswordView({super.key});

  @override
  State<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<ForgotPasswordView> {
  final _email = TextEditingController();
  String? _localError;

  bool get _canSubmit =>
      _email.text.isNotEmpty &&
      _email.text.contains('@') &&
      !context.read<SessionStore>().isLoading;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _sendReset() async {
    if (!_canSubmit) return;
    final session = context.read<SessionStore>();

    if (!_email.text.contains('@') || !_email.text.contains('.')) {
      setState(() => _localError = 'Geçerli bir e-posta adresi gir.');
      return;
    }

    setState(() => _localError = null);
    session.clearMessages();
    await session.sendPasswordReset(email: _email.text);
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionStore>();
    final router = context.read<AppRouter>();

    return CommonAuthScaffold(
      title: 'Şifreni yenile',
      subtitle: 'Kayıtlı e-posta adresine güvenli sıfırlama bağlantısı gönder.',
      icon: 'key.fill',
      showCallout: false,
      leading: TextButton.icon(
        onPressed: session.isLoading ? null : () => router.pop(),
        icon: SBIcon('chevron.left', size: 16, color: SBColors.blue),
        label: Text(
          'Geri dön',
          style: SBTypography.labelMedium.copyWith(color: SBColors.blue),
        ),
      ),
      child: Column(
        children: [
          AuthFieldContainer(
            icon: 'envelope',
            hint: 'E-posta',
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            onSubmit: _sendReset,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: SBSpacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(SBSpacing.md),
            decoration: BoxDecoration(
              color: SBColors.selectedBlue,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: SBColors.softLine),
            ),
            child: Row(
              children: [
                SBIcon('info.circle', size: 18, color: SBColors.blue),
                const SizedBox(width: SBSpacing.md),
                Expanded(
                  child: Text(
                    'Bağlantı yalnızca kayıtlı e-posta adresine gönderilir.',
                    style: SBTypography.bodySmall.copyWith(
                      color: SBColors.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_localError != null || session.errorMessage != null) ...[
            const SizedBox(height: SBSpacing.lg),
            SBInlineError(message: _localError ?? session.errorMessage!),
          ],
          if (session.successMessage != null) ...[
            const SizedBox(height: SBSpacing.lg),
            AuthSuccessMessage(message: session.successMessage!),
          ],
          const SizedBox(height: SBSpacing.lg),
          SBButton(
            session.isLoading
                ? 'Gönderiliyor...'
                : 'Sıfırlama bağlantısı gönder',
            icon: 'paperplane',
            variant: SBButtonVariant.primary,
            size: SBButtonSize.large,
            isLoading: session.isLoading,
            isDisabled: !_canSubmit,
            fullWidth: true,
            onPressed: _sendReset,
          ),
          const SizedBox(height: SBSpacing.md),
          SBButton(
            'Giriş ekranına dön',
            variant: SBButtonVariant.secondary,
            size: SBButtonSize.medium,
            isDisabled: session.isLoading,
            fullWidth: true,
            onPressed: () => router.popToRoot(),
          ),
        ],
      ),
    );
  }
}
