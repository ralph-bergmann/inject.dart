// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lookup_key.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LookupKey _$LookupKeyFromJson(Map<String, dynamic> json) => $checkedCreate(
      'LookupKey',
      json,
      ($checkedConvert) {
        final val = LookupKey(
          $checkedConvert(
              'root', (v) => SymbolPath.fromJson(v as Map<String, dynamic>)),
          qualifier: $checkedConvert(
              'qualifier',
              (v) => v == null
                  ? null
                  : SymbolPath.fromJson(v as Map<String, dynamic>)),
          typeArguments: $checkedConvert(
              'typeArguments',
              (v) => (v as List<dynamic>?)
                  ?.map((e) => LookupKey.fromJson(e as Map<String, dynamic>))
                  .toList()),
          bound: $checkedConvert(
              'bound',
              (v) => v == null
                  ? null
                  : LookupKey.fromJson(v as Map<String, dynamic>)),
        );
        return val;
      },
    );

Map<String, dynamic> _$LookupKeyToJson(LookupKey instance) => <String, dynamic>{
      'root': instance.root,
      'qualifier': instance.qualifier,
      'typeArguments': instance.typeArguments,
      'bound': instance.bound,
    };
