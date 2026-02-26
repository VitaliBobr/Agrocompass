import 'package:flutter_test/flutter_test.dart';
import 'package:agrokilar_compass/main.dart';

void main() {
  testWidgets('App starts with main screen', (WidgetTester tester) async {
    await tester.pumpWidget(const AgrokilarCompassApp());
    expect(find.text('Новая линия'), findsOneWidget);
  });
}
