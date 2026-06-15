import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_router.dart';
import '../../core/session_store.dart';
import '../../design_system/sb_button.dart';
import '../../design_system/sb_colors.dart';
import '../../design_system/sb_error_state.dart';
import '../../design_system/sb_spacing.dart';
import '../../design_system/sb_typography.dart';
import 'auth_components.dart';

/// Port of VerifyEmailView: 6-digit OTP entry with resend countdown.
class VerifyEmailView extends StatefulWidget {
  const VerifyEmailView({super.key, required this.email});

  final String email;

  @override
  State<VerifyEmailView> createState() => _VerifyEmailViewState();
}

class _VerifyEmailViewState extends State<VerifyEmailView> {
  static const _resendInterval = Duration(seconds: 120);

  final List<TextEditingController> _otp = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  late DateTime _deadline;
  int _remainingSeconds = 120;
  Timer? _timer;
  String? _localError;

  bool get _canVerify =>
      _otp.every((c) => c.text.isNotEmpty) &&
      !context.read<SessionStore>().isLoading;

  bool get _canResend =>
      _remainingSeconds == 0 && !context.read<SessionStore>().isLoading;

  String get _timerLabel {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    for (final node in _focusNodes) {
      node.addListener(() => setState(() {}));
    }
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _otp) {
      c.dispose();
    }
    for (final n in _focusNodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _deadline = DateTime.now().add(_resendInterval);
    _refreshRemaining();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _refreshRemaining();
      if (_remainingSeconds == 0) _timer?.cancel();
    });
  }

  void _refreshRemaining() {
    setState(() {
      _remainingSeconds = _deadline
          .difference(DateTime.now())
          .inSeconds
          .clamp(0, 999);
    });
  }

  Future<void> _verify() async {
    if (!_canVerify) return;
    final session = context.read<SessionStore>();
    final router = context.read<AppRouter>();

    final code = _otp.map((c) => c.text).join();
    if (code.length != 6) {
      setState(() => _localError = 'Lütfen 6 haneli doğrulama kodunu gir.');
      return;
    }

    setState(() => _localError = null);
    session.clearMessages();
    final didVerify = await session.verifyEmailOTP(
      email: widget.email,
      token: code,
    );
    if (didVerify && mounted) {
      // RootView shows the central ecosystem onboarding gate if the shared
      // profile is missing; otherwise the app.
      router.reset(AppRoute.drive);
    }
  }

  Future<void> _resendCode() async {
    if (!_canResend) return;
    final session = context.read<SessionStore>();
    setState(() => _localError = null);
    session.clearMessages();
    await session.resendVerificationEmail(email: widget.email);
    _startTimer();
  }

  void _distribute(String digits, int startIndex) {
    var cursor = startIndex;
    for (final char in digits.split('')) {
      if (cursor >= 6) break;
      _otp[cursor].text = char;
      cursor += 1;
    }
    _focusNodes[cursor.clamp(0, 5)].requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionStore>();
    final router = context.read<AppRouter>();
    final compact = MediaQuery.of(context).size.width <= 360;
    final otpGap = compact ? 4.0 : SBSpacing.sm;

    return CommonAuthScaffold(
      title: 'E-postanı doğrula',
      subtitle: '6 haneli kodu girerek SourceBase hesabını güvenli hale getir.',
      icon: 'checkmark.shield.fill',
      showCallout: false,
      maxFormWidth: 500,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: SBSpacing.lg,
              vertical: SBSpacing.md,
            ),
            decoration: BoxDecoration(
              color: SBColors.selectedBlue,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: SBColors.softLine),
            ),
            child: Text(
              widget.email,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: SBTypography.titleMedium.copyWith(color: SBColors.navy),
            ),
          ),
          const SizedBox(height: SBSpacing.lg),
          LayoutBuilder(
            builder: (context, constraints) {
              final fieldWidth = (constraints.maxWidth - otpGap * 5) / 6;
              return Row(
                children: [
                  for (var i = 0; i < 6; i++) ...[
                    if (i > 0) SizedBox(width: otpGap),
                    SizedBox(width: fieldWidth, child: _otpField(i)),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: SBSpacing.lg),
          _resendSection(session),
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
            session.isLoading ? 'Doğrulanıyor...' : 'Doğrula',
            icon: 'checkmark.shield',
            variant: SBButtonVariant.primary,
            size: SBButtonSize.large,
            isLoading: session.isLoading,
            isDisabled: !_canVerify,
            fullWidth: true,
            onPressed: _verify,
          ),
          const SizedBox(height: SBSpacing.md),
          TextButton(
            onPressed: () => router.replace(AppRoute.register),
            child: Text(
              'E-postayı değiştir',
              style: SBTypography.labelMedium.copyWith(color: SBColors.blue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _otpField(int index) {
    final isFocused = _focusNodes[index].hasFocus;
    final compact = MediaQuery.of(context).size.width <= 360;

    return AnimatedScale(
      scale: isFocused && !compact ? 1.05 : 1,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      child: Container(
        height: compact ? 50 : 56,
        decoration: BoxDecoration(
          color: SBColors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(compact ? 12 : 14),
          border: Border.all(
            color: isFocused ? SBColors.blue : SBColors.line,
            width: isFocused ? 2 : 1,
          ),
          boxShadow: isFocused
              ? [
                  BoxShadow(
                    color: SBColors.blue.withValues(alpha: 0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: TextField(
            controller: _otp[index],
            focusNode: _focusNodes[index],
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: SBTypography.scaled(
              compact ? 22 : 24,
              weight: FontWeight.bold,
            ).copyWith(color: SBColors.blue),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isCollapsed: true,
              counterText: '',
            ),
            onChanged: (value) {
              if (value.length > 1) {
                _otp[index].text = value[0];
                _distribute(value, index);
              } else if (value.isNotEmpty && index < 5) {
                _focusNodes[index + 1].requestFocus();
              }
              setState(() {});
            },
          ),
        ),
      ),
    );
  }

  Widget _resendSection(SessionStore session) {
    final compact = MediaQuery.of(context).size.width <= 360;
    final action = GestureDetector(
      onTap: _canResend ? _resendCode : null,
      child: Text(
        session.isLoading ? 'Gönderiliyor...' : 'Tekrar gönder',
        style: SBTypography.labelMedium.copyWith(
          color: _canResend ? SBColors.blue : SBColors.muted,
        ),
      ),
    );
    final timer = Text(
      _timerLabel,
      style: SBTypography.labelMedium.copyWith(
        color: _canResend ? SBColors.blue : SBColors.muted,
      ),
    );

    return Container(
      padding: EdgeInsets.all(compact ? SBSpacing.sm : SBSpacing.md),
      decoration: BoxDecoration(
        color: SBColors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SBColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (compact)
            Text(
              'Kod gelmedi mi?',
              style: SBTypography.bodyMedium.copyWith(color: SBColors.muted),
            ),
          if (compact) const SizedBox(height: SBSpacing.sm),
          if (compact)
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: SBSpacing.sm,
              runSpacing: SBSpacing.xs,
              children: [
                action,
                SizedBox(
                  height: 20,
                  child: VerticalDivider(width: 1, color: SBColors.line),
                ),
                timer,
              ],
            )
          else
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: SBSpacing.sm,
              children: [
                Text(
                  'Kod gelmedi mi?',
                  style: SBTypography.bodyMedium.copyWith(
                    color: SBColors.muted,
                  ),
                ),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: SBSpacing.sm,
                  children: [
                    action,
                    SizedBox(
                      height: 20,
                      child: VerticalDivider(width: 1, color: SBColors.line),
                    ),
                    timer,
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }
}
