# Tab Support Implementation Plan

## Overview
Add support for tab key input in the Flutter markdown editor, enabling users to:
1. Insert tab characters (or spaces for soft tabs) when pressing Tab
2. Create indented lists using tabs
3. Prevent the Tab key from moving focus away from the text field

## Current State Analysis

### Existing Code Structure
- **[`MarkdownEditor`](lib/src/markdown_editor.dart:4)** widget: A `StatefulWidget` that wraps a `TextField`
- **[`MarkdownEditingController`](lib/src/markdown_text_editing_controller.dart:3)**: Custom `TextEditingController` that provides markdown syntax highlighting
- **List patterns**: Regex patterns already support leading spaces/tabs (`[ \\t]*`)

### Current Issues
1. Pressing Tab causes focus to leave the text field (default Flutter behavior)
2. No way to insert tab characters for list indentation
3. The regex supports tabs in lists, but users can't input them

## Implementation Plan

### 1. Add Tab Key Handling to MarkdownEditor Widget

**File:** [`lib/src/markdown_editor.dart`](lib/src/markdown_editor.dart)

**Changes:**
- Add a `FocusNode` to capture keyboard events
- Wrap the `TextField` with a `Focus` widget or use `onKey` callback
- Intercept Tab key presses and insert tab character(s)
- Prevent default Tab behavior (focus change)

**Code Structure:**
```dart
class MarkdownEditor extends StatefulWidget {
  // Existing properties...
  final bool useSoftTabs;  // New: Use spaces instead of tab character
  final int tabWidth;      // New: Number of spaces for soft tabs (default: 2 or 4)

  const MarkdownEditor({
    // Existing parameters...
    this.useSoftTabs = true,
    this.tabWidth = 2,
  });
}

class _MarkdownEditorState extends State<MarkdownEditor> {
  late final MarkdownEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = MarkdownEditingController(text: widget.initialValue);
    _controller.addListener(_onSelectionChanged);
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.removeListener(_onSelectionChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.tab) {
      // Insert tab character or spaces
      _insertTab();
      return KeyEventResult.handled;  // Prevent default behavior
    }
    return KeyEventResult.ignored;
  }

  void _insertTab() {
    final text = _controller.value.text;
    final selection = _controller.value.selection;

    if (!selection.isValid) return;

    final tabString = widget.useSoftTabs ? ' ' * widget.tabWidth : '\t';

    if (selection.isCollapsed) {
      // Insert tab at cursor position
      final newText = text.substring(0, selection.baseOffset) + 
                      tabString + 
                      text.substring(selection.baseOffset);
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: selection.baseOffset + tabString.length
        ),
      );
    } else {
      // Indent selected lines
      _indentSelectedLines(tabString);
    }
  }

  void _indentSelectedLines(String tabString) {
    final text = _controller.value.text;
    final selection = _controller.value.selection;
    final (startLine, endLine) = _getSelectedLineRange(selection);

    // Get all lines in the selection
    final lines = text.split('\n');
    final newLines = <String>[];

    for (int i = startLine; i <= endLine; i++) {
      if (i < lines.length) {
        newLines.add(tabString + lines[i]);
      }
    }

    // Reconstruct text
    final before = lines.sublist(0, startLine).join('\n');
    final after = lines.sublist(endLine + 1).join('\n');
    final middle = newLines.join('\n');

    final separator = startLine > 0 ? '\n' : '';
    final separatorAfter = endLine < lines.length - 1 ? '\n' : '';

    _controller.value = TextEditingValue(
      text: '$before$separator$middle$separatorAfter$after',
      selection: selection,
    );
  }

  (int, int) _getSelectedLineRange(TextSelection selection) {
    // Implementation to get start and end line numbers from selection
    // ... (use existing _getLineNumber logic)
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        onChanged: widget.onChanged,
        style: widget.style,
        decoration: widget.decoration,
        maxLines: null,
        keyboardType: TextInputType.multiline,
      ),
    );
  }
}
```

### 2. Add Helper Methods to MarkdownEditingController (Optional)

**File:** [`lib/src/markdown_text_editing_controller.dart`](lib/src/markdown_text_editing_controller.dart)

**Optional Enhancement:**
- Add helper methods for getting line ranges from selection
- These can be moved to the controller for reusability

```dart
/// Returns the line numbers (start, end) for a given text selection
(int, int) getLineRangeFromSelection(TextSelection selection) {
  final startLine = _getLineNumber(selection.baseOffset);
  final endLine = _getLineNumber(selection.extentOffset);
  return (startLine, endLine);
}
```

### 3. Verify Tab Support in List Patterns

**File:** [`lib/src/markdown_text_editing_controller.dart`](lib/src/markdown_text_editing_controller.dart)

**Current State:**
- Unordered list pattern: `^([ \t]*)([*+-])([ \t]+)` (line 105)
- Ordered list pattern: `^([ \t]*)(\d+\.)([ \t]+)` (line 111)

**Action:**
- Verify these patterns correctly handle tab characters
- The `[ \t]*` pattern already matches both spaces and tabs
- No changes needed to regex patterns

### 4. Test Cases to Verify

After implementation, verify:
1. Pressing Tab inserts a tab character (or spaces) at cursor position
2. Pressing Tab does not move focus away from the editor
3. Tab can be used to indent list items:
   ```
   - Item 1
   \t- Nested item (using tab)
   ```
4. Selecting multiple lines and pressing Tab indents all selected lines
5. Shift+Tab (optional enhancement) could outdent selected lines

### 5. Optional Enhancements

Consider adding:
- **Shift+Tab support**: Outdent selected lines
- **Auto-indent on new line**: When pressing Enter in an indented list, maintain indentation
- **Tab width configuration**: Allow users to specify tab width (2, 4, or 8 spaces)
- **Smart tab**: Detect existing indentation and match it

## Implementation Order

1. Add `useSoftTabs` and `tabWidth` properties to `MarkdownEditor`
2. Add `FocusNode` and `_handleKeyEvent` method
3. Implement `_insertTab` for single cursor insertion
4. Implement `_indentSelectedLines` for multi-line selection
5. Update the `build` method to wrap `TextField` with `Focus`
6. Test with the example app
7. Optional: Add Shift+Tab outdent support

## Files to Modify

1. **[`lib/src/markdown_editor.dart`](lib/src/markdown_editor.dart)** - Main implementation
2. **[`lib/src/markdown_text_editing_controller.dart`](lib/src/markdown_text_editing_controller.dart)** - Optional helper methods
3. **[`example/lib/main.dart`](example/lib/main.dart)** - Update to test new features

## Notes

- The existing list regex patterns already support tabs, so no changes to markdown parsing are needed
- Using `Focus` widget with `onKeyEvent` is the modern Flutter approach (Flutter 3.7+)
- For older Flutter versions, `RawKeyboardListener` could be used instead
