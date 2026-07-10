import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:code_builder/code_builder.dart';

import '../analysis/assisted_reader.dart';
import '../analysis/dependency_discovery.dart';
import '../analysis/inject_reader.dart';
import '../analysis/module_reader.dart';
import '../extensions/dart_type_extensions.dart';
import '../extensions/element_extensions.dart';
import '../extensions/string_extensions.dart';
import '../validation/binding_key.dart';
import 'listener_generator.dart';

/// Generates `_TypeName$Provider` classes implementing `Provider<T>`.
///
/// Each provider encapsulates one binding — either a module `@provides`
/// method or an `@inject`-annotated constructor. This story generates
/// simple (non-singleton, synchronous) providers only.
class ProviderGenerator {
  /// Generates a provider class for a module `@provides` method.
  ///
  /// Constructor parameter order: dependency providers first, module last.
  Class generateModuleProvider({
    required ProviderDescriptor descriptor,
    required ClassElement moduleClass,
    required bool isAsynchronous,
    required Map<BindingKey, bool> asyncBindings,
    List<ListenerCallInfo> listenerCalls = const [],
    String? sourceUri,
  }) {
    final DartType returnType = descriptor.returnType;
    // For @asynchronous Future<T> providers, use T for class naming so
    // the provider class name matches consumer dep references.
    final DartType unwrapped = returnType.unwrapFuture;
    final String typeName = descriptor.metadata.isAsynchronous && !identical(unwrapped, returnType)
        ? unwrapped.displayName
        : returnType.displayName;
    final String? qualifier = descriptor.metadata.qualifier;
    final String className = providerClassName(typeName, qualifier);

    final TypeReference generatedReturnTypeRef = _generatedReturnTypeRef(
      returnType: returnType,
      isAsynchronous: isAsynchronous,
      sourceUri: sourceUri,
    );
    final providerTypeRef = TypeReference(
      (b) => b
        ..symbol = 'Provider'
        ..url = 'package:inject_annotation/inject_annotation.dart'
        ..types.add(generatedReturnTypeRef),
    );
    final Reference moduleTypeRef = refer(moduleClass.name!, moduleClass.resolvePublicUri(sourceUri: sourceUri));

    final (:List<Field> fields, params: List<Parameter> constructorParams) = buildDependencyProviderFields(
      [for (final dep in descriptor.dependencies) (type: dep.type, qualifier: dep.qualifier)],
    );

    // Listener provider fields (between deps and module)
    for (final listener in listenerCalls) {
      fields.add(
        Field(
          (b) => b
            ..name = listener.fieldName
            ..type = refer(listener.providerClassName)
            ..modifier = FieldModifier.final$,
        ),
      );
      constructorParams.add(
        Parameter(
          (b) => b
            ..name = listener.fieldName
            ..toThis = true,
        ),
      );
    }

    // Module is always LAST
    fields.add(
      Field(
        (b) => b
          ..name = '_module'
          ..type = moduleTypeRef
          ..modifier = FieldModifier.final$,
      ),
    );
    constructorParams.add(
      Parameter(
        (b) => b
          ..name = '_module'
          ..toThis = true,
      ),
    );

    // Build get() body: _module.methodName(dep1.get(), dep2.get(), ...)
    final String args = descriptor.dependencies
        .map((dep) {
          final String depTypeName = dep.type.displayName;
          final String? depQualifier = dep.qualifier;
          final String depFieldName = _providerFieldName(depTypeName, depQualifier);
          final BindingKey? depKey = BindingKey.fromDartType(dep.type, qualifier: dep.qualifier);
          final bool isAsyncDep = depKey != null && asyncBindings[depKey] == true;
          return isAsyncDep ? 'await $depFieldName.get()' : '$depFieldName.get()';
        })
        .join(', ');
    final bool hasAsyncDependencies = descriptor.dependencies.any((dep) {
      final BindingKey? depKey = BindingKey.fromDartType(dep.type, qualifier: dep.qualifier);
      return depKey != null && asyncBindings[depKey] == true;
    });

    final methodCall = '_module.${descriptor.method.name}($args)';
    final bool explicitAsync = descriptor.metadata.isAsynchronous;
    final bool effectivelySingleton = descriptor.metadata.isSingleton || descriptor.metadata.isProvisionListener;
    final bool isSyncSingleton = effectivelySingleton && !isAsynchronous;
    final bool isAsyncSingleton = effectivelySingleton && isAsynchronous;
    final bool hasMutableState = isSyncSingleton || isAsyncSingleton;
    final bool hasListeners = listenerCalls.isNotEmpty;

    final bool needsAsyncModifier = isAsynchronous && (hasAsyncDependencies || !explicitAsync);

    // Build listener call statements
    final String listenerStatements = listenerCalls
        .map(
          (l) => '${l.fieldName}.get().onProvision(instance);',
        )
        .join('\n');

    // For methods that do actual creation, decide between lambda and block
    final needsAwaitOnCall = explicitAsync;
    final createExpression = needsAwaitOnCall ? 'await $methodCall' : methodCall;

    Code createBody;
    bool createLambda;
    if (hasListeners) {
      createBody = Code('final instance = $createExpression;\n$listenerStatements\nreturn instance;');
      createLambda = false;
    } else {
      createBody = Code(methodCall);
      createLambda = true;
    }

    Code getBody;
    bool getLambda;
    if (isSyncSingleton || isAsyncSingleton) {
      getBody = isSyncSingleton ? const Code('_singleton') : const Code('_singletonFuture ??= _create()');
      getLambda = true;
    } else if (hasListeners) {
      getBody = createBody;
      getLambda = false;
    } else {
      getBody = Code(methodCall);
      getLambda = true;
    }

    return Class(
      (b) => b
        ..name = className
        ..implements.add(providerTypeRef)
        ..constructors.add(
          Constructor(
            (b) => b
              ..constant = !hasMutableState
              ..requiredParameters.addAll(constructorParams),
          ),
        )
        ..fields.addAll(fields)
        ..fields.addAll([
          if (isSyncSingleton)
            Field(
              (b) => b
                ..name = '_singleton'
                ..late = true
                ..modifier = FieldModifier.final$
                ..type = generatedReturnTypeRef
                ..assignment = refer('_create').call([]).code,
            ),
          if (isAsyncSingleton)
            Field(
              (b) => b
                ..name = '_singletonFuture'
                ..type = _nullableTypeRef(generatedReturnTypeRef),
            ),
        ])
        ..methods.addAll([
          if (isSyncSingleton)
            Method(
              (b) => b
                ..name = '_create'
                ..returns = generatedReturnTypeRef
                ..lambda = createLambda
                ..body = createBody,
            ),
          if (isAsyncSingleton)
            Method(
              (b) => b
                ..name = '_create'
                ..modifier = needsAsyncModifier || (hasListeners && needsAwaitOnCall) ? MethodModifier.async : null
                ..returns = generatedReturnTypeRef
                ..lambda = createLambda
                ..body = createBody,
            ),
          Method((b) {
            b
              ..name = 'get'
              ..returns = generatedReturnTypeRef
              ..annotations.add(refer('override'))
              ..lambda = getLambda;
            if ((needsAsyncModifier || (hasListeners && needsAwaitOnCall)) && !isAsyncSingleton) {
              b.modifier = MethodModifier.async;
            }
            b.body = getBody;
          }),
        ]),
    );
  }

