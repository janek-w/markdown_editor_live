import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Tracks information about inserted spacing newlines for an image
class _ImageSpacingRegion {
  /// The source text offset where the image markdown starts
  final int sourceStart;
  /// The source text offset where the image markdown ends
  final int sourceEnd;
  /// Number of newlines inserted before the image
  final int newlinesBefore;
  /// Number of newlines inserted after the image
  final int newlinesAfter;
  /// The display offset where the image starts (including inserted newlines)
  int get displayStart => sourceStart + newlinesBefore;
  /// The display offset where the image ends (including inserted newlines)
  int get displayEnd => sourceEnd + newlinesBefore;

  _ImageSpacingRegion({
    required this.sourceStart,
    required this.sourceEnd,
    required this.newlinesBefore,
    required this.newlinesAfter,
  });
}

class MarkdownEditingController extends TextEditingController {
  MarkdownEditingController({super.text, this.onLinkTap, this.onImageTap});

  /// Called when a link is tapped. Receives the URL as a string.
  final void Function(String url)? onLinkTap;

  /// Called when an image is tapped. Receives the image URL as a string.
  final void Function(String url)? onImageTap;

  /// Active gesture recognizers for links, disposed on each rebuild.
  final List<GestureRecognizer> _recognizers = [];

  /// Tracks inserted newlines for images in the current text
  List<_ImageSpacingRegion> _imageSpacingRegions = [];

  /// The currently focused line number (0-indexed).
  /// When set, syntax markers are hidden on all other lines.
  int? _focusedLine;

  /// Image display height in pixels
  static const double imageHeight = 200.0;

  int? get focusedLine => _focusedLine;

  set focusedLine(int? value) {
    if (_focusedLine != value) {
      _focusedLine = value;
      notifyListeners();
    }
  }

  void updateFocusedLineFromSelection() {
    if (selection.isValid && selection.baseOffset >= 0) {
      // Convert display offset to source offset before calculating line
      final sourceOffset = displayToSource(selection.baseOffset);
      focusedLine = _getLineNumber(sourceOffset, _sourceText);
    }
  }

  /// Get the source text (without inserted newlines)
  String get _sourceText => super.text;

  /// Override text to return display text (with inserted newlines)
  @override
  String get text {
    return _sourceToDisplayText(_sourceText);
  }

  /// Convert source text offset to display text offset
  int sourceToDisplay(int sourceOffset) {
    int offset = sourceOffset;
    for (final region in _imageSpacingRegions) {
      if (sourceOffset > region.sourceStart) {
        offset += region.newlinesBefore;
      }
      if (sourceOffset >= region.sourceEnd) {
        offset += region.newlinesAfter;
      }
    }
    return offset;
  }

  /// Convert display text offset to source text offset
  int displayToSource(int displayOffset) {
    int offset = displayOffset;
    for (final region in _imageSpacingRegions) {
      // If we're in the "newlines before" region, snap to image start
      if (displayOffset >= region.sourceStart &&
          displayOffset < region.sourceStart + region.newlinesBefore) {
        return region.sourceStart;
      }
      // If we're in the "newlines after" region, snap to image end
      if (displayOffset >= region.sourceEnd + region.newlinesBefore &&
          displayOffset < region.sourceEnd + region.newlinesBefore + region.newlinesAfter) {
        return region.sourceEnd;
      }
      // Subtract inserted newlines for positions after them
      if (displayOffset >= region.sourceStart + region.newlinesBefore) {
        offset -= region.newlinesBefore;
      }
      if (displayOffset >= region.sourceEnd + region.newlinesBefore + region.newlinesAfter) {
        offset -= region.newlinesAfter;
      }
    }
    return offset;
  }

