// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_core.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ProjectCoreImpl _$$ProjectCoreImplFromJson(Map<String, dynamic> json) {
  $checkKeys(
    json,
    requiredKeys: const ['serial_num', 'name'],
  );
  return _$ProjectCoreImpl(
    serialNum: json['serial_num'] as String,
    name: json['name'] as String,
    description: json['description'] as String?,
  );
}

Map<String, dynamic> _$$ProjectCoreImplToJson(_$ProjectCoreImpl instance) =>
    <String, dynamic>{
      'serial_num': instance.serialNum,
      'name': instance.name,
      'description': instance.description,
    };
