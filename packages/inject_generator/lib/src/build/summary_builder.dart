// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:collection/collection.dart';

import '../analyzer/utils.dart';
import '../analyzer/visitors.dart';
import '../context.dart';
import '../source/symbol_path.dart';
import '../summary.dart';
import 'builder_utils.dart';

/// Extracts metadata about modules and components from Dart libraries.
class InjectSummaryBuilder implements Builder {
  /// Constructor.
  const InjectSummaryBuilder();

  @override
  Map<String, List<String>> get buildExtensions => {
        summaryInputExtension: [
          summaryOutputExtension,
          componentOutputExtension,
        ],
      };

  @override
  Future<void> build(BuildStep buildStep) => runInContext<void>(buildStep, () => _buildInContext(buildStep));

  Future<void> _buildInContext(BuildStep buildStep) async {
    final resolver = buildStep.resolver;
    final isLibrary = await resolver.isLibrary(buildStep.inputId);
    if (!isLibrary) {
      final contents = await buildStep.readAsString(buildStep.inputId);
      if (contents.contains(RegExp(r'part\s+of'))) {
        builderContext.rawLogger.info(
          'Skipping ${buildStep.inputId} because it is a part file.',
        );
      } else {
        builderContext.rawLogger.severe(
          'Failed to analyze ${buildStep.inputId}. Please check that the '
          'file is a valid Dart library.',
        );
      }
      return;
    }

    final lib = await buildStep.inputLibrary;
    if (!_hasInjectImports(lib)) {
      return;
    }

    final components = <ComponentSummary>[];
    final modules = <ModuleSummary>[];
    final injectables = <InjectableSummary>[];
    final assistedInjectables = <InjectableSummary>[];
    final factories = <FactorySummary>[];
    _SummaryBuilderVisitor(
      components,
      modules,
      injectables,
      assistedInjectables,
      factories,
    ).visitLibrary(lib);

    if (components.isNotEmpty) {
      final componentsSummary = ComponentsSummary(SymbolPath.toAssetUri(lib.source.uri), components: components);
      final content = _componentsSummaryToJson(componentsSummary);
      await saveContent(
        buildStep,
        summaryInputExtension,
        componentOutputExtension,
        content,
      );
    }

    if (modules.isNotEmpty || injectables.isNotEmpty || assistedInjectables.isNotEmpty || factories.isNotEmpty) {
      final librarySummary = LibrarySummary(
        SymbolPath.toAssetUri(lib.source.uri),
        modules: modules,
        injectables: injectables,
        assistedInjectables: assistedInjectables,
        factories: factories,
      );
      final content = _librarySummaryToJson(librarySummary);
      await saveContent(
        buildStep,
        summaryInputExtension,
        summaryOutputExtension,
        content,
      );
    }
  }

  bool _hasInjectImports(LibraryElement library) => library.nonCoreImports.any((import) {
        final uri = import.importedLibrary?.source.uri;
        return uri?.toString() == 'package:inject_annotation/inject_annotation.dart';
      });
}

extension NonCoreImports on LibraryElement {
  Iterable<LibraryImportElement> get nonCoreImports => library.libraryImports.where((element) {
        final lib = element.importedLibrary;
        if (lib == null) {
          return false;
        }

        return !lib.isDartAsync && //
            !lib.isDartCore &&
            !lib.isInSdk;
      });
}

class _SummaryBuilderVisitor extends InjectLibraryVisitor {
  final List<ComponentSummary> _components;
  final List<ModuleSummary> _modules;
  final List<InjectableSummary> _injectables;
  final List<InjectableSummary> _assistedInjectables;
  final List<FactorySummary> _factories;

  const _SummaryBuilderVisitor(
    this._components,
    this._modules,
    this._injectables,
    this._assistedInjectables,
    this._factories,
  );

