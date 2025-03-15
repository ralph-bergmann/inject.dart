// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'symbol_path.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SymbolPath _$SymbolPathFromJson(Map<String, dynamic> json) => $checkedCreate(
      'SymbolPath',
      json,
      ($checkedConvert) {
        final val = SymbolPath(
          $checkedConvert('package', (v) => v as String?),
          $checkedConvert('path', (v) => v as String?),
          $checkedConvert('symbol', (v) => v as String),
        );
        return val;
      },
    );

Map<String, dynamic> _$SymbolPathToJson(SymbolPath instance) => <String, dynamic>{
      'package': instance.package,
      'path': instance.path,
      'symbol': instance.symbol,
    };
