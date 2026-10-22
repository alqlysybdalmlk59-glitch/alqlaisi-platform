import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alqlaisi_customer/app.dart';

const MethodChannel secureStorageChannel =
    MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async {
      switch (call.method) {
        case 'read':
          return null;
        case 'readAll':
          return <String, String>{};
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
  });

  testWidgets('Arabic customer login screen initializes with localizations',
      (WidgetTester tester) async {
    await tester.pumpWidget(const AlQulaisiApp());
    await tester.pumpAndSettle();

    expect(find.text('مرحبًا بك في منصة القليسي'), findsOneWidget);
    expect(find.text('متابعة باستخدام Google'), findsOneWidget);
    final loginContext = tester.element(find.text('مرحبًا بك في منصة القليسي'));
    expect(Localizations.localeOf(loginContext), const Locale('ar'));
    expect(MaterialLocalizations.of(loginContext), isNotNull);
  });
  testWidgets('Google sign-in reports missing OAuth configuration clearly',
      (WidgetTester tester) async {
    await tester.pumpWidget(const AlQulaisiApp());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('متابعة باستخدام Google'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('متابعة باستخدام Google'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'تسجيل Google غير مهيأ. استخدم معرّف Web OAuth الحقيقي من Google Cloud في GOOGLE_SERVER_CLIENT_ID.',
      ),
      findsOneWidget,
    );
  });
}
