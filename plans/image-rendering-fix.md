# Image Rendering Fix Plan

## Problem Statement

Images rendered in the markdown editor overlap with text lines above and below them. The `WidgetSpan` in `TextField` doesn't expand line height.

## Previous Attempts (All Failed)

1. **Container padding** - Padding is inside widget, doesn't affect text layout
2. **Fixed SizedBox** - WidgetSpan doesn't contribute to line height
3. **TextSpan newlines** - Breaks cursor positioning (visual vs actual text mismatch)
4. **Zero-width space with large height** - Doesn't expand line height

## Solution: Actual Text Modification + Cursor Mapping

### Overview
Modify the actual text content to include newlines around images, then map cursor positions between "source text" (what user typed) and "display text" (with spacing newlines).

### Architecture

```
Source Text (user's input):
"## Header\n![img](url)\nMore text"

Display Text (internal rendering):
"## Header\n\n\n\n\n\n\n\n![img](url)\n\n\n\n\n\n\n\nMore text"
          ^-- newlines inserted --^    ^-- newlines inserted --^
```

### Components

1. **TextTransformer** - Converts between source and display text
   - Detects image markdown patterns
   - Calculates required newlines based on image height / line height
   - Inserts newlines before/after image lines
   - Maintains offset mapping

2. **CursorMapper** - Translates cursor positions
   - `sourceToDisplay(offset)` - adds offset for inserted newlines before position
   - `displayToSource(offset)` - removes offset for inserted newlines
   - Tracks regions of inserted newlines

3. **CursorRedirector** - Handles cursor movement
   - When cursor enters an inserted-newline region, redirect to the image line
   - Override selection changes to apply mapping

### Implementation Steps

1. Create `_ImageSpacingInfo` class to track:
   - Source line number
   - Display line number
   - Number of newlines inserted before
   - Number of newlines inserted after

2. In `buildTextSpan`:
   - Scan for image patterns
   - Calculate spacing needed for each
   - Build mapping structure
   - Return TextSpan with actual newlines in text

3. Override cursor/selection handling:
   - Intercept selection changes
   - Map display position to source position
   - Redirect if in spacer region

### Files to Modify

- [`lib/src/markdown_text_editing_controller.dart`](../lib/src/markdown_text_editing_controller.dart)
  - Add text transformation logic
  - Add cursor mapping
  - Modify `buildTextSpan` to use transformed text

### Code Structure

```dart
class _ImageSpacingRegion {
  final int sourceLineStart;
  final int sourceLineEnd;
  final int displayLineStart;
  final int displayLineEnd;
  final int newlinesBefore;
  final int newlinesAfter;
}

class MarkdownEditingController extends TextEditingController {
  List<_ImageSpacingRegion> _spacingRegions = [];
  
  int displayToSource(int displayOffset) {
    // Subtract inserted newlines before this position
  }
  
  int sourceToDisplay(int sourceOffset) {
    // Add inserted newlines before this position
  }
  
  @override
  TextSpan buildTextSpan(...) {
    // Build display text with newlines
    // Track spacing regions
    // Return span with actual \n characters
  }
}
```

### Cursor Redirection Logic

When the user clicks or moves cursor to an inserted-empty-line region:
1. Detect that cursor is in a spacer region
2. Calculate the nearest image line
3. Move cursor to the beginning of that image line