  /// Transform source text to display text by inserting newlines around images
  String _sourceToDisplayText(String sourceText) {
    // Find all image patterns
    final imagePattern = RegExp(r'!\[([^\]]*?)\]\(([^\)]+)\)');
    final matches = imagePattern.allMatches(sourceText).toList();

    if (matches.isEmpty) {
      _imageSpacingRegions = [];
      return sourceText;
    }

    // Calculate newlines needed based on image height and font size
    const imageHeight = MarkdownEditingController.imageHeight;
    const fontSize = 16.0; // Default font size
    final lineHeight = fontSize * 1.4;
    final newlinesNeeded = (imageHeight / lineHeight).ceil();

    // Build display text and track regions
    final buffer = StringBuffer();
    final regions = <_ImageSpacingRegion>[];
    int lastEnd = 0;

    for (final match in matches) {
      // Add text before this image
      buffer.write(sourceText.substring(lastEnd, match.start));

      // Insert newlines before image
      buffer.write('\n' * newlinesNeeded);

      // Add the image markdown
      buffer.write(match.group(0));

      // Insert newlines after image
      buffer.write('\n' * newlinesNeeded);

      // Track the region
      regions.add(_ImageSpacingRegion(
        sourceStart: match.start,
        sourceEnd: match.end,
        newlinesBefore: newlinesNeeded,
        newlinesAfter: newlinesNeeded,
      ));

      lastEnd = match.end;
    }

    // Add remaining text
    buffer.write(sourceText.substring(lastEnd));

    _imageSpacingRegions = regions;
    return buffer.toString();
  }

  int _getLineNumber(int offset, String text) {
    int line = 0;
    for (int i = 0; i < offset && i < text.length; i++) {
      if (text[i] == '\n') {
        line++;
      }
    }
    return line;
  }

  (int start, int end) _getLineRange(int lineNumber, String text) {
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

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    _disposeRecognizers();
    style ??= const TextStyle();
    return _parseMarkdown(_sourceText, style, context);
  }

  TextSpan _parseMarkdown(
    String text,
    TextStyle defaultStyle,
    BuildContext context,
  ) {
    final List<InlineSpan> spans = [];

    // Calculate focused line range in SOURCE text
    (int start, int end)? focusedLineRange;
    if (_focusedLine != null) {
      focusedLineRange = _getLineRange(_focusedLine!, text);
    }

    // Pattern definitions
    final patterns = <_MarkdownPattern>[
      // Headers: show # only on focused line
      _MarkdownPattern(RegExp(r'^(#{1,6}\s+)(.*)$', multiLine: true), (match) {
        final headingLevel = match.group(1)!.trim().length;
        final fontSizes = [28.0, 24.0, 20.0, 18.0, 16.0, 14.0];
        final fontSize = fontSizes[headingLevel.clamp(1, 6) - 1];
        return TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: fontSize,
          color: Colors.blueAccent,
        );
      }, type: _PatternType.header),
      // Unordered List
      _MarkdownPattern(
        RegExp(r'^([ \t]*)([*+-])([ \t]+)', multiLine: true),
        (match) => const TextStyle(fontWeight: FontWeight.w500),
        type: _PatternType.list,
      ),
      // Ordered List
      _MarkdownPattern(
        RegExp(r'^([ \t]*)(\d+\.)([ \t]+)', multiLine: true),
        (match) => const TextStyle(fontWeight: FontWeight.w500),
        type: _PatternType.list,
      ),
      // Bold **text**
      _MarkdownPattern(
        RegExp(r'(\*\*)(.+?)(\*\*)'),
        (match) => const TextStyle(fontWeight: FontWeight.bold),
        type: _PatternType.inline,
      ),
      // Bold __text__
      _MarkdownPattern(
        RegExp(r'(__)(.+?)(__)'),
        (match) => const TextStyle(fontWeight: FontWeight.bold),
        type: _PatternType.inline,
      ),
      // Italic *text*
      _MarkdownPattern(
        RegExp(r'(\*)(.+?)(\*)'),
        (match) => const TextStyle(fontStyle: FontStyle.italic),
        type: _PatternType.inline,
      ),
      // Italic _text_
      _MarkdownPattern(
        RegExp(r'(_)(.+?)(_)'),
        (match) => const TextStyle(fontStyle: FontStyle.italic),
        type: _PatternType.inline,
      ),
      // Strikethrough ~~text~~
      _MarkdownPattern(
        RegExp(r'(~~)(.+?)(~~)'),
        (match) => const TextStyle(decoration: TextDecoration.lineThrough),
        type: _PatternType.inline,
      ),
      // Inline code `text`
      _MarkdownPattern(
        RegExp(r'(`)([^`]+)(`)'),
        (match) => TextStyle(
          fontFamily: 'monospace',
          backgroundColor: Colors.grey.shade200.withValues(alpha: 0.5),
        ),
        type: _PatternType.inline,
      ),
      // Block code ```text```
      _MarkdownPattern(
        RegExp(r'(```)([\s\S]*?)(```)'),
        (match) => TextStyle(
          fontFamily: 'monospace',
          backgroundColor: Colors.grey.shade200.withValues(alpha: 0.5),
        ),
        type: _PatternType.inline,
      ),
      // Images ![alt](url) — must come before links
      _MarkdownPattern(
        RegExp(r'(!\[)([^\]]*?)(\]\()([^\)]+)(\))'),
        (match) => const TextStyle(color: Colors.teal),
        type: _PatternType.image,
      ),
      // Links [text](url)
      _MarkdownPattern(
        RegExp(r'(\[)([^\]]+)(\]\()([^\)]+)(\))'),
        (match) => const TextStyle(
          color: Colors.blue,
          decoration: TextDecoration.underline,
        ),
        type: _PatternType.link,
      ),
      // Thematic break
      _MarkdownPattern(
        RegExp(
          r'^ {0,3}((\*[ \t]*){3,}|(-[ \t]*){3,}|(_[ \t]*){3,})$',
          multiLine: true,
        ),
        (match) => const TextStyle(color: Colors.grey),
        type: _PatternType.thematicBreak,
        priority: 1,
      ),
    ];

