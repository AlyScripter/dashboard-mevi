import 'package:dashboardmevi/ui/core/panels/left_panel.dart';
import 'package:dashboardmevi/ui/core/widgets/dashboard/battery_indicator_widget.dart';
import 'package:dashboardmevi/ui/core/panels/status_indicator_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../ui_test_utils.dart';

void main() {
  setUpAll(() async {
    await ensureUiTestSetup();
  });

  testWidgets('LeftPanel renders key sub-widgets', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(height: 800, width: 420, child: LeftPanel()),
        ),
      ),
    );

    // Allow animations to complete with limited frames
    await tester.pump(const Duration(milliseconds: 500));

    // Just verify the widgets exist
    expect(find.byType(StatusIndicatorPanel), findsOneWidget);
    expect(find.byType(BatteryIndicatorWidget), findsOneWidget);
  });
}
