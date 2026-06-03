import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oneshot/main.dart';

void main() {
  testWidgets('renders the OneShot home screen', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const OneShotApp());
    await tester.pumpAndSettle(); // wait for settings to load

    // App bar title and the key controls are present.
    expect(find.text('OneShot'), findsOneWidget);
    expect(find.text('Check'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('Stop'), findsOneWidget);
  });
}