  @override
  void visitInjectable(ClassElement clazz, bool singleton) {
    final classIsAnnotated = hasInjectAnnotation(clazz);
    final annotatedConstructors = clazz.constructors.where(hasInjectAnnotation);

    if (classIsAnnotated && annotatedConstructors.isNotEmpty) {
      throw StateError(
        constructMessage(
          builderContext.buildStep.inputId,
          clazz,
          'has @inject annotation on both the class and on one of the '
          'constructors. Please annotate one or the other,  but not both.',
        ),
      );
    }

    if (classIsAnnotated && clazz.constructors.length > 1) {
      throw StateError(
        constructMessage(
          builderContext.buildStep.inputId,
          clazz,
          'has more than one constructor. Please annotate one of the '
          'constructors instead of the class.',
        ),
      );
    }

    if (annotatedConstructors.length > 1) {
      throw StateError(
        constructMessage(
          builderContext.buildStep.inputId,
          clazz,
          'no more than one constructor may be annotated with @inject.',
        ),
      );
    }

    ProviderSummary? constructorSummary;
    if (annotatedConstructors.length == 1) {
      // Use the explicitly annotated constructor.
      final constructor = annotatedConstructors.single;
      constructorSummary = _createConstructorProviderSummary(
        constructor,
        singleton,
        false,
        constructor.isConst,
      );
    } else if (classIsAnnotated) {
      if (clazz.constructors.length <= 1) {
        // This is the case of a default or an only constructor.
        final constructor = clazz.constructors.single;
        constructorSummary = _createConstructorProviderSummary(
          constructor,
          singleton,
          false,
          constructor.isConst,
        );
      }
    }

    if (constructorSummary != null) {
      _injectables.add(
        InjectableSummary(getSymbolPath(clazz.thisType), constructorSummary),
      );
    }
  }

  @override
  void visitAssistedInjectable(ClassElement clazz) {
    final classIsAnnotated = hasAssistedInjectAnnotation(clazz);
    final annotatedConstructors = clazz.constructors.where(hasAssistedInjectAnnotation);

    if (classIsAnnotated && annotatedConstructors.isNotEmpty) {
      throw StateError(
        constructMessage(
          builderContext.buildStep.inputId,
          clazz,
          'has @assistedInject annotation on both the class and on one of the '
          'constructors. Please annotate one or the other,  but not both.',
        ),
      );
    }

    if (classIsAnnotated && clazz.constructors.length > 1) {
      throw StateError(
        constructMessage(
          builderContext.buildStep.inputId,
          clazz,
          'has more than one constructor. Please annotate one of the '
          'constructors instead of the class.',
        ),
      );
    }

    if (annotatedConstructors.length > 1) {
      throw StateError(
        constructMessage(
          builderContext.buildStep.inputId,
          clazz,
          'no more than one constructor may be annotated with @assistedInject.',
        ),
      );
    }

    ProviderSummary? constructorSummary;
    if (annotatedConstructors.length == 1) {
      // Use the explicitly annotated constructor.
      final constructor = annotatedConstructors.single;
      constructorSummary = _createConstructorProviderSummary(
        constructor,
        false,
        true,
        constructor.isConst,
      );
    } else if (classIsAnnotated) {
      if (clazz.constructors.length <= 1) {
        // This is the case of a default or an only constructor.
        final constructor = clazz.constructors.single;
        constructorSummary = _createConstructorProviderSummary(
          constructor,
          false,
          true,
          constructor.isConst,
        );
      }
    }

    if (constructorSummary != null) {
      _assistedInjectables.add(
        InjectableSummary(
          getSymbolPath(clazz.thisType),
          constructorSummary,
        ),
      );
    }
  }

  @override
  void visitAssistedFactory(ClassElement clazz) {
    if (!clazz.hasDefaultConstructor()) {
      throw StateError(
        constructMessage(
          builderContext.buildStep.inputId,
          clazz,
          'factory class should have no constructor or only the default constructor.',
        ),
      );
    }

    final visitor = _FactorySummaryVisitor()..visitClass(clazz);
    if (visitor._factories.isEmpty) {
      throw StateError(
        constructMessage(
          builderContext.buildStep.inputId,
          clazz,
          'factory class is missing an abstract, non-default method, usually '
          'called `create`, whose return type matches the assisted injection '
          'type and whose parameters match all @assisted-annotated parameters '
          'of the injected class.',
        ),
      );
    } else if (visitor._factories.length > 1) {
      throw StateError(
        constructMessage(
          builderContext.buildStep.inputId,
          clazz,
          'factory class should contain a single abstract, non-default method but '
          'found multiple.',
        ),
      );
    } else {
      _factories.add(
        FactorySummary(
          getSymbolPath(clazz.thisType),
          visitor._factories.single,
        ),
      );
    }
  }

