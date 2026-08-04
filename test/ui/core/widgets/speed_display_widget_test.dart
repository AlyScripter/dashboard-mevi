import 'package:dashboardmevi/ui/core/widgets/dashboard/speed_display_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../ui_test_utils.dart';

void main() {
  setUpAll(() async {
    await ensureUiTestSetup();
  });

  testWidgets('SpeedDisplayWidget renders fallback speed', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: SpeedDisplayWidget())),
      ),
    );

    expect(find.text('20'), findsOneWidget);
    expect(find.text('Km/h'), findsOneWidget);
  });
}
