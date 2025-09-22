import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weefizz/screens/new_project_screen.dart';

void main() {
  testWidgets('NewProjectScreen builds and shows title', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: NewProjectScreen()));
    expect(find.text('Nouveau projet'), findsOneWidget);
  });
}
