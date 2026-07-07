/// Returns [value] as a complete single-quoted Dart string literal.
String dartStringLiteral(String value) {
  final buffer = StringBuffer("'");

  for (final rune in value.runes) {
    switch (rune) {
      case 0x08:
        buffer.write(r'\b');
      case 0x09:
        buffer.write(r'\t');
      case 0x0a:
        buffer.write(r'\n');
      case 0x0c:
        buffer.write(r'\f');
      case 0x0d:
        buffer.write(r'\r');
      case 0x24:
        buffer.write(r'\$');
      case 0x27:
        buffer.write(r"\'");
      case 0x5c:
        buffer.write(r'\\');
      default:
        if (rune < 0x20 || rune == 0x7f) {
          buffer
            ..write(r'\u{')
            ..write(rune.toRadixString(16))
            ..write('}');
        } else {
          buffer.writeCharCode(rune);
        }
    }
  }

  buffer.write("'");
  return buffer.toString();
}
