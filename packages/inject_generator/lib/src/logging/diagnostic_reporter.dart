import 'package:analyzer/dart/element/element.dart';
import 'package:logging/logging.dart';

import '../extensions/element_extensions.dart';
import 'source_snippet.dart';

/// Severity level for a diagnostic message.
enum DiagnosticSeverity {
  /// A fatal issue that blocks code generation.
  error,

  /// A non-fatal issue that does not block code generation.
  warning,

  /// An informational notice that does not indicate a problem.
  info,
}

/// An immutable diagnostic message with structured context.
///
/// Each message includes the source location (file path and line number),
/// a human-readable problem description, and a concrete fix suggestion.
class DiagnosticMessage {
  /// Creates a new diagnostic message.
  const DiagnosticMessage({
    required this.severity,
    required this.filePath,
    required this.line,
    required this.column,
    required this.message,
    this.suggestion,
    this.snippet,
  });

  /// The severity of this diagnostic.
  final DiagnosticSeverity severity;

  /// The file path where the issue was found.
  final String filePath;

  /// The line number where the issue was found.
  final int line;

  /// A human-readable description of the problem.
  final String message;

  /// A concrete suggestion for how to fix the problem.
  final String? suggestion;

  /// The column number where the issue was found.
  final int column;

  /// An optional source-code snippet showing the error location.
  final SourceSnippet? snippet;

  String _indentBlock(String value, {required String prefix}) =>
      value.split('\n').map((line) => '$prefix$line').join('\n');

  /// Returns the formatted diagnostic message for build output.
  ///
  /// Format (with snippet):
  /// ```text
  /// [inject_generator] {ERROR|WARNING} in {filePath}:{line}:{column}
  ///   ╷
  /// 3 │ class Foo {
  /// 4 │   @inject
  ///   │   ^^^^^^
  /// 5 │ }
  ///   ╵
  ///   {message}
  ///   → {suggestion}
  /// ```
  String get formattedMessage => [
    '[inject_generator] ${switch (severity) {
      DiagnosticSeverity.error => 'ERROR',
      DiagnosticSeverity.warning => 'WARNING',
      DiagnosticSeverity.info => 'INFO',
    }} in $filePath:$line:$column',
    if (snippet != null) snippet!.format().trimRight(),
    _indentBlock(message, prefix: '  '),
    if (suggestion != null && suggestion!.isNotEmpty) _indentBlock(suggestion!, prefix: '  → '),
  ].join('\n');
}

/// Collects and formats diagnostic messages from all generator phases.
///
/// This is the single point of contact for reporting user-facing issues.
/// All pipeline phases (analysis, validation, code generation) report
/// through this class instead of using ad-hoc logging or thrown exceptions.
class DiagnosticReporter {
  final List<DiagnosticMessage> _diagnostics = [];

  /// Reports a fatal error that will block code generation.
  void error({
    required String filePath,
    required int line,
    required int column,
    required String message,
    String? suggestion,
    SourceSnippet? snippet,
  }) {
    _diagnostics.add(
      DiagnosticMessage(
        severity: DiagnosticSeverity.error,
        filePath: filePath,
        line: line,
        column: column,
        message: message,
        suggestion: suggestion,
        snippet: snippet,
      ),
    );
  }

  /// Reports a non-fatal warning that does not block code generation.
  void warning({
    required String filePath,
    required int line,
    required int column,
    required String message,
    String? suggestion,
    SourceSnippet? snippet,
  }) {
    _diagnostics.add(
      DiagnosticMessage(
        severity: DiagnosticSeverity.warning,
        filePath: filePath,
        line: line,
        column: column,
        message: message,
        suggestion: suggestion,
        snippet: snippet,
      ),
    );
  }

  /// Reports an informational notice that does not indicate a problem.
  void info({
    required String filePath,
    required int line,
    required int column,
    required String message,
    String? suggestion,
    SourceSnippet? snippet,
  }) {
    _diagnostics.add(
      DiagnosticMessage(
        severity: DiagnosticSeverity.info,
        filePath: filePath,
        line: line,
        column: column,
        message: message,
        suggestion: suggestion,
        snippet: snippet,
      ),
    );
  }

