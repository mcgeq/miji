// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'todo_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TodoResponseImpl _$$TodoResponseImplFromJson(Map<String, dynamic> json) {
  $checkKeys(
    json,
    requiredKeys: const [
      'serial_num',
      'title',
      'progress',
      'projects',
      'tags',
      'reminders',
      'attachments'
    ],
  );
  return _$TodoResponseImpl(
    serialNum: json['serial_num'] as String,
    title: json['title'] as String,
    description: json['description'] as String?,
    createdAt: dateTimeFromJson(json['created_at'] as String),
    updatedAt: dateTimeFromJson(json['updated_at'] as String),
    dueAt: dateTimeFromJson(json['due_at'] as String),
    priority: Priority.fromJson((json['priority'] as num).toInt()),
    status: Status.fromJson((json['status'] as num).toInt()),
    repeat: json['repeat'] as String?,
    completedAt: dateTimeFromJson(json['completed_at'] as String),
    assigneeId: json['assignee_id'] as String?,
    progress: (json['progress'] as num).toInt(),
    location: json['location'] as String?,
    ownerId: json['owner_id'] as String?,
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
}

Map<String, dynamic> _$$TodoResponseImplToJson(_$TodoResponseImpl instance) =>
    <String, dynamic>{
      'serial_num': instance.serialNum,
      'title': instance.title,
      'description': instance.description,
      'created_at': dateTimeToJson(instance.createdAt),
      'updated_at': dateTimeToJson(instance.updatedAt),
      'due_at': dateTimeToJson(instance.dueAt),
      'priority': priorityToJson(instance.priority),
      'status': statusToJson(instance.status),
      'repeat': instance.repeat,
      'completed_at': dateTimeToJson(instance.completedAt),
      'assignee_id': instance.assigneeId,
      'progress': instance.progress,
      'location': instance.location,
      'owner_id': instance.ownerId,
      'projects': instance.projects,
      'tags': instance.tags,
      'reminders': instance.reminders,
      'attachments': instance.attachments,
    };
