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

/// Port of RegisterView.
class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  static const _universities = [
    'Erciyes Üniversitesi',
    'İstanbul Üniversitesi-Cerrahpaşa',
    'Ankara Üniversitesi',
    'Ege Üniversitesi',
    'Hacettepe Üniversitesi',
    'Diğer',
  ];

  static const _faculties = [
    'Tıp Fakültesi',
    'Diş Hekimliği',
    'Veteriner Fakültesi',
    'Hemşirelik',
    'Ebelik',
    'Sağlık Bilimleri',
  ];

  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _university;
  String? _faculty;
  String? _localError;

  String? get _validationError {
    if (_firstName.text.trim().isEmpty) {
      return 'Ad bilgisini doldurmalısın.';
    }
    if (_lastName.text.trim().isEmpty) {
      return 'Soyad bilgisini doldurmalısın.';
    }
    if (_university == null) {
      return 'Üniversite seçmelisin.';
    }
    if (_faculty == null) {
      return 'Fakülte veya alan seçmelisin.';
    }
    if (_email.text.isEmpty) return 'E-posta adresini girmelisin.';
    if (!_email.text.contains('@') || !_email.text.contains('.')) {
      return 'Geçerli bir e-posta adresi gir.';
    }
    if (_password.text.length < 8) return 'Şifre en az 8 karakter olmalı.';
    if (!_password.text.contains(RegExp(r'[A-Za-z]')) ||
        !_password.text.contains(RegExp(r'[0-9]'))) {
      return 'Şifre en az bir harf ve bir rakam içermeli.';
    }
    return null;
  }

  bool get _canSubmit =>
      _validationError == null && !context.read<SessionStore>().isLoading;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    final session = context.read<SessionStore>();
    final router = context.read<AppRouter>();
    if (session.isLoading) return;

    final error = _validationError;
    if (error != null) {
      setState(() => _localError = error);
      return;
    }

    setState(() => _localError = null);
    session.clearMessages();
    final cleanEmail = _email.text.trim();
    await session.signUp(
      fullName: '${_firstName.text.trim()} ${_lastName.text.trim()}'.trim(),
      email: cleanEmail,
      password: _password.text,
      university: _university,
      faculty: _faculty,
    );
    if (!mounted) return;
    if (session.successMessage?.contains('Doğrulama') == true) {
      router.replace(AppRoute.verifyEmail(email: cleanEmail));
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionStore>();
    final router = context.read<AppRouter>();

    return CommonAuthScaffold(
      title: 'Hesap oluştur',
      subtitle: 'MedAsi ekosistemine SourceBase ile katıl.',
      icon: 'person.badge.plus.fill',
      maxFormWidth: 520,
      footer: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        runSpacing: 4,
        children: [
          Text(
            'Zaten hesabın var mı?',
            style: SBTypography.bodyMedium.copyWith(color: SBColors.muted),
          ),
          GestureDetector(
            onTap: () => router.pop(),
            child: Text(
              'Giriş yap',
              style: SBTypography.labelMedium.copyWith(color: SBColors.blue),
            ),
          ),
        ],
      ),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final stackNameFields = constraints.maxWidth < 330;
              final firstNameField = AuthFieldContainer(
                icon: 'person',
                hint: 'Ad',
                controller: _firstName,
                onChanged: (_) => setState(() {}),
              );
              final lastNameField = AuthFieldContainer(
                icon: 'person',
                hint: 'Soyad',
                controller: _lastName,
                onChanged: (_) => setState(() {}),
              );

              if (stackNameFields) {
                return Column(
                  children: [
                    firstNameField,
                    const SizedBox(height: SBSpacing.md),
                    lastNameField,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: firstNameField),
                  const SizedBox(width: SBSpacing.md),
                  Expanded(child: lastNameField),
                ],
              );
            },
          ),
          const SizedBox(height: SBSpacing.md),
          AuthSelectField(
            icon: 'building.columns',
            hint: 'Üniversite',
            value: _university,
            items: _universities,
            onChanged: (value) => setState(() => _university = value),
          ),
          const SizedBox(height: SBSpacing.md),
          AuthSelectField(
            icon: 'graduationcap',
            hint: 'Fakülte / Alan',
            value: _faculty,
            items: _faculties,
            onChanged: (value) => setState(() => _faculty = value),
          ),
          const SizedBox(height: SBSpacing.md),
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
            onSubmit: _signUp,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: SBSpacing.sm),
          AuthPasswordStrength(password: _password.text),
          const SizedBox(height: SBSpacing.lg),
          Text(
            'Devam ederek Kullanım Koşulları ve Gizlilik Politikası’nı kabul edersin.',
            textAlign: TextAlign.center,
            style: SBTypography.caption.copyWith(color: SBColors.softText),
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
            'Kayıt ol',
            icon: 'person.badge.plus',
            variant: SBButtonVariant.primary,
            size: SBButtonSize.large,
            isLoading: session.isLoading,
            isDisabled: !_canSubmit,
            fullWidth: true,
            onPressed: _signUp,
          ),
        ],
      ),
    );
  }
}

/// Close-button row reused by modal-style auth screens.
class AuthCloseButton extends StatelessWidget {
  const AuthCloseButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: SBIcon('xmark', size: 17, color: SBColors.muted),
          ),
        ),
      ),
    );
  }
}
