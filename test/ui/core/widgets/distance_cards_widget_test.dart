import 'package:dashboardmevi/ui/core/widgets/dashboard/distance_cards_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../ui_test_utils.dart';

void main() {
  setUpAll(() async {
    await ensureUiTestSetup();
  });

  testWidgets('DistanceCardsWidget shows default ultrasonic distance', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: DistanceCardsWidget(batteryPercent: 0.5)),
      ),
    );

    expect(find.text('50 m'), findsOneWidget);
  });

  testWidgets('DistanceCardsWidget displays remaining range from battery', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: DistanceCardsWidget(batteryPercent: 0.7)),
      ),
    );

    expect(find.text('3.5 km'), findsOneWidget);
  });
}
