// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'summary.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ComponentSummary _$ComponentSummaryFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'ComponentSummary',
      json,
      ($checkedConvert) {
        final val = ComponentSummary(
          $checkedConvert(
              'clazz', (v) => SymbolPath.fromJson(v as Map<String, dynamic>)),
          $checkedConvert(
              'modules',
              (v) => (v as List<dynamic>)
                  .map((e) => SymbolPath.fromJson(e as Map<String, dynamic>))
                  .toList()),
          $checkedConvert(
              'providers',
              (v) => (v as List<dynamic>).map(
                  (e) => ProviderSummary.fromJson(e as Map<String, dynamic>))),
        );
        return val;
      },
    );

Map<String, dynamic> _$ComponentSummaryToJson(ComponentSummary instance) =>
    <String, dynamic>{
      'clazz': instance.clazz,
      'modules': instance.modules,
      'providers': instance.providers,
    };

FactorySummary _$FactorySummaryFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'FactorySummary',
      json,
      ($checkedConvert) {
        final val = FactorySummary(
          $checkedConvert(
              'clazz', (v) => SymbolPath.fromJson(v as Map<String, dynamic>)),
          $checkedConvert('factory',
              (v) => FactoryMethodSummary.fromJson(v as Map<String, dynamic>)),
        );
        return val;
      },
    );

Map<String, dynamic> _$FactorySummaryToJson(FactorySummary instance) =>
    <String, dynamic>{
      'clazz': instance.clazz,
      'factory': instance.factory,
    };

FactoryMethodSummary _$FactoryMethodSummaryFromJson(
        Map<String, dynamic> json) =>
    $checkedCreate(
      'FactoryMethodSummary',
      json,
      ($checkedConvert) {
        final val = FactoryMethodSummary(
          $checkedConvert('name', (v) => v as String),
          $checkedConvert('createdType',
              (v) => InjectedType.fromJson(v as Map<String, dynamic>)),
          $checkedConvert(
              'parameters',
              (v) => (v as List<dynamic>)
                  .map((e) => InjectedType.fromJson(e as Map<String, dynamic>))
                  .toList()),
        );
        return val;
      },
    );

Map<String, dynamic> _$FactoryMethodSummaryToJson(
        FactoryMethodSummary instance) =>
    <String, dynamic>{
      'name': instance.name,
      'createdType': instance.createdType,
      'parameters': instance.parameters,
    };

InjectableSummary _$InjectableSummaryFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'InjectableSummary',
      json,
      ($checkedConvert) {
        final val = InjectableSummary(
          $checkedConvert(
              'clazz', (v) => SymbolPath.fromJson(v as Map<String, dynamic>)),
          $checkedConvert('constructor',
              (v) => ProviderSummary.fromJson(v as Map<String, dynamic>)),
        );
        return val;
      },
    );

Map<String, dynamic> _$InjectableSummaryToJson(InjectableSummary instance) =>
    <String, dynamic>{
      'clazz': instance.clazz,
      'constructor': instance.constructor,
    };

LibrarySummary _$LibrarySummaryFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'LibrarySummary',
      json,
      ($checkedConvert) {
        final val = LibrarySummary(
          $checkedConvert('assetUri', (v) => Uri.parse(v as String)),
          modules: $checkedConvert(
              'modules',
              (v) =>
                  (v as List<dynamic>?)
                      ?.map((e) =>
                          ModuleSummary.fromJson(e as Map<String, dynamic>))
                      .toList() ??
                  const []),
          injectables: $checkedConvert(
              'injectables',
              (v) =>
                  (v as List<dynamic>?)
                      ?.map((e) =>
                          InjectableSummary.fromJson(e as Map<String, dynamic>))
                      .toList() ??
                  const []),
          assistedInjectables: $checkedConvert(
              'assistedInjectables',
              (v) =>
                  (v as List<dynamic>?)
                      ?.map((e) =>
                          InjectableSummary.fromJson(e as Map<String, dynamic>))
                      .toList() ??
                  const []),
          factories: $checkedConvert(
              'factories',
              (v) =>
                  (v as List<dynamic>?)
                      ?.map((e) =>
                          FactorySummary.fromJson(e as Map<String, dynamic>))
                      .toList() ??
                  const []),
        );
        return val;
      },
    );

Map<String, dynamic> _$LibrarySummaryToJson(LibrarySummary instance) =>
    <String, dynamic>{
      'assetUri': instance.assetUri.toString(),
      'modules': instance.modules,
      'injectables': instance.injectables,
      'assistedInjectables': instance.assistedInjectables,
      'factories': instance.factories,
    };

ComponentsSummary _$ComponentsSummaryFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'ComponentsSummary',
      json,
      ($checkedConvert) {
        final val = ComponentsSummary(
          $checkedConvert('assetUri', (v) => Uri.parse(v as String)),
          components: $checkedConvert(
              'components',
              (v) => (v as List<dynamic>)
                  .map((e) =>
                      ComponentSummary.fromJson(e as Map<String, dynamic>))
                  .toList()),
        );
        return val;
      },
    );

Map<String, dynamic> _$ComponentsSummaryToJson(ComponentsSummary instance) =>
    <String, dynamic>{
      'assetUri': instance.assetUri.toString(),
      'components': instance.components,
    };

ModuleSummary _$ModuleSummaryFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'ModuleSummary',
      json,
      ($checkedConvert) {
        final val = ModuleSummary(
          $checkedConvert(
              'clazz', (v) => SymbolPath.fromJson(v as Map<String, dynamic>)),
          $checkedConvert('hasDefaultConstructor', (v) => v as bool),
          $checkedConvert(
              'providers',
              (v) => (v as List<dynamic>).map(
                  (e) => ProviderSummary.fromJson(e as Map<String, dynamic>))),
        );
        return val;
      },
    );

Map<String, dynamic> _$ModuleSummaryToJson(ModuleSummary instance) =>
    <String, dynamic>{
      'clazz': instance.clazz,
      'hasDefaultConstructor': instance.hasDefaultConstructor,
      'providers': instance.providers,
    };

ProviderSummary _$ProviderSummaryFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'ProviderSummary',
      json,
      ($checkedConvert) {
        final val = ProviderSummary(
          $checkedConvert('name', (v) => v as String),
          $checkedConvert('kind', (v) => $enumDecode(_$ProviderKindEnumMap, v)),
          $checkedConvert('injectedType',
              (v) => InjectedType.fromJson(v as Map<String, dynamic>)),
          dependencies: $checkedConvert(
              'dependencies',
              (v) =>
                  (v as List<dynamic>?)?.map((e) =>
                      InjectedType.fromJson(e as Map<String, dynamic>)) ??
                  const []),
        );
        return val;
      },
    );

Map<String, dynamic> _$ProviderSummaryToJson(ProviderSummary instance) =>
    <String, dynamic>{
      'name': instance.name,
      'kind': _$ProviderKindEnumMap[instance.kind]!,
      'injectedType': instance.injectedType,
      'dependencies': instance.dependencies,
    };

const _$ProviderKindEnumMap = {
  ProviderKind.constructor: 'constructor',
  ProviderKind.method: 'method',
  ProviderKind.getter: 'getter',
};
