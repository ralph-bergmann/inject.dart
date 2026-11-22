import 'package:inject_lints/src/rules/require_valid_module_list.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'support.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(RequireValidModuleListTest);
  });
}

@reflectiveTest
class RequireValidModuleListTest extends InjectRuleTest {
  static const _declarations = r'''
import 'package:inject_annotation/inject_annotation.dart';

@module
class ApiModule {}

class Plain {}

@subcomponent
abstract class UserComponent {}
''';

  @override
  void setUp() {
    rule = RequireValidModuleList();
    super.setUp();
  }

  Future<void> test_duplicateModule() => assertLints(
    '''
$_declarations
@Component([ApiModule, ApiModule])
abstract class MainComponent {}
''',
    ['…ApiModule'],
  );

  Future<void> test_subcomponentAsModule() => assertLints(
    '''
$_declarations
@Component([UserComponent])
abstract class MainComponent {}
''',
    ['…UserComponent'],
  );

  Future<void> test_includesWithoutModule() => assertLints(
    '''
$_declarations
@Module(includes: [Plain])
class AppModule {}
''',
    ['…Plain'],
  );

  Future<void> test_subcomponentsWithoutSubcomponent() => assertLints(
    '''
$_declarations
@Module(subcomponents: [Plain])
class AppModule {}
''',
    ['…Plain'],
  );

  Future<void> test_valid() => assertNoDiagnostics('''
$_declarations
@Module(includes: [ApiModule], subcomponents: [UserComponent])
class AppModule {}

@Component([AppModule, ApiModule])
abstract class MainComponent {}

@Subcomponent([ApiModule])
abstract class OtherComponent {}
''');
}
