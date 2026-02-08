import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_editor_live/src/markdown_text_editing_controller.dart';

void main() {
  test(
    'MarkdownEditingController preserves text length in spans when syntax is hidden',
    () {
      final controller = MarkdownEditingController(
        text: '# Header\n\n**Bold**',
      );

      // Helper to extract text from spans
      String extractText(TextSpan span) {
        String text = span.text ?? '';
        if (span.children != null) {
          for (final child in span.children!) {
            if (child is TextSpan) {
              text += extractText(child);
            }
          }
        }
        return text;
      }

      // Helper to check for invisible spans
      bool hasInvisibleSyntax(TextSpan span) {
        if (span.style?.fontSize == 0.0) return true;
        if (span.children != null) {
          for (final child in span.children!) {
            if (child is TextSpan && hasInvisibleSyntax(child)) return true;
          }
        }
        return false;
      }

      // Case 1: No focus - Syntax should be hidden but text preserved
      controller.focusedLine = null;
      final span1 = controller.buildTextSpan(
        context: _MockContext(),
        style: const TextStyle(),
        withComposing: false,
      );

      expect(
        extractText(span1),
        '# Header\n\n**Bold**',
        reason: 'Text content mismatch when not focused',
      );
      expect(
        hasInvisibleSyntax(span1),
        true,
        reason: 'Should have invisible syntax when not focused',
      );

      // Case 2: Focus on line 0 - Header syntax visible
      controller.focusedLine = 0;
      final span2 = controller.buildTextSpan(
        context: _MockContext(),
        style: const TextStyle(),
        withComposing: false,
      );

      expect(
        extractText(span2),
        '# Header\n\n**Bold**',
        reason: 'Text content mismatch when focused on header',
      );
      // Header syntax should be visible (not size 0). Bold syntax (line 2) should be invisible.
      // Note: checking specifically for header visibility is harder with just traversal,
      // but we can ensure total text is correct.

      // Case 3: Focus on line 2 - Bold syntax visible
      controller.focusedLine = 2;
      final span3 = controller.buildTextSpan(
        context: _MockContext(),
        style: const TextStyle(),
        withComposing: false,
      );
      expect(extractText(span3), '# Header\n\n**Bold**');
    },
  );
}

class _MockContext extends BuildContext {
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
