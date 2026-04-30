import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:openclaw_remote/theme.dart';
import 'package:openclaw_remote/widgets/brightness_slider.dart';

void main() {
  testWidgets('brightness slider shows its label and percentage', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: SizedBox(
            height: 320,
            child: BrightnessSlider(
              label: 'RGB STRIP',
              value: 128,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('RGB STRIP'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
  });
}