  /// Generates a provider class for an `@inject`-annotated constructor.
  Class generateInjectProvider({
    required ClassElement classElement,
    required InjectableData injectable,
    required bool isAsynchronous,
    required Map<BindingKey, bool> asyncBindings,
    List<ListenerCallInfo> listenerCalls = const [],
    String? sourceUri,
  }) {
    final String typeName = classElement.name!;
    final String? qualifier = injectable.key.qualifier;
    final String className = providerClassName(typeName, qualifier);
    final classTypeRef = classElement.thisType.typeRef(sourceUri: sourceUri) as TypeReference;
    final TypeReference generatedReturnTypeRef = isAsynchronous
        ? classElement.thisType.futureTypeRef(sourceUri: sourceUri)
        : classTypeRef;

    final bool isSingleton = injectable.isSingleton;

    final providerTypeRef = TypeReference(
      (b) => b
        ..symbol = 'Provider'
        ..url = 'package:inject_annotation/inject_annotation.dart'
        ..types.add(generatedReturnTypeRef),
    );

    final (:List<Field> fields, params: List<Parameter> constructorParams) = buildDependencyProviderFields(
      [for (final dep in injectable.dependencies) (type: dep.type, qualifier: dep.qualifier)],
    );

    // Listener provider fields
    for (final listener in listenerCalls) {
      fields.add(
        Field(
          (b) => b
            ..name = listener.fieldName
            ..type = refer(listener.providerClassName)
            ..modifier = FieldModifier.final$,
        ),
      );
      constructorParams.add(
        Parameter(
          (b) => b
            ..name = listener.fieldName
            ..toThis = true,
        ),
      );
    }

    final bool hasListeners = listenerCalls.isNotEmpty;

    // Build constructor call: ClassName(dep1.get(), dep2.get(), ...)
    final positionalArgs = <Expression>[];
    final namedArgs = <String, Expression>{};
    for (final FormalParameterElement param in injectable.constructor.formalParameters) {
      final ParameterDependency dep = injectable.dependencies.firstWhere((candidate) => candidate.parameter == param);
      // Use nonNullableDisplayName: Foo? widens to the Foo provider (_Foo$Provider)
      final String depTypeName = dep.type.nonNullableDisplayName;
      final String? depQualifier = dep.qualifier;
      final String depFieldName = _providerFieldName(depTypeName, depQualifier);
      final BindingKey? depKey = BindingKey.fromDartType(dep.type, qualifier: dep.qualifier);
      // A `Provider<T>` parameter receives the provider field directly; every
      // other dependency is resolved with `.get()` (awaited when async).
      final Expression expr;
      if (dep.isProvider) {
        expr = refer(depFieldName);
      } else {
        final Expression depExpr = refer(depFieldName).property('get').call([]);
        expr = depKey != null && asyncBindings[depKey] == true ? refer('await').call([depExpr]) : depExpr;
      }
      if (param.isNamed) {
        namedArgs[param.name!] = expr;
      } else {
        positionalArgs.add(expr);
      }
    }

    final String? constructorName = injectable.constructorName;
    final Expression constructorCall = constructorName != null
        ? classTypeRef.newInstanceNamed(constructorName, positionalArgs, namedArgs)
        : classTypeRef.newInstance(positionalArgs, namedArgs);

    // Build listener call statements
    final List<Code> listenerStatementCodes = listenerCalls
        .map(
          (l) => Code('${l.fieldName}.get().onProvision(instance);'),
        )
        .toList();

    // Determine body shapes for _create() and get()
    Code createBodyCode;
    bool createLambda;
    if (hasListeners) {
      createBodyCode = Block.of([
        declareFinal('instance').assign(constructorCall).statement,
        ...listenerStatementCodes,
        refer('instance').returned.statement,
      ]);
      createLambda = false;
    } else {
      createBodyCode = constructorCall.code;
      createLambda = true;
    }

    return Class(
      (b) => b
        ..name = className
        ..implements.add(providerTypeRef)
        ..constructors.add(
          Constructor(
            (b) => b
              ..constant = !isSingleton
              ..requiredParameters.addAll(constructorParams),
          ),
        )
        ..fields.addAll(fields)
        ..fields.addAll([
          if (isSingleton)
            Field(
              (b) => b
                ..name = '_singleton'
                ..late = true
                ..modifier = FieldModifier.final$
                ..type = generatedReturnTypeRef
                ..assignment = refer('_create').call([]).code,
            ),
          if (isSingleton && isAsynchronous)
            Field(
              (b) => b
                ..name = '_singletonFuture'
                ..type = _nullableTypeRef(generatedReturnTypeRef),
            ),
        ])
        ..methods.addAll([
          if (isSingleton && !isAsynchronous)
            Method(
              (b) => b
                ..name = '_create'
                ..returns = classTypeRef
                ..lambda = createLambda
                ..body = createBodyCode,
            ),
          if (isSingleton && isAsynchronous)
            Method(
              (b) => b
                ..name = '_create'
                ..modifier = MethodModifier.async
                ..returns = generatedReturnTypeRef
                ..lambda = createLambda
                ..body = createBodyCode,
            ),
          Method((b) {
            b
              ..name = 'get'
              ..returns = generatedReturnTypeRef
              ..annotations.add(refer('override'));
            if (isAsynchronous) {
              b.modifier = MethodModifier.async;
              if (isSingleton) {
                b
                  ..lambda = true
                  ..body = const Code('_singletonFuture ??= _create()');
              } else {
                b
                  ..lambda = !hasListeners
                  ..body = hasListeners ? createBodyCode : constructorCall.code;
              }
            } else if (isSingleton) {
              b
                ..lambda = true
                ..body = refer('_singleton').code;
            } else {
              b
                ..lambda = !hasListeners
                ..body = hasListeners ? createBodyCode : constructorCall.code;
            }
          }),
        ]),
    );
  }

