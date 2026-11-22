import 'package:inject_lints/src/rules/prefer_inject_over_provides.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'support.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(PreferInjectOverProvidesTest);
  });
}

@reflectiveTest
class PreferInjectOverProvidesTest extends InjectRuleTest {
  @override
  void setUp() {
    rule = PreferInjectOverProvides();
    newPackage('http_client').addFile('lib/http_client.dart', r'''
class Client {
  Client(this.name);
  final String name;
}
''');
    super.setUp();
  }

  Future<void> test_forwardsParameters() => assertLints(
    r'''
import 'package:inject_annotation/inject_annotation.dart';

class Api {}

class Repository {
  Repository(this.api);
  final Api api;
}

@module
class AppModule {
  @provides
  @singleton
  Repository provideRepository(Api api) => Repository(api);
}
''',
    ['provideRepository'],
  );

  Future<void> test_forwardsParameters_blockBody() => assertLints(
    r'''
import 'package:inject_annotation/inject_annotation.dart';

class Api {}

class Repository {
  Repository({required this.api});
  final Api api;
}

@module
class AppModule {
  @provides
  Repository provideRepository(Api api) {
    return Repository(api: api);
  }
}
''',
    ['provideRepository'],
  );

  Future<void> test_noParameters() => assertLints(
    r'''
import 'package:inject_annotation/inject_annotation.dart';

class Api {}

@module
class AppModule {
  @provides
  Api provideApi() => Api();
}
''',
    ['provideApi'],
  );

  Future<void> test_usesModuleField() => assertNoDiagnostics(r'''
import 'package:inject_annotation/inject_annotation.dart';

class Api {
  Api(this.baseUrl);
  final String baseUrl;
}

@module
class ApiModule {
  const ApiModule(this.baseUrl);
  final String baseUrl;

  @provides
  Api provideApi() => Api(baseUrl);
}
''');

  Future<void> test_usesLiteral() => assertNoDiagnostics(r'''
import 'package:inject_annotation/inject_annotation.dart';

class Api {
  Api(this.baseUrl);
  final String baseUrl;
}

@module
class ApiModule {
  @provides
  Api provideApi() => Api('https://example.com');
}
''');

  Future<void> test_bindsInterface() => assertNoDiagnostics(r'''
import 'package:inject_annotation/inject_annotation.dart';

abstract class Logger {}

class ConsoleLogger implements Logger {}

@module
class CoreModule {
  @provides
  Logger provideLogger() => ConsoleLogger();
}
''');

  Future<void> test_typeFromOtherPackage() => assertNoDiagnostics(r'''
import 'package:http_client/http_client.dart';
import 'package:inject_annotation/inject_annotation.dart';

@module
class NetworkModule {
  @provides
  Client provideClient(String name) => Client(name);
}
''');

  Future<void> test_asynchronous() => assertNoDiagnostics(r'''
import 'package:inject_annotation/inject_annotation.dart';

class Api {}

@module
class AppModule {
  @provides
  @asynchronous
  Future<Api> provideApi() async => Api();
}
''');

  Future<void> test_methodWithoutProvides() => assertNoDiagnostics(r'''
class Api {}

class ApiBuilder {
  Api build() => Api();
}
''');
}
