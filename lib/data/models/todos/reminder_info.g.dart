// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reminder_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ReminderInfoImpl _$$ReminderInfoImplFromJson(Map<String, dynamic> json) {
  $checkKeys(
    json,
    requiredKeys: const ['serial_num'],
  );
  return _$ReminderInfoImpl(
    serialNum: json['serial_num'] as String,
    remindAt: dateTimeFromJson(json['remind_at'] as String),
  );
}

Map<String, dynamic> _$$ReminderInfoImplToJson(_$ReminderInfoImpl instance) =>
    <String, dynamic>{
      'serial_num': instance.serialNum,
      'remind_at': dateTimeToJson(instance.remindAt),
    };
