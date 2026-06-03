import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oneshot/main.dart';

void main() {
  testWidgets('renders the OneShot home screen', (tester) async {
    await tester.pumpWidget(const OneShotApp());

    // App bar title and the key controls are present.
    expect(find.text('OneShot'), findsOneWidget);
    expect(find.text('Check'), findsOneWidget);
    expect(find.text('Install'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
  });
}