  /// Returns `true` if any error-severity diagnostic was collected.
  bool get hasErrors => _diagnostics.any((d) => d.severity == DiagnosticSeverity.error);

  /// Returns the number of error-severity diagnostics collected.
  int get errorCount => _diagnostics.where((d) => d.severity == DiagnosticSeverity.error).length;

  /// Returns the number of warning-severity diagnostics collected.
  int get warningCount => _diagnostics.where((d) => d.severity == DiagnosticSeverity.warning).length;

  /// Returns the number of info-severity diagnostics collected.
  int get infoCount => _diagnostics.where((d) => d.severity == DiagnosticSeverity.info).length;

  /// Returns an unmodifiable list of all collected diagnostics.
  List<DiagnosticMessage> get messages => List.unmodifiable(_diagnostics);

  /// Reports all collected diagnostics to the given [logger].
  ///
  /// Errors are logged at [Level.SEVERE], warnings at [Level.WARNING].
  void reportToLog(Logger logger) {
    for (final DiagnosticMessage diagnostic in _diagnostics) {
      switch (diagnostic.severity) {
        case DiagnosticSeverity.error:
          logger.severe(diagnostic.formattedMessage);
        case DiagnosticSeverity.warning:
          logger.warning(diagnostic.formattedMessage);
        case DiagnosticSeverity.info:
          logger.info(diagnostic.formattedMessage);
      }
    }
  }

  /// Flushes all collected diagnostics to the given [logger] and returns
  /// whether code generation may proceed.
  ///
  /// Each diagnostic is logged individually (errors at [Level.SEVERE],
  /// warnings at [Level.WARNING]), followed by a summary line at
  /// [Level.INFO]. If no diagnostics were collected, nothing is logged.
  ///
  /// Returns `true` if generation may proceed (no errors), `false` if
  /// at least one error was collected.
  ///
  /// This method should be called once per build. Calling it multiple times
  /// on the same instance will emit all diagnostics and the summary line
  /// again for each call.
  bool flushToLog(Logger logger) {
    if (_diagnostics.isEmpty) {
      return true;
    }
    reportToLog(logger);
    final bool hasErrors = this.hasErrors;
    final outcome = hasErrors ? 'failed' : 'completed';
    logger.info('[inject_generator] Build $outcome with $errorCount error(s) and $warningCount warning(s).');
    return !hasErrors;
  }
}

/// Convenience extension for reporting diagnostics tied to an [Element].
extension DiagnosticReporterExt on DiagnosticReporter {
  /// Reports a fatal error located at the source position of [element].
  void errorForElement(Element element, {required String message, String? suggestion}) {
    final (String filePath, int lineNumber, int column) = element.elementPosition;
    final SourceSnippet? snippet = extractSnippet(element);
    error(
      filePath: filePath,
      line: lineNumber,
      column: column,
      message: message,
      suggestion: suggestion,
      snippet: snippet,
    );
  }

  /// Reports a non-fatal warning located at the source position of [element].
  void warningForElement(Element element, {required String message, String? suggestion}) {
    final (String filePath, int lineNumber, int column) = element.elementPosition;
    final SourceSnippet? snippet = extractSnippet(element);
    warning(
      filePath: filePath,
      line: lineNumber,
      column: column,
      message: message,
      suggestion: suggestion,
      snippet: snippet,
    );
  }

  /// Reports an informational notice located at the source position of [element].
  void infoForElement(Element element, {required String message, String? suggestion}) {
    final (String filePath, int lineNumber, int column) = element.elementPosition;
    final SourceSnippet? snippet = extractSnippet(element);
    info(
      filePath: filePath,
      line: lineNumber,
      column: column,
      message: message,
      suggestion: suggestion,
      snippet: snippet,
    );
  }
}