  // --- Public naming helpers (used by ComponentGenerator) ---

  /// Provider class name: `_TypeName$Provider` or `_TypeNameQualifier$Provider`.
  ///
  /// The type name is Pascal-cased so primitive types (`int`, `double`, `bool`,
  /// etc.) emit `_Int$Provider` / `_Double$Provider` — disambiguating from the
  /// camel-cased field name (`_int$Provider`) emitted by [providerBaseName].
  static String providerClassName(String typeName, String? qualifier) {
    final String qualifierSuffix = qualifier != null ? qualifier.capitalize : '';
    return '_${typeName.capitalize}$qualifierSuffix\$Provider';
  }

  /// Provider base name without leading underscore: `typeName$Provider`.
  ///
  /// Used for local variable names in the component constructor.
  static String providerBaseName(String typeName, String? qualifier) {
    final String base = typeName.uncapitalize;
    final String qualifierSuffix = qualifier != null ? qualifier.capitalize : '';
    return '$base$qualifierSuffix\$Provider';
  }

  /// Builds provider fields and constructor parameters for a list of
  /// dependencies.
  ///
  /// When [partFileContext] is `true`, field types use `Provider<T>` generic
  /// references (for `.factory.dart` part files). When `false`, field types
  /// reference the concrete generated provider class name (for `.inject.dart`).
  static ({List<Field> fields, List<Parameter> params}) buildDependencyProviderFields(
    List<({DartType type, String? qualifier})> dependencies, {
    bool partFileContext = false,
  }) {
    final fields = <Field>[];
    final params = <Parameter>[];
    for (final dep in dependencies) {
      // Use non-nullable display name: the provider for `Foo?` is the same as
      // for `Foo` (nullable-widening), so both map to `_Foo$Provider`.
      final String depTypeName = dep.type.nonNullableDisplayName;
      final String depFieldName = _providerFieldName(depTypeName, dep.qualifier);
      final Reference depFieldType = partFileContext
          ? dep.type.providerTypeRef(partFileContext: true)
          : refer(providerClassName(depTypeName, dep.qualifier));

      fields.add(
        Field(
          (b) => b
            ..name = depFieldName
            ..type = depFieldType
            ..modifier = FieldModifier.final$,
        ),
      );
      params.add(
        Parameter(
          (b) => b
            ..name = depFieldName
            ..toThis = true,
        ),
      );
    }
    return (fields: fields, params: params);
  }

