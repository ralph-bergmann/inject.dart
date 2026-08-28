import 'package:analyzer/dart/element/element.dart';

import '../analysis/inject_reader.dart';
import '../analysis/module_reader.dart';
import '../extensions/string_extensions.dart';
import '../logging/diagnostic_reporter.dart';
import 'binding_key.dart';

/// Validates module-level and injectable-level constraints before graph resolution.
///
/// Three checks:
/// - Private class used as `@module` (cannot be instantiated outside its library).
/// - Dart reserved word used as a class name in a codegen-sensitive position.
/// - Qualified and unqualified provider for the same base type in the same module.
class ModuleValidator {
  /// Creates a [ModuleValidator] reporting through the given [DiagnosticReporter].
  ModuleValidator({required this._reporter});
  final DiagnosticReporter _reporter;

  static const _dartReservedAndBuiltinIdentifiers = <String>{
    // Category A: Dart reserved words (never allowed as identifiers)
    'assert', 'break', 'case', 'catch', 'class', 'const', 'continue',
    'default', 'do', 'else', 'enum', 'extends', 'false', 'final',
    'finally', 'for', 'if', 'in', 'is', 'new', 'null', 'rethrow',
    'return', 'super', 'switch', 'this', 'throw', 'true', 'try',
    'var', 'void', 'while', 'with',
    // Category B: Built-in identifiers problematic in param/field position
    'abstract', 'as', 'covariant', 'deferred', 'dynamic', 'export',
    'external', 'factory', 'get', 'implements', 'import', 'interface',
    'late', 'library', 'mixin', 'operator', 'part', 'required',
    'set', 'static', 'typedef',
  };

  /// Validates each module class: public visibility, reserved-word names,
  /// and qualified/unqualified binding conflicts.
  void validateModules(List<({ClassElement moduleClass, ModuleData moduleData})> modules) {
    for (final (:moduleClass, :moduleData) in modules) {
      final String? name = moduleClass.name;
      if (name == null) {
        continue;
      }

      // A private class cannot be used as a module — the generated Component
      // cannot instantiate it from outside the library.
      if (name.startsWith('_')) {
        _reporter.errorForElement(
          moduleClass,
          message:
              "Module class '$name' must be public. "
              'Remove the leading underscore or make the class public.',
          suggestion: "Rename '$name' to '${name.substring(1)}' or move it to a public library.",
        );
        continue;
      }

      // A class whose uncapitalized name is a Dart reserved word will produce
      // an invalid identifier when codegen writes `name.uncapitalize` as a
      // constructor parameter or field name.
      if (_dartReservedAndBuiltinIdentifiers.contains(name.uncapitalize)) {
        _reporter.errorForElement(
          moduleClass,
          message:
              "Module class name '$name' is a Dart reserved word. "
              'Rename the class to avoid invalid generated code.',
          suggestion:
              'Choose a name that does not conflict with Dart keywords, '
              'e.g. rename to ${name}Module.',
        );
      }

      _checkQualifiedUnqualifiedConflict(moduleClass, moduleData);
    }
  }

  /// Validates each `@inject` class name against Dart reserved words to
  /// avoid invalid generated identifiers.
  void validateInjectables(List<({ClassElement classElement, InjectableData injectable})> injectables) {
    for (final (:classElement, injectable: _) in injectables) {
      final String? name = classElement.name;
      if (name == null) {
        continue;
      }

      // Same reserved-word guard for injectable types — codegen uses
      // `typeName.uncapitalize` as a provider base name or field name.
      if (_dartReservedAndBuiltinIdentifiers.contains(name.uncapitalize)) {
        _reporter.errorForElement(
          classElement,
          message:
              "Type name '$name' is a Dart reserved word. "
              'Rename the class to avoid invalid generated code.',
          suggestion: 'Choose a name that does not conflict with Dart keywords.',
        );
      }
    }
  }

  void _checkQualifiedUnqualifiedConflict(ClassElement moduleClass, ModuleData moduleData) {
    // Group non-listener providers by base type identity (ignoring qualifier).
    final Map<String, List<({String? qualifier, String displayKey})>> byType = {};
    for (final ProviderDescriptor provider in moduleData.providers) {
      if (provider.metadata.isProvisionListener) {
        continue;
      }
      final BindingKey key = provider.key;
      byType.putIfAbsent(key.typeIdentity, () => []).add(
        (qualifier: key.qualifier, displayKey: key.debugLabel),
      );
    }

    for (final List<({String? qualifier, String displayKey})> entries in byType.values) {
      if (entries.length < 2) {
        continue;
      }

      final bool hasUnqualified = entries.any((e) => e.qualifier == null);
      final List<({String? qualifier, String displayKey})> qualifiedEntries = entries
          .where((e) => e.qualifier != null)
          .toList();

      if (!hasUnqualified || qualifiedEntries.isEmpty) {
        continue;
      }

      final String unqualifiedLabel = entries.firstWhere((e) => e.qualifier == null).displayKey;
      final String qualifiedList = qualifiedEntries.map((e) => "'${e.displayKey}'").join(', ');
      _reporter.warningForElement(
        moduleClass,
        message:
            "Module '${moduleClass.name}' provides both a qualified "
            "($qualifiedList) and an unqualified ('$unqualifiedLabel') "
            'binding for the same type. This is usually a mistake.',
        suggestion:
            'If this is intentional, ignore this warning. '
            'Otherwise, remove one of the providers or add a qualifier to the unqualified one.',
      );
    }
  }
}
