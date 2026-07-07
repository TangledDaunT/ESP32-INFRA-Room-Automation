import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:openclaw_remote/theme.dart';
import 'package:openclaw_remote/widgets/brightness_slider.dart';

void main() {
  testWidgets('brightness slider shows percentage value', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: SizedBox(
            height: 320,
            width: 80,
            child: BrightnessSlider(
              icon: Symbols.light_group,
              value: 128,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    // Percentage display: 128/255 = 50%
    expect(find.text('50'), findsOneWidget);
  });
}
