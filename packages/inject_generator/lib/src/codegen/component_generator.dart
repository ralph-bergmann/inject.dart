import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:code_builder/code_builder.dart';

import '../analysis/assisted_reader.dart';
import '../analysis/component_reader.dart';
import '../analysis/entry_point_collector.dart';
import '../analysis/dependency_discovery.dart';
import '../analysis/inject_reader.dart';
import '../analysis/module_reader.dart';
import '../analysis/subcomponent_reader.dart';
import '../extensions/dart_type_extensions.dart';
import '../extensions/element_extensions.dart';
import '../extensions/string_extensions.dart';
import '../validation/binding_key.dart';
import 'listener_generator.dart';
import 'provider_generator.dart';

/// Generates `ComponentName$Component` classes implementing the
/// abstract component interface.
///
/// The component class wires all providers together in its constructor
/// and exposes entry points as overridden getters/methods.
class ComponentGenerator {
  /// Generates a `$Component` class.
  ///
  /// [modules] provides the module ClassElements paired with their read data.
  /// [injectables] provides the injectable ClassElements paired with their data.
  Class generate({
    required ClassElement componentClass,
    required ComponentData componentData,
    required List<({ClassElement moduleClass, ModuleData moduleData})> modules,
    required List<({ClassElement classElement, InjectableData injectable})> injectables,
    List<({ClassElement factoryElement, AssistedInjectData injectData, AssistedFactoryData factoryData})> factories =
        const [],
    List<TypedefProviderData> typedefProviders = const [],
    Map<BindingKey, bool> asyncBindings = const {},
    List<({ClassElement moduleClass, ProviderDescriptor descriptor})> listenerProviders = const [],
    Map<BindingKey, List<ListenerCallInfo>> listenerCallsPerBinding = const {},
    String? componentPrefix,
    List<({BindingKey key, ClassElement factoryClass})> subcomponentFactoryBindings = const [],
    Set<BindingKey> promoteToFields = const {},
    String? sourceUri,
  }) {
    final String componentName = componentClass.name!;
    final className = '$componentName\$Component';
    final Reference componentTypeRef = refer(componentName, componentClass.resolvePublicUri(sourceUri: sourceUri));

    // Build binding registry
    final List<_Binding> bindings = _buildBindings(
      modules,
      injectables,
      factories,
      typedefProviders,
      asyncBindings,
      componentPrefix: componentPrefix,
    );

    // Subcomponent factories are bindings of the parent graph: constructed
    // with the component instance itself (`this`), no graph dependencies.
    for (final factoryBinding in subcomponentFactoryBindings) {
      bindings.add(
        _Binding(
          key: factoryBinding.key,
          typeName: factoryBinding.factoryClass.name!,
          qualifier: null,
          moduleParamName: null,
          dependencyKeys: [],
          isSingleton: false,
          isAsynchronous: false,
          componentPrefix: componentPrefix,
          isSubcomponentFactory: true,
        ),
      );
    }

    // Providers consumed by installed subcomponents must be addressable after
    // construction — promote them from constructor locals to fields so the
    // generated subcomponent can read them as `_parent._<provider>`.
    if (promoteToFields.isNotEmpty) {
      for (final binding in bindings) {
        if (promoteToFields.contains(binding.key)) {
          binding.promoted = true;
        }
      }
    }

    // Add listener providers as implicit dependencies for topological ordering
    for (final MapEntry<BindingKey, List<ListenerCallInfo>> entry in listenerCallsPerBinding.entries) {
      final _Binding? binding = bindings.where((b) => b.key == entry.key).firstOrNull;
      if (binding == null) continue;
      for (final ListenerCallInfo listener in entry.value) {
        final String listenerBaseName = listener.fieldName.substring(1); // remove leading _
        final _Binding? listenerBinding = bindings.where((b) => b.baseName == listenerBaseName).firstOrNull;
        if (listenerBinding != null && !binding.dependencyKeys.contains(listenerBinding.key)) {
          binding.dependencyKeys.add(listenerBinding.key);
        }
      }
    }

    // Nullable-widening: normalize dep keys — replace `Foo?` with `Foo` when
    // no exact nullable binding exists but a non-nullable one does.
    // Runs after listener insertion so listener-added keys are covered.
    final Set<BindingKey> bindingKeys = {for (final b in bindings) b.key};
    for (final binding in bindings) {
      for (var i = 0; i < binding.dependencyKeys.length; i++) {
        final BindingKey key = binding.dependencyKeys[i];
        if (key.isNullable) {
          final BindingKey nonNullableKey = key.nonNullable;
          if (!bindingKeys.contains(key) && bindingKeys.contains(nonNullableKey)) {
            binding.dependencyKeys[i] = nonNullableKey;
          }
        }
      }
    }

    // Match entry points to bindings
    _matchEntryPoints(bindings, componentData.entryPoints);

    // Topological sort
    final List<_Binding> sorted = _topologicalSort(bindings);

    // Module parameter names: uncapitalized class name, preserving declaration
    // order from @Component([...]) — later modules can override earlier ones.
    final moduleParams = <({ClassElement moduleClass, String paramName, bool hasDefaultConstructor})>[];
    for (final m in modules) {
      final String name = m.moduleClass.name!.uncapitalize;
      moduleParams.add((
        moduleClass: m.moduleClass,
        paramName: name,
        hasDefaultConstructor: m.moduleData.hasDefaultConstructor,
      ));
    }

    // Generate factory constructor
    final Constructor factoryConstructor = _buildFactory(
      className: className,
      moduleParams: moduleParams,
      sourceUri: sourceUri,
    );

    // Generate private constructor — does not need the default-ctor flag.
    final Constructor privateConstructor = _buildPrivateConstructor(
      moduleParams: [
        for (final mp in moduleParams) (moduleClass: mp.moduleClass, paramName: mp.paramName),
      ],
      sortedBindings: sorted,
      listenerCallsPerBinding: listenerCallsPerBinding,
      sourceUri: sourceUri,
    );

    // Generate late final fields for entry-point and promoted providers
    final entryFields = <Field>[];
    for (final binding in sorted) {
      if (binding.isField) {
        entryFields.add(
          Field(
            (b) => b
              ..name = '_${binding.baseName}'
              ..type = refer(binding.providerClassName)
              ..late = true
              ..modifier = FieldModifier.final$,
          ),
        );
      }
    }

    // Generate entry-point overrides
    final entryMethods = <Method>[];
    for (final binding in sorted) {
      if (!binding.isEntryPoint) {
        continue;
      }
      for (final EntryPoint ep in binding.entryPoints) {
        final Element element = ep.element;
        final DartType? returnType = element.entryPointReturnType;
        final String? name = element.entryPointName;
        if (returnType == null || name == null) {
          continue;
        }

        final bodyExpr = ep.isProvider ? '_${binding.baseName}' : '_${binding.baseName}.get()';

        entryMethods.add(
          Method(
            (b) => b
              ..name = name
              ..returns = returnType.typeRef(sourceUri: sourceUri)
              ..annotations.add(refer('override'))
              ..lambda = true
              ..body = Code(bodyExpr)
              ..type = element is PropertyAccessorElement ? MethodType.getter : null,
          ),
        );
      }
    }

    return Class(
      (b) => b
        ..name = className
        ..implements.add(componentTypeRef)
        ..constructors.addAll([factoryConstructor, privateConstructor])
        ..fields.addAll(entryFields)
        ..methods.addAll(entryMethods),
    );
  }

