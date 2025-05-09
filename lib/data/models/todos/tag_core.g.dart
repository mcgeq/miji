// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tag_core.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TagCoreImpl _$$TagCoreImplFromJson(Map<String, dynamic> json) {
  $checkKeys(
    json,
    requiredKeys: const ['serial_num', 'name'],
  );
  return _$TagCoreImpl(
    serialNum: json['serial_num'] as String,
    name: json['name'] as String,
  );
}

Map<String, dynamic> _$$TagCoreImplToJson(_$TagCoreImpl instance) =>
    <String, dynamic>{
      'serial_num': instance.serialNum,
      'name': instance.name,
    };