  /// Generates a provider class for an `@assistedFactory`-annotated class.
  ///
  /// The provider wraps an inline factory class (`_<FactoryName>$Factory`)
  /// and returns a lazily initialized singleton instance via `get()`.
  Class generateFactoryProvider({
    required ClassElement factoryElement,
    required List<AssistedInjectData> injectDataList,
    String? sourceUri,
  }) {
    final String factoryName = factoryElement.name!;
    final className = '_$factoryName\$Provider';
    final Reference factoryTypeRef = refer(factoryName, factoryElement.resolvePublicUri(sourceUri: sourceUri));

    final providerTypeRef = TypeReference(
      (b) => b
        ..symbol = 'Provider'
        ..url = 'package:inject_annotation/inject_annotation.dart'
        ..types.add(factoryTypeRef),
    );

    // Unify deps from all constructors (dedup by BindingKey).
    // NOTE: Field names are derived from displayName which could theoretically
    // collide for same-named types from different libraries. In practice this
    // requires two identically-named unqualified types injected into the same
    // class — an unlikely scenario that would also confuse human readers.
    // TODO(inject.dart): propagate BindingKey→fieldName mapping if needed.
    //
    // Nullable deps (Foo?) are normalized to their non-nullable key for
    // deduplication: the provider for Foo? is the same as for Foo (widening).
    final seen = <BindingKey>{};
    final allDeps = <({DartType type, String? qualifier})>[];
    for (final injectData in injectDataList) {
      for (final ParameterDependency dep in injectData.injectedDependencies) {
        final BindingKey? rawKey = BindingKey.fromDartType(dep.type, qualifier: dep.qualifier);
        if (rawKey == null) continue;
        final BindingKey dedupKey = rawKey.isNullable ? rawKey.nonNullable : rawKey;
        if (seen.add(dedupKey)) {
          allDeps.add((type: dep.type, qualifier: dep.qualifier));
        }
      }
    }

    final (:List<Field> fields, params: List<Parameter> constructorParams) = buildDependencyProviderFields(allDeps);

    // Inline factory class name (lives in .inject.dart)
    final factoryInlineClassName = '_$factoryName\$Factory';
    final String factoryArgsStr = fields.map((f) => f.name).join(', ');

    return Class(
      (b) => b
        ..name = className
        ..implements.add(providerTypeRef)
        ..constructors.add(Constructor((b) => b..requiredParameters.addAll(constructorParams)))
        ..fields.addAll(fields)
        ..fields.add(
          Field(
            (b) => b
              ..name = '_factory'
              ..late = true
              ..modifier = FieldModifier.final$
              ..type = factoryTypeRef
              ..assignment = Code('$factoryInlineClassName($factoryArgsStr)'),
          ),
        )
        ..methods.add(
          Method(
            (b) => b
              ..name = 'get'
              ..returns = factoryTypeRef
              ..annotations.add(refer('override'))
              ..lambda = true
              ..body = const Code('_factory'),
          ),
        ),
    );
  }