  // --- Factory constructor ---

  Constructor _buildFactory({
    required String className,
    required List<({ClassElement moduleClass, String paramName, bool hasDefaultConstructor})> moduleParams,
    String? sourceUri,
  }) {
    final params = <Parameter>[];
    final args = <Expression>[];

    for (final mp in moduleParams) {
      final Reference moduleTypeRef = refer(
        mp.moduleClass.name!,
        mp.moduleClass.resolvePublicUri(sourceUri: sourceUri),
      );
      final bool hasDefaultCtor = mp.hasDefaultConstructor;
      params.add(
        Parameter(
          (b) => b
            ..name = mp.paramName
            ..named = true
            ..required = !hasDefaultCtor
            ..type = TypeReference(
              (b) => b
                ..symbol = moduleTypeRef.symbol
                ..url = moduleTypeRef.url
                ..isNullable = hasDefaultCtor,
            ),
        ),
      );
      final Expression arg = hasDefaultCtor
          ? refer(mp.paramName).ifNullThen(moduleTypeRef.newInstance([]))
          : refer(mp.paramName);
      args.add(arg);
    }

    return Constructor(
      (b) => b
        ..factory = true
        ..name = 'create'
        ..optionalParameters.addAll(params)
        ..lambda = true
        ..body = refer(className).newInstanceNamed('_', args).code,
    );
  }

  // --- Private constructor ---

  Constructor _buildPrivateConstructor({
    required List<({ClassElement moduleClass, String paramName})> moduleParams,
    required List<_Binding> sortedBindings,
    Map<BindingKey, List<ListenerCallInfo>> listenerCallsPerBinding = const {},
    String? sourceUri,
  }) {
    final params = <Parameter>[];
    for (final mp in moduleParams) {
      final Reference moduleTypeRef = refer(
        mp.moduleClass.name!,
        mp.moduleClass.resolvePublicUri(sourceUri: sourceUri),
      );
      params.add(
        Parameter(
          (b) => b
            ..name = mp.paramName
            ..type = moduleTypeRef,
        ),
      );
    }

    // Build body: instantiate providers in topological order
    final bodyStatements = <String>[];
    for (final binding in sortedBindings) {
      final ctorArgs = <String>[];

      // Collect listener binding keys for this binding to exclude from regular deps
      final List<ListenerCallInfo>? listenerCalls = listenerCallsPerBinding[binding.key];
      final listenerBindingKeys = <BindingKey>{};
      if (listenerCalls != null) {
        for (final ListenerCallInfo listener in listenerCalls) {
          final String listenerBaseName = listener.fieldName.substring(1); // remove leading _
          final _Binding listenerBinding = sortedBindings.firstWhere((b) => b.baseName == listenerBaseName);
          listenerBindingKeys.add(listenerBinding.key);
        }
      }

      // Subcomponent factory providers receive the component instance itself.
      if (binding.isSubcomponentFactory) {
        ctorArgs.add('this');
      }

      // Dependency providers first (excluding listener deps added for topo sort)
      for (final BindingKey depKey in binding.dependencyKeys) {
        if (listenerBindingKeys.contains(depKey)) continue;
        final _Binding depBinding = sortedBindings.firstWhere((b) => b.key == depKey);
        ctorArgs.add(depBinding.isField ? '_${depBinding.baseName}' : depBinding.variableName);
      }

      // Listener provider refs between deps and module
      if (listenerCalls != null) {
        for (final ListenerCallInfo listener in listenerCalls) {
          final String listenerBaseName = listener.fieldName.substring(1); // remove leading _
          final _Binding listenerBinding = sortedBindings.firstWhere((b) => b.baseName == listenerBaseName);
          ctorArgs.add(listenerBinding.isField ? '_${listenerBinding.baseName}' : listenerBinding.variableName);
        }
      }

      // Module instance last (for module providers)
      if (binding.moduleParamName != null) {
        ctorArgs.add(binding.moduleParamName!);
      }

      final String argsStr = ctorArgs.join(', ');

      if (binding.isField) {
        bodyStatements.add('_${binding.baseName} = ${binding.providerClassName}($argsStr);');
      } else {
        bodyStatements.add('final ${binding.variableName} = ${binding.providerClassName}($argsStr);');
      }
    }

    return Constructor(
      (b) => b
        ..name = '_'
        ..requiredParameters.addAll(params)
        ..body = Code(bodyStatements.join('\n')),
    );
  }

