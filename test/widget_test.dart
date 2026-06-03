import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oneshot/main.dart';

void main() {
  testWidgets('renders the OneShot home screen', (tester) async {
    SharedPreferences.setMockInitialValues({});

    // Tall surface so the whole ListView builds (its children are lazy).
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const OneShotApp());
    // Auto-setup spins an indeterminate progress indicator, so a settle never
    // completes; pump a fixed slice to let settings load and the first frame paint.
    await tester.pump(const Duration(milliseconds: 500));

    // App bar title and the key controls are present.
    expect(find.text('OneShot'), findsOneWidget);
    expect(find.text('Check'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('Stop'), findsOneWidget);
  });
}
