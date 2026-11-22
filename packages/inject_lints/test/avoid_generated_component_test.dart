import 'package:inject_lints/src/rules/avoid_generated_component.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'support.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AvoidGeneratedComponentTest);
  });
}

@reflectiveTest
class AvoidGeneratedComponentTest extends InjectRuleTest {
  @override
  void setUp() {
    rule = AvoidGeneratedComponent();
    super.setUp();
    newFile('$testPackageLibPath/test.inject.dart', r'''
import 'test.dart';

class MainComponent$Component implements MainComponent {
  factory MainComponent$Component.create() => MainComponent$Component._();

  MainComponent$Component._();
}
''');
  }

  Future<void> test_createCalledOnGeneratedClass() => assertLints(
    r'''
import 'package:inject_annotation/inject_annotation.dart';

import 'test.inject.dart' as g;

@component
abstract class MainComponent {
  static const create = g.MainComponent$Component.create;
}

MainComponent f() => g.MainComponent$Component.create();
''',
    [r'…g.MainComponent$Component'],
  );

  Future<void> test_tearOffOfGeneratedClass() => assertLints(
    r'''
import 'package:inject_annotation/inject_annotation.dart';

import 'test.inject.dart' as g;

@component
abstract class MainComponent {}

const create = g.MainComponent$Component.create;
''',
    [r'g.MainComponent$Component'],
  );

  Future<void> test_createCalledOnComponent() => assertNoDiagnostics(r'''
import 'package:inject_annotation/inject_annotation.dart';

import 'test.inject.dart' as g;

@component
abstract class MainComponent {
  static const create = g.MainComponent$Component.create;
}

MainComponent f() => MainComponent.create();
''');

  Future<void> test_generatedLibraryItself() async {
    newFile(testFilePath, r'''
import 'package:inject_annotation/inject_annotation.dart';

@component
abstract class MainComponent {}
''');
    await assertNoDiagnosticsInFile('$testPackageLibPath/test.inject.dart');
  }
}
