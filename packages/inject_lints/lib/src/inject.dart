import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/dart/analysis/uri_converter.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/file_system/file_system.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Skill names as they appear in the skills' frontmatter, so a reader (or a
/// coding agent) can load the matching skill straight from a diagnostic.
const createModuleSkill = "See the skill 'inject-annotation-create-module'.";
const setupSkill = "See the skill 'inject-annotation-setup-di'.";
const assistedInjectionSkill = "See the skill 'inject-annotation-add-assisted-injection'.";
const viewModelSkill = "See the skill 'inject-annotation-flutter-view-model'.";

/// Whether the options exclude the library that [context] analyzes from the
/// rule [ruleName].
///
/// The options live in a top-level `inject_lints` section of
/// `analysis_options.yaml`, because the plugin's `diagnostics` section only
/// takes `true`, `false` or a severity:
///
/// ```yaml
/// inject_lints:
///   rules:
///     avoid_constructing_injected_class:
///       exclude:
///         - test/**
/// ```
///
/// `exclude` works like the analyzer's own `analyzer: exclude`:
///
/// - Each pattern is a glob relative to the folder of the
///   `analysis_options.yaml` that the package uses, also when the pattern
///   comes from an included file. A shared file therefore applies its
///   patterns to each package that includes it.
/// - The package uses the nearest `analysis_options.yaml` at or above its
///   root. In a pub workspace, a package without its own file uses the file
///   of the workspace root.
/// - The lists of a file and the files it includes are combined.
/// - An `analysis_options.yaml` in a subfolder adds its own patterns,
///   relative to its folder. The patterns of the files above it still apply.
///
/// A `package:` include needs the library's session to resolve, so a rule
/// that runs on parsed results only skips such includes.
bool isExcludedFromRule(RuleContext context, String ruleName) {
  final Folder? root = context.package?.root;
  if (root == null) return false;
  final File file = context.definingUnit.file;
  final UriConverter? converter = context.libraryElement?.session.uriConverter;
  final p.Context pathContext = root.provider.pathContext;

  bool atOrAbovePackageRoot = false;
  for (Folder folder = file.parent; ; folder = folder.parent) {
    atOrAbovePackageRoot = atOrAbovePackageRoot || folder.path == root.path;
    final File options = folder.getFile('analysis_options.yaml');
    if (options.exists) {
      final String relative = p.posix.joinAll(pathContext.split(pathContext.relative(file.path, from: folder.path)));
      for (final String pattern in _readExcludes(options, ruleName, converter, {})) {
        try {
          if (Glob(pattern, context: p.posix).matches(relative)) return true;
        } on FormatException {
          // An invalid pattern excludes nothing.
        }
      }
      // This is the file the package uses; the files above it apply only through `include:`.
      if (atOrAbovePackageRoot) return false;
    }
    if (folder.isRoot) return false;
  }
}

/// The `exclude` patterns of [ruleName] in [file] and the files it includes.
///
/// As in the analyzer, the lists of all these files are combined. [seen]
/// stops include cycles.
Set<String> _readExcludes(File file, String ruleName, UriConverter? converter, Set<String> seen) {
  if (!seen.add(file.path) || !file.exists) return const {};
  final Object? options;
  try {
    options = loadYaml(file.readAsStringSync());
  } on Exception {
    return const {}; // The analyzer reports a broken options file itself.
  }

  final List<String> includes = switch (options) {
    {'include': final String include} => [include],
    {'include': final List<Object?> includes} => includes.whereType<String>().toList(),
    _ => const [],
  };
  final Object? rule = switch (options) {
    {'inject_lints': {'rules': final Map<Object?, Object?> rules}} => rules[ruleName],
    _ => null,
  };
  return {
    for (final String include in includes)
      if (_resolveInclude(file, include, converter) case final File included)
        ..._readExcludes(included, ruleName, converter, seen),
    if (rule case {'exclude': final List<Object?> excludes}) ...excludes.whereType<String>(),
  };
}

/// The file that the `include:` entry [include] in [from] points to: a path
/// relative to [from], or a `package:` URI.
File? _resolveInclude(File from, String include, UriConverter? converter) {
  final Uri? uri = Uri.tryParse(include);
  if (uri == null) return null;
  final p.Context pathContext = from.provider.pathContext;
  final String? path = uri.isScheme('package')
      ? converter?.uriToPath(uri)
      : pathContext.normalize(pathContext.join(from.parent.path, pathContext.fromUri(uri)));
  return path == null ? null : from.provider.getFile(path);
}

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
