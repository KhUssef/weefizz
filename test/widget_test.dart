// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:weefizz/main.dart';

void main() {
  testWidgets('App renders login screen by default', (tester) async {
    // Build app
    await tester.pumpWidget(const MyApp());

    // AuthWrapper should show LoginPage when not connected
    expect(find.text('Connectez-vous à votre compte'), findsOneWidget);
    expect(find.text('Connexion'), findsOneWidget);
  });
}
