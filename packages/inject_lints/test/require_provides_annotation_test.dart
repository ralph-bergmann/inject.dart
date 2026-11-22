import 'package:inject_lints/src/rules/require_provides_annotation.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'support.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(RequireProvidesAnnotationTest);
  });
}

@reflectiveTest
class RequireProvidesAnnotationTest extends InjectRuleTest {
  @override
  void setUp() {
    rule = RequireProvidesAnnotation();
    super.setUp();
  }

  Future<void> test_methodWithoutProvides() => assertLints(
    r'''
import 'package:inject_annotation/inject_annotation.dart';

@module
class AppModule {
  @provides
  String provideName() => 'name';

  int provideCount() => 1;
}
''',
    ['provideCount'],
  );

  Future<void> test_methodWithoutProvides_moduleWithArguments() => assertLints(
    r'''
import 'package:inject_annotation/inject_annotation.dart';

@Module(includes: [])
class AppModule {
  int provideCount() => 1;
}
''',
    ['provideCount'],
  );

  Future<void> test_helpersAndFields() => assertNoDiagnostics(r'''
import 'package:inject_annotation/inject_annotation.dart';

@module
class AppModule {
  const AppModule(this.baseUrl);

  final String baseUrl;

  static int defaultCount() => 1;

  int get count => _count();

  @provides
  int provideCount() => _count();

  int _count() => 1;
}
''');

  Future<void> test_classWithoutAnnotation() => assertNoDiagnostics(r'''
class AppModule {
  int provideCount() => 1;
}
''');
}
