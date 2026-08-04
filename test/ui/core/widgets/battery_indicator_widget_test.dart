import 'package:dashboardmevi/ui/core/widgets/dashboard/battery_indicator_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../ui_test_utils.dart';

void main() {
  setUpAll(() async {
    await ensureUiTestSetup();
  });

  testWidgets('BatteryIndicatorWidget shows formatted percentage', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BatteryIndicatorWidget(batteryPercent: 0.6, onTap: () {}),
        ),
      ),
    );

    expect(find.text('60%'), findsOneWidget);
  });

  testWidgets('BatteryIndicatorWidget triggers tap callback', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BatteryIndicatorWidget(
            batteryPercent: 0.4,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(BatteryIndicatorWidget));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
  });
}
