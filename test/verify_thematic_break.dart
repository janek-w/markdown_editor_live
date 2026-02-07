import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_markdown_editor_live/flutter_markdown_editor_live.dart';

// Helper to access private members or simulate behavior if needed.
// Since we are testing public API behavior (buildTextSpan), we can just use the controller.

void main() {
  group('Thematic Break Verification', () {
    testWidgets('Renders Divider when not focused', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final controller = MarkdownEditingController(text: '---');
                // No focus set initially.

                final span = controller.buildTextSpan(
                  context: context,
                  withComposing: false,
                );

                // Expect a WidgetSpan with a Divider
                bool hasDivider = false;
                span.visitChildren((child) {
                  if (child is WidgetSpan) {
                    final widget = child.child;
                    if (widget is Divider) {
                      hasDivider = true;
                      return false;
                    }
                    if (widget is SizedBox && widget.child is Divider) {
                      hasDivider = true;
                      return false;
                    }
                  }
                  return true;
                });

                expect(
                  hasDivider,
                  isTrue,
                  reason: 'Should contain a Divider WidgetSpan',
                );

                return Container();
              },
            ),
          ),
        ),
      );
    });

    testWidgets('Renders Text when focused', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final controller = MarkdownEditingController(text: '---');

                // Simulate focus on line 0
                controller.selection = const TextSelection.collapsed(offset: 0);
                controller.updateFocusedLineFromSelection();

                // Verify focus is set
                expect(controller.focusedLine, 0);

                final span = controller.buildTextSpan(
                  context: context,
                  withComposing: false,
                );

                // Expect NO Divider, but text '---'
                bool hasDivider = false;
                StringBuffer textContent = StringBuffer();

                span.visitChildren((child) {
                  if (child is WidgetSpan) {
                    final widget = child.child;
                    if (widget is Divider) hasDivider = true;
                    if (widget is SizedBox && widget.child is Divider)
                      hasDivider = true;
                  }
                  if (child is TextSpan) {
                    textContent.write(child.text);
                  }
                  return true; // continue visiting
                });

                expect(
                  hasDivider,
                  isFalse,
                  reason:
                      'Should NOT contain a Divider WidgetSpan when focused',
                );
                expect(textContent.toString(), contains('---'));

                return Container();
              },
            ),
          ),
        ),
      );
    });

    testWidgets('Handles various patterns', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final patterns = ['***', '___', '   ---', ' - - - '];

                for (final pattern in patterns) {
                  final controller = MarkdownEditingController(text: pattern);
                  // Unfocused
                  final span = controller.buildTextSpan(
                    context: context,
                    withComposing: false,
                  );

                  bool hasDivider = false;
                  span.visitChildren((child) {
                    if (child is WidgetSpan) {
                      final widget = child.child;
                      if (widget is Divider) {
                        hasDivider = true;
                        return false;
                      }
                      if (widget is SizedBox && widget.child is Divider) {
                        hasDivider = true;
                        return false;
                      }
                    }
                    return true;
                  });

                  expect(
                    hasDivider,
                    isTrue,
                    reason: 'Pattern "$pattern" should result in a Divider',
                  );
                }

                return Container();
              },
            ),
          ),
        ),
      );
    });

    testWidgets('Does not trigger on invalid patterns', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final patterns = ['--', '**', '__', 'text---', '---text'];

                for (final pattern in patterns) {
                  final controller = MarkdownEditingController(text: pattern);
                  final span = controller.buildTextSpan(
                    context: context,
                    withComposing: false,
                  );

                  bool hasDivider = false;
                  span.visitChildren((child) {
                    if (child is WidgetSpan) {
                      final widget = child.child;
                      if (widget is Divider) {
                        hasDivider = true;
                        return false;
                      }
                      if (widget is SizedBox && widget.child is Divider) {
                        hasDivider = true;
                        return false;
                      }
                    }
                    return true;
                  });

                  expect(
                    hasDivider,
                    isFalse,
                    reason: 'Pattern "$pattern" should NOT result in a Divider',
                  );
                }

                return Container();
              },
            ),
          ),
        ),
      );
    });
  });
}
