// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attachment_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AttachmentInfoImpl _$$AttachmentInfoImplFromJson(Map<String, dynamic> json) {
  $checkKeys(
    json,
    requiredKeys: const ['serial_num'],
  );
  return _$AttachmentInfoImpl(
    serialNum: json['serial_num'] as String,
    filePath: json['file_path'] as String?,
    url: json['url'] as String?,
  );
}

Map<String, dynamic> _$$AttachmentInfoImplToJson(
        _$AttachmentInfoImpl instance) =>
    <String, dynamic>{
      'serial_num': instance.serialNum,
      'file_path': instance.filePath,
      'url': instance.url,
    };
