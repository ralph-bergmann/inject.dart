import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:inject_generator/src/logging/source_snippet.dart';
import 'package:test/test.dart';

Future<LibraryElement> _resolveLibrary(String source) => resolveSource(
  source,
  (resolver) async => resolver.libraryFor(AssetId('_resolve_source', 'lib/_resolve_source.dart')),
  readAllSourcesFromFilesystem: true,
);

void main() {
  group('SourceSnippet.format()', () {
    test('formats standard 7-line snippet with highlight', () {
      const snippet = SourceSnippet(
        lines: [
          '',
          'class Foo {',
          '  @inject',
          '  @async',
          '  const Foo() {}',
          '}',
          '',
        ],
        errorLineIndex: 3,
        highlightColumn: 2,
        highlightLength: 6,
        startLineNumber: 2,
      );

      expect(
        snippet.format(),
        equals(
          '  ╷\n'
          '2 │ \n'
          '3 │ class Foo {\n'
          '4 │   @inject\n'
          '5 │   @async\n'
          '  │   ^^^^^^\n'
          '6 │   const Foo() {}\n'
          '7 │ }\n'
          '8 │ \n'
          '  ╵\n',
        ),
      );
    });

    test('formats error on line 1 with no preceding context', () {
      const snippet = SourceSnippet(
        lines: [
          '@inject',
          'class Foo {}',
          '',
        ],
        errorLineIndex: 0,
        highlightColumn: 0,
        highlightLength: 7,
        startLineNumber: 1,
      );

      expect(
        snippet.format(),
        equals(
          '  ╷\n'
          '1 │ @inject\n'
          '  │ ^^^^^^^\n'
          '2 │ class Foo {}\n'
          '3 │ \n'
          '  ╵\n',
        ),
      );
    });

    test('formats error on last line with no trailing context', () {
      const snippet = SourceSnippet(
        lines: [
          '',
          'class Bar {',
          '  void run() {}',
          '}',
        ],
        errorLineIndex: 3,
        highlightColumn: 0,
        highlightLength: 1,
        startLineNumber: 4,
      );

      expect(
        snippet.format(),
        equals(
          '  ╷\n'
          '4 │ \n'
          '5 │ class Bar {\n'
          '6 │   void run() {}\n'
          '7 │ }\n'
          '  │ ^\n'
          '  ╵\n',
        ),
      );
    });

    test('formats file with fewer than 7 lines', () {
      const snippet = SourceSnippet(
        lines: [
          'import "dart:core";',
          '',
          '@inject',
          'class Tiny {}',
        ],
        errorLineIndex: 2,
        highlightColumn: 0,
        highlightLength: 7,
        startLineNumber: 1,
      );

      expect(
        snippet.format(),
        equals(
          '  ╷\n'
          '1 │ import "dart:core";\n'
          '2 │ \n'
          '3 │ @inject\n'
          '  │ ^^^^^^^\n'
          '4 │ class Tiny {}\n'
          '  ╵\n',
        ),
      );
    });

    test('formats with three-digit line numbers (right-aligned gutter)', () {
      const snippet = SourceSnippet(
        lines: [
          '  // line 97',
          '  // line 98',
          '  // line 99',
          '  @inject',
          '  // line 101',
          '  // line 102',
          '  // line 103',
        ],
        errorLineIndex: 3,
        highlightColumn: 2,
        highlightLength: 7,
        startLineNumber: 97,
      );

      expect(
        snippet.format(),
        equals(
          '    ╷\n'
          ' 97 │   // line 97\n'
          ' 98 │   // line 98\n'
          ' 99 │   // line 99\n'
          '100 │   @inject\n'
          '    │   ^^^^^^^\n'
          '101 │   // line 101\n'
          '102 │   // line 102\n'
          '103 │   // line 103\n'
          '    ╵\n',
        ),
      );
    });

    test('formats single-line file', () {
      const snippet = SourceSnippet(
        lines: ['class X {}'],
        errorLineIndex: 0,
        highlightColumn: 6,
        highlightLength: 1,
        startLineNumber: 1,
      );

      expect(
        snippet.format(),
        equals(
          '  ╷\n'
          '1 │ class X {}\n'
          '  │       ^\n'
          '  ╵\n',
        ),
      );
    });
  });

  group('extractSnippet()', () {
    test('extracts snippet from class element with context lines', () async {
      final LibraryElement library = await _resolveLibrary('''
        // line 1
        // line 2
        // line 3
        // line 4
        class MyService {
          void run() {}
        }
        // line 8
        // line 9
      ''');

      final ClassElement classElement = library.getClass('MyService')!;
      final SourceSnippet? snippet = extractSnippet(classElement);

      expect(snippet, isNotNull);
      expect(snippet!.highlightLength, 'MyService'.length);
      // The snippet should contain the class line
      expect(snippet.lines.any((l) => l.contains('MyService')), isTrue);
      // Error line index should point to the line containing MyService
      final String errorLine = snippet.lines[snippet.errorLineIndex];
      expect(errorLine, contains('MyService'));
    });

    test('returns snippet with highlight for short-name element', () async {
      final LibraryElement library = await _resolveLibrary('''
        class A {}
      ''');

      final ClassElement classElement = library.getClass('A')!;
      final SourceSnippet? snippet = extractSnippet(classElement);

      expect(snippet, isNotNull);
      expect(snippet!.highlightLength, 1);
    });

    test('handles element at beginning of file', () async {
      final LibraryElement library = await _resolveLibrary('''
class TopLevel {}
      ''');

      final ClassElement classElement = library.getClass('TopLevel')!;
      final SourceSnippet? snippet = extractSnippet(classElement);

      expect(snippet, isNotNull);
      expect(snippet!.startLineNumber, 1);
      expect(snippet.lines.any((l) => l.contains('TopLevel')), isTrue);
    });

    test('extracts snippet from element in multi-line file', () async {
      final LibraryElement library = await _resolveLibrary('''
        // 1
        // 2
        // 3
        // 4
        // 5
        // 6
        // 7
        // 8
        // 9
        // 10
        class DeepElement {}
        // 12
        // 13
        // 14
        // 15
      ''');

      final ClassElement classElement = library.getClass('DeepElement')!;
      final SourceSnippet? snippet = extractSnippet(classElement);

      expect(snippet, isNotNull);
      // Should have context lines around the element
      final String errorLine = snippet!.lines[snippet.errorLineIndex];
      expect(errorLine, contains('DeepElement'));
      expect(snippet.highlightLength, 'DeepElement'.length);
    });
  });
}