  // --- Subcomponent generation ---

  /// Maps every binding key of a graph to its provider field name
  /// (`_<baseName>`), using the same naming rules as [generate].
  ///
  /// Used by the orchestrator to tell [generateSubcomponent] how consumed
  /// parent bindings are addressed through the parent reference.
  Map<BindingKey, String> providerFieldNames({
    required List<({ClassElement moduleClass, ModuleData moduleData})> modules,
    required List<({ClassElement classElement, InjectableData injectable})> injectables,
    List<({ClassElement factoryElement, AssistedInjectData injectData, AssistedFactoryData factoryData})> factories =
        const [],
    List<TypedefProviderData> typedefProviders = const [],
    List<({BindingKey key, ClassElement factoryClass})> subcomponentFactoryBindings = const [],
    String? componentPrefix,
  }) {
    final List<_Binding> bindings = _buildBindings(
      modules,
      injectables,
      factories,
      typedefProviders,
      const {},
      componentPrefix: componentPrefix,
    );
    return {
      for (final binding in bindings) binding.key: '_${binding.baseName}',
      for (final factoryBinding in subcomponentFactoryBindings)
        factoryBinding.key:
            '_${ProviderGenerator.providerBaseName(factoryBinding.factoryClass.name!, null, componentPrefix: componentPrefix)}',
    };
  }

