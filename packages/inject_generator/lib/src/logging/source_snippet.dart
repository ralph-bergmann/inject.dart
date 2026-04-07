import 'dart:convert';
import 'dart:math' as math;

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:analyzer/source/source.dart';

/// An immutable source-code snippet with context lines and highlight marker.
///
/// Used by the diagnostic system to show the relevant source location
/// alongside error/warning/info messages — similar to the Dart analyzer
/// and Riverpod generator output style.
class SourceSnippet {
  /// Creates a source-code snippet.
  const SourceSnippet({
    required this.lines,
    required this.errorLineIndex,
    required this.highlightColumn,
    required this.highlightLength,
    required this.startLineNumber,
  });

  /// The source lines to display (context + error line).
  final List<String> lines;

  /// Index of the error line within [lines].
  final int errorLineIndex;

  /// Column position (0-based) where the highlight starts.
  final int highlightColumn;

  /// Number of `^` characters for the underline.
  final int highlightLength;

  /// The 1-based line number of the first displayed line.
  final int startLineNumber;

  /// Formats the snippet with line numbers, box-drawing borders, and
  /// a `^`-underline beneath the error token.
  ///
  /// Output example:
  /// ```text
  ///   ╷
  /// 3 │ class Foo {
  /// 4 │    @inject
  /// 5 │    @async
  ///   │    ^^^^^^
  /// 6 │    const Foo() {}
  /// 7 │ }
  ///   ╵
  /// ```
  String format() {
    final int lastLineNumber = startLineNumber + lines.length - 1;
    final int gutterWidth = lastLineNumber.toString().length;
    final String emptyGutter = ' ' * gutterWidth;
    final buffer = StringBuffer()..writeln('$emptyGutter ╷');

    for (var i = 0; i < lines.length; i++) {
      final String lineNum = (startLineNumber + i).toString().padLeft(gutterWidth);
      buffer.writeln('$lineNum │ ${lines[i]}');

      if (i == errorLineIndex) {
        final String padding = ' ' * highlightColumn;
        final String underline = '^' * highlightLength;
        buffer.writeln('$emptyGutter │ $padding$underline');
      }
    }

    buffer.writeln('$emptyGutter ╵');
    return buffer.toString();
  }
}

/// Extracts a [SourceSnippet] from the given [element], or returns `null`
/// if the source text is not available.
SourceSnippet? extractSnippet(Element element) {
  final Fragment fragment = element.firstFragment;
  final LibraryFragment? libraryFragment = fragment.libraryFragment;
  if (libraryFragment == null) {
    return null;
  }

  final Source source = libraryFragment.source;
  final String contents = source.contents.data;
  if (contents.isEmpty) {
    return null;
  }

  final int? offset = fragment.nameOffset;
  if (offset == null || offset < 0 || offset >= contents.length) {
    return null;
  }

  final CharacterLocation location = libraryFragment.lineInfo.getLocation(offset);
  final int errorLine = location.lineNumber; // 1-based
  final int errorColumn = location.columnNumber - 1; // convert to 0-based

  final List<String> allLines = const LineSplitter().convert(contents);
  final int totalLines = allLines.length;

  final int highlightLength = math.max(element.name?.length ?? 1, 1);

  // ±3 context lines around the error
  final int startLine = math.max(errorLine - 3, 1);
  final int endLine = math.min(errorLine + 3, totalLines);

  final List<String> snippetLines = allLines.sublist(startLine - 1, endLine);
  final int errorLineIndex = errorLine - startLine;

  return SourceSnippet(
    lines: snippetLines,
    errorLineIndex: errorLineIndex,
    highlightColumn: errorColumn,
    highlightLength: highlightLength,
    startLineNumber: startLine,
  );
}
