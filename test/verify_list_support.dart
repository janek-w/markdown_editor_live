import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_editor_live/src/markdown_text_editing_controller.dart';

void main() {
  testWidgets('List rendering verification', (WidgetTester tester) async {
    final controller = MarkdownEditingController();

    // Setup text with list and inline style
    // "* **Bold**"
    controller.text = '* **Bold**';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              // 1. Not focused (should see bullet and bold text)
              final span = controller.buildTextSpan(
                context: context,
                withComposing: false,
              );

              print('--- Spans for "* **Bold**" (Unfocused) ---');
              int spanCount = 0;
              span.visitChildren((child) {
                if (child is TextSpan) {
                  print(
                    'Span ${spanCount++}: "${child.text}", Style: ${child.style}',
                  );
                }
                return true;
              });

              // 2. Focused (should see "* " and bold text)
              controller.selection = const TextSelection.collapsed(offset: 0);
              controller.updateFocusedLineFromSelection();

              final spanFocused = controller.buildTextSpan(
                context: context,
                withComposing: false,
              );

              print('\n--- Spans for "* **Bold**" (Focused) ---');
              spanCount = 0;
              spanFocused.visitChildren((child) {
                if (child is TextSpan) {
                  print(
                    'Span ${spanCount++}: "${child.text}", Style: ${child.style}',
                  );
                }
                return true;
              });

              return Container();
            },
          ),
        ),
      ),
    );
  });
}
