import 'package:inject_lints/src/rules/require_valid_factory.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'support.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(RequireValidFactoryTest);
  });
}

@reflectiveTest
class RequireValidFactoryTest extends InjectRuleTest {
  static const _target = r'''
import 'package:inject_annotation/inject_annotation.dart';

class Logger {}

class Greeter {
  @assistedInject
  Greeter(Logger logger, {@assisted required String name});
}
''';

  @override
  void setUp() {
    rule = RequireValidFactory();
    super.setUp();
  }

  Future<void> test_valid() => assertNoDiagnostics('''
$_target
@assistedFactory
abstract class GreeterFactory {
  Greeter create({required String name});
}
''');

  Future<void> test_notAbstract() => assertLints(
    '''
$_target
@assistedFactory
class GreeterFactory {
  Greeter create({required String name}) => throw '';
}
''',
    ['GreeterFactory'],
  );

  Future<void> test_twoAbstractMethods() => assertLints(
    '''
$_target
@assistedFactory
abstract class GreeterFactory {
  Greeter create({required String name});
  Greeter other({required String name});
}
''',
    ['GreeterFactory'],
  );

  Future<void> test_targetWithoutAssistedInject() => assertLints(
    '''
$_target
@assistedFactory
abstract class LoggerFactory {
  Logger create();
}
''',
    ['LoggerFactory'],
  );

  Future<void> test_parameterMismatch() => assertLints(
    '''
$_target
@assistedFactory
abstract class GreeterFactory {
  Greeter create({required int name});
}
''',
    ['GreeterFactory'],
  );

  Future<void> test_missingNamedParameter() => assertLints(
    '''
$_target
@assistedFactory
abstract class GreeterFactory {
  Greeter create({required String title});
}
''',
    ['GreeterFactory'],
  );

  Future<void> test_subcomponentFactory() => assertNoDiagnostics(r'''
import 'package:inject_annotation/inject_annotation.dart';

@subcomponent
abstract class UserComponent {}

@subcomponentFactory
abstract class UserComponentFactory {
  UserComponent create();
}
''');

  Future<void> test_subcomponentFactoryWrongReturnType() => assertLints(
    r'''
import 'package:inject_annotation/inject_annotation.dart';

abstract class UserComponent {}

@subcomponentFactory
abstract class UserComponentFactory {
  UserComponent create();
}
''',
    ['UserComponentFactory'],
  );
}
