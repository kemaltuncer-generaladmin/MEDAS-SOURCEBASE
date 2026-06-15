import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sourcebase/core/app_router.dart';
import 'package:sourcebase/core/session_store.dart';
import 'package:sourcebase/features/auth/auth_components.dart';
import 'package:sourcebase/features/auth/forgot_password_view.dart';
import 'package:sourcebase/features/auth/login_view.dart';
import 'package:sourcebase/features/auth/register_view.dart';
import 'package:sourcebase/features/auth/reset_password_view.dart';
import 'package:sourcebase/features/auth/verify_email_view.dart';

Future<void> _pumpAuthSurface(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  AppRouter.shared.popToRoot();
  SessionStore.shared.clearMessages();

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: SessionStore.shared),
        ChangeNotifierProvider.value(value: AppRouter.shared),
      ],
      child: MaterialApp(home: child),
    ),
  );
  await tester.pump(const Duration(milliseconds: 120));

  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('SourceBase auth screen renders', (tester) async {
    await _pumpAuthSurface(tester, const LoginView());

    expect(find.text('SourceBase’e giriş yap'), findsOneWidget);
    expect(find.byType(EcosystemCallout), findsOneWidget);
    expect(find.text('Giriş yap'), findsOneWidget);
  });

  testWidgets('auth screens fit narrow mobile widths without overflow', (
    tester,
  ) async {
    const mobileSizes = [Size(320, 568), Size(360, 640), Size(390, 844)];

    for (final size in mobileSizes) {
      await _pumpAuthSurface(tester, const LoginView(), size: size);
      expect(find.text('SourceBase’e giriş yap'), findsOneWidget);

      await _pumpAuthSurface(tester, const RegisterView(), size: size);
      expect(find.text('Hesap oluştur'), findsOneWidget);

      await _pumpAuthSurface(
        tester,
        const VerifyEmailView(email: 'uzun.kullanici.adi@sourcebase.test'),
        size: size,
      );
      expect(find.text('E-postanı doğrula'), findsOneWidget);

      await _pumpAuthSurface(tester, const ForgotPasswordView(), size: size);
      expect(find.text('Şifreni yenile'), findsOneWidget);

      await _pumpAuthSurface(tester, const ResetPasswordView(), size: size);
      expect(find.text('Yeni şifreni belirle'), findsOneWidget);
    }
  });
}