  @override
  void visitComponent(ClassElement clazz, List<SymbolPath> modules) {
    final visitor = _ProviderSummaryVisitor(true)..visitClass(clazz);
    if (visitor._providers.isEmpty) {
      throw StateError(
        constructMessage(
          builderContext.buildStep.inputId,
          clazz,
          'component class must declare at least one @inject-annotated provider',
        ),
      );
    }
    final summary = ComponentSummary(
      getSymbolPath(clazz.thisType),
      modules,
      visitor._providers,
    );
    _components.add(summary);
  }

  @override
  void visitModule(ClassElement clazz) {
    final visitor = _ProviderSummaryVisitor(false)..visitClass(clazz);
    if (visitor._providers.isEmpty) {
      throw StateError(
        constructMessage(
          builderContext.buildStep.inputId,
          clazz,
          'module class must declare at least one @provides-annotated provider',
        ),
      );
    }
    for (final ps in visitor._providers) {
      if (ps.kind == ProviderKind.getter) {
        throw StateError(
          constructMessage(
            builderContext.buildStep.inputId,
            clazz,
            'module class must not declare providers as getters, '
            'but only as methods.',
          ),
        );
      }
    }

    final summary = ModuleSummary(
      getSymbolPath(clazz.thisType),
      clazz.hasDefaultConstructor(),
      visitor._providers,
    );
    _modules.add(summary);
  }
}

class _FactorySummaryVisitor extends FactoryClassVisitor {
  final List<FactoryMethodSummary> _factories = <FactoryMethodSummary>[];

  @override
  void visitFactoryMethod(MethodElement method) {
    if (!method.isAbstract) {
      throw StateError(
        constructMessage(
          builderContext.buildStep.inputId,
          method,
          'factory methods must be abstract.',
        ),
      );
    }
    if (method.returnType.isDartCoreFunction) {
      throw StateError(
        constructMessage(
          builderContext.buildStep.inputId,
          method,
          'factory methods can only return a class and not a function',
        ),
      );
    }

    _checkReturnType(method);

    final summary = FactoryMethodSummary(
      method.name,
      getInjectedType(method.returnType, isAssisted: true),
      method.parameters
          .map((p) {
            if (p.type is DynamicType) {
              throw StateError(
                constructMessage(
                    builderContext.buildStep.inputId,
                    p.enclosingElement,
                    'Parameter named `${p.name}` resolved to dynamic. This can '
                    'happen when the return type is not specified, when it is '
                    'specified as `dynamic`, or when the return type failed to '
                    'resolve to a proper type due to a bad import or a typo. Do '
                    'make sure that there are no analyzer warnings in your '
                    'code.'),
              );
            }

            return getInjectedType(
              p.type,
              name: p.name,
              isRequired: p.isRequired,
              isNamed: p.isNamed,
              qualifier: hasQualifier(p) ? extractQualifier(p) : null,
            );
          })
          .whereNotNull()
          .toList(),
    );
    _factories.add(summary);
  }
}

class _ProviderSummaryVisitor extends InjectClassVisitor {
  final List<ProviderSummary> _providers = <ProviderSummary>[];

  _ProviderSummaryVisitor(super.isForComponent);

  @override
  void visitProvideMethod(MethodElement method, bool singleton, bool asynchronous, {SymbolPath? qualifier}) {
    if (isForComponent && !method.isAbstract) {
      throw StateError(
        constructMessage(
          builderContext.buildStep.inputId,
          method,
          'providers declared on component class must be abstract.',
        ),
      );
    }
    if (asynchronous && !(method.returnType.isDartAsyncFuture)) {
      throw StateError(
        constructMessage(
          builderContext.buildStep.inputId,
          method,
          'asynchronous provider must return a Future.',
        ),
      );
    }

    _checkReturnType(method);

    final summary = ProviderSummary(
      method.name,
      ProviderKind.method,
      getInjectedType(method.returnType, qualifier: qualifier, isSingleton: singleton),
      dependencies: method.parameters.map((p) {
        if (isForComponent) {
          throw StateError(
            constructMessage(
              builderContext.buildStep.inputId,
              p,
              'component methods cannot have parameters',
            ),
          );
        } else if (p.type is DynamicType) {
          throw StateError(
            constructMessage(
              builderContext.buildStep.inputId,
              p.enclosingElement,
              'Parameter named `${p.name}` resolved to dynamic. This can '
              'happen when the return type is not specified, when it is '
              'specified as `dynamic`, or when the return type failed to '
              'resolve to a proper type due to a bad import or a typo. Do '
              'make sure that there are no analyzer warnings in your '
              'code.',
            ),
          );
        }

        return getInjectedType(
          p.type,
          name: p.name,
          qualifier: hasQualifier(p) ? extractQualifier(p) : null,
          isRequired: p.isRequired,
          isNamed: p.isNamed,
          isAssisted: hasAssistedAnnotation(p),
        );
      }).whereNotNull(),
    );
    _providers.add(summary);
  }