  /// Generates an inline factory class for `.inject.dart` that implements
  /// the abstract factory type and delegates to the target constructor(s).
  ///
  /// This class lives in `.inject.dart` (not `.factory.dart`) so that
  /// the provider can reference it directly. The `.factory.dart` part file's
  /// private `_$Impl` class would be invisible from `.inject.dart`.
  Class generateInlineFactory({
    required ClassElement factoryElement,
    required List<({AssistedInjectData injectData, AssistedFactoryData factoryData})> entries,
    String? sourceUri,
  }) {
    final String factoryName = factoryElement.name!;
    final className = '_$factoryName\$Factory';
    final Reference factoryTypeRef = refer(factoryName, factoryElement.resolvePublicUri(sourceUri: sourceUri));

    // Unify deps from all constructors (dedup by BindingKey).
    // NOTE: same displayName-based field name caveat as generateFactoryProvider.
    // Nullable deps are normalized to non-nullable for deduplication (widening).
    final seen = <BindingKey>{};
    final allDeps = <({DartType type, String? qualifier})>[];
    for (final (:injectData, factoryData: _) in entries) {
      for (final ParameterDependency dep in injectData.injectedDependencies) {
        final BindingKey? rawKey = BindingKey.fromDartType(dep.type, qualifier: dep.qualifier);
        if (rawKey == null) continue;
        final BindingKey dedupKey = rawKey.isNullable ? rawKey.nonNullable : rawKey;
        if (seen.add(dedupKey)) {
          allDeps.add((type: dep.type, qualifier: dep.qualifier));
        }
      }
    }

    final (:List<Field> fields, params: List<Parameter> constructorParams) = buildDependencyProviderFields(allDeps);

    // Generate one method per entry.
    final methods = <Method>[];
    for (final (:injectData, :factoryData) in entries) {
      methods.add(
        _buildInlineFactoryMethod(
          injectData: injectData,
          factoryData: factoryData,
          sourceUri: sourceUri,
        ),
      );
    }

    return Class(
      (b) => b
        ..name = className
        ..implements.add(factoryTypeRef)
        ..constructors.add(
          Constructor(
            (b) => b
              ..constant = true
              ..requiredParameters.addAll(constructorParams),
          ),
        )
        ..fields.addAll(fields)
        ..methods.addAll(methods),
    );
  }

