import 'package:dashboardmevi/ui/core/panels/status_indicator_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// import 'package:lucide_icons/lucide_icons.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../ui_test_utils.dart';

void main() {
  setUpAll(() async {
    await ensureUiTestSetup();
  });

  testWidgets('StatusIndicatorPanel triggers callbacks for toggles', (
    tester,
  ) async {
    var lampState = true;
    var engineState = true;
    var hazardState = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return StatusIndicatorPanel(
                indicatorLampOn: lampState,
                engineOn: engineState,
                hazardOn: hazardState,
                onLampToggle: (value) => setState(() => lampState = value),
                onEngineToggle: (value) => setState(() => engineState = value),
                onHazardToggle: (value) => setState(() => hazardState = value),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(LucideIcons.lightbulb));
    await tester.pumpAndSettle();
    expect(lampState, isFalse);

    await tester.tap(find.byIcon(LucideIcons.zap));
    await tester.pumpAndSettle();
    expect(engineState, isFalse);

    await tester.tap(find.byIcon(LucideIcons.triangleAlert));
    await tester.pumpAndSettle();
    expect(hazardState, isTrue);
  });
}