    // Collect all matches
    List<_MatchRange> ranges = [];

    for (final pattern in patterns) {
      for (final match in pattern.exp.allMatches(text)) {
        final isOnFocusedLine =
            focusedLineRange != null &&
            match.start >= focusedLineRange.$1 &&
            match.start < focusedLineRange.$2;

        final rangeStyle = pattern.styleBuilder(match);
        final List<InlineSpan> matchSpans = [];

        // TextStyle to start with (merging default + pattern style)
        final combinedStyle = defaultStyle.merge(rangeStyle);
        // Style for hidden syntax (zero size)
        final hiddenStyle = combinedStyle.copyWith(fontSize: 0.0);

        if (pattern.type == _PatternType.header) {
          // Group 1: Syntax (e.g. "# "), Group 2: Content
          final syntax = match.group(1)!;
          final content = match.group(2)!;

          matchSpans.add(
            TextSpan(
              text: syntax,
              style: isOnFocusedLine || _focusedLine == null
                  ? combinedStyle
                  : hiddenStyle,
            ),
          );
          matchSpans.add(TextSpan(text: content, style: combinedStyle));
        } else if (pattern.type == _PatternType.list) {
          // Group 1: Leading indent, Group 2: Bullet/Number, Group 3: Space
          final indent = match.group(1)!;
          final bulletOrNumber = match.group(2)!;
          final space = match.group(3)!;

          matchSpans.add(TextSpan(text: indent, style: defaultStyle));

          if (isOnFocusedLine || _focusedLine == null) {
            matchSpans.add(
              TextSpan(
                text: bulletOrNumber + space,
                style: combinedStyle.copyWith(color: Colors.blueAccent),
              ),
            );
          } else {
            final replacement = RegExp(r'^\d+\.$').hasMatch(bulletOrNumber)
                ? bulletOrNumber
                : '•';
            matchSpans.add(
              TextSpan(
                text: replacement + space,
                style: combinedStyle.copyWith(fontWeight: FontWeight.bold),
              ),
            );
          }
        } else if (pattern.type == _PatternType.thematicBreak) {
          if (isOnFocusedLine || _focusedLine == null) {
            matchSpans.add(
              TextSpan(
                text: match.group(0),
                style: combinedStyle.copyWith(color: Colors.grey),
              ),
            );
          } else {
            final lineLength = match.group(0)!.length;
            final lineChars = '─' * lineLength;
            matchSpans.add(
              TextSpan(
                text: lineChars,
                style: combinedStyle.copyWith(
                  color: Colors.grey,
                  letterSpacing: 0,
                ),
              ),
            );
          }
        } else if (pattern.type == _PatternType.image) {
          // Groups: 1=![, 2=alt, 3=](, 4=url, 5=)
          final exclamationBracket = match.group(1)!;
          final altText = match.group(2)!;
          final middle = match.group(3)!;
          final url = match.group(4)!;
          final closeParen = match.group(5)!;

          final imageStyle = combinedStyle;

          if (isOnFocusedLine || _focusedLine == null) {
            // Show full syntax on focused line
            matchSpans.add(
              TextSpan(text: exclamationBracket, style: imageStyle),
            );
            matchSpans.add(TextSpan(text: altText, style: imageStyle));
            matchSpans.add(TextSpan(text: middle, style: imageStyle));
            matchSpans.add(
              TextSpan(
                text: url,
                style: imageStyle.copyWith(color: Colors.teal.shade300),
              ),
            );
            matchSpans.add(TextSpan(text: closeParen, style: imageStyle));
          } else {
            // WYSIWYG: hide all syntax, render actual image with spacing
            matchSpans.add(
              TextSpan(text: exclamationBracket, style: hiddenStyle),
            );
            matchSpans.add(TextSpan(text: altText, style: hiddenStyle));
            matchSpans.add(TextSpan(text: middle, style: hiddenStyle));
            matchSpans.add(TextSpan(text: url, style: hiddenStyle));
            matchSpans.add(TextSpan(text: closeParen, style: hiddenStyle));

            TapGestureRecognizer? imageRecognizer;
            if (onImageTap != null) {
              imageRecognizer = TapGestureRecognizer()
                ..onTap = () => onImageTap!(url);
              _recognizers.add(imageRecognizer);
            }

            // Calculate newlines needed based on image height and font size
            const imageHeight = MarkdownEditingController.imageHeight;
            final fontSize = defaultStyle.fontSize ?? 16.0;
            final lineHeight = fontSize * 1.4;
            final newlinesNeeded = (imageHeight / lineHeight).ceil();

            // Add newlines BEFORE widget to create space above
            matchSpans.add(
              TextSpan(text: '\n' * newlinesNeeded, style: defaultStyle),
            );

            matchSpans.add(
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: GestureDetector(
                  onTap: onImageTap != null ? () => onImageTap!(url) : null,
                  child: SizedBox(
                    height: imageHeight,
                    width: 300,
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return SizedBox(
                          height: imageHeight,
                          width: 300,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.broken_image,
                                size: 16,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                altText.isNotEmpty ? altText : 'Image',
                                style: defaultStyle.copyWith(
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            );

            // Add newlines AFTER widget to create space below
            matchSpans.add(
              TextSpan(text: '\n' * newlinesNeeded, style: defaultStyle),
            );
          }
        } else if (pattern.type == _PatternType.link) {
          // Groups: 1=[, 2=text, 3=](, 4=url, 5=)
          final bracket = match.group(1)!;
          final linkText = match.group(2)!;
          final middle = match.group(3)!;
          final url = match.group(4)!;
          final closeParen = match.group(5)!;

          final linkStyle = combinedStyle;

          TapGestureRecognizer? recognizer;
          if (onLinkTap != null) {
            recognizer = TapGestureRecognizer()..onTap = () => onLinkTap!(url);
            _recognizers.add(recognizer);
          }

          if (isOnFocusedLine || _focusedLine == null) {
            matchSpans.add(TextSpan(text: bracket, style: linkStyle));
            matchSpans.add(
              TextSpan(
                text: linkText,
                style: linkStyle,
                recognizer: recognizer,
              ),
            );
            matchSpans.add(TextSpan(text: middle, style: linkStyle));
            matchSpans.add(
              TextSpan(
                text: url,
                style: linkStyle.copyWith(color: Colors.blue.shade300),
              ),
            );
            matchSpans.add(TextSpan(text: closeParen, style: linkStyle));
          } else {
            matchSpans.add(TextSpan(text: bracket, style: hiddenStyle));
            matchSpans.add(
              TextSpan(
                text: linkText,
                style: linkStyle,
                recognizer: recognizer,
              ),
            );
            matchSpans.add(TextSpan(text: middle, style: hiddenStyle));
            matchSpans.add(TextSpan(text: url, style: hiddenStyle));
            matchSpans.add(TextSpan(text: closeParen, style: hiddenStyle));
          }
        } else if (pattern.type == _PatternType.inline) {
          if (match.groupCount >= 3) {
            final prefix = match.group(1)!;
            final content = match.group(2)!;
            final suffix = match.group(3)!;

            matchSpans.add(
              TextSpan(
                text: prefix,
                style: isOnFocusedLine || _focusedLine == null
                    ? combinedStyle
                    : hiddenStyle,
              ),
            );
            matchSpans.add(TextSpan(text: content, style: combinedStyle));
            matchSpans.add(
              TextSpan(
                text: suffix,
                style: isOnFocusedLine || _focusedLine == null
                    ? combinedStyle
                    : hiddenStyle,
              ),
            );
          } else {
            matchSpans.add(
              TextSpan(text: match.group(0), style: combinedStyle),
            );
          }
        }

        ranges.add(
          _MatchRange(match.start, match.end, matchSpans, pattern.priority),
        );
      }
    }

    // Sort by start position, then by length (longer matches first)
    ranges.sort((a, b) {
      final startCompare = a.start.compareTo(b.start);
      if (startCompare != 0) return startCompare;
      final lengthCompare = b.end.compareTo(a.end);
      if (lengthCompare != 0) return lengthCompare;
      return b.priority.compareTo(a.priority);
    });

    // Remove overlapping ranges
    List<_MatchRange> filteredRanges = [];
    int lastEnd = 0;
    for (final range in ranges) {
      if (range.start >= lastEnd) {
        filteredRanges.add(range);
        lastEnd = range.end;
      }
    }

    // Build final spans
    int textCursor = 0;

    for (final range in filteredRanges) {
      if (range.start > textCursor) {
        spans.add(
          TextSpan(
            text: text.substring(textCursor, range.start),
            style: defaultStyle,
          ),
        );
      }

      spans.addAll(range.spans);
      textCursor = range.end;
    }

    // Add remaining text
    if (textCursor < text.length) {
      spans.add(
        TextSpan(text: text.substring(textCursor), style: defaultStyle),
      );
    }

    return TextSpan(style: defaultStyle, children: spans);
  }
}

enum _PatternType { header, list, inline, image, link, thematicBreak }

class _MarkdownPattern {
  final RegExp exp;
  final TextStyle Function(Match match) styleBuilder;
  final _PatternType type;
  final int priority;

  _MarkdownPattern(
    this.exp,
    this.styleBuilder, {
    this.type = _PatternType.inline,
    this.priority = 0,
  });
}

class _MatchRange {
  final int start;
  final int end;
  final List<InlineSpan> spans;
  final int priority;

  _MatchRange(this.start, this.end, this.spans, this.priority);
}