  /// Builds a single factory method for an inline factory class.
  Method _buildInlineFactoryMethod({
    required AssistedInjectData injectData,
    required AssistedFactoryData factoryData,
    String? sourceUri,
  }) {
    // Partition create() params by Dart parameter kind so optional-positional
    // params end up in optionalParameters (rendered as `[...]`) rather than
    // requiredParameters.
    final requiredCreateParams = <Parameter>[];
    final optionalCreateParams = <Parameter>[];
    for (final FormalParameterElement param in factoryData.createMethod.formalParameters) {
      final spec = Parameter((b) {
        b
          ..name = param.name!
          ..type = param.type.typeRef(sourceUri: sourceUri);
        if (param.isNamed) {
          b.named = true;
          if (param.isRequired) {
            b.required = true;
          }
        }
      });
      if (param.isRequiredPositional) {
        requiredCreateParams.add(spec);
      } else {
        optionalCreateParams.add(spec);
      }
    }

    // Build constructor call arguments in target constructor parameter order
    final List<FormalParameterElement> positionalFactoryParams = factoryData.createMethod.formalParameters
        .where((p) => !p.isNamed)
        .toList();
    final namedFactoryParams = <String, FormalParameterElement>{
      for (final p in factoryData.createMethod.formalParameters.where((p) => p.isNamed)) p.name!: p,
    };

    final InterfaceElement targetElement = injectData.constructor.enclosingElement;
    final Reference targetTypeRef = refer(targetElement.name!, targetElement.resolvePublicUri(sourceUri: sourceUri));

    final positionalArgs = <Expression>[];
    final namedArgs = <String, Expression>{};
    var assistedIndex = 0;

    for (final FormalParameterElement param in injectData.constructor.formalParameters) {
      final bool isAssisted = injectData.assistedParameters.any((ap) => ap.parameter == param);

      if (isAssisted) {
        final String argName;
        if (param.isNamed) {
          argName = namedFactoryParams[param.name!]!.name!;
        } else {
          argName = positionalFactoryParams[assistedIndex].name!;
          assistedIndex++;
        }
        if (param.isNamed) {
          namedArgs[param.name!] = refer(argName);
        } else {
          positionalArgs.add(refer(argName));
        }
      } else {
        final ParameterDependency injectedDep = injectData.injectedDependencies.firstWhere(
          (ip) => ip.parameter == param,
        );
        final String depFieldName = _providerFieldName(injectedDep.type.nonNullableDisplayName, injectedDep.qualifier);
        final Expression expr = refer(depFieldName).property('get').call([]);
        if (param.isNamed) {
          namedArgs[param.name!] = expr;
        } else {
          positionalArgs.add(expr);
        }
      }
    }

    final String? constructorName = injectData.constructorName;
    final Expression constructorCall = constructorName != null
        ? targetTypeRef.newInstanceNamed(constructorName, positionalArgs, namedArgs)
        : targetTypeRef.newInstance(positionalArgs, namedArgs);
    final Reference returnTypeRef = factoryData.createMethod.returnType.typeRef(sourceUri: sourceUri);

    return Method(
      (b) => b
        ..name = factoryData.createMethod.name
        ..returns = returnTypeRef
        ..annotations.add(refer('override'))
        ..requiredParameters.addAll(requiredCreateParams)
        ..optionalParameters.addAll(optionalCreateParams)
        ..lambda = true
        ..body = constructorCall.code,
    );
  }

