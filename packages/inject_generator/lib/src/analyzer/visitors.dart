// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/visitor.dart';

import '../context.dart';
import '../source/symbol_path.dart';
import 'utils.dart';

/// Scans a resolved [LibraryElement] looking for metadata-annotated members.
///
/// Looks for:
/// - [visitInjectable]: Classes or constructors annotated with `@inject`.
/// - [visitAssistedFactory]: Classes or constructors annotated with `@assistedFactory`.
/// - [visitComponent]: Classes annotated with `@component`.
/// - [visitModule]: Classes annotated with `@module`.
abstract class InjectLibraryVisitor {
  const InjectLibraryVisitor();

  /// Call to start visiting [library].
  void visitLibrary(LibraryElement library) {
    _LibraryVisitor(this).visitLibraryElement(library);
  }

  /// Called when [clazz] is annotated with `@inject`.
  ///
  /// If [clazz] is annotated with `@singleton`, then [singleton] is true.
  void visitInjectable(ClassElement clazz, bool singleton);

  /// Called when [clazz] is annotated with `@assistedInject`.
  void visitAssistedInjectable(ClassElement clazz);

  /// Called when [clazz] is annotated with `@assistedFactory`.
  void visitAssistedFactory(ClassElement clazz);

  /// Called when [clazz] is annotated with `@component`.
  ///
  /// [modules] is the list of types supplied as modules in the annotation.
  ///
  /// Example:
  ///
  ///     @Component(const [FooModule, BarModule])
  ///     class Services {
  ///       ...
  ///     }
  ///
  /// In this example, [modules] will contain references to `FooModule` and
  /// `BarModule` types.
  void visitComponent(ClassElement clazz, List<SymbolPath> modules);

  /// Called when [clazz] is annotated with `@module`.
  void visitModule(ClassElement clazz);
}

class _LibraryVisitor extends RecursiveElementVisitor<void> {
  final InjectLibraryVisitor _injectLibraryVisitor;

  const _LibraryVisitor(this._injectLibraryVisitor);

  @override
  void visitClassElement(ClassElement element) {
    var isInjectable = false;
    var isAssistedInjectable = false;
    var isAssistedFactory = false;
    var isModule = false;
    var isComponent = false;

    var count = 0;
    if (isInjectableClass(element)) {
      isInjectable = true;
      count++;
    }
    if (isAssistedInjectableClass(element)) {
      isAssistedInjectable = true;
      count++;
    }
    if (isAssistedFactoryClass(element)) {
      isAssistedFactory = true;
      count++;
    }
    if (isModuleClass(element)) {
      isModule = true;
      count++;
    }
    if (isComponentClass(element)) {
      isComponent = true;
      count++;
    }

    if (count > 1) {
      final types = [
        isInjectable ? 'injectable' : null,
        isAssistedFactory ? 'isAssistedFactory' : null,
        isModule ? 'module' : null,
        isComponent ? 'component' : null,
      ].nonNulls;

      throw StateError(
        constructMessage(
          builderContext.buildStep.inputId,
          element,
          'A class may be an injectable, a module or an component, '
          'but not more than one of these types. However class '
          '${element.name} was found to be ${types.join(' and ')}',
        ),
      );
    }

    if (isInjectable) {
      final singleton = isSingletonClass(element);
      final asynchronous = hasAsynchronousAnnotation(element) || element.constructors.any(hasAsynchronousAnnotation);
      if (asynchronous) {
        throw StateError(
          constructMessage(
            builderContext.buildStep.inputId,
            element,
            'Classes and constructors cannot be annotated with @Asynchronous().',
          ),
        );
      }
      _injectLibraryVisitor.visitInjectable(
        element,
        singleton,
      );
    }
    if (isAssistedInjectable) {
      final singleton = isSingletonClass(element);
      if (singleton) {
        throw StateError(
          constructMessage(
            builderContext.buildStep.inputId,
            element,
            'Classes and constructors cannot be annotated with @Singleton().',
          ),
        );
      }
      final asynchronous = hasAsynchronousAnnotation(element) || element.constructors.any(hasAsynchronousAnnotation);
      if (asynchronous) {
        throw StateError(
          constructMessage(
            builderContext.buildStep.inputId,
            element,
            'Classes and constructors cannot be annotated with @Asynchronous().',
          ),
        );
      }
      _injectLibraryVisitor.visitAssistedInjectable(element);
    }
    if (isAssistedFactory) {
      _injectLibraryVisitor.visitAssistedFactory(element);
    }
    if (isModule) {
      _injectLibraryVisitor.visitModule(element);
    }
    if (isComponent) {
      _injectLibraryVisitor.visitComponent(
        element,
        _extractModules(element),
      );
    }
    return;
  }
}

