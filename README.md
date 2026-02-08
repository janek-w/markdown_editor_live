# Markdown Editor Live

A simple WYSIWYG-style markdown editor for Flutter. It provides live syntax highlighting for markdown while keeping the raw text editable.

## Features

- **Live Syntax Highlighting**: See changes as you type.
- **Supports Common Markdown**: Headers, Bold, Italic, Code blocks.
- **Customizable**: Override styles for editor text.

## Getting started

Add this package to your `pubspec.yaml`:

```yaml
dependencies:
  markdown_editor_live: ^0.0.1
```

## Usage

Import the package:

```dart
import 'package:markdown_editor_live/markdown_editor_live.dart';
```

Use the `MarkdownEditor` widget:

```dart
MarkdownEditor(
  initialValue: '# Hello World\n\nThis is **bold**.',
  onChanged: (text) {
    print('Text changed: $text');
  },
  style: TextStyle(fontSize: 16),
)
```

## Additional information

This package is a work in progress. Contributions are welcome!
