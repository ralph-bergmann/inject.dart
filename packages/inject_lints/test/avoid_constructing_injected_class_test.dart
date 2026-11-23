import 'package:analyzer_testing/utilities/utilities.dart';
import 'package:inject_lints/src/rules/avoid_constructing_injected_class.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'support.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AvoidConstructingInjectedClassTest);
  });
}

@reflectiveTest
class AvoidConstructingInjectedClassTest extends InjectRuleTest {
  @override
  void setUp() {
    rule = AvoidConstructingInjectedClass();
    newPackage('shared_lints').addFile('lib/options.yaml', _excludeTests);
    super.setUp();
  }

  static const _classes = r'''
import 'package:inject_annotation/inject_annotation.dart';

@inject
class Logger {}

class ApiClient {
  @inject
  const ApiClient();
}

class Greeter {
  @assistedInject
  Greeter(Logger logger, {@assisted required String name});

  factory Greeter.silent(Logger logger) => Greeter(logger, name: '');
}

class Plain {}
''';

  Future<void> test_injectedClass() => assertLints('$_classes\nfinal logger = Logger();\n', ['…Logger']);

  Future<void> test_injectedConstructor() => assertLints('$_classes\nconst client = ApiClient();\n', ['…ApiClient']);

  Future<void> test_assistedInjectedConstructor() =>
      assertLints("$_classes\nfinal greeter = Greeter(Logger(), name: 'a');\n", ['…Greeter', '…Logger']);

  Future<void> test_plainClass() => assertNoDiagnostics('$_classes\nfinal plain = Plain();\n');

  static const _testCode = "import '../lib/classes.dart';\n\nfinal logger = Logger();\n";

  Future<void> test_testDirectory() async {
    newFile('$testPackageRootPath/lib/classes.dart', _classes);
    final String path = '$testPackageTestPath/logger_test.dart';
    newFile(path, _testCode);
    await assertDiagnosticsInFile(path, [lint(_testCode.lastIndexOf('Logger'), 6)]);
  }

  Future<void> test_excludedTestDirectory() async {
    _writeOptions(extra: _excludeTests);
    await _assertTestFileNotReported();
    // Outside the excluded files, the rule still reports.
    await assertLints('$_classes\nfinal logger = Logger();\n', ['…Logger']);
  }

  Future<void> test_nestedOptionsFile() async {
    // A nested options file's patterns are relative to its own folder.
    newFile(
      '$testPackageTestPath/analysis_options.yaml',
      'include: ../analysis_options.yaml\n${_exclude('logger_test.dart')}',
    );
    await _assertTestFileNotReported();
    await assertLints('$_classes\nfinal logger = Logger();\n', ['…Logger']);
  }

  Future<void> test_nestedOptionsFileKeepsParentExcludes() async {
    _writeOptions(extra: _excludeTests);
    newFile('$testPackageTestPath/analysis_options.yaml', 'include: ../analysis_options.yaml\n');
    await _assertTestFileNotReported();
  }

  Future<void> test_optionsFileAboveThePackage() async {
    // A pub workspace member without its own options file uses the workspace
    // root's file. Its globs are relative to that file's folder.
    deleteFile('$testPackageRootPath/analysis_options.yaml');
    _writeParentOptions(_exclude('*/test/**'));
    await _assertTestFileNotReported();
  }

  Future<void> test_packageOptionsFileHidesTheFileAbove() async {
    // As in the analyzer, the nearest options file at or above the package
    // root wins; the file above it applies only through an include.
    _writeParentOptions(_exclude('*/test/**'));
    _writeOptions();
    newFile('$testPackageRootPath/lib/classes.dart', _classes);
    final String path = '$testPackageTestPath/logger_test.dart';
    newFile(path, _testCode);
    await assertDiagnosticsInFile(path, [lint(_testCode.lastIndexOf('Logger'), 6)]);
  }

  void _writeParentOptions(String extra) => newAnalysisOptionsYamlFile(
    resourceProvider.pathContext.dirname(testPackageRootPath),
    '${analysisOptionsContent(rules: [rule.name])}\n$extra',
  );

  Future<void> test_relativeInclude() async {
    newFile('$testPackageRootPath/shared.yaml', _excludeTests);
    _writeOptions(includes: ['shared.yaml']);
    await _assertTestFileNotReported();
  }

  Future<void> test_packageInclude() async {
    _writeOptions(includes: ['package:shared_lints/options.yaml']);
    await _assertTestFileNotReported();
  }

  Future<void> test_includedListsAreCombined() async {
    newFile('$testPackageRootPath/shared.yaml', _excludeTests);
    _writeOptions(includes: ['shared.yaml'], extra: _exclude('lib/other/**'));
    await _assertTestFileNotReported();
  }

  static final _excludeTests = _exclude('test/**');

  static String _exclude(String pattern) =>
      'inject_lints:\n'
      '  rules:\n'
      '    avoid_constructing_injected_class:\n'
      "      exclude: ['$pattern']\n";

  void _writeOptions({List<String> includes = const [], String extra = ''}) => newAnalysisOptionsYamlFile(
    testPackageRootPath,
    '${analysisOptionsContent(includes: includes, rules: [rule.name])}\n$extra',
  );

  Future<void> _assertTestFileNotReported() async {
    newFile('$testPackageRootPath/lib/classes.dart', _classes);
    final String path = '$testPackageTestPath/logger_test.dart';
    newFile(path, _testCode);
    await assertNoDiagnosticsInFile(path);
  }

  Future<void> test_generatedFile() async {
    newFile('$testPackageRootPath/lib/classes.dart', _classes);
    final String path = '$testPackageLibPath/main.inject.dart';
    newFile(path, "import 'classes.dart';\n\nfinal logger = Logger();\n");
    await assertNoDiagnosticsInFile(path);
  }
}
