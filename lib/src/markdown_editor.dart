import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'markdown_text_editing_controller.dart';

class MarkdownEditor extends StatefulWidget {
  final String? initialValue;
  final ValueChanged<String>? onChanged;
  final void Function(String url)? onLinkTap;
  final void Function(String url)? onImageTap;
  final TextStyle? style;
  final InputDecoration? decoration;
  final bool useSoftTabs;
  final int tabWidth;

  const MarkdownEditor({
    super.key,
    this.initialValue,
    this.onChanged,
    this.onLinkTap,
    this.onImageTap,
    this.style,
    this.decoration,
    this.useSoftTabs = true,
    this.tabWidth = 2,
  });

  @override
  State<MarkdownEditor> createState() => _MarkdownEditorState();
}

class _MarkdownEditorState extends State<MarkdownEditor> {
  late final MarkdownEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = MarkdownEditingController(
      text: widget.initialValue,
      onLinkTap: widget.onLinkTap,
      onImageTap: widget.onImageTap,
    );
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

  void _onSelectionChanged() {
    _controller.updateFocusedLineFromSelection();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.tab) {
      _insertTab();
      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
      if (_handleListContinuation()) {
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  /// Regex patterns for detecting list items
  static final _unorderedListPattern = RegExp(r'^([ \t]*)([*+-])([ \t]+)(.*)$');
  static final _orderedListPattern = RegExp(r'^([ \t]*)(\d+)(\.)([ \t]+)(.*)$');

  /// Handles Enter key press for list continuation.
  bool _handleListContinuation() {
    final text = _controller.value.text;
    final selection = _controller.value.selection;

    if (!selection.isValid || !selection.isCollapsed) return false;

    final cursorOffset = selection.baseOffset;
    final lineNumber = _getLineNumber(cursorOffset);
    final (lineStart, lineEnd) = _getLineRange(lineNumber);
    final currentLine = text.substring(lineStart, lineEnd);

    // Check for unordered list
    final unorderedMatch = _unorderedListPattern.firstMatch(currentLine);
    if (unorderedMatch != null) {
      final indent = unorderedMatch.group(1)!;
      final bullet = unorderedMatch.group(2)!;
      final space = unorderedMatch.group(3)!;
      final content = unorderedMatch.group(4)!;

      if (content.isEmpty) {
        _removeListPrefix(lineStart, lineEnd);
      } else {
        _insertNewListItem(cursorOffset, '$indent$bullet$space');
      }
      return true;
    }

    // Check for ordered list
    final orderedMatch = _orderedListPattern.firstMatch(currentLine);
    if (orderedMatch != null) {
      final indent = orderedMatch.group(1)!;
      final number = int.parse(orderedMatch.group(2)!);
      final dot = orderedMatch.group(3)!;
      final space = orderedMatch.group(4)!;
      final content = orderedMatch.group(5)!;

      if (content.isEmpty) {
        _removeListPrefix(lineStart, lineEnd);
      } else {
        _insertNewListItem(cursorOffset, '$indent${number + 1}$dot$space');
      }
      return true;
    }

    return false;
  }

  /// Inserts a new line with the given list prefix at the cursor position.
  void _insertNewListItem(int cursorOffset, String prefix) {
    final text = _controller.value.text;
    final newText =
        '${text.substring(0, cursorOffset)}\n$prefix${text.substring(cursorOffset)}';

    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: cursorOffset + 1 + prefix.length,
      ),
    );
  }

  /// Removes the list prefix from the current line, leaving just the newline.
  void _removeListPrefix(int lineStart, int lineEnd) {
    final text = _controller.value.text;

    if (lineStart == 0) {
      final newText = text.substring(lineEnd);
      _controller.value = TextEditingValue(
        text: newText,
        selection: const TextSelection.collapsed(offset: 0),
      );
    } else {
      // Remove the previous newline and the entire line content
      final newText =
          text.substring(0, lineStart - 1) + text.substring(lineEnd);
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: lineStart - 1),
      );
    }
  }

  (int, int) _getLineRange(int lineNumber) {
    final text = _controller.value.text;
    int currentLine = 0;
    int lineStart = 0;

    for (int i = 0; i < text.length; i++) {
      if (currentLine == lineNumber) {
        int lineEnd = i;
        while (lineEnd < text.length && text[lineEnd] != '\n') {
          lineEnd++;
        }
        return (lineStart, lineEnd);
      }
      if (text[i] == '\n') {
        currentLine++;
        lineStart = i + 1;
      }
    }

    if (currentLine == lineNumber) {
      return (lineStart, text.length);
    }

    return (0, 0);
  }

  void _insertTab() {
    final text = _controller.value.text;
    final selection = _controller.value.selection;

    if (!selection.isValid) return;

    final tabString = widget.useSoftTabs ? ' ' * widget.tabWidth : '\t';

    if (selection.isCollapsed) {
      // Insert tab at cursor position
      final newText =
          text.substring(0, selection.baseOffset) +
          tabString +
          text.substring(selection.baseOffset);
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: selection.baseOffset + tabString.length,
        ),
      );
    } else {
      _indentSelectedLines(tabString);
    }
  }

  void _indentSelectedLines(String tabString) {
    final text = _controller.value.text;
    final selection = _controller.value.selection;
    final (startLine, endLine) = _getSelectedLineRange(selection);

    final lines = text.split('\n');
    final newLines = <String>[];

    for (int i = startLine; i <= endLine; i++) {
      if (i < lines.length) {
        newLines.add(tabString + lines[i]);
      }
    }

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
    final startLine = _getLineNumber(selection.baseOffset);
    final endLine = _getLineNumber(selection.extentOffset);
    return (startLine, endLine);
  }

  int _getLineNumber(int offset) {
    final text = _controller.value.text;
    int line = 0;
    for (int i = 0; i < offset && i < text.length; i++) {
      if (text[i] == '\n') {
        line++;
      }
    }
    return line;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: TextField(
        controller: _controller,
        onChanged: widget.onChanged,
        style: widget.style,
        decoration:
            widget.decoration?.copyWith(
              contentPadding:
                  widget.decoration?.contentPadding ??
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            ) ??
            const InputDecoration(
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 16,
              ),
            ),
        maxLines: null,
        keyboardType: TextInputType.multiline,
      ),
    );
  }
}
