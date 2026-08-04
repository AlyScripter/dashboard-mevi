import 'package:dashboardmevi/ui/core/widgets/dashboard/weather_time_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../ui_test_utils.dart';

void main() {
  setUpAll(() async {
    await ensureUiTestSetup();
  });

  testWidgets(
    'WeatherTimeWidget renders time in H.mm format when weather hidden',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: WeatherTimeWidget(embedded: true, showWeather: false),
            ),
          ),
        ),
      );

      final texts = tester.widgetList<Text>(find.byType(Text));
      final hasClockDisplay = texts.any((text) {
        final value = text.data ?? '';
        return RegExp(r'^\d{1,2}\.\d{2}$').hasMatch(value);
      });

      expect(hasClockDisplay, isTrue);
    },
  );
}
