// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'injected_type.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

InjectedType _$InjectedTypeFromJson(Map<String, dynamic> json) => $checkedCreate(
      'InjectedType',
      json,
      ($checkedConvert) {
        final val = InjectedType(
          $checkedConvert('lookupKey', (v) => LookupKey.fromJson(v as Map<String, dynamic>)),
          name: $checkedConvert('name', (v) => v as String?),
          isNullable: $checkedConvert('isNullable', (v) => v as bool?),
          isRequired: $checkedConvert('isRequired', (v) => v as bool?),
          isNamed: $checkedConvert('isNamed', (v) => v as bool?),
          isProvider: $checkedConvert('isProvider', (v) => v as bool?),
          isSingleton: $checkedConvert('isSingleton', (v) => v as bool?),
          isAsynchronous: $checkedConvert('isAsynchronous', (v) => v as bool?),
          isAssisted: $checkedConvert('isAssisted', (v) => v as bool?),
          isConst: $checkedConvert('isConst', (v) => v as bool?),
        );
        return val;
      },
    );

Map<String, dynamic> _$InjectedTypeToJson(InjectedType instance) => <String, dynamic>{
      'lookupKey': instance.lookupKey,
      'name': instance.name,
      'isNullable': instance.isNullable,
      'isRequired': instance.isRequired,
      'isNamed': instance.isNamed,
      'isProvider': instance.isProvider,
      'isSingleton': instance.isSingleton,
      'isAsynchronous': instance.isAsynchronous,
      'isAssisted': instance.isAssisted,
      'isConst': instance.isConst,
    };
