import 'package:inject_lints/src/rules/require_unambiguous_inject_constructor.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'support.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(RequireUnambiguousInjectConstructorTest);
  });
}

@reflectiveTest
class RequireUnambiguousInjectConstructorTest extends InjectRuleTest {
  @override
  void setUp() {
    rule = RequireUnambiguousInjectConstructor();
    super.setUp();
  }

  Future<void> test_severalWithoutQualifier() => assertLints(
    r'''
import 'package:inject_annotation/inject_annotation.dart';

class Client {
  @inject
  Client();

  @inject
  Client.other();
}
''',
    ['Client'],
  );

  Future<void> test_duplicateQualifier() => assertLints(
    r'''
import 'package:inject_annotation/inject_annotation.dart';

class Client {
  @inject
  @Qualifier(#a)
  Client();

  @inject
  @Qualifier(#a)
  Client.other();
}
''',
    ['Client'],
  );

  Future<void> test_invalidQualifier() => assertLints(
    r'''
import 'package:inject_annotation/inject_annotation.dart';

class Client {
  @assistedInject
  @Qualifier(#a)
  Client(@assisted int x);

  @assistedInject
  @Qualifier(#b.c)
  Client.other(@assisted int x);
}
''',
    ['Client'],
  );

  Future<void> test_classLevelWithoutUnnamedConstructor() => assertLints(
    r'''
import 'package:inject_annotation/inject_annotation.dart';

@inject
class Client {
  Client.a();
  Client.b();
}
''',
    ['Client'],
  );

  Future<void> test_valid() => assertNoDiagnostics(r'''
import 'package:inject_annotation/inject_annotation.dart';

@inject
class Single {
  Single.named();
}

@inject
class WithUnnamed {
  WithUnnamed();
  WithUnnamed.other();
}

class Qualified {
  @inject
  @Qualifier(#a)
  Qualified();

  @inject
  @Qualifier(#b)
  Qualified.other();
}
''');
}
