void main() {
  final regex = RegExp(
    r'^ {0,3}((\*\s*){3,}|(-\s*){3,}|(_\s*){3,})$',
    multiLine: true,
  );
  final text = '---\nText';

  final matches = regex.allMatches(text);
  for (final match in matches) {
    print('Match: "${match.group(0)}"');
    print('Start: ${match.start}, End: ${match.end}');
    print(
      'Remaining text starts with: "${text.length > match.end ? text.substring(match.end, match.end + 1) : "EOF"}"',
    );
  }
}
