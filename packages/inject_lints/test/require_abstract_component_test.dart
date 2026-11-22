import 'package:inject_lints/src/rules/require_abstract_component.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'support.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(RequireAbstractComponentTest);
  });
}

@reflectiveTest
class RequireAbstractComponentTest extends InjectRuleTest {
  @override
  void setUp() {
    rule = RequireAbstractComponent();
    super.setUp();
  }

  Future<void> test_concreteComponent() => assertLints(
    r'''
import 'package:inject_annotation/inject_annotation.dart';

@component
class MainComponent {}
''',
    ['MainComponent'],
  );

  Future<void> test_concreteSubcomponent() => assertLints(
    r'''
import 'package:inject_annotation/inject_annotation.dart';

@Subcomponent([])
class SessionComponent {}
''',
    ['SessionComponent'],
  );

  Future<void> test_abstractComponent() => assertNoDiagnostics(r'''
import 'package:inject_annotation/inject_annotation.dart';

@component
abstract class MainComponent {}
''');

  Future<void> test_classWithoutAnnotation() => assertNoDiagnostics(r'''
class MainComponent {}
''');
}
