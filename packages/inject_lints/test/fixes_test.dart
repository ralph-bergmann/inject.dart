import 'package:inject_lints/src/fixes.dart';
import 'package:inject_lints/src/rules/avoid_asynchronous_on_inject.dart';
import 'package:inject_lints/src/rules/avoid_inject_constructor_in_component.dart';
import 'package:inject_lints/src/rules/require_abstract_component.dart';
import 'package:inject_lints/src/rules/require_assisted_parameter.dart';
import 'package:inject_lints/src/rules/require_provides_annotation.dart';
import 'package:inject_lints/src/rules/require_valid_factory.dart';
import 'package:inject_lints/src/rules/require_valid_module_list.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'support.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AddAbstractComponentTest);
    defineReflectiveTests(AddAbstractFactoryTest);
    defineReflectiveTests(AddProvidesTest);
    defineReflectiveTests(RemoveAsynchronousTest);
    defineReflectiveTests(RemoveInjectAnnotationTest);
    defineReflectiveTests(ReplaceWithInjectTest);
    defineReflectiveTests(RemoveDuplicateEntryTest);
  });
}

const _import = "import 'package:inject_annotation/inject_annotation.dart';\n";

@reflectiveTest
class AddAbstractComponentTest extends InjectRuleTest {
  @override
  void setUp() {
    rule = RequireAbstractComponent();
    super.setUp();
  }

  Future<void> test_addAbstract() => assertFix(
    '$_import\n@component\nclass MainComponent {}\n',
    'MainComponent',
    AddAbstract.new,
    '$_import\n@component\nabstract class MainComponent {}\n',
  );
}

@reflectiveTest
class AddAbstractFactoryTest extends InjectRuleTest {
  @override
  void setUp() {
    rule = RequireValidFactory();
    super.setUp();
  }

  Future<void> test_addAbstract() => assertFix(
    '$_import\n@subcomponent\nabstract class UserComponent {}\n\n'
        '@subcomponentFactory\nclass UserFactory {\n  UserComponent create() => throw 0;\n}\n',
    'UserFactory',
    AddAbstract.new,
    '$_import\n@subcomponent\nabstract class UserComponent {}\n\n'
        '@subcomponentFactory\nabstract class UserFactory {\n  UserComponent create() => throw 0;\n}\n',
  );
}

@reflectiveTest
class AddProvidesTest extends InjectRuleTest {
  @override
  void setUp() {
    rule = RequireProvidesAnnotation();
    super.setUp();
  }

  Future<void> test_addProvides() => assertFix(
    '$_import\n@module\nclass AppModule {\n  /// The count.\n  int provideCount() => 1;\n}\n',
    'provideCount',
    AddProvides.new,
    '$_import\n@module\nclass AppModule {\n  /// The count.\n  @provides\n  int provideCount() => 1;\n}\n',
  );

  Future<void> test_addProvides_prefixed() => assertFix(
    "import 'package:inject_annotation/inject_annotation.dart' as di;\n\n"
        '@di.module\nclass AppModule {\n  int provideCount() => 1;\n}\n',
    'provideCount',
    AddProvides.new,
    "import 'package:inject_annotation/inject_annotation.dart' as di;\n\n"
        '@di.module\nclass AppModule {\n  @di.provides\n  int provideCount() => 1;\n}\n',
  );
}

@reflectiveTest
class RemoveAsynchronousTest extends InjectRuleTest {
  @override
  void setUp() {
    rule = AvoidAsynchronousOnInject();
    super.setUp();
  }

  Future<void> test_remove() => assertFix(
    '$_import\n@inject\n@asynchronous\nclass Repository {}\n',
    '@asynchronous',
    RemoveAsynchronous.new,
    '$_import\n@inject\nclass Repository {}\n',
  );
}

@reflectiveTest
class RemoveInjectAnnotationTest extends InjectRuleTest {
  @override
  void setUp() {
    rule = AvoidInjectConstructorInComponent();
    super.setUp();
  }

  Future<void> test_remove() => assertFix(
    '$_import\n@component\nabstract class MainComponent {\n  @inject\n  MainComponent();\n}\n',
    '…MainComponent',
    RemoveInjectAnnotation.new,
    '$_import\n@component\nabstract class MainComponent {\n  MainComponent();\n}\n',
  );
}

@reflectiveTest
class ReplaceWithInjectTest extends InjectRuleTest {
  @override
  void setUp() {
    rule = RequireAssistedParameter();
    super.setUp();
  }

  Future<void> test_replace() => assertFix(
    '$_import\nclass Greeter {\n  @assistedInject\n  Greeter(String name);\n}\n',
    '(String name)',
    ReplaceWithInject.new,
    '$_import\nclass Greeter {\n  @inject\n  Greeter(String name);\n}\n',
  );
}

@reflectiveTest
class RemoveDuplicateEntryTest extends InjectRuleTest {
  @override
  void setUp() {
    rule = RequireValidModuleList();
    super.setUp();
  }

  Future<void> test_remove() => assertFix(
    '$_import\n@module\nclass ApiModule {}\n\n@Component([ApiModule, ApiModule])\nabstract class MainComponent {}\n',
    '…ApiModule',
    RemoveDuplicateEntry.new,
    '$_import\n@module\nclass ApiModule {}\n\n@Component([ApiModule])\nabstract class MainComponent {}\n',
  );
}
