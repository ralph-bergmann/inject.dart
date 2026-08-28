import 'package:inject_annotation/inject_annotation.dart';
import 'package:test/test.dart';

class FakeModuleA {}

class FakeModuleB {}

class FakeSubcomponent {}

class FakeIncludedModuleA {}

class FakeIncludedModuleB {}

void main() {
  group('Subcomponent', () {
    test('is constructible without modules', () {
      const annotation = Subcomponent();
      expect(annotation.modules, isEmpty);
    });

    test('is constructible with a module list', () {
      const annotation = Subcomponent([FakeModuleA, FakeModuleB]);
      expect(annotation.modules, [FakeModuleA, FakeModuleB]);
    });

    test('const instances are canonicalized', () {
      expect(identical(const Subcomponent(), const Subcomponent()), isTrue);
      expect(identical(const Subcomponent(), subcomponent), isTrue);
    });
  });

  group('Module', () {
    test('supports the subcomponents parameter', () {
      const annotation = Module(subcomponents: [FakeSubcomponent]);
      expect(annotation.subcomponents, [FakeSubcomponent]);
    });

    test('module const has an empty subcomponents list', () {
      expect(module.subcomponents, isEmpty);
      expect(identical(const Module(), module), isTrue);
    });

    test('supports the includes parameter', () {
      const annotation = Module(includes: [FakeIncludedModuleA, FakeIncludedModuleB]);
      expect(annotation.includes, [FakeIncludedModuleA, FakeIncludedModuleB]);
    });

    test('module const has an empty includes list', () {
      expect(module.includes, isEmpty);
    });

    test('supports both subcomponents and includes on the same annotation', () {
      const annotation = Module(subcomponents: [FakeSubcomponent], includes: [FakeIncludedModuleA]);
      expect(annotation.subcomponents, [FakeSubcomponent]);
      expect(annotation.includes, [FakeIncludedModuleA]);
    });
  });

  group('Component', () {
    test('const instances are canonicalized', () {
      expect(identical(const Component(), component), isTrue);
    });
  });

  group('SubcomponentFactory', () {
    test('subcomponentFactory constant is usable as an annotation value', () {
      expect(subcomponentFactory, isA<SubcomponentFactory>());
    });
  });
}
