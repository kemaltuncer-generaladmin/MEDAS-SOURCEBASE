import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_router.dart';
import '../../core/session_store.dart';
import '../../design_system/sb_button.dart';
import '../../design_system/sb_error_state.dart';
import '../../design_system/sb_spacing.dart';
import 'auth_components.dart';

/// Port of ResetPasswordView.
class ResetPasswordView extends StatefulWidget {
  const ResetPasswordView({super.key});

  @override
  State<ResetPasswordView> createState() => _ResetPasswordViewState();
}

class _ResetPasswordViewState extends State<ResetPasswordView> {
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  String? _localError;

  bool get _canSubmit =>
      _password.text.length >= 8 &&
      _password.text == _confirmation.text &&
      !context.read<SessionStore>().isLoading;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    final session = context.read<SessionStore>();
    final router = context.read<AppRouter>();
    if (session.isLoading) return;

    if (_password.text.length < 8) {
      setState(() => _localError = 'Şifre en az 8 karakter olmalı.');
      return;
    }
    if (_password.text != _confirmation.text) {
      setState(() => _localError = 'Şifreler eşleşmiyor.');
      return;
    }

    setState(() => _localError = null);
    session.clearMessages();
    final ok = await session.updatePassword(_password.text);
    if (ok && mounted) {
      router.reset(AppRoute.drive);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionStore>();

    return CommonAuthScaffold(
      title: 'Yeni şifreni belirle',
      subtitle: 'Hesabın için en az 8 karakterli yeni bir şifre oluştur.',
      icon: 'key.horizontal.fill',
      showCallout: false,
      child: Column(
        children: [
          AuthFieldContainer(
            icon: 'lock',
            hint: 'Yeni şifre',
            controller: _password,
            isSecure: true,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: SBSpacing.sm),
          AuthPasswordStrength(password: _password.text),
          const SizedBox(height: SBSpacing.md),
          AuthFieldContainer(
            icon: 'lock.rotation',
            hint: 'Yeni şifre tekrar',
            controller: _confirmation,
            isSecure: true,
            onSubmit: _updatePassword,
            onChanged: (_) => setState(() {}),
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
            'Şifreyi güncelle',
            icon: 'checkmark',
            variant: SBButtonVariant.primary,
            size: SBButtonSize.large,
            isLoading: session.isLoading,
            isDisabled: !_canSubmit,
            fullWidth: true,
            onPressed: _updatePassword,
          ),
        ],
      ),
    );
  }
}
