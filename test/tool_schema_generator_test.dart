import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:source_gen/source_gen.dart';
import 'package:test/test.dart';

import 'package:tool_schema_generator/src/tool_schema_generator.dart';

/// Creates the [Builder] used by the generator, wired up identically
/// to the production `builder.dart`.
Builder _makeBuilder() =>
    SharedPartBuilder([ToolSchemaGenerator()], 'tool_schema');

void main() {
  group('ToolSchemaGenerator', () {
    // ------------------------------------------------------------------
    // Basic function — no params
    // ------------------------------------------------------------------
    test('generates schema for function with no parameters', () async {
      await testBuilder(
        _makeBuilder(),
        {
          'tool_schema_generator|lib/tool_schema_generator.dart':
              _annotationSource,
          '_test|lib/test.dart': '''
            import 'package:tool_schema_generator/tool_schema_generator.dart';
            part 'test.g.dart';

            /// A simple tool with no parameters.
            @Tool()
            void doNothing() {}
          ''',
        },
        generateFor: {'_test|lib/test.dart'},
        outputs: {
          '_test|lib/test.tool_schema.g.part': decodedMatches(
            allOf([
              contains("const doNothingToolSchema"),
              contains("'type': 'function'"),
              contains("'name': 'doNothing'"),
              contains("A simple tool with no parameters."),
              contains("'type': 'object'"),
              contains("const allToolSchemas"),
              contains("doNothingToolSchema"),
            ]),
          ),
        },
      );
    });

    // ------------------------------------------------------------------
    // Required positional params
    // ------------------------------------------------------------------
    test('generates schema with required positional parameters', () async {
      await testBuilder(
        _makeBuilder(),
        {
          'tool_schema_generator|lib/tool_schema_generator.dart':
              _annotationSource,
          '_test|lib/test.dart': '''
            import 'package:tool_schema_generator/tool_schema_generator.dart';
            part 'test.g.dart';

            /// Adds two numbers.
            @Tool()
            int addNumbers(int a, int b) => a + b;
          ''',
        },
        generateFor: {'_test|lib/test.dart'},
        outputs: {
          '_test|lib/test.tool_schema.g.part': decodedMatches(
            allOf([
              contains("const addNumbersToolSchema"),
              contains("'a':"),
              contains("'b':"),
              contains("'type': 'integer'"),
              contains("'required': <String>['a', 'b']"),
            ]),
          ),
        },
      );
    });

    // ------------------------------------------------------------------
    // Optional named params
    // ------------------------------------------------------------------
    test('generates schema with optional named parameters', () async {
      await testBuilder(
        _makeBuilder(),
        {
          'tool_schema_generator|lib/tool_schema_generator.dart':
              _annotationSource,
          '_test|lib/test.dart': '''
            import 'package:tool_schema_generator/tool_schema_generator.dart';
            part 'test.g.dart';

            /// Greets a user.
            @Tool()
            String greet({String? title, String name = 'World'}) => '';
          ''',
        },
        generateFor: {'_test|lib/test.dart'},
        outputs: {
          '_test|lib/test.tool_schema.g.part': decodedMatches(
            allOf([
              contains("const greetToolSchema"),
              contains("'title':"),
              contains("'name':"),
              // title is nullable optional, name has default — neither required
              isNot(contains("'required':")),
            ]),
          ),
        },
      );
    });

    // ------------------------------------------------------------------
    // Required named params
    // ------------------------------------------------------------------
    test('generates schema with required named parameters', () async {
      await testBuilder(
        _makeBuilder(),
        {
          'tool_schema_generator|lib/tool_schema_generator.dart':
              _annotationSource,
          '_test|lib/test.dart': '''
            import 'package:tool_schema_generator/tool_schema_generator.dart';
            part 'test.g.dart';

            @Tool()
            void send({required String to, required String body, String? cc}) {}
          ''',
        },
        generateFor: {'_test|lib/test.dart'},
        outputs: {
          '_test|lib/test.tool_schema.g.part': decodedMatches(
            allOf([
              contains("'required': <String>['to', 'body']"),
              contains("'cc':"),
            ]),
          ),
        },
      );
    });

    // ------------------------------------------------------------------
    // @Describe annotation on params
    // ------------------------------------------------------------------
    test('includes @Describe annotations in schema', () async {
      await testBuilder(
        _makeBuilder(),
        {
          'tool_schema_generator|lib/tool_schema_generator.dart':
              _annotationSource,
          '_test|lib/test.dart': '''
            import 'package:tool_schema_generator/tool_schema_generator.dart';
            part 'test.g.dart';

            @Tool()
            void search(
              @Describe('The search query string') String query,
              @Describe('Max results to return') int limit,
            ) {}
          ''',
        },
        generateFor: {'_test|lib/test.dart'},
        outputs: {
          '_test|lib/test.tool_schema.g.part': decodedMatches(
            allOf([
              contains("'description': 'The search query string'"),
              contains("'description': 'Max results to return'"),
              contains("'query':"),
              contains("'limit':"),
            ]),
          ),
        },
      );
    });

    // ------------------------------------------------------------------
    // Param without @Describe — no description key injected
    // ------------------------------------------------------------------
    test('omits description for params without @Describe', () async {
      await testBuilder(
        _makeBuilder(),
        {
          'tool_schema_generator|lib/tool_schema_generator.dart':
              _annotationSource,
          '_test|lib/test.dart': '''
            import 'package:tool_schema_generator/tool_schema_generator.dart';
            part 'test.g.dart';

            @Tool()
            void ping(String host) {}
          ''',
        },
        generateFor: {'_test|lib/test.dart'},
        outputs: {
          '_test|lib/test.tool_schema.g.part': decodedMatches(
            allOf([contains("'host':"), contains("'type': 'string'")]),
          ),
        },
      );
    });

    // ------------------------------------------------------------------
    // @Tool(name:) override
    // ------------------------------------------------------------------
    test('uses @Tool(name:) override', () async {
      await testBuilder(
        _makeBuilder(),
        {
          'tool_schema_generator|lib/tool_schema_generator.dart':
              _annotationSource,
          '_test|lib/test.dart': '''
            import 'package:tool_schema_generator/tool_schema_generator.dart';
            part 'test.g.dart';

            @Tool(name: 'custom_tool_name')
            void myFunction() {}
          ''',
        },
        generateFor: {'_test|lib/test.dart'},
        outputs: {
          '_test|lib/test.tool_schema.g.part': decodedMatches(
            allOf([
              contains("'name': 'custom_tool_name'"),
              // var name should still be based on function name
              contains("const myFunctionToolSchema"),
            ]),
          ),
        },
      );
    });

    // ------------------------------------------------------------------
    // @Tool(description:) override
    // ------------------------------------------------------------------
    test('uses @Tool(description:) override instead of doc comment', () async {
      await testBuilder(
        _makeBuilder(),
        {
          'tool_schema_generator|lib/tool_schema_generator.dart':
              _annotationSource,
          '_test|lib/test.dart': '''
            import 'package:tool_schema_generator/tool_schema_generator.dart';
            part 'test.g.dart';

            /// This doc comment should be ignored.
            @Tool(description: 'Override description here.')
            void myFunc() {}
          ''',
        },
        generateFor: {'_test|lib/test.dart'},
        outputs: {
          '_test|lib/test.tool_schema.g.part': decodedMatches(
            allOf([
              contains("'description': 'Override description here.'"),
              isNot(contains('This doc comment should be ignored')),
            ]),
          ),
        },
      );
    });

    // ------------------------------------------------------------------
    // Multi-line doc comment
    // ------------------------------------------------------------------
    test('extracts multi-line doc comments with newlines', () async {
      await testBuilder(
        _makeBuilder(),
        {
          'tool_schema_generator|lib/tool_schema_generator.dart':
              _annotationSource,
          '_test|lib/test.dart': '''
            import 'package:tool_schema_generator/tool_schema_generator.dart';
            part 'test.g.dart';

            /// First line.
            ///
            /// Second paragraph.
            @Tool()
            void documented() {}
          ''',
        },
        generateFor: {'_test|lib/test.dart'},
        outputs: {
          '_test|lib/test.tool_schema.g.part': decodedMatches(
            allOf([
              contains('First line.'),
              contains('Second paragraph.'),
              contains(r'\n'),
            ]),
          ),
        },
      );
    });

    // ------------------------------------------------------------------
    // No doc comment → empty description
    // ------------------------------------------------------------------
    test('generates empty description when no doc comment', () async {
      await testBuilder(
        _makeBuilder(),
        {
          'tool_schema_generator|lib/tool_schema_generator.dart':
              _annotationSource,
          '_test|lib/test.dart': '''
            import 'package:tool_schema_generator/tool_schema_generator.dart';
            part 'test.g.dart';

            @Tool()
            void noDoc() {}
          ''',
        },
        generateFor: {'_test|lib/test.dart'},
        outputs: {
          '_test|lib/test.tool_schema.g.part': decodedMatches(
            contains("'description': ''"),
          ),
        },
      );
    });

    // ------------------------------------------------------------------
    // Enum parameter
    // ------------------------------------------------------------------
    test('generates enum values for enum-typed parameter', () async {
      await testBuilder(
        _makeBuilder(),
        {
          'tool_schema_generator|lib/tool_schema_generator.dart':
              _annotationSource,
          '_test|lib/test.dart': '''
            import 'package:tool_schema_generator/tool_schema_generator.dart';
            part 'test.g.dart';

            enum Priority { low, medium, high }

            @Tool()
            void setTask(Priority priority) {}
          ''',
        },
        generateFor: {'_test|lib/test.dart'},
        outputs: {
          '_test|lib/test.tool_schema.g.part': decodedMatches(
            allOf([
              contains("'type': 'string'"),
              contains("'enum':"),
              contains("'low'"),
              contains("'medium'"),
              contains("'high'"),
            ]),
          ),
        },
      );
    });

    // ------------------------------------------------------------------
    // Nested class parameter
    // ------------------------------------------------------------------
    test('generates nested object schema for class parameter', () async {
      await testBuilder(
        _makeBuilder(),
        {
          'tool_schema_generator|lib/tool_schema_generator.dart':
              _annotationSource,
          '_test|lib/test.dart': '''
            import 'package:tool_schema_generator/tool_schema_generator.dart';
            part 'test.g.dart';

            class Address {
              final String street;
              final String city;
              const Address({required this.street, required this.city});
            }

            @Tool()
            void ship(Address address) {}
          ''',
        },
        generateFor: {'_test|lib/test.dart'},
        outputs: {
          '_test|lib/test.tool_schema.g.part': decodedMatches(
            allOf([
              contains("'address':"),
              contains("'type': 'object'"),
              contains("'street':"),
              contains("'city':"),
              contains("'required': <String>['street', 'city']"),
            ]),
          ),
        },
      );
    });

    // ------------------------------------------------------------------
    // List<String> parameter
    // ------------------------------------------------------------------
    test('generates array schema for List parameter', () async {
      await testBuilder(
        _makeBuilder(),
        {
          'tool_schema_generator|lib/tool_schema_generator.dart':
              _annotationSource,
          '_test|lib/test.dart': '''
            import 'package:tool_schema_generator/tool_schema_generator.dart';
            part 'test.g.dart';

            @Tool()
            void tag(List<String> tags) {}
          ''',
        },
        generateFor: {'_test|lib/test.dart'},
        outputs: {
          '_test|lib/test.tool_schema.g.part': decodedMatches(
            allOf([
              contains("'tags':"),
              contains("'type': 'array'"),
              contains("'items':"),
            ]),
          ),
        },
      );
    });

    // ------------------------------------------------------------------
    // Nullable parameter
    // ------------------------------------------------------------------
    test('generates nullable schema for nullable parameter', () async {
      await testBuilder(
        _makeBuilder(),
        {
          'tool_schema_generator|lib/tool_schema_generator.dart':
              _annotationSource,
          '_test|lib/test.dart': '''
            import 'package:tool_schema_generator/tool_schema_generator.dart';
            part 'test.g.dart';

            @Tool()
            void optionalSearch({int? maxResults}) {}
          ''',
        },
        generateFor: {'_test|lib/test.dart'},
        outputs: {
          '_test|lib/test.tool_schema.g.part': decodedMatches(
            allOf([
              contains("'maxResults':"),
              contains("'nullable': true"),
              contains("'type': 'integer'"),
            ]),
          ),
        },
      );
    });

    // ------------------------------------------------------------------
    // Multiple @Tool functions → allToolSchemas
    // ------------------------------------------------------------------
    test('generates allToolSchemas aggregate for multiple tools', () async {
      await testBuilder(
        _makeBuilder(),
        {
          'tool_schema_generator|lib/tool_schema_generator.dart':
              _annotationSource,
          '_test|lib/test.dart': '''
            import 'package:tool_schema_generator/tool_schema_generator.dart';
            part 'test.g.dart';

            @Tool()
            void alpha() {}

            @Tool()
            void beta() {}

            @Tool()
            void gamma() {}
          ''',
        },
        generateFor: {'_test|lib/test.dart'},
        outputs: {
          '_test|lib/test.tool_schema.g.part': decodedMatches(
            allOf([
              contains("const alphaToolSchema"),
              contains("const betaToolSchema"),
              contains("const gammaToolSchema"),
              contains("const allToolSchemas"),
              contains("alphaToolSchema,"),
              contains("betaToolSchema,"),
              contains("gammaToolSchema,"),
            ]),
          ),
        },
      );
    });

    // ------------------------------------------------------------------
    // No @Tool annotations → no output
    // ------------------------------------------------------------------
    test('generates no output when no @Tool annotations present', () async {
      await testBuilder(
        _makeBuilder(),
        {
          'tool_schema_generator|lib/tool_schema_generator.dart':
              _annotationSource,
          '_test|lib/test.dart': '''
            import 'package:tool_schema_generator/tool_schema_generator.dart';
            part 'test.g.dart';

            void plainFunction() {}
            String anotherFunction(int x) => '';
          ''',
        },
        generateFor: {'_test|lib/test.dart'},
        // No outputs expected — the .g.dart should be empty / not generated
      );
    });

    // ------------------------------------------------------------------
    // Non-function element annotated with @Tool — should be skipped
    // ------------------------------------------------------------------
    test('skips non-function elements annotated with @Tool', () async {
      await testBuilder(
        _makeBuilder(),
        {
          'tool_schema_generator|lib/tool_schema_generator.dart':
              _annotationSource,
          '_test|lib/test.dart': '''
            import 'package:tool_schema_generator/tool_schema_generator.dart';
            part 'test.g.dart';

            @Tool()
            class NotAFunction {}
          ''',
        },
        generateFor: {'_test|lib/test.dart'},
        // Should not produce any output since @Tool is on a class
      );
    });

    // ------------------------------------------------------------------
    // Mixed positional + named params
    // ------------------------------------------------------------------
    test('handles mixed positional and named parameters', () async {
      await testBuilder(
        _makeBuilder(),
        {
          'tool_schema_generator|lib/tool_schema_generator.dart':
              _annotationSource,
          '_test|lib/test.dart': '''
            import 'package:tool_schema_generator/tool_schema_generator.dart';
            part 'test.g.dart';

            @Tool()
            void mixed(
              String required1,
              int required2, {
              bool? optional1,
              required double required3,
            }) {}
          ''',
        },
        generateFor: {'_test|lib/test.dart'},
        outputs: {
          '_test|lib/test.tool_schema.g.part': decodedMatches(
            allOf([
              contains("'required1':"),
              contains("'required2':"),
              contains("'optional1':"),
              contains("'required3':"),
              contains(
                "'required': <String>['required1', 'required2', 'required3']",
              ),
            ]),
          ),
        },
      );
    });

    // ------------------------------------------------------------------
    // Map<String, dynamic> parameter type
    // ------------------------------------------------------------------
    test('generates object schema for Map parameter', () async {
      await testBuilder(
        _makeBuilder(),
        {
          'tool_schema_generator|lib/tool_schema_generator.dart':
              _annotationSource,
          '_test|lib/test.dart': '''
            import 'package:tool_schema_generator/tool_schema_generator.dart';
            part 'test.g.dart';

            @Tool()
            void process(Map<String, dynamic> data) {}
          ''',
        },
        generateFor: {'_test|lib/test.dart'},
        outputs: {
          '_test|lib/test.tool_schema.g.part': decodedMatches(
            allOf([contains("'data':"), contains("'type': 'object'")]),
          ),
        },
      );
    });

    // ------------------------------------------------------------------
    // @Tool(name:) + @Tool(description:) combined
    // ------------------------------------------------------------------
    test('uses both name and description overrides together', () async {
      await testBuilder(
        _makeBuilder(),
        {
          'tool_schema_generator|lib/tool_schema_generator.dart':
              _annotationSource,
          '_test|lib/test.dart': '''
            import 'package:tool_schema_generator/tool_schema_generator.dart';
            part 'test.g.dart';

            @Tool(name: 'get_data', description: 'Fetches data from API')
            void getData(String endpoint) {}
          ''',
        },
        generateFor: {'_test|lib/test.dart'},
        outputs: {
          '_test|lib/test.tool_schema.g.part': decodedMatches(
            allOf([
              contains("const getDataToolSchema"),
              contains("'name': 'get_data'"),
              contains("'description': 'Fetches data from API'"),
              contains("'endpoint':"),
            ]),
          ),
        },
      );
    });
  });
}

/// Inline version of the annotation source to make it available to
/// the test's asset graph. This must match the public API of the
/// `tool_schema_generator` package.
const _annotationSource = '''
class Tool {
  final String? name;
  final String? description;
  const Tool({this.name, this.description});
}

class Describe {
  final String description;
  const Describe(this.description);
}
''';
