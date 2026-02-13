import 'package:flutter/material.dart';
import 'package:markdown_editor_live/markdown_editor_live.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Markdown Editor Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Markdown Editor Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _markdownData = """
# Markdown Editor Demo

This is a **live** markdown editor.

## Features

- **Bold text**
- *Italic text*
- `Inline code`
- Headers

## Nested Lists (Try pressing Tab!)

- Level 1 item
  - Nested item (press Tab to indent)
  - Another nested item
- Back to level 1
  - Another nested item
    - Deeply nested item

## Ordered Lists

1. First item
   1. Nested ordered item
   2. Another nested item
2. Second item

```
Block code
```

## Images

![Flutter logo](https://pbs.twimg.com/media/HBCe3_lbgAAQowC?format=jpg&name=medium)

Try typing here!
""";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: MarkdownEditor(
                initialValue: _markdownData,
                onChanged: (value) {
                  setState(() {
                    _markdownData = value;
                  });
                },
                style: const TextStyle(fontSize: 16),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Type markdown here...',
                ),
              ),
            ),
          ),
          const VerticalDivider(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(child: Text(_markdownData)),
            ),
          ),
        ],
      ),
    );
  }
}