  /// Generates the `<Name>$Subcomponent` class implementing the abstract
  /// `@subcomponent` interface.
  ///
  /// Mirrors [generate] with three differences: the private constructor holds
  /// the parent component reference (`_parent`), the public `create(...)`
  /// factory takes the parent as first positional parameter, and dependencies
  /// satisfied by the parent graph are read as `_parent._<provider>`.
  ///
  /// When the source file declares more than one `@Component`, the class name
  /// is prefixed with the parent's name (same collision rule as providers).
  Class generateSubcomponent({
    required ClassElement subcomponentClass,
    required SubcomponentData subcomponentData,
    required String parentClassName,
    required Map<BindingKey, String> parentProviderFieldNames,
    required List<({ClassElement moduleClass, ModuleData moduleData})> modules,
    required List<({ClassElement classElement, InjectableData injectable})> injectables,
    List<({ClassElement factoryElement, AssistedInjectData injectData, AssistedFactoryData factoryData})> factories =
        const [],
    List<TypedefProviderData> typedefProviders = const [],
    Map<BindingKey, bool> asyncBindings = const {},
    List<({ClassElement moduleClass, ProviderDescriptor descriptor})> listenerProviders = const [],
    Map<BindingKey, List<ListenerCallInfo>> listenerCallsPerBinding = const {},
    List<({BindingKey key, FormalParameterElement parameter})> valueParameters = const [],
    String? parentPrefix,
    String? sourceUri,
  }) {
    final String subcomponentName = subcomponentClass.name!;
    final String classNamePrefix = parentPrefix != null ? '$parentPrefix\$' : '';
    // Must compute the identical value as `CodeGenerator._generateSubcomponentOutput`'s
    // `childPrefix` — that's what actually names the standalone provider
    // `Class` specs referenced by the field types built below. Keeping the
    // two in sync is what lets two different `@Component`s in one file each
    // install the same `@subcomponent` class without their child providers
    // colliding (see the comment there for the full rationale).
    final String componentPrefix = '$classNamePrefix$subcomponentName';
    final className = '$classNamePrefix$subcomponentName\$Subcomponent';
    final Reference subcomponentTypeRef = refer(
      subcomponentName,
      subcomponentClass.resolvePublicUri(sourceUri: sourceUri),
    );

    final List<_Binding> bindings = _buildBindings(
      modules,
      injectables,
      factories,
      typedefProviders,
      asyncBindings,
      componentPrefix: componentPrefix,
      valueParameters: valueParameters,
    );

    // Add listener providers as implicit dependencies for topological ordering
    for (final MapEntry<BindingKey, List<ListenerCallInfo>> entry in listenerCallsPerBinding.entries) {
      final _Binding? binding = bindings.where((b) => b.key == entry.key).firstOrNull;
      if (binding == null) continue;
      for (final ListenerCallInfo listener in entry.value) {
        final String listenerBaseName = listener.fieldName.substring(1); // remove leading _
        final _Binding? listenerBinding = bindings.where((b) => b.baseName == listenerBaseName).firstOrNull;
        if (listenerBinding != null && !binding.dependencyKeys.contains(listenerBinding.key)) {
          binding.dependencyKeys.add(listenerBinding.key);
        }
      }
    }

    // Nullable-widening within the child graph only; deps satisfied by the
    // parent stay untouched — the parent lookup below widens on its own.
    final Set<BindingKey> bindingKeys = {for (final b in bindings) b.key};
    for (final binding in bindings) {
      for (var i = 0; i < binding.dependencyKeys.length; i++) {
        final BindingKey key = binding.dependencyKeys[i];
        if (key.isNullable) {
          final BindingKey nonNullableKey = key.nonNullable;
          if (!bindingKeys.contains(key) && bindingKeys.contains(nonNullableKey)) {
            binding.dependencyKeys[i] = nonNullableKey;
          }
        }
      }
    }

    _matchEntryPoints(bindings, subcomponentData.entryPoints);

    final List<_Binding> sorted = _topologicalSort(bindings);

    final moduleParams = <({ClassElement moduleClass, String paramName, bool hasDefaultConstructor})>[];
    for (final m in modules) {
      moduleParams.add((
        moduleClass: m.moduleClass,
        paramName: m.moduleClass.name!.uncapitalize,
        hasDefaultConstructor: m.moduleData.hasDefaultConstructor,
      ));
    }

    final List<FormalParameterElement> valueParams = [for (final vp in valueParameters) vp.parameter];

    final Constructor createFactory = _buildSubcomponentCreateFactory(
      className: className,
      parentClassName: parentClassName,
      moduleParams: moduleParams,
      valueParams: valueParams,
      sourceUri: sourceUri,
    );

    final Constructor privateConstructor = _buildSubcomponentPrivateConstructor(
      parentClassName: parentClassName,
      moduleParams: [
        for (final mp in moduleParams) (moduleClass: mp.moduleClass, paramName: mp.paramName),
      ],
      valueParams: valueParams,
      sortedBindings: sorted,
      parentProviderFieldNames: parentProviderFieldNames,
      listenerCallsPerBinding: listenerCallsPerBinding,
      sourceUri: sourceUri,
    );

    final fields = <Field>[
      Field(
        (b) => b
          ..name = '_parent'
          ..type = refer(parentClassName)
          ..modifier = FieldModifier.final$,
      ),
    ];
    // Value parameters materialize as plain `final` fields directly on the
    // subcomponent (Dagger's `@BindsInstance` output shape) — no provider
    // wrapper for *this* field; other bindings that depend on the same key
    // consume it through the ordinary provider field added by the loop below.
    for (final FormalParameterElement vp in valueParams) {
      fields.add(
        Field(
          (b) => b
            ..name = vp.name!
            ..type = vp.type.typeRef(sourceUri: sourceUri)
            ..modifier = FieldModifier.final$,
        ),
      );
    }
    for (final binding in sorted) {
      if (binding.isField) {
        fields.add(
          Field(
            (b) => b
              ..name = '_${binding.baseName}'
              ..type = refer(binding.providerClassName)
              ..late = true
              ..modifier = FieldModifier.final$,
          ),
        );
      }
    }

    final entryMethods = <Method>[];
    final matchedEntryPoints = <EntryPoint>{};
    for (final binding in sorted) {
      if (!binding.isEntryPoint) {
        continue;
      }
      for (final EntryPoint ep in binding.entryPoints) {
        matchedEntryPoints.add(ep);
        final Element element = ep.element;
        final DartType? returnType = element.entryPointReturnType;
        final String? name = element.entryPointName;
        if (returnType == null || name == null) {
          continue;
        }
        final bodyExpr = ep.isProvider ? '_${binding.baseName}' : '_${binding.baseName}.get()';
        entryMethods.add(
          Method(
            (b) => b
              ..name = name
              ..returns = returnType.typeRef(sourceUri: sourceUri)
              ..annotations.add(refer('override'))
              ..lambda = true
              ..body = Code(bodyExpr)
              ..type = element is PropertyAccessorElement ? MethodType.getter : null,
          ),
        );
      }
    }

    // Entry points satisfied by the PARENT graph (no child binding): read
    // them through the parent reference.
    for (final EntryPoint ep in subcomponentData.entryPoints) {
      if (matchedEntryPoints.contains(ep)) {
        continue;
      }
      final Element element = ep.element;
      final DartType? returnType = element.entryPointReturnType;
      final String? name = element.entryPointName;
      if (returnType == null || name == null) {
        continue;
      }
      final String? parentField = _parentFieldFor(ep.key, parentProviderFieldNames);
      if (parentField == null) {
        continue; // Already diagnosed as a missing binding during validation.
      }
      final bodyExpr = ep.isProvider ? '_parent.$parentField' : '_parent.$parentField.get()';
      entryMethods.add(
        Method(
          (b) => b
            ..name = name
            ..returns = returnType.typeRef(sourceUri: sourceUri)
            ..annotations.add(refer('override'))
            ..lambda = true
            ..body = Code(bodyExpr)
            ..type = element is PropertyAccessorElement ? MethodType.getter : null,
        ),
      );
    }

    return Class(
      (b) => b
        ..name = className
        ..implements.add(subcomponentTypeRef)
        ..constructors.addAll([createFactory, privateConstructor])
        ..fields.addAll(fields)
        ..methods.addAll(entryMethods),
    );
  }

