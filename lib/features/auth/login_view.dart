import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_router.dart';
import '../../core/session_store.dart';
import '../../design_system/sb_button.dart';
import '../../design_system/sb_colors.dart';
import '../../design_system/sb_error_state.dart';
import '../../design_system/sb_spacing.dart';
import '../../design_system/sb_typography.dart';
import 'auth_components.dart';

/// Port of LoginView.
class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool get _canSubmit {
    final session = context.read<SessionStore>();
    return _email.text.trim().isNotEmpty &&
        _password.text.isNotEmpty &&
        !session.isLoading;
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_canSubmit) return;
    FocusScope.of(context).unfocus();
    final session = context.read<SessionStore>();
    final router = context.read<AppRouter>();
    session.clearMessages();
    final cleanEmail = _email.text.trim();
    final didSignIn = await session.signIn(
      email: cleanEmail,
      password: _password.text,
    );
    if (!mounted) return;
    if (didSignIn) {
      if (session.needsEmailVerification) {
        router.replace(
          AppRoute.verifyEmail(
            email: session.email.isEmpty ? cleanEmail : session.email,
          ),
        );
      } else {
        // Clear the nav stack; RootView shows the ecosystem onboarding gate
        // (central setup) when the shared profile is missing, else the app.
        router.reset(AppRoute.drive);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionStore>();
    final router = context.read<AppRouter>();

    return CommonAuthScaffold(
      title: 'SourceBase’e giriş yap',
      subtitle: 'Kaynaklarını çalışma sistemine dönüştürmeye devam et.',
      icon: 'books.vertical.fill',
      footer: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 5,
        runSpacing: 4,
        children: [
          Text(
            'Hesabın yok mu?',
            style: SBTypography.bodyMedium.copyWith(color: SBColors.muted),
          ),
          GestureDetector(
            onTap: session.isLoading
                ? null
                : () => router.navigate(AppRoute.register),
            child: Text(
              'Kayıt ol',
              style: SBTypography.labelMedium.copyWith(color: SBColors.blue),
            ),
          ),
        ],
      ),
      child: Column(
        children: [
          AuthFieldContainer(
            icon: 'envelope',
            hint: 'E-posta',
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: SBSpacing.md),
          AuthFieldContainer(
            icon: 'lock',
            hint: 'Şifre',
            controller: _password,
            isSecure: true,
            textInputAction: TextInputAction.go,
            onSubmit: _signIn,
            onChanged: (_) => setState(() {}),
          ),
          if (session.errorMessage != null) ...[
            const SizedBox(height: SBSpacing.lg),
            SBInlineError(message: session.errorMessage!),
          ],
          if (session.successMessage != null) ...[
            const SizedBox(height: SBSpacing.lg),
            AuthSuccessMessage(message: session.successMessage!),
          ],
          const SizedBox(height: SBSpacing.lg),
          SBButton(
            'Giriş yap',
            icon: 'arrow.right',
            variant: SBButtonVariant.primary,
            size: SBButtonSize.large,
            isLoading: session.isLoading,
            isDisabled: !_canSubmit,
            fullWidth: true,
            onPressed: _signIn,
          ),
          const SizedBox(height: SBSpacing.md),
          TextButton(
            onPressed: session.isLoading
                ? null
                : () => router.navigate(AppRoute.forgotPassword),
            child: Text(
              'Şifremi unuttum',
              style: SBTypography.labelMedium.copyWith(color: SBColors.blue),
            ),
          ),
          const SizedBox(height: SBSpacing.lg),
          Text(
            'Sağlık bilimleri için kişiselleştirilmiş çalışma',
            textAlign: TextAlign.center,
            style: SBTypography.caption.copyWith(color: SBColors.softText),
          ),
          const SizedBox(height: SBSpacing.md),
          const AuthDisciplineChips(),
        ],
      ),
    );
  }
}
