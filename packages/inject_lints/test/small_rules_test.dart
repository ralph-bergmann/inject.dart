import 'package:inject_lints/src/rules/avoid_asynchronous_on_inject.dart';
import 'package:inject_lints/src/rules/avoid_inject_constructor_in_component.dart';
import 'package:inject_lints/src/rules/avoid_qualified_and_unqualified_provider.dart';
import 'package:inject_lints/src/rules/require_provision_listener_type.dart';
import 'package:inject_lints/src/rules/require_public_module.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'support.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(RequirePublicModuleTest);
    defineReflectiveTests(AvoidAsynchronousOnInjectTest);
    defineReflectiveTests(AvoidQualifiedAndUnqualifiedProviderTest);
    defineReflectiveTests(AvoidInjectConstructorInComponentTest);
    defineReflectiveTests(RequireProvisionListenerTypeTest);
  });
}

@reflectiveTest
class RequirePublicModuleTest extends InjectRuleTest {
  @override
  void setUp() {
    rule = RequirePublicModule();
    super.setUp();
  }

  Future<void> test_privateModule() => assertLints(
    r'''
import 'package:inject_annotation/inject_annotation.dart';

@module
class _AppModule {}

@module
class ApiModule {}

class _Helper {}
''',
    ['_AppModule'],
  );
}

@reflectiveTest
class AvoidAsynchronousOnInjectTest extends InjectRuleTest {
  @override
  void setUp() {
    rule = AvoidAsynchronousOnInject();
    super.setUp();
  }

  Future<void> test_onClassAndConstructor() => assertLints(
    r'''
import 'package:inject_annotation/inject_annotation.dart';

@asynchronous
class Repository {
  @inject
  @asynchronous
  Repository();
}
''',
    ['@asynchronous', '…@asynchronous'],
  );

  Future<void> test_notInjected() => assertNoDiagnostics(r'''
import 'package:inject_annotation/inject_annotation.dart';

@asynchronous
class Repository {}
''');
}

@reflectiveTest
class AvoidQualifiedAndUnqualifiedProviderTest extends InjectRuleTest {
  @override
  void setUp() {
    rule = AvoidQualifiedAndUnqualifiedProvider();
    super.setUp();
  }

  Future<void> test_mixed() => assertLints(
    r'''
import 'package:inject_annotation/inject_annotation.dart';

@module
class AppModule {
  @provides
  @Qualifier(#baseUrl)
  String provideBaseUrl() => 'a';

  @provides
  String provideName() => 'b';

  @provides
  int provideCount() => 1;
}
''',
    ['provideName'],
  );

  Future<void> test_asyncUnwrapsFuture() => assertLints(
    r'''
import 'package:inject_annotation/inject_annotation.dart';

@module
class AppModule {
  @provides
  @Qualifier(#baseUrl)
  String provideBaseUrl() => 'a';

  @provides
  @asynchronous
  Future<String> provideName() async => 'b';
}
''',
    ['provideName'],
  );

  Future<void> test_onlyQualified() => assertNoDiagnostics(r'''
import 'package:inject_annotation/inject_annotation.dart';

@module
class AppModule {
  @provides
  @Qualifier(#a)
  String provideA() => 'a';

  @provides
  @Qualifier(#b)
  String provideB() => 'b';
}
''');
}

@reflectiveTest
class AvoidInjectConstructorInComponentTest extends InjectRuleTest {
  @override
  void setUp() {
    rule = AvoidInjectConstructorInComponent();
    super.setUp();
  }

  Future<void> test_injectConstructor() => assertLints(
    r'''
import 'package:inject_annotation/inject_annotation.dart';

@component
abstract class MainComponent {
  @inject
  MainComponent();
}

class Service {
  @inject
  Service();
}
''',
    ['…MainComponent'],
  );
}

@reflectiveTest
class RequireProvisionListenerTypeTest extends InjectRuleTest {
  @override
  void setUp() {
    rule = RequireProvisionListenerType();
    super.setUp();
  }

  Future<void> test_wrongType() => assertLints(
    r'''
import 'package:inject_annotation/inject_annotation.dart';

class Logger implements ProvisionListener<Object> {
  @override
  void onProvision(Object instance) {}
}

@module
class AppModule {
  @provides
  @provisionListener
  Logger provideLogger() => Logger();

  @provides
  @provisionListener
  String provideName() => 'a';
}
''',
    ['String'],
  );
}
