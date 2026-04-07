import 'package:inject_annotation/inject_annotation.dart';
import 'package:source_gen/source_gen.dart';

const _injectAnnotationPackage = 'inject_annotation';

/// Checks for `@component` / `@Component(...)` annotations.
const componentChecker = TypeChecker.typeNamed(Component, inPackage: _injectAnnotationPackage);

/// Checks for `@module` annotations.
const moduleChecker = TypeChecker.typeNamed(Module, inPackage: _injectAnnotationPackage);

/// Checks for `@inject` annotations.
const injectChecker = TypeChecker.typeNamed(Inject, inPackage: _injectAnnotationPackage);

/// Checks for `@provides` annotations.
const providesChecker = TypeChecker.typeNamed(Provides, inPackage: _injectAnnotationPackage);

/// Checks for `@singleton` annotations.
const singletonChecker = TypeChecker.typeNamed(Singleton, inPackage: _injectAnnotationPackage);

/// Checks for `@asynchronous` annotations.
const asynchronousChecker = TypeChecker.typeNamed(Asynchronous, inPackage: _injectAnnotationPackage);

/// Checks for `@Qualifier(#name)` annotations.
const qualifierChecker = TypeChecker.typeNamed(Qualifier, inPackage: _injectAnnotationPackage);

/// Checks for `@assistedInject` annotations.
const assistedInjectChecker = TypeChecker.typeNamed(AssistedInject, inPackage: _injectAnnotationPackage);

/// Checks for `@assisted` annotations.
const assistedChecker = TypeChecker.typeNamed(Assisted, inPackage: _injectAnnotationPackage);

/// Checks for `@assistedFactory` annotations.
const assistedFactoryChecker = TypeChecker.typeNamed(AssistedFactory, inPackage: _injectAnnotationPackage);

/// Checks for `@provisionListener` annotations.
const provisionListenerChecker = TypeChecker.typeNamed(
  ProvisionListenerAnnotation,
  inPackage: _injectAnnotationPackage,
);

/// Checks whether a type implements [ProvisionListener].
const provisionListenerInterfaceChecker = TypeChecker.typeNamed(ProvisionListener, inPackage: _injectAnnotationPackage);