  @override
  void visitProvideGetter(FieldElement field, bool singleton, {SymbolPath? qualifier}) {
    _checkReturnType(field.getter!);
    final returnType = field.getter!.returnType;
    final summary = ProviderSummary(
      field.name,
      ProviderKind.getter,
      getInjectedType(returnType, qualifier: qualifier, isSingleton: singleton),
      dependencies: const [],
    );
    _providers.add(summary);
  }
}

void _checkReturnType(ExecutableElement element) {
  final returnType = element.returnType;
  final returnTypeElement = returnType.element;

  if (returnTypeElement?.kind == ElementKind.DYNAMIC ||
      returnTypeElement is TypeDefiningElement && returnTypeElement.kind == ElementKind.DYNAMIC) {
    throw StateError(
      constructMessage(
        builderContext.buildStep.inputId,
        element,
        'return type resolved to dynamic. This can happen when the '
        'return type is not specified, when it is specified as `dynamic`, or '
        'when the return type failed to resolve to a proper type due to a '
        'bad import or a typo. Do make sure that there are no analyzer '
        'warnings in your code.',
      ),
    );
  }
}

ProviderSummary _createConstructorProviderSummary(
  ConstructorElement element,
  bool isSingleton,
  bool isAssisted,
  bool isConst,
) {
  final returnType = element.enclosingElement.thisType;
  return ProviderSummary(
    element.name,
    ProviderKind.constructor,
    getInjectedType(
      returnType,
      isSingleton: isSingleton,
      isAssisted: isAssisted,
      isConst: isConst,
    ),
    dependencies: element.parameters.map((p) {
      SymbolPath? qualifier;
      if (hasQualifier(p)) {
        qualifier = extractQualifier(p);
      } else if (p.isInitializingFormal) {
        // In the example of:
        //
        // @someQualifier
        // final String _some;
        //
        // Clazz(this._some);
        //
        // Extract @someQualifier as the qualifier.
        final clazz = element.enclosingElement;
        final formal = clazz.getField(p.name)!;
        if (hasQualifier(formal)) {
          qualifier = extractQualifier(formal);
        }
      }

      if (p.type is DynamicType) {
        throw StateError(
          constructMessage(
            builderContext.buildStep.inputId,
            p,
            'a constructor argument type resolved to dynamic. This can '
            'happen when the return type is not specified, when it is '
            'specified as `dynamic`, or when the return type failed '
            'to resolve to a proper type due to a bad import or a '
            'typo. Do make sure that there are no analyzer warnings '
            'in your code.',
          ),
        );
      }

      return getInjectedType(
        p.type,
        name: p.name,
        qualifier: qualifier,
        isRequired: p.isRequired,
        isNamed: p.isNamed,
        isAssisted: hasAssistedAnnotation(p),
      );
    }).whereNotNull(),
  );
}

String _librarySummaryToJson(LibrarySummary library) => const JsonEncoder.withIndent('  ').convert(library.toJson());

String _componentsSummaryToJson(ComponentsSummary components) =>
    const JsonEncoder.withIndent('  ').convert(components.toJson());

extension _ClassElement on ClassElement {
  /// true if it has no constructor or a default constructor
  bool hasDefaultConstructor() =>
      constructors.isEmpty || constructors.where((constructor) => !constructor.isDefaultConstructor).isEmpty;
}
