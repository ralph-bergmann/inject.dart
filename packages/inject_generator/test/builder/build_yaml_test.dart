import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  group('build.yaml', () {
    late YamlMap buildYaml;
    late YamlMap builders;

    setUpAll(() {
      final String content = _findBuildYaml().readAsStringSync();
      buildYaml = loadYaml(content) as YamlMap;
      builders = buildYaml['builders'] as YamlMap;
    });

    // Task 1.1: both builders registered
    test('registers both factory_builder and inject_builder', () {
      expect(builders, contains('factory_builder'));
      expect(builders, contains('inject_builder'));
    });

    // Task 1.2: runs_before ordering
    test('factory_builder has runs_before inject_builder', () {
      final factoryBuilder = builders['factory_builder'] as YamlMap;
      final runsBefore = factoryBuilder['runs_before'] as YamlList;
      expect(runsBefore, contains('inject_generator|inject_builder'));
    });

    // Task 1.3: build_extensions
    group('build_extensions', () {
      test('factory_builder produces .factory.dart', () {
        final factoryBuilder = builders['factory_builder'] as YamlMap;
        final extensions = factoryBuilder['build_extensions'] as YamlMap;
        final dartExtensions = extensions['.dart'] as YamlList;
        expect(dartExtensions, contains('.factory.dart'));
      });

      test('inject_builder produces .inject.dart', () {
        final injectBuilder = builders['inject_builder'] as YamlMap;
        final extensions = injectBuilder['build_extensions'] as YamlMap;
        final dartExtensions = extensions['.dart'] as YamlList;
        expect(dartExtensions, contains('.inject.dart'));
      });
    });

    // Task 1.4: auto_apply and build_to
    group('auto_apply and build_to', () {
      test('factory_builder has auto_apply dependents and build_to source', () {
        final factoryBuilder = builders['factory_builder'] as YamlMap;
        expect(factoryBuilder['auto_apply'], equals('dependents'));
        expect(factoryBuilder['build_to'], equals('source'));
      });

      test('inject_builder has auto_apply dependents and build_to source', () {
        final injectBuilder = builders['inject_builder'] as YamlMap;
        expect(injectBuilder['auto_apply'], equals('dependents'));
        expect(injectBuilder['build_to'], equals('source'));
      });
    });

    // Task 1.5: import and builder_factories
    group('import and builder_factories', () {
      test('factory_builder imports inject_generator and uses factoryBuilder', () {
        final factoryBuilder = builders['factory_builder'] as YamlMap;
        expect(factoryBuilder['import'], equals('package:inject_generator/inject_generator.dart'));
        final factories = factoryBuilder['builder_factories'] as YamlList;
        expect(factories, contains('factoryBuilder'));
      });

      test('inject_builder imports inject_generator and uses injectBuilder', () {
        final injectBuilder = builders['inject_builder'] as YamlMap;
        expect(injectBuilder['import'], equals('package:inject_generator/inject_generator.dart'));
        final factories = injectBuilder['builder_factories'] as YamlList;
        expect(factories, contains('injectBuilder'));
      });
    });
  });
}

/// Resolves `build.yaml` regardless of the working directory.
///
/// Supports execution from both `packages/inject_generator/` and the
/// workspace root.
File _findBuildYaml() {
  // CWD is packages/inject_generator/
  final direct = File('build.yaml');
  if (direct.existsSync()) return direct;

  // CWD is the monorepo workspace root
  final fromRoot = File(p.join('packages', 'inject_generator', 'build.yaml'));
  if (fromRoot.existsSync()) return fromRoot;

  throw StateError(
    'Could not find build.yaml. '
    'Run from packages/inject_generator/ or the workspace root.',
  );
}
