// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'todo_input.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TodoInputImpl _$$TodoInputImplFromJson(Map<String, dynamic> json) =>
    _$TodoInputImpl(
      title: json['title'] as String?,
      description: json['description'] as String?,
      dueAt: dateTimeFromJson(json['dueAt'] as String?),
      priority: $enumDecodeNullable(_$PriorityEnumMap, json['priority']),
      status: $enumDecodeNullable(_$StatusEnumMap, json['status']),
      tags: (json['tags'] as List<dynamic>?)
          ?.map((e) => CreateOrUpdateForm.fromJson(e as Map<String, dynamic>))
          .toList(),
      repeat: json['repeat'] as String?,
      progress: (json['progress'] as num?)?.toInt(),
      assigneeId: json['assigneeId'] as String?,
      projects: (json['projects'] as List<dynamic>?)
          ?.map((e) => CreateOrUpdateForm.fromJson(e as Map<String, dynamic>))
          .toList(),
      location: json['location'] as String?,
      ownerId: json['ownerId'] as String?,
    );

Map<String, dynamic> _$$TodoInputImplToJson(_$TodoInputImpl instance) =>
    <String, dynamic>{
      'title': instance.title,
      'description': instance.description,
      'dueAt': dateTimeToJson(instance.dueAt),
      'priority': instance.priority,
      'status': instance.status,
      'tags': instance.tags,
      'repeat': instance.repeat,
      'progress': instance.progress,
      'assigneeId': instance.assigneeId,
      'projects': instance.projects,
      'location': instance.location,
      'ownerId': instance.ownerId,
    };

const _$PriorityEnumMap = {
  Priority.low: 'low',
  Priority.medium: 'medium',
  Priority.high: 'high',
};

const _$StatusEnumMap = {
  Status.todo: 'todo',
  Status.inProgress: 'inProgress',
  Status.done: 'done',
};
