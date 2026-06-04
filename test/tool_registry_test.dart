import 'package:test/test.dart';
import 'package:tool_schema_generator/tool_schema_generator.dart';

void main() {
  group('ToolRegistry', () {
    test('call returns the raw tool value', () async {
      final registry = ToolRegistry({
        'double': (args) async =>
            ToolRegistry.getRequiredArg<int>(args, 'value') * 2,
      });

      final result = await registry.call('double', {'value': 21});

      expect(result, 42);
    });

    test('call throws ToolNotFoundException for unknown tools', () async {
      final registry = ToolRegistry(const {});

      await expectLater(
        registry.call('missing', const {}),
        throwsA(isA<ToolNotFoundException>()),
      );
    });

    test('validation helpers throw typed argument exceptions', () {
      expect(
        () => ToolRegistry.getRequiredArg<String>(const {}, 'city'),
        throwsA(isA<MissingToolArgumentException>()),
      );

      expect(
        () => ToolRegistry.getRequiredArg<String>(const {'city': 123}, 'city'),
        throwsA(isA<InvalidToolArgumentException>()),
      );
    });

    test('call wraps tool function failures', () async {
      final registry = ToolRegistry({
        'fail': (_) async => throw StateError('boom'),
      });

      await expectLater(
        registry.call('fail', const {}),
        throwsA(isA<ToolExecutionException>()),
      );
    });

    test('schemas are grouped by flavor', () {
      const openAiSchema = <String, Object?>{'name': 'search'};
      const anthropicSchema = <String, Object?>{'input_schema': {}};
      final registry = ToolRegistry(const {}, const {
        SchemaFlavor.openAi: {'search': openAiSchema},
        SchemaFlavor.anthropic: {'search': anthropicSchema},
      });

      expect(registry.schemasFor(SchemaFlavor.openAi), [openAiSchema]);
      expect(
        registry.schemaFor('search', SchemaFlavor.anthropic),
        anthropicSchema,
      );
      expect(registry.allSchemas, [openAiSchema]);
    });
  });
}
