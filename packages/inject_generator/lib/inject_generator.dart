import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'src/builder/factory_builder.dart';
import 'src/builder/factory_builder_options.dart';
import 'src/builder/inject_builder.dart';
import 'src/builder/inject_builder_options.dart';

export 'src/builder/factory_builder.dart' show FactoryBuilder;
export 'src/builder/inject_builder.dart' show InjectBuilder;
export 'src/builder/inject_builder_options.dart' show InjectBuilderOptions;

/// Top-level factory function for build.yaml registration.
///
/// Creates a [LibraryBuilder] that generates `.inject.dart` files
/// using the [InjectBuilder] pipeline.
Builder injectBuilder(BuilderOptions options) {
  final parsedOptions = InjectBuilderOptions.fromBuilderOptions(options);
  return LibraryBuilder(InjectBuilder(options: parsedOptions), generatedExtension: '.inject.dart');
}

/// Top-level factory function for build.yaml registration.
///
/// Creates a [PartBuilder] that generates `.factory.dart` part files
/// using the [FactoryBuilder] pipeline.
Builder factoryBuilder(BuilderOptions options) {
  final parsedOptions = FactoryBuilderOptions.fromBuilderOptions(options);
  return PartBuilder([FactoryBuilder(options: parsedOptions)], '.factory.dart');
}
