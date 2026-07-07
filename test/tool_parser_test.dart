import 'package:build_test/build_test.dart';
import 'package:source_gen/source_gen.dart';
import 'package:test/test.dart';
import 'package:tool_schema_generator/src/schema_spec.dart';
import 'package:tool_schema_generator/src/tool_parser.dart';
import 'package:tool_schema_generator/src/tool_spec.dart';

void main() {
  group('ToolParser', () {
    test('parses tool metadata and parameter specs', () async {
      final tools = await _parseTools('''
        import 'package:tool_schema_generator/tool_schema_generator.dart';

        /// Finds products.
        @Tool(name: 'search_products', formats: [SchemaFormat.openAi])
        void search(
          @Describe('Search text') String query, {
          int limit = 10,
          @Inject() String? userId,
        }) {}
      ''');

      expect(tools, hasLength(1));
      final tool = tools.single;
      expect(tool.name, 'search_products');
      expect(tool.description, 'Finds products.');
      expect(tool.formats.map((format) => format.name), ['openAi']);
      expect(tool.strict, isFalse);
      expect(tool.parameters, hasLength(3));

      final query = tool.parameters.firstWhere((p) => p.name == 'query');
      expect(query.isRequired, isTrue);
      expect(query.isInjected, isFalse);
      expect(query.schema, isA<StringSchemaSpec>());
      expect(query.schema!.description, 'Search text');

      final limit = tool.parameters.firstWhere((p) => p.name == 'limit');
      expect(limit.isRequired, isFalse);
      expect(limit.defaultValueCode, '10');

      final userId = tool.parameters.firstWhere((p) => p.name == 'userId');
      expect(userId.isInjected, isTrue);
      expect(userId.schema, isNull);
      expect(tool.parametersSchema.properties.keys, ['query', 'limit']);
      expect(tool.parametersSchema.required, ['query']);
    });

    test('strict mode transforms nested object schemas', () async {
      final tools = await _parseTools('''
        import 'package:tool_schema_generator/tool_schema_generator.dart';

        class Location {
          final double lat;
          final double lng;
          const Location({required this.lat, required this.lng});
        }

        @Tool(strict: true)
        void nearby(Location location, {String? category}) {}
      ''');

      final schema = tools.single.parametersSchema;
      expect(schema.additionalProperties, isFalse);
      expect(schema.required, ['location', 'category']);

      final location = schema.properties['location'];
      expect(location, isA<ObjectSchemaSpec>());
      final locationObject = location as ObjectSchemaSpec;
      expect(locationObject.additionalProperties, isFalse);
      expect(locationObject.required, ['lat', 'lng']);
    });

    test('rejects strict tools with free-form map parameters', () async {
      await expectLater(
        () => _parseTools('''
          import 'package:tool_schema_generator/tool_schema_generator.dart';

          @Tool(strict: true)
          void process(Map<String, dynamic> payload) {}
        '''),
        throwsA(
          isA<InvalidGenerationSourceError>().having(
            (error) => error.message,
            'message',
            contains('cannot be used with @Tool(strict: true)'),
          ),
        ),
      );
    });

    test('rejects strict tools with dynamic parameters', () async {
      await expectLater(
        () => _parseTools('''
          import 'package:tool_schema_generator/tool_schema_generator.dart';

          @Tool(strict: true)
          void process(dynamic payload) {}
        '''),
        throwsA(
          isA<InvalidGenerationSourceError>().having(
            (error) => error.message,
            'message',
            contains('cannot be used with @Tool(strict: true)'),
          ),
        ),
      );
    });

    test('rejects strict tools with nested free-form map fields', () async {
      await expectLater(
        () => _parseTools('''
          import 'package:tool_schema_generator/tool_schema_generator.dart';

          class Payload {
            final Map<String, dynamic> metadata;
            const Payload({required this.metadata});
          }

          @Tool(strict: true)
          void process(Payload payload) {}
        '''),
        throwsA(isA<InvalidGenerationSourceError>()),
      );
    });

    test('rejects strict tools with recursive object graphs', () async {
      await expectLater(
        () => _parseTools('''
          import 'package:tool_schema_generator/tool_schema_generator.dart';

          class Node {
            final Node? next;
            const Node({this.next});
          }

          @Tool(strict: true)
          void process(Node node) {}
        '''),
        throwsA(
          isA<InvalidGenerationSourceError>().having(
            (error) => error.message,
            'message',
            contains('recursive object types'),
          ),
        ),
      );
    });
  });
}

Future<List<ToolSpec>> _parseTools(String source) async {
  late List<ToolSpec> tools;

  await resolveSources(
    {
      'tool_schema_generator|lib/tool_schema_generator.dart': _annotationSource,
      '_test|lib/test.dart':
          '''
        library test_lib;
        $source
      ''',
    },
    (resolver) async {
      final lib = await resolver.findLibraryByName('test_lib');
      tools = ToolParser().parse(LibraryReader(lib!));
    },
    resolverFor: '_test|lib/test.dart',
  );

  return tools;
}

const _annotationSource = '''
import 'package:meta/meta_meta.dart';

enum SchemaFormat {
  openAi,
  anthropic,
  gemini,
}

@Target({TargetKind.function})
class Tool {
  final String? name;
  final String? description;
  final List<SchemaFormat> formats;
  final bool strict;
  const Tool({
    this.name,
    this.description,
    this.formats = const [
      SchemaFormat.openAi,
      SchemaFormat.anthropic,
      SchemaFormat.gemini,
    ],
    this.strict = false,
  });
}

@Target({TargetKind.parameter})
class Describe {
  final String description;
  const Describe(this.description);
}

@Target({TargetKind.parameter})
class Inject {
  const Inject();
}
''';
