import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('smoke placeholder', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('LDP'))));
    expect(find.text('LDP'), findsOneWidget);
  });
}
