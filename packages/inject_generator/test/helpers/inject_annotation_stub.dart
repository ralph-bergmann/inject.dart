/// Minimal stub of the `inject_annotation` package for `testBuilder`.
///
/// Provides just enough type definitions for
/// `TypeChecker.typeNamed(..., inPackage: 'inject_annotation')` to match
/// annotations when using `testBuilder`'s in-memory filesystem.
const _injectAnnotationStub = '''
class Component {
  final List<Type> modules;
  const factory Component([List<Type> modules]) = Component._;
  const Component._([this.modules = const <Type>[]]);
}
const component = Component();

class Module {
  final List<Type> subcomponents;
  final List<Type> includes;
  const factory Module({List<Type> subcomponents, List<Type> includes}) = Module._;
  const Module._({this.subcomponents = const <Type>[], this.includes = const <Type>[]});
}
const module = Module._();

class Subcomponent {
  final List<Type> modules;
  const factory Subcomponent([List<Type> modules]) = Subcomponent._;
  const Subcomponent._([this.modules = const <Type>[]]);
}
const subcomponent = Subcomponent();

class SubcomponentFactory { const SubcomponentFactory._(); }
const subcomponentFactory = SubcomponentFactory._();

class Inject { const Inject._(); }
const inject = Inject._();

class Provides { const Provides._(); }
const provides = Provides._();

class Singleton { const Singleton._(); }
const singleton = Singleton._();

class Asynchronous { const Asynchronous._(); }
const asynchronous = Asynchronous._();

class Qualifier {
  final Symbol name;
  const factory Qualifier(Symbol name) = Qualifier._;
  const Qualifier._(this.name);
}

class AssistedInject { const AssistedInject._(); }
const assistedInject = AssistedInject._();

class Assisted { const Assisted._(); }
const assisted = Assisted._();

class AssistedFactory { const AssistedFactory._(); }
const assistedFactory = AssistedFactory._();

class ProvisionListenerAnnotation { const ProvisionListenerAnnotation._(); }
const provisionListener = ProvisionListenerAnnotation._();

abstract class ProvisionListener<T> {
  void onProvision(T instance);
}

abstract class Provider<T> {
  T get();
}
''';

/// Source assets for the `inject_annotation` package.
///
/// Spread into `testBuilder`'s `sourceAssets` map so that
/// `import 'package:inject_annotation/inject_annotation.dart'` resolves
/// inside `testBuilder`'s in-memory filesystem.
const Map<String, String> injectAnnotationAssets = {
  'inject_annotation|lib/inject_annotation.dart': _injectAnnotationStub,
};
