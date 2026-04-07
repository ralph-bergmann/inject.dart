import 'package:build/build.dart';
import 'package:logging/logging.dart';

/// Policy for when both `Foo` and `Foo?` bindings exist for the same type.
///
/// Configure via `build.yaml`:
/// ```yaml
/// targets:
///   $default:
///     builders:
///       inject_generator|inject_builder:
///         options:
///           nullable_duplicate_binding_policy: error  # error | warn | allow
/// ```
enum NullableDuplicatePolicy {
  /// Hard error (default). Having both a nullable and a non-nullable binding
  /// for the same type is almost certainly a programming mistake.
  error,

  /// Warning only. Both bindings are kept; a WARNING diagnostic is emitted.
  warn,

  /// Silent. Both bindings are kept; no diagnostic is emitted.
  allow,
}

/// Typed configuration parsed from `build.yaml` builder options for
/// `inject_generator|inject_builder`.
///
/// Use [InjectBuilderOptions.fromBuilderOptions] to parse from a `BuilderOptions` instance.
class InjectBuilderOptions {
  /// Creates options with the given duplicate-binding policy and debug flag.
  const InjectBuilderOptions({
    this.nullableDuplicatePolicy = NullableDuplicatePolicy.error,
    this.debugGraph = false,
  });

  /// Parses [options] into an [InjectBuilderOptions] instance.
  ///
  /// Unknown keys produce a single aggregated WARNING via [log]. Malformed
  /// values (wrong Dart type, invalid enum string, missing value) produce a
  /// SEVERE log entry and fall back to the documented default for that key.
  factory InjectBuilderOptions.fromBuilderOptions(BuilderOptions options, {Logger? log}) {
    final Map<String, dynamic> config = options.config;
    final Logger logger = log ?? Logger('inject_generator');

    const validKeys = {'nullable_duplicate_binding_policy', 'debug_graph'};

    final List<String> unknownKeys = config.keys.where((k) => !validKeys.contains(k)).toList();
    if (unknownKeys.isNotEmpty) {
      final String formattedKeys = unknownKeys.map((k) => "'$k'").join(', ');
      final String validFormatted = validKeys.map((k) => "'$k'").join(', ');
      logger.warning(
        'inject_generator (inject_builder): Unknown build option(s): $formattedKeys. '
        'Valid options: $validFormatted.',
      );
    }

    NullableDuplicatePolicy policy = NullableDuplicatePolicy.error;
    if (config.containsKey('nullable_duplicate_binding_policy')) {
      policy = _parsePolicy(config['nullable_duplicate_binding_policy'], logger);
    }

    var debugGraph = false;
    if (config.containsKey('debug_graph')) {
      debugGraph = _parseBool(config['debug_graph'], 'debug_graph', logger, defaultValue: false);
    }

    return InjectBuilderOptions(nullableDuplicatePolicy: policy, debugGraph: debugGraph);
  }

  static bool _parseBool(Object? raw, String keyName, Logger logger, {required bool defaultValue}) {
    if (raw == null) {
      logger.severe(
        "inject_generator: '$keyName' has no value. "
        'Provide a bool (true or false). '
        'Falling back to default ($defaultValue).',
      );
      return defaultValue;
    }
    if (raw is! bool) {
      logger.severe(
        "inject_generator: '$keyName' must be a bool "
        '(got ${raw.runtimeType}). '
        'Falling back to default ($defaultValue).',
      );
      return defaultValue;
    }
    return raw;
  }

  static NullableDuplicatePolicy _parsePolicy(Object? raw, Logger logger) {
    if (raw == null) {
      logger.severe(
        "inject_generator: 'nullable_duplicate_binding_policy' has no value. "
        "Provide one of 'error', 'warn', 'allow'. "
        "Falling back to default ('error').",
      );
      return NullableDuplicatePolicy.error;
    }
    if (raw is! String) {
      logger.severe(
        "inject_generator: 'nullable_duplicate_binding_policy' must be a string "
        "(got ${raw.runtimeType}). Valid values: 'error', 'warn', 'allow'. "
        "Falling back to default ('error').",
      );
      return NullableDuplicatePolicy.error;
    }
    switch (raw) {
      case 'error':
        return NullableDuplicatePolicy.error;
      case 'warn':
        return NullableDuplicatePolicy.warn;
      case 'allow':
        return NullableDuplicatePolicy.allow;
      default:
        logger.severe(
          "inject_generator: Invalid value '$raw' for 'nullable_duplicate_binding_policy'. "
          "Valid values (case-sensitive): 'error', 'warn', 'allow'. "
          "Falling back to default ('error').",
        );
        return NullableDuplicatePolicy.error;
    }
  }

  /// Default options — all fields at their documented defaults.
  static const defaults = InjectBuilderOptions();

  /// Policy applied when both `Foo` and `Foo?` are bound for the same type.
  final NullableDuplicatePolicy nullableDuplicatePolicy;

  /// When `true`, prints a formatted dependency-graph tree to stdout for
  /// each validated component before code generation. Uses `print` (visible
  /// without `--verbose`) so the tree is immediately seen when the flag is set.
  ///
  /// Enable in `build.yaml` under `inject_generator|inject_builder: options:`
  /// with `debug_graph: true`. Off by default; has no performance impact when
  /// disabled. See `GraphPrinter` for the output format.
  final bool debugGraph;
}
