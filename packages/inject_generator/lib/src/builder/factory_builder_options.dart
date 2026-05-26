import 'package:build/build.dart';
import 'package:logging/logging.dart';

/// Typed configuration parsed from `build.yaml` builder options for
/// `inject_generator|factory_builder`.
///
/// `factory_builder` currently accepts no options. Any key passed under
/// the `factory_builder` section produces a WARNING diagnostic, since
/// policy options like `nullable_duplicate_binding_policy` only take
/// effect under `inject_builder`.
class FactoryBuilderOptions {
  /// Creates the default `factory_builder` options.
  const FactoryBuilderOptions();

  /// Parses [options] into a [FactoryBuilderOptions] instance.
  ///
  /// Any key produces a single aggregated WARNING via [log], because
  /// `factory_builder` currently accepts no configurable options.
  factory FactoryBuilderOptions.fromBuilderOptions(BuilderOptions options, {Logger? log}) {
    final Map<String, dynamic> config = options.config;
    if (config.isEmpty) return defaults;

    final Logger logger = log ?? Logger('inject_generator');
    final String formattedKeys = config.keys.map((k) => "'$k'").join(', ');
    logger.warning(
      'inject_generator (factory_builder): Unknown build option(s): $formattedKeys. '
      'factory_builder accepts no options; configure policies under inject_builder instead.',
    );
    return defaults;
  }

  /// Default options — empty.
  static const defaults = FactoryBuilderOptions();
}
