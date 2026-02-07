import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'markdown_text_editing_controller.dart';

class MarkdownEditor extends StatefulWidget {
  final String? initialValue;
  final ValueChanged<String>? onChanged;
  final TextStyle? style;
  final InputDecoration? decoration;
  final bool useSoftTabs;
  final int tabWidth;

  const MarkdownEditor({
    super.key,
    this.initialValue,
    this.onChanged,
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

  void _onSelectionChanged() {
    // Update focused line whenever selection changes
    _controller.updateFocusedLineFromSelection();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.tab) {
      _insertTab();
      return KeyEventResult.handled;
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
          offset: selection.baseOffset + tabString.length,
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
        decoration: widget.decoration,
        maxLines: null,
        keyboardType: TextInputType.multiline,
      ),
    );
  }
}
