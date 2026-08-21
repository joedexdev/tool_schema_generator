import 'package:test/test.dart';
import 'package:tool_schema_generator/tool_schema_generator.dart';

void main() {
  group('ToolRegistry', () {
    test('call returns the raw tool value', () async {
      final registry = ToolRegistry([
        ToolDefinition(
          name: 'double',
          description: 'Double the value',
          parametersSchema: const {},
          handler: (args) async =>
              ToolRegistry.getRequiredArg<int>(args, 'value') * 2,
        ),
      ]);

      final result = await registry.call('double', {'value': 21});

      expect(result, 42);
    });

    test('call throws ToolNotFoundException for unknown tools', () async {
      final registry = ToolRegistry(const []);

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
      final registry = ToolRegistry([
        ToolDefinition(
          name: 'fail',
          description: 'Always fails',
          parametersSchema: const {},
          handler: (_) async => throw StateError('boom'),
        ),
      ]);

      await expectLater(
        registry.call('fail', const {}),
        throwsA(isA<ToolExecutionException>()),
      );
    });

    test('schemas are derived from format', () {
      final registry = ToolRegistry([
        ToolDefinition(
          name: 'search',
          description: 'Search tool',
          parametersSchema: const {'type': 'object'},
          handler: (_) async => null,
        ),
      ]);

      final openAiSchema = registry
          .encode(name: 'search', format: SchemaFormat.openAi)
          .first;
      expect(openAiSchema['type'], 'function');
      expect((openAiSchema['function'] as Map)['name'], 'search');

      final anthropicSchema = registry
          .encode(name: 'search', format: SchemaFormat.anthropic)
          .first;
      expect(anthropicSchema['name'], 'search');
      expect(anthropicSchema['input_schema'], const {'type': 'object'});

      expect(registry.encoded.length, 1);
      expect(registry.encode(format: SchemaFormat.anthropic).length, 1);
    });

    test('strict tools encode strict flag for supported providers', () {
      final registry = ToolRegistry([
        ToolDefinition(
          name: 'search',
          description: 'Search tool',
          parametersSchema: const {'type': 'object'},
          handler: (_) async => null,
          strict: true,
        ),
      ]);

      final openAiSchema = registry
          .encode(name: 'search', format: SchemaFormat.openAi)
          .first;
      expect((openAiSchema['function'] as Map)['strict'], isTrue);

      final anthropicSchema = registry
          .encode(name: 'search', format: SchemaFormat.anthropic)
          .first;
      expect(anthropicSchema['strict'], isTrue);

      final geminiSchema = registry
          .encode(name: 'search', format: SchemaFormat.gemini)
          .first;
      expect(geminiSchema.containsKey('strict'), isFalse);
    });

    test('extend() composition works', () async {
      final baseRegistry = ToolRegistry([
        ToolDefinition(
          name: 'a',
          description: 'a',
          parametersSchema: const {},
          handler: (_) async => 'a',
        ),
      ]);

      final expanded = baseRegistry.extend([
        ToolDefinition(
          name: 'b',
          description: 'b',
          parametersSchema: const {},
          handler: (_) async => 'b',
        ),
      ]);

      // Intentionally exercises the String-name overload of `contains`
      // (documented 1.x behavior; superseded by `hasTool` in a future major).
      expect(
        // ignore: collection_methods_unrelated_type
        expanded.contains('a'),
        isTrue,
      );
      expect(
        // ignore: collection_methods_unrelated_type
        expanded.contains('b'),
        isTrue,
      );
      expect(await expanded.call('a', const {}), 'a');
      expect(await expanded.call('b', const {}), 'b');
    });

    test('operator [] access works', () {
      final registry = ToolRegistry([
        ToolDefinition(
          name: 'test',
          description: 'test desc',
          parametersSchema: const {},
          handler: (_) async => null,
        ),
      ]);

      final tool = registry['test'];
      expect(tool, isNotNull);
      expect(tool!.name, 'test');
      expect(tool.description, 'test desc');
    });

    test('ToolDefinition.raw parses OpenAI nested format', () {
      final rawOpenAi = {
        'type': 'function',
        'function': {
          'name': 'nested_tool',
          'description': 'nested desc',
          'parameters': {
            'type': 'object',
            'properties': {
              'x': {'type': 'string'},
            },
          },
        },
      };

      final tool = ToolDefinition.raw(
        schema: rawOpenAi,
        handler: (args) async => 'nested',
      );

      expect(tool.name, 'nested_tool');
      expect(tool.description, 'nested desc');
      expect(tool.parametersSchema['type'], 'object');
      expect(tool['type'], 'function');
    });

    test('ToolDefinition.raw parses flat formats', () {
      final rawFlat = {
        'name': 'flat_tool',
        'description': 'flat desc',
        'parameters': {
          'type': 'object',
          'properties': {
            'y': {'type': 'integer'},
          },
        },
      };

      final tool = ToolDefinition.raw(
        schema: rawFlat,
        handler: (args) async => 'flat',
      );

      expect(tool.name, 'flat_tool');
      expect(tool.description, 'flat desc');
      expect(tool.parametersSchema['type'], 'object');
      expect(tool['type'], 'function');
      expect((tool['function'] as Map)['name'], 'flat_tool');
    });

    test('ToolRegistry implements IterableBase and spreads correctly', () {
      final registry = ToolRegistry([
        ToolDefinition(
          name: 'a',
          description: 'a',
          parametersSchema: const {},
          handler: (_) async => null,
        ),
        ToolDefinition(
          name: 'b',
          description: 'b',
          parametersSchema: const {},
          handler: (_) async => null,
        ),
      ]);

      final schemasList = [...registry];
      expect(schemasList.length, 2);
      expect(schemasList.first['type'], 'function');
    });

    test('ToolRegistry supports raw JSON schema maps directly', () async {
      final rawSchema = {
        'name': 'raw_map_tool',
        'description': 'no handler',
        'parameters': {'type': 'object'},
      };

      final registry = ToolRegistry([rawSchema]);

      expect(
        // Intentional: exercises the String-name overload of `contains`.
        // ignore: collection_methods_unrelated_type
        registry.contains('raw_map_tool'),
        isTrue,
      );
      expect(registry['raw_map_tool']!.name, 'raw_map_tool');

      await expectLater(
        registry.call('raw_map_tool', {}),
        throwsA(isA<ToolExecutionException>()),
      );
    });

    test(
      'ToolRegistry definitions, schemas, and multi-format getters work',
      () {
        final registry = ToolRegistry([
          ToolDefinition(
            name: 'getWeather',
            description: 'Get weather',
            parametersSchema: const {
              'type': 'object',
              'properties': {
                'city': {'type': 'string'},
              },
            },
            handler: (args) async => 'sunny',
          ),
        ]);

        expect(registry.definitions.length, 1);
        expect(registry.schemas.length, 1);

        final geminiList = registry.toGeminiSchemas();
        expect(geminiList.first['name'], 'getWeather');
        expect(geminiList.first.containsKey('parameters'), isTrue);
        expect(geminiList.first.containsKey('type'), isFalse);

        final anthropicList = registry.toAnthropicSchemas();
        expect(anthropicList.first['input_schema'], isNotNull);

        final mcpList = registry.toMcpSchemas();
        expect(mcpList.first['inputSchema'], isNotNull);

        final openAiList = registry.toOpenAiSchemas();
        expect(openAiList.first['type'], 'function');

        final tool = registry['getWeather']!;
        expect(tool.schema.toGemini()['name'], 'getWeather');
        expect(tool.schema.toAnthropic()['name'], 'getWeather');
        expect(tool.schema.toMcp()['name'], 'getWeather');
        expect(tool.schema.parameters['type'], 'object');
      },
    );

    test('operator + combines two registries', () {
      final reg1 = ToolRegistry([
        ToolDefinition(
          name: 'a',
          description: 'a',
          parametersSchema: const {},
          handler: (_) async => 'a',
        ),
      ]);
      final reg2 = ToolRegistry([
        ToolDefinition(
          name: 'b',
          description: 'b',
          parametersSchema: const {},
          handler: (_) async => 'b',
        ),
      ]);

      final combined = reg1 + reg2;
      expect(combined.definitions.length, 2);
      expect(
        // ignore: collection_methods_unrelated_type
        combined.contains('a'),
        isTrue,
      );
      expect(
        // ignore: collection_methods_unrelated_type
        combined.contains('b'),
        isTrue,
      );
    });
  });
}