List<SymbolPath> _extractModules(ClassElement clazz) {
  final annotation = getComponentAnnotation(clazz);
  final modules = annotation?.computeConstantValue()?.getField('modules')?.toListValue();
  if (modules == null) {
    return const <SymbolPath>[];
  }
  return modules.map((obj) => obj.toTypeValue()).nonNulls.map(getSymbolPath).toList();
}

/// Scans a resolved [ClassElement] looking for metadata-annotated members.
abstract class InjectClassVisitor {
  const InjectClassVisitor(this.isForComponent);

  /// Whether we are collecting providers for an component class or a module class.
  final bool isForComponent;

  /// Call to start visiting [clazz].
  void visitClass(ClassElement clazz) {
    for (final supertype in clazz.allSupertypes.where((t) => !t.isDartCoreObject)) {
      _AnnotatedClassVisitor(this).visitElement(supertype.element);
    }
    _AnnotatedClassVisitor(this).visitClassElement(clazz);
  }

  /// Called when a method is annotated with `@provides`.
  ///
  /// [singleton] is `true` when the method is also annotated with
  /// `@singleton`.
  ///
  /// [asynchronous] is `true` when the method is also annotated with
  /// `@asynchronous`.
  ///
  /// [qualifier] is non-null when the method is also annotated with
  /// an annotation created by `const Qualifier(...)`.
  void visitProvideMethod(
    MethodElement method,
    bool singleton,
    bool asynchronous, {
    SymbolPath? qualifier,
  });

  /// Called when a getter is annotated with `@provides`.
  ///
  /// [singleton] is `true` when the getter is also annotated with
  /// `@singleton`.
  void visitProvideGetter(
    FieldElement method,
    bool singleton, {
    SymbolPath? qualifier,
  });
}

class _AnnotatedClassVisitor extends GeneralizingElementVisitor<void> {
  final InjectClassVisitor _classVisitor;

  const _AnnotatedClassVisitor(this._classVisitor);

  // - true, if it is a component and has the `@inject` annotation
  // - true, if it is a component and the element is abstract
  //   unlike modules, the `@inject` annotation is optional in components
  // - true, if it is a module and has the `@provides` annotation
  bool _isProvider(ExecutableElement element) {
    if (_classVisitor.isForComponent) {
      return (hasInjectAnnotation(element) || element.isAbstract) && !hasProvidesAnnotation(element);
    } else {
      return hasProvidesAnnotation(element);
    }
  }

  @override
  void visitMethodElement(MethodElement method) {
    if (_isProvider(method)) {
      final singleton = hasSingletonAnnotation(method);
      final asynchronous = hasAsynchronousAnnotation(method);
      _classVisitor.visitProvideMethod(
        method,
        singleton,
        asynchronous,
        qualifier: hasQualifier(method) ? extractQualifier(method) : null,
      );
    } else if (_classVisitor.isForComponent && hasProvidesAnnotation(method)) {
      throw StateError(
        constructMessage(
          builderContext.buildStep.inputId,
          method,
          '@provides annotation is not supported for components',
        ),
      );
    } else if (!_classVisitor.isForComponent && hasInjectAnnotation(method)) {
      throw StateError(
        constructMessage(
          builderContext.buildStep.inputId,
          method,
          '@inject annotation is not supported for modules',
        ),
      );
    }
  }

  @override
  void visitFieldElement(FieldElement field) {
    if (_isProvider(field.getter!)) {
      final singleton = hasSingletonAnnotation(field);
      final asynchronous = hasAsynchronousAnnotation(field);
      if (asynchronous) {
        throw StateError(
          constructMessage(
            builderContext.buildStep.inputId,
            field,
            'Getters cannot be annotated with @Asynchronous().',
          ),
        );
      }
      _classVisitor.visitProvideGetter(
        field,
        singleton,
        qualifier: hasQualifier(field.getter!) ? extractQualifier(field.getter!) : null,
      );
    } else if (_classVisitor.isForComponent && hasProvidesAnnotation(field.getter!)) {
      throw StateError(
        constructMessage(
          builderContext.buildStep.inputId,
          field.getter!,
          '@provides annotation is not supported for components',
        ),
      );
    } else if (!_classVisitor.isForComponent && hasInjectAnnotation(field.getter!)) {
      throw StateError(
        constructMessage(
          builderContext.buildStep.inputId,
          field.getter!,
          '@inject annotation is not supported for modules',
        ),
      );
    }
    return;
  }
}

abstract class FactoryClassVisitor extends GeneralizingElementVisitor<void> {
  /// Call to start visiting [clazz].
  void visitClass(ClassElement clazz) {
    visitClassElement(clazz);
  }

  @override
  void visitMethodElement(MethodElement element) {
    visitFactoryMethod(element);
  }

  void visitFactoryMethod(MethodElement method);
}
