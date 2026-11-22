import 'package:inject_lints/src/rules/prefer_single_entry_point.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'support.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(PreferSingleEntryPointTest);
  });
}

@reflectiveTest
class PreferSingleEntryPointTest extends InjectRuleTest {
  @override
  void setUp() {
    rule = PreferSingleEntryPoint();
    super.setUp();
  }

  Future<void> test_severalEntryPoints() => assertLints(
    r'''
import 'package:inject_annotation/inject_annotation.dart';

@component
abstract class MainComponent {
  @inject
  String get first;

  int get second;

  double third();
}
''',
    ['second', 'third'],
  );

  Future<void> test_severalEntryPoints_subcomponent() => assertLints(
    r'''
import 'package:inject_annotation/inject_annotation.dart';

@subcomponent
abstract class SessionComponent {
  String get first;

  int get second;
}
''',
    ['second'],
  );

  Future<void> test_singleEntryPoint() => assertNoDiagnostics(r'''
import 'package:inject_annotation/inject_annotation.dart';

@component
abstract class MainComponent {
  static String describe() => 'main';

  @inject
  String get first;
}
''');

  Future<void> test_classWithoutAnnotation() => assertNoDiagnostics(r'''
abstract class Repository {
  String get first;

  int get second;
}
''');
}
