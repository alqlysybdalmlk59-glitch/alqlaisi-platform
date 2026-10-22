import 'package:flutter_test/flutter_test.dart';

import 'package:alqlaisi_customer/app.dart';

void main() {
  testWidgets('Alqulaisi Customer smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AlQulaisiApp());
    expect(find.byType(AlQulaisiApp), findsOneWidget);
  });
}