  /// Generates the private `_<FactoryName>$Factory` implementation of the
  /// abstract subcomponent factory: holds the parent component reference and
  /// delegates `create(...)` to `<Name>$Subcomponent.create(_parent, ...)`.
  Class generateSubcomponentFactoryImpl({
    required ClassElement factoryClass,
    required ClassElement subcomponentClass,
    required String parentClassName,
    required List<({ClassElement moduleClass, ModuleData moduleData})> modules,
    String? parentPrefix,
    String? sourceUri,
  }) {
    final String factoryName = factoryClass.name!;
    final String classNamePrefix = parentPrefix != null ? '$parentPrefix\$' : '';
    final className = '_$classNamePrefix$factoryName\$Factory';
    final subcomponentImplName = '$classNamePrefix${subcomponentClass.name!}\$Subcomponent';
    final Reference factoryTypeRef = refer(factoryName, factoryClass.resolvePublicUri(sourceUri: sourceUri));
    final Reference subcomponentTypeRef = refer(
      subcomponentClass.name!,
      subcomponentClass.resolvePublicUri(sourceUri: sourceUri),
    );

    final params = <Parameter>[];
    final args = <String, Expression>{};
    for (final m in modules) {
      final String paramName = m.moduleClass.name!.uncapitalize;
      final Reference moduleTypeRef = refer(m.moduleClass.name!, m.moduleClass.resolvePublicUri(sourceUri: sourceUri));
      final bool hasDefaultCtor = m.moduleData.hasDefaultConstructor;
      params.add(
        Parameter(
          (b) => b
            ..name = paramName
            ..named = true
            ..required = !hasDefaultCtor
            ..type = TypeReference(
              (b) => b
                ..symbol = moduleTypeRef.symbol
                ..url = moduleTypeRef.url
                ..isNullable = hasDefaultCtor,
            ),
        ),
      );
      args[paramName] = refer(paramName);
    }

    return Class(
      (b) => b
        ..name = className
        ..implements.add(factoryTypeRef)
        ..constructors.add(
          Constructor(
            (b) => b
              ..constant = true
              ..requiredParameters.add(
                Parameter(
                  (b) => b
                    ..name = '_parent'
                    ..toThis = true,
                ),
              ),
          ),
        )
        ..fields.add(
          Field(
            (b) => b
              ..name = '_parent'
              ..type = refer(parentClassName)
              ..modifier = FieldModifier.final$,
          ),
        )
        ..methods.add(
          Method(
            (b) => b
              ..name = 'create'
              ..returns = subcomponentTypeRef
              ..annotations.add(refer('override'))
              ..optionalParameters.addAll(params)
              ..lambda = true
              ..body = refer(subcomponentImplName).newInstanceNamed('create', [refer('_parent')], args).code,
          ),
        ),
    );
  }

  /// Generates the private `_<FactoryName>$Factory` implementation of an
  /// **explicit** `@subcomponentFactory` — mirrors [generateSubcomponentFactoryImpl]
  /// but the override method mirrors [explicitFactoryData]'s user-declared
  /// `create(...)` signature exactly (arbitrary positional/named mix, in
  /// whatever order the user wrote it), rather than the synthesized factory's
  /// all-named-module shape.
  ///
  /// Every parameter is forwarded to `<Name>$Subcomponent.create(...)` by
  /// name: for a module parameter the forwarded name is the module's own
  /// conventional name (`m.moduleClass.name!.uncapitalize`, matching
  /// `_buildSubcomponentCreateFactory`'s parameter names) regardless of what
  /// the user called their own parameter; for a value parameter it is the
  /// user's own parameter name (matching `_buildSubcomponentCreateFactory`'s
  /// value-parameter naming, see [ComponentGenerator.generateSubcomponent]).
  Class generateExplicitSubcomponentFactoryImpl({
    required SubcomponentFactoryData explicitFactoryData,
    required ClassElement subcomponentClass,
    required String parentClassName,
    String? parentPrefix,
    String? sourceUri,
  }) {
    final ClassElement factoryClass = explicitFactoryData.factoryElement;
    final MethodElement createMethod = explicitFactoryData.createMethod;
    final String factoryName = factoryClass.name!;
    final String classNamePrefix = parentPrefix != null ? '$parentPrefix\$' : '';
    final className = '_$classNamePrefix$factoryName\$Factory';
    final subcomponentImplName = '$classNamePrefix${subcomponentClass.name!}\$Subcomponent';
    final Reference factoryTypeRef = refer(factoryName, factoryClass.resolvePublicUri(sourceUri: sourceUri));

    // Mirror the user's exact method signature — same approach as
    // `ProviderGenerator._buildInlineFactoryMethod` for `@assistedFactory`.
    final requiredParams = <Parameter>[];
    final optionalParams = <Parameter>[];
    for (final FormalParameterElement param in createMethod.formalParameters) {
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
        requiredParams.add(spec);
      } else {
        optionalParams.add(spec);
      }
    }

    // Forward every parameter by name. Module parameters use the module's
    // conventional name (the internal factory's own parameter name); value
    // parameters use the user's own chosen name (the internal factory
    // exposes the exact same name for that value parameter).
    final args = <String, Expression>{};
    for (final (:moduleClass, :parameter) in explicitFactoryData.moduleParameters) {
      args[moduleClass.name!.uncapitalize] = refer(parameter.name!);
    }
    for (final (:parameter, type: _, qualifier: _) in explicitFactoryData.valueParameters) {
      args[parameter.name!] = refer(parameter.name!);
    }

    final Reference returnTypeRef = createMethod.returnType.typeRef(sourceUri: sourceUri);

