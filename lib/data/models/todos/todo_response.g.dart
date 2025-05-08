// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'todo_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TodoResponseImpl _$$TodoResponseImplFromJson(Map<String, dynamic> json) =>
    _$TodoResponseImpl(
      serialNum: json['serialNum'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      createdAt: dateTimeFromJson(json['createdAt'] as String),
      updatedAt: dateTimeFromJson(json['updatedAt'] as String),
      dueAt: dateTimeFromJson(json['dueAt'] as String),
      priority: Priority.fromJson((json['priority'] as num).toInt()),
      status: Status.fromJson((json['status'] as num).toInt()),
      repeat: json['repeat'] as String?,
      completedAt: dateTimeFromJson(json['completedAt'] as String),
      assigneeId: json['assigneeId'] as String?,
      progress: (json['progress'] as num).toInt(),
      location: json['location'] as String?,
      ownerId: json['ownerId'] as String?,
      projects: (json['projects'] as List<dynamic>)
          .map((e) => ProjectInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      tags: (json['tags'] as List<dynamic>)
          .map((e) => TagInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      reminders: (json['reminders'] as List<dynamic>)
          .map((e) => ReminderInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      attachments: (json['attachments'] as List<dynamic>)
          .map((e) => AttachmentInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$$TodoResponseImplToJson(_$TodoResponseImpl instance) =>
    <String, dynamic>{
      'serialNum': instance.serialNum,
      'title': instance.title,
      'description': instance.description,
      'createdAt': dateTimeToJson(instance.createdAt),
      'updatedAt': dateTimeToJson(instance.updatedAt),
      'dueAt': dateTimeToJson(instance.dueAt),
      'priority': _priorityToJson(instance.priority),
      'status': _statusToJson(instance.status),
      'repeat': instance.repeat,
      'completedAt': dateTimeToJson(instance.completedAt),
      'assigneeId': instance.assigneeId,
      'progress': instance.progress,
      'location': instance.location,
      'ownerId': instance.ownerId,
      'projects': instance.projects,
      'tags': instance.tags,
      'reminders': instance.reminders,
      'attachments': instance.attachments,
    };
