import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_editor_live/src/markdown_text_editing_controller.dart';

void main() {
  testWidgets('Image span structure verification', (WidgetTester tester) async {
    final controller = MarkdownEditingController();
    controller.text = '![alt](http://img.com)';

    // We are focused on line 5, so line 0 (image) should be rendered as image widget
    controller.focusedLine = 5;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            // Trigger buildTextSpan manually to inspect it
            final span = controller.buildTextSpan(
              context: context,
              style: const TextStyle(fontSize: 10.0), // base font size
              withComposing: false,
            );

            final children = span.children!;
            expect(children.length, greaterThanOrEqualTo(3));

            // 1. Verify split text structure for cursor fix
            // Index 0: "!" (hidden)
            expect(children[0], isA<TextSpan>());
            final firstSpan = children[0] as TextSpan;
            expect(firstSpan.text, '!');
            expect(
              firstSpan.style?.fontSize,
              0.0,
              reason: 'First char should be hidden',
            );

            // Index 1: WidgetSpan (The Image)
            expect(children[1], isA<WidgetSpan>());
            final widgetSpan = children[1] as WidgetSpan;

            // Index 2: "[" (hidden)
            expect(children[2], isA<TextSpan>());
            final thirdSpan = children[2] as TextSpan;
            expect(thirdSpan.text, '[');
            expect(
              thirdSpan.style?.fontSize,
              0.0,
              reason: 'Third char should be hidden',
            );

            // Verify WidgetSpan properties (from previous test)

            // 1. Verify alignment is middle (to fix overlap issues)
            expect(
              widgetSpan.alignment,
              PlaceholderAlignment.middle,
              reason: 'Alignment should be middle',
            );

            // 2. Verify structure: GestureDetector -> Padding -> SizedBox -> Image
            expect(widgetSpan.child, isA<GestureDetector>());
            final gestureDetector = widgetSpan.child as GestureDetector;

            expect(gestureDetector.child, isA<Padding>());
            final padding = gestureDetector.child as Padding;
            expect(
              padding.padding,
              const EdgeInsets.symmetric(horizontal: 4.0),
            );

            expect(padding.child, isA<SizedBox>());
            final sizedBox = padding.child as SizedBox;

            // 3. Verify sizing: fixed height, unconstrained width
            // Target height calculation: fontSize (10) * 1.4 * 5 = 14 * 5 = 70.
            expect(
              sizedBox.height,
              closeTo(70.0, 0.01),
              reason: 'Height should be fixed to 5 lines',
            );
            expect(
              sizedBox.width,
              isNull,
              reason: 'Width should be unconstrained to respect aspect ratio',
            );

            // 4. Verify Image fit
            expect(sizedBox.child, isA<Image>());
            final image = sizedBox.child as Image;
            expect(image.fit, BoxFit.contain, reason: 'Fit should be contain');

            return const SizedBox();
          },
        ),
      ),
    );
  });
}