  /// Generates a provider class that synthesizes a typedef function type
  /// value by creating a closure.
  ///
  /// For example, `ViewModelFactory<HomePageViewModel>` (a typedef for a
  /// function returning `ViewModelBuilder<HomePageViewModel>`) produces:
  /// ```dart
  /// class _ViewModelFactoryOfHomePageViewModel$Provider
  ///     implements Provider<ViewModelFactory<HomePageViewModel>> {
  ///   const _ViewModelFactoryOfHomePageViewModel$Provider(
  ///     this._homePageViewModel$Provider,
  ///   );
  ///   final _HomePageViewModel$Provider _homePageViewModel$Provider;
  ///   @override
  ///   ViewModelFactory<HomePageViewModel> get() =>
  ///     ({key, init, required builder, child}) =>
  ///       ViewModelBuilder<HomePageViewModel>(
  ///         key: key, init: init, builder: builder, child: child,
  ///         viewModelProvider: _homePageViewModel$Provider,
  ///       );
  /// }
  /// ```
  Class generateTypedefProvider({required TypedefProviderData typedefData, String? sourceUri}) {
    final DartType typedefType = typedefData.typedefType;
    final String typeName = typedefType.displayName;
    final String className = providerClassName(typeName, null);
    final Reference typedefTypeRef = typedefType.typeRef(sourceUri: sourceUri);

    final providerTypeRef = TypeReference(
      (b) => b
        ..symbol = 'Provider'
        ..url = 'package:inject_annotation/inject_annotation.dart'
        ..types.add(typedefTypeRef),
    );

    final (:List<Field> fields, params: List<Parameter> constructorParams) = buildDependencyProviderFields(
      [for (final injected in typedefData.injectedParams) (type: injected.depType, qualifier: injected.qualifier)],
    );

    // Build the closure as a code_builder Method so the scoped emitter
    // handles import prefixes for all type references.
    final Reference returnTypeRef = typedefData.returnType.typeRef(sourceUri: sourceUri);

    // Closure parameters (from the function signature)
    final closureParams = <Parameter>[];
    for (final FormalParameterElement param in typedefData.closureParams) {
      closureParams.add(
        Parameter((b) {
          b
            ..name = param.name!
            ..type = param.type.typeRef(sourceUri: sourceUri);
          if (param.isNamed) {
            b.named = true;
            if (param.isRequired) {
              b.required = true;
            }
          }
        }),
      );
    }

    // Build constructor call: ReturnType(forwardedArgs..., injectedArgs...)
    final Set<String?> funcParamNames = typedefData.closureParams.map((p) => p.name).toSet();
    final positionalArgs = <Expression>[];
    final namedArgs = <String, Expression>{};

    for (final FormalParameterElement ctorParam in typedefData.constructor.formalParameters) {
      if (funcParamNames.contains(ctorParam.name)) {
        // Forward from closure parameter
        final Reference expr = refer(ctorParam.name!);
        if (ctorParam.isNamed) {
          namedArgs[ctorParam.name!] = expr;
        } else {
          positionalArgs.add(expr);
        }
      } else {
        // Injected parameter — look up the provider field
        final ({DartType depType, FormalParameterElement param, String? qualifier, bool passProvider}) injected =
            typedefData.injectedParams.firstWhere((ip) => ip.param == ctorParam);
        final String depFieldName = _providerFieldName(injected.depType.displayName, injected.qualifier);
        final Expression expr = injected.passProvider
            ? refer(depFieldName)
            : refer(depFieldName).property('get').call([]);
        if (ctorParam.isNamed) {
          namedArgs[ctorParam.name!] = expr;
        } else {
          positionalArgs.add(expr);
        }
      }
    }

    final Expression constructorCall = returnTypeRef.newInstance(positionalArgs, namedArgs);

    // Build closure expression: ({params}) => ReturnType(args)
    final closureMethod = Method(
      (b) => b
        ..requiredParameters.addAll(closureParams.where((p) => !p.named))
        ..optionalParameters.addAll(closureParams.where((p) => p.named))
        ..lambda = true
        ..body = constructorCall.code,
    );

    return Class(
      (b) => b
        ..name = className
        ..implements.add(providerTypeRef)
        ..constructors.add(
          Constructor(
            (b) => b
              ..constant = true
              ..requiredParameters.addAll(constructorParams),
          ),
        )
        ..fields.addAll(fields)
        ..methods.add(
          Method(
            (b) => b
              ..name = 'get'
              ..returns = typedefTypeRef
              ..annotations.add(refer('override'))
              ..lambda = true
              ..body = closureMethod.closure.code,
          ),
        ),
    );
  }

  // --- Private helpers ---

  /// Provider field name with leading underscore: `_typeName$Provider`.
  static String _providerFieldName(String typeName, String? qualifier) => '_${providerBaseName(typeName, qualifier)}';

  TypeReference _generatedReturnTypeRef({
    required DartType returnType,
    required bool isAsynchronous,
    required String? sourceUri,
  }) {
    if (!isAsynchronous) {
      return returnType.typeRef(sourceUri: sourceUri) as TypeReference;
    }

    // If already Future<T>, keep as-is; otherwise wrap in Future<>.
    if (!identical(returnType.unwrapFuture, returnType)) {
      return returnType.typeRef(sourceUri: sourceUri) as TypeReference;
    }

    return returnType.futureTypeRef(sourceUri: sourceUri);
  }

  TypeReference _nullableTypeRef(TypeReference reference) => TypeReference(
    (b) => b
      ..symbol = reference.symbol
      ..url = reference.url
      ..isNullable = true
      ..types.addAll(reference.types),
  );
}
