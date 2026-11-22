import 'package:inject_lints/src/rules/require_assisted_parameter.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'support.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(RequireAssistedParameterTest);
  });
}

@reflectiveTest
class RequireAssistedParameterTest extends InjectRuleTest {
  @override
  void setUp() {
    rule = RequireAssistedParameter();
    super.setUp();
  }

  Future<void> test_noAssistedParameter() => assertLints(
    r'''
import 'package:inject_annotation/inject_annotation.dart';

class Greeter {
  @assistedInject
  Greeter(String name);
}
''',
    ['(String name)'],
  );

  Future<void> test_assistedParameter() => assertNoDiagnostics(r'''
import 'package:inject_annotation/inject_annotation.dart';

class Greeter {
  @assistedInject
  Greeter(@assisted String name);

  @inject
  Greeter.other(String name);
}
''');
}