    return Class(
      (b) => b
        ..name = className
        ..implements.add(factoryTypeRef)
        ..constructors.add(
          Constructor(
            (b) => b
              ..constant = true
              ..requiredParameters.add(
                Parameter(
                  (b) => b
                    ..name = '_parent'
                    ..toThis = true,
                ),
              ),
          ),
        )
        ..fields.add(
          Field(
            (b) => b
              ..name = '_parent'
              ..type = refer(parentClassName)
              ..modifier = FieldModifier.final$,
          ),
        )
        ..methods.add(
          Method(
            (b) => b
              ..name = createMethod.name
              ..returns = returnTypeRef
              ..annotations.add(refer('override'))
              ..requiredParameters.addAll(requiredParams)
              ..optionalParameters.addAll(optionalParams)
              ..lambda = true
              ..body = refer(subcomponentImplName).newInstanceNamed('create', [refer('_parent')], args).code,
          ),
        ),
    );
  }

  Constructor _buildSubcomponentCreateFactory({
    required String className,
    required String parentClassName,
    required List<({ClassElement moduleClass, String paramName, bool hasDefaultConstructor})> moduleParams,
    List<FormalParameterElement> valueParams = const [],
    String? sourceUri,
  }) {
    final params = <Parameter>[];
    final args = <Expression>[refer('parent')];

    for (final mp in moduleParams) {
      final Reference moduleTypeRef = refer(
        mp.moduleClass.name!,
        mp.moduleClass.resolvePublicUri(sourceUri: sourceUri),
      );
      final bool hasDefaultCtor = mp.hasDefaultConstructor;
      params.add(
        Parameter(
          (b) => b
            ..name = mp.paramName
            ..named = true
            ..required = !hasDefaultCtor
            ..type = TypeReference(
              (b) => b
                ..symbol = moduleTypeRef.symbol
                ..url = moduleTypeRef.url
                ..isNullable = hasDefaultCtor,
            ),
        ),
      );
      final Expression arg = hasDefaultCtor
          ? refer(mp.paramName).ifNullThen(moduleTypeRef.newInstance([]))
          : refer(mp.paramName);
      args.add(arg);
    }

    // Value parameters (`@subcomponentFactory` instance bindings) are always
    // required named parameters — there is no sensible default for a value
    // that must be supplied by the caller.
    for (final FormalParameterElement vp in valueParams) {
      params.add(
        Parameter(
          (b) => b
            ..name = vp.name!
            ..named = true
            ..required = true
            ..type = vp.type.typeRef(sourceUri: sourceUri),
        ),
      );
      args.add(refer(vp.name!));
    }

    return Constructor(
      (b) => b
        ..factory = true
        ..name = 'create'
        ..requiredParameters.add(
          Parameter(
            (b) => b
              ..name = 'parent'
              ..type = refer(parentClassName),
          ),
        )
        ..optionalParameters.addAll(params)
        ..lambda = true
        ..body = refer(className).newInstanceNamed('_', args).code,
    );
  }

  Constructor _buildSubcomponentPrivateConstructor({
    required String parentClassName,
    required List<({ClassElement moduleClass, String paramName})> moduleParams,
    required List<_Binding> sortedBindings,
    required Map<BindingKey, String> parentProviderFieldNames,
    List<FormalParameterElement> valueParams = const [],
    Map<BindingKey, List<ListenerCallInfo>> listenerCallsPerBinding = const {},
    String? sourceUri,
  }) {
    final params = <Parameter>[
      Parameter(
        (b) => b
          ..name = '_parent'
          ..toThis = true,
      ),
    ];
    for (final mp in moduleParams) {
      final Reference moduleTypeRef = refer(
        mp.moduleClass.name!,
        mp.moduleClass.resolvePublicUri(sourceUri: sourceUri),
      );
      params.add(
        Parameter(
          (b) => b
            ..name = mp.paramName
            ..type = moduleTypeRef,
        ),
      );
    }
    // Value parameters set their raw field directly via `this.<name>` — the
    // field is declared alongside in `generateSubcomponent`.
    for (final FormalParameterElement vp in valueParams) {
      params.add(
        Parameter(
          (b) => b
            ..name = vp.name!
            ..toThis = true,
        ),
      );
    }

    final bodyStatements = <String>[];
    for (final binding in sortedBindings) {
      // Value-parameter bindings have no dependencies and no module: their
      // provider simply wraps the raw field set above via the initializing
      // formal parameter of the same name.
      if (binding.isValueParameter) {
        bodyStatements.add('_${binding.baseName} = ${binding.providerClassName}(${binding.valueParameter!.name!});');
        continue;
      }

      final ctorArgs = <String>[];

      final List<ListenerCallInfo>? listenerCalls = listenerCallsPerBinding[binding.key];
      final listenerBindingKeys = <BindingKey>{};
      if (listenerCalls != null) {
        for (final ListenerCallInfo listener in listenerCalls) {
          final String listenerBaseName = listener.fieldName.substring(1); // remove leading _
          final _Binding listenerBinding = sortedBindings.firstWhere((b) => b.baseName == listenerBaseName);
          listenerBindingKeys.add(listenerBinding.key);
        }
      }

      // Dependency providers first: child bindings by local reference,
      // parent bindings through the parent component's promoted fields.
      for (final BindingKey depKey in binding.dependencyKeys) {
        if (listenerBindingKeys.contains(depKey)) continue;
        final _Binding? depBinding = sortedBindings.where((b) => b.key == depKey).firstOrNull;
        if (depBinding != null) {
          ctorArgs.add(depBinding.isField ? '_${depBinding.baseName}' : depBinding.variableName);
          continue;
        }
        final String? parentField = _parentFieldFor(depKey, parentProviderFieldNames);
        if (parentField == null) {
          // Should be unreachable: `BindingResolver` already proved this key
          // resolves through the parent (`parentBindingsUsed`), so codegen
          // and validation have diverged — an inject.dart generator bug, not
          // a problem with the user's annotations.
          throw StateError(
            "inject.dart internal error while generating '$parentClassName': dependency "
            "'${depKey.debugLabel}' was validated as a parent binding but has no promoted "
            'parent field at codegen time. Please file an issue at '
            'https://github.com/ralph-bergmann/inject.dart/issues with a reproduction.',
          );
        }
        ctorArgs.add('_parent.$parentField');
      }

      if (listenerCalls != null) {
        for (final ListenerCallInfo listener in listenerCalls) {
          final String listenerBaseName = listener.fieldName.substring(1); // remove leading _
          final _Binding listenerBinding = sortedBindings.firstWhere((b) => b.baseName == listenerBaseName);
          ctorArgs.add(listenerBinding.isField ? '_${listenerBinding.baseName}' : listenerBinding.variableName);
        }
      }

      if (binding.moduleParamName != null) {
        ctorArgs.add(binding.moduleParamName!);
      }

      final String argsStr = ctorArgs.join(', ');

      if (binding.isField) {
        bodyStatements.add('_${binding.baseName} = ${binding.providerClassName}($argsStr);');
      } else {
        bodyStatements.add('final ${binding.variableName} = ${binding.providerClassName}($argsStr);');
      }
    }

    return Constructor(
      (b) => b
        ..name = '_'
        ..requiredParameters.addAll(params)
        ..body = Code(bodyStatements.join('\n')),
    );
  }

  /// Resolves the parent provider field for [key], widening `Foo?` to `Foo`
  /// when only the non-nullable parent binding exists.
  static String? _parentFieldFor(BindingKey key, Map<BindingKey, String> parentProviderFieldNames) =>
      parentProviderFieldNames[key] ?? (key.isNullable ? parentProviderFieldNames[key.nonNullable] : null);

  // --- Binding resolution ---

  List<_Binding> _buildBindings(
    List<({ClassElement moduleClass, ModuleData moduleData})> modules,
    List<({ClassElement classElement, InjectableData injectable})> injectables,
    List<({ClassElement factoryElement, AssistedInjectData injectData, AssistedFactoryData factoryData})> factories,
    List<TypedefProviderData> typedefProviders,
    Map<BindingKey, bool> asyncBindings, {
    String? componentPrefix,
    List<({BindingKey key, FormalParameterElement parameter})> valueParameters = const [],
  }) {
    final bindings = <_Binding>[];

    // NOTE: order-sensitive — later modules override earlier ones (mock-injection pattern). Do not sort or reorder.
    for (final m in modules) {
      final String moduleParamName = m.moduleClass.name!.uncapitalize;
      for (final ProviderDescriptor provider in m.moduleData.providers) {
        final DartType returnType = provider.returnType;
        // For @asynchronous Future<T> providers, use T for naming so
        // the provider class name matches consumer dep references.
        final DartType unwrapped = returnType.unwrapFuture;
        final String typeName = provider.metadata.isAsynchronous && !identical(unwrapped, returnType)
            ? unwrapped.displayName
            : returnType.displayName;
        bindings
          ..removeWhere((binding) => binding.key == provider.key)
          ..add(
            _Binding(
              key: provider.key,
              typeName: typeName,
              qualifier: provider.key.qualifier,
              moduleParamName: moduleParamName,
              dependencyKeys: provider.dependencies
                  .map((dep) => _requireBindingKey(dep.type, qualifier: dep.qualifier))
                  .toList(),
              isSingleton: provider.metadata.isSingleton || provider.metadata.isProvisionListener,
              isAsynchronous: asyncBindings[provider.key] == true,
              componentPrefix: componentPrefix,
            ),
          );
      }
    }

    for (final injectable in injectables) {
      final String typeName = injectable.classElement.name!;
      bindings.add(
        _Binding(
          key: injectable.injectable.key,
          typeName: typeName,
          qualifier: injectable.injectable.key.qualifier,
          moduleParamName: null,
          dependencyKeys: injectable.injectable.dependencies
              .map((dep) => _requireBindingKey(dep.type, qualifier: dep.qualifier))
              .toList(),
          isSingleton: injectable.injectable.isSingleton,
          isAsynchronous: asyncBindings[injectable.injectable.key] == true,
          componentPrefix: componentPrefix,
        ),
      );
    }

    // Group factories by factoryElement so multi-constructor factories
    // produce a single binding with unified dependency keys.
    final factoriesByElement =
        <
          ClassElement,
          List<({ClassElement factoryElement, AssistedInjectData injectData, AssistedFactoryData factoryData})>
        >{};
    for (final factory in factories) {
      (factoriesByElement[factory.factoryElement] ??= []).add(factory);
    }

    for (final List<({AssistedFactoryData factoryData, ClassElement factoryElement, AssistedInjectData injectData})>
        group
        in factoriesByElement.values) {
      final String typeName = group.first.factoryElement.name!;
      final BindingKey? key = BindingKey.fromDartType(group.first.factoryElement.thisType);
      if (key == null) {
        continue;
      }

      // Unify dependency keys across all constructors (deduplicate)
      final depKeys = <BindingKey>{};
      for (final factory in group) {
        for (final ParameterDependency dep in factory.injectData.injectedDependencies) {
          depKeys.add(_requireBindingKey(dep.type, qualifier: dep.qualifier));
        }
      }

      bindings.add(
        _Binding(
          key: key,
          typeName: typeName,
          qualifier: null,
          moduleParamName: null,
          dependencyKeys: depKeys.toList(),
          isSingleton: false,
          isAsynchronous: asyncBindings[key] == true,
          componentPrefix: componentPrefix,
        ),
      );
    }

    for (final typedefData in typedefProviders) {
      final DartType typedefType = typedefData.typedefType;
      final BindingKey? key = BindingKey.fromDartType(typedefType);
      if (key == null) {
        continue;
      }
      final String typeName = typedefType.displayName;
      bindings.add(
        _Binding(
          key: key,
          typeName: typeName,
          qualifier: null,
          moduleParamName: null,
          dependencyKeys: typedefData.injectedParams
              .map((ip) => _requireBindingKey(ip.depType, qualifier: ip.qualifier))
              .toList(),
          isSingleton: false,
          isAsynchronous: asyncBindings[key] == true,
          componentPrefix: componentPrefix,
        ),
      );
    }

    // `@subcomponentFactory` value parameters (Dagger's `@BindsInstance`
    // equivalent) — the provider wraps the raw value that already lives as a
    // plain field on the enclosing `<Name>$Subcomponent`; see
    // `_buildSubcomponentPrivateConstructor`. Never present on parent
    // component graphs (`generate` always passes the default empty list).
    for (final vp in valueParameters) {
      bindings.add(
        _Binding(
          key: vp.key,
          typeName: vp.parameter.type.nonNullableDisplayName,
          qualifier: vp.key.qualifier,
          moduleParamName: null,
          dependencyKeys: [],
          isSingleton: false,
          isAsynchronous: false,
          componentPrefix: componentPrefix,
          valueParameter: vp.parameter,
        ),
      );
    }

    return bindings;
  }

  void _matchEntryPoints(List<_Binding> bindings, List<EntryPoint> entryPoints) {
    for (final ep in entryPoints) {
      for (final binding in bindings) {
        if (binding.key == ep.key) {
          binding.entryPoints.add(ep);
          break;
        }
      }
    }
  }

  List<_Binding> _topologicalSort(List<_Binding> bindings) {
    // Sort by typeName for determinism before topological sort
    final sorted = <_Binding>[];
    final visited = <BindingKey>{};

    void visit(_Binding binding) {
      if (visited.contains(binding.key)) {
        return;
      }
      visited.add(binding.key);
      for (final BindingKey depKey in binding.dependencyKeys) {
        final _Binding? dep = bindings.where((b) => b.key == depKey).firstOrNull;
        if (dep != null) {
          visit(dep);
        }
      }
      sorted.add(binding);
    }

    // Process in alphabetical order for determinism
    ([...bindings]..sort((a, b) {
          final int cmp = a.typeName.compareTo(b.typeName);
          if (cmp != 0) return cmp;
          // Tiebreaker: sort by qualifier so that multiple bindings of the
          // same type produce a deterministic order.
          return (a.qualifier ?? '').compareTo(b.qualifier ?? '');
        }))
        .forEach(visit);

    return sorted;
  }

  // --- Helpers ---

  static BindingKey _requireBindingKey(DartType dartType, {String? qualifier}) {
    final BindingKey? key = BindingKey.fromDartType(dartType, qualifier: qualifier);
    if (key != null) {
      return key;
    }
    throw StateError('Unsupported binding type in component generation: ${dartType.getDisplayString()}');
  }
}

