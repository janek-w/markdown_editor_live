import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_editor_live/markdown_editor_live.dart';

void main() {
  group('MarkdownEditingController', () {
    test('Initializes with text', () {
      final controller = MarkdownEditingController(text: 'Hello');
      expect(controller.text, 'Hello');
    });

    testWidgets('Builds TextSpan with styles', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final controller = MarkdownEditingController(
                  text: '# Header\n\n**Bold**',
                );
                final span = controller.buildTextSpan(
                  context: context,
                  withComposing: false,
                );

                // We expect a TextSpan with children
                expect(span, isA<TextSpan>());
                expect(span.children, isNotEmpty);

                // Check for Header style
                // The first child should match '# Header' with bold and larger font
                // Note: Our naive parser might return a list of spans where the text is split.
                // '# Header' should be one span if it matched the regex.

                // Let's print the structure to verify in logs if test fails
                // print(span.toPlainText());
                return Container();
              },
            ),
          ),
        ),
      );
    });

    testWidgets('Parses bold text correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final controller = MarkdownEditingController(
                  text: 'This is **bold** text',
                );
                final span = controller.buildTextSpan(
                  context: context,
                  withComposing: false,
                );

                // Based on our logic:
                // "This is " (default)
                // "**bold**" (bold)
                // " text" (default)

                expect(span.children?.length, 3);
                expect(span.children![0].toPlainText(), 'This is ');
                expect(span.children![1].toPlainText(), '**bold**');
                expect(span.children![1].style?.fontWeight, FontWeight.bold);
                expect(span.children![2].toPlainText(), ' text');

                return Container();
              },
            ),
          ),
        ),
      );
    });
  });
}
