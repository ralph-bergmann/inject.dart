import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

/// Skill names as they appear in the skills' frontmatter, so a reader (or a
/// coding agent) can load the matching skill straight from a diagnostic.
const createModuleSkill = "See the skill 'inject-annotation-create-module'.";
const setupSkill = "See the skill 'inject-annotation-setup-di'.";
const assistedInjectionSkill = "See the skill 'inject-annotation-add-assisted-injection'.";
const viewModelSkill = "See the skill 'inject-annotation-flutter-view-model'.";

/// Whether [element] is declared in the pub package named [package].
bool isFromPackage(Element element, String package) =>
    element.library?.uri.toString().startsWith('package:$package/') ?? false;

/// Whether [element] carries an inject.dart annotation whose class name is in
/// [classNames], for example `{'Component', 'Subcomponent'}`.
///
/// The check uses the constant value, so it treats `@inject` and a qualifier
/// constant such as `@baseUrl` the same way as a constructor call.
bool hasAnnotation(Element? element, Set<String> classNames) => findAnnotation(element, classNames) != null;

/// The first inject.dart annotation on [element] whose class name is in
/// [classNames], or `null`.
ElementAnnotation? findAnnotation(Element? element, Set<String> classNames) {
  if (element == null) return null;
  for (final ElementAnnotation annotation in element.metadata.annotations) {
    final Element? type = annotation.computeConstantValue()?.type?.element;
    if (type != null && classNames.contains(type.name) && isFromPackage(type, 'inject_annotation')) {
      return annotation;
    }
  }
  return null;
}

/// The symbol name of the `@Qualifier` on [element], such as `baseUrl` for
/// `@Qualifier(#baseUrl)`, or `null` without a qualifier.
String? readQualifier(Element element) =>
    findAnnotation(element, const {'Qualifier'})?.computeConstantValue()?.getField('name')?.toSymbolValue();

/// Whether the generator can turn [qualifier] into part of a class name.
bool isValidQualifier(String qualifier) => RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(qualifier);

/// Whether the class [element] or one of its constructors is annotated with
/// `@inject` or `@assistedInject`.
bool isInjected(InterfaceElement element) {
  const names = {'Inject', 'AssistedInject'};
  return hasAnnotation(element, names) || element.constructors.any((c) => hasAnnotation(c, names));
}

/// Whether [element] has the Flutter class [className] among its supertypes.
bool extendsFlutterClass(InterfaceElement element, String className) =>
    element.allSupertypes.any((type) => type.element.name == className && isFromPackage(type.element, 'flutter'));

/// Whether [type] is something the dependency graph hands out: an injected
/// class, a factory, a component, `Provider<T>` or `ViewModelFactory<T>`.
///
/// shortcut: a type that only a `@provides` method binds (a third-party class
/// or an interface) is not recognized, because the type itself does not show
/// it. Upgrade when rules can see all modules of a package.
bool isGraphType(DartType type) {
  final Element? alias = type.alias?.element;
  if (alias != null && alias.name == 'ViewModelFactory' && isFromPackage(alias, 'inject_flutter')) {
    return true;
  }
  if (type is! InterfaceType) return false;

  final InterfaceElement element = type.element;
  if (element.name == 'Provider' && isFromPackage(element, 'inject_annotation')) return true;
  if (isInjected(element)) return true;
  if (hasAnnotation(element, const {'Component', 'Subcomponent', 'AssistedFactory', 'SubcomponentFactory'})) {
    return true;
  }

  // A generated factory has no annotation: it is an abstract class with one
  // abstract method that returns the injected type or the subcomponent.
  if (element is ClassElement && element.isAbstract) {
    final List<MethodElement> abstractMethods = element.methods.where((m) => m.isAbstract).toList();
    if (abstractMethods.length == 1) {
      final DartType created = abstractMethods.single.returnType;
      return created is InterfaceType &&
          (isInjected(created.element) || hasAnnotation(created.element, const {'Subcomponent'}));
    }
  }
  return false;
}
