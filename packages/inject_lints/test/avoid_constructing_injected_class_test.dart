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
    _writeExcludes('[test/**]');
    newFile('$testPackageRootPath/lib/classes.dart', _classes);
    final String path = '$testPackageTestPath/logger_test.dart';
    newFile(path, _testCode);
    await assertNoDiagnosticsInFile(path);
    // Outside the excluded files, the rule still reports.
    await assertLints('$_classes\nfinal logger = Logger();\n', ['…Logger']);
  }

  void _writeExcludes(String excludes) => newAnalysisOptionsYamlFile(
    testPackageRootPath,
    '${analysisOptionsContent(rules: [rule.name])}\n'
    'inject_lints:\n'
    '  rules:\n'
    '    avoid_constructing_injected_class:\n'
    '      exclude: $excludes\n',
  );

  Future<void> test_generatedFile() async {
    newFile('$testPackageRootPath/lib/classes.dart', _classes);
    final String path = '$testPackageLibPath/main.inject.dart';
    newFile(path, "import 'classes.dart';\n\nfinal logger = Logger();\n");
    await assertNoDiagnosticsInFile(path);
  }
}
