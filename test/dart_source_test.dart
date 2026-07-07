import 'package:test/test.dart';
import 'package:tool_schema_generator/src/dart_source.dart';

void main() {
  group('dartStringLiteral', () {
    test('returns a complete single-quoted literal', () {
      final literal = dartStringLiteral('plain');

      expect(literal, "'plain'");
      expect(literal, startsWith("'"));
      expect(literal, endsWith("'"));
    });

    test('escapes Dart string metacharacters and control characters', () {
      final value =
          "Cost \$5 'quote' \\ path\n\r\t\b\f${String.fromCharCode(1)}";

      expect(
        dartStringLiteral(value),
        r"'Cost \$5 \'quote\' \\ path\n\r\t\b\f\u{1}'",
      );
    });

    test('preserves normal unicode characters', () {
      expect(dartStringLiteral('cafe'), "'cafe'");
      expect(dartStringLiteral('مرحبا'), "'مرحبا'");
    });
  });
}
