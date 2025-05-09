// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'todo_id.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TodoIdImpl _$$TodoIdImplFromJson(Map<String, dynamic> json) {
  $checkKeys(
    json,
    requiredKeys: const ['serial_num'],
  );
  return _$TodoIdImpl(
    serialNum: json['serial_num'] as String,
  );
}

Map<String, dynamic> _$$TodoIdImplToJson(_$TodoIdImpl instance) =>
    <String, dynamic>{
      'serial_num': instance.serialNum,
    };
