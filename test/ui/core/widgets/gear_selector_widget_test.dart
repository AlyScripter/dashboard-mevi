import 'package:dashboardmevi/ui/core/widgets/dashboard/gear_selector_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../ui_test_utils.dart';

void main() {
  setUpAll(() async {
    await ensureUiTestSetup();
  });

  testWidgets('GearSelectorWidget renders all default gears', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GearSelectorWidget(selectedGear: 'P', onGearChanged: (_) {}),
        ),
      ),
    );

    for (final gear in const ['P', 'N', 'R', 'D']) {
      expect(find.text(gear), findsOneWidget);
    }
  });

  testWidgets('GearSelectorWidget notifies gear changes on tap', (
    tester,
  ) async {
    var tappedGear = '';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GearSelectorWidget(
            selectedGear: 'P',
            onGearChanged: (gear) => tappedGear = gear,
          ),
        ),
      ),
    );

    await tester.tap(find.text('D'));
    await tester.pumpAndSettle();

    expect(tappedGear, 'D');
  });
}