// --- Internal data types ---

class _Binding {
  _Binding({
    required this.key,
    required this.typeName,
    required this.qualifier,
    required this.moduleParamName,
    required this.dependencyKeys,
    required this.isSingleton,
    required this.isAsynchronous,
    required this.componentPrefix,
    this.isSubcomponentFactory = false,
    this.valueParameter,
  });

  final BindingKey key;
  final String typeName;
  final String? qualifier;
  final String? moduleParamName;
  final List<BindingKey> dependencyKeys;
  final bool isSingleton;
  final bool isAsynchronous;
  final String? componentPrefix;

  /// `true` for the synthesized factory binding of an installed subcomponent —
  /// its provider is constructed with the component instance (`this`).
  final bool isSubcomponentFactory;

  /// Non-null for an `@subcomponentFactory` value parameter — its provider
  /// wraps the raw value already held by the enclosing `<Name>$Subcomponent`
  /// (see `ComponentGenerator.generateSubcomponent`) instead of any
  /// dependency-based construction.
  final FormalParameterElement? valueParameter;

  bool get isValueParameter => valueParameter != null;

  /// Set when an installed subcomponent consumes this binding — the provider
  /// is then emitted as a field instead of a constructor local so the
  /// generated subcomponent can address it through the parent reference.
  bool promoted = false;

  final List<EntryPoint> entryPoints = [];

  bool get isEntryPoint => entryPoints.isNotEmpty;

  /// Whether the provider is stored in a field (`_<baseName>`) rather than a
  /// constructor local.
  bool get isField => isEntryPoint || promoted || isValueParameter;

  String get providerClassName =>
      ProviderGenerator.providerClassName(typeName, qualifier, componentPrefix: componentPrefix);

  String get baseName => ProviderGenerator.providerBaseName(typeName, qualifier, componentPrefix: componentPrefix);

  /// Variable name used in the component constructor (no underscore for locals).
  String get variableName => baseName;
}
