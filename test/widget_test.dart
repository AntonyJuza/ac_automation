import 'package:flutter_test/flutter_test.dart';
import 'package:ac_automation/app.dart';

void main() {
  testWidgets('Home screen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ACAutomationApp());

    // Verify that our app bar title is shown.
    expect(find.text('My Devices'), findsOneWidget);
    expect(find.text('Living Room'), findsOneWidget);
  });
}
