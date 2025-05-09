// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'todo_input.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TodoInputImpl _$$TodoInputImplFromJson(Map<String, dynamic> json) =>
    _$TodoInputImpl(
      title: json['title'] as String?,
      description: json['description'] as String?,
      dueAt: dateTimeFromJson(json['due_at'] as String),
      priority: Priority.fromJson((json['priority'] as num).toInt()),
      status: Status.fromJson((json['status'] as num).toInt()),
      tags: (json['tags'] as List<dynamic>?)
          ?.map((e) => CreateOrUpdateForm.fromJson(e as Map<String, dynamic>))
          .toList(),
      repeat: json['repeat'] as String?,
      progress: (json['progress'] as num?)?.toInt(),
      assigneeId: json['assignee_id'] as String?,
      projects: (json['projects'] as List<dynamic>?)
          ?.map((e) => CreateOrUpdateForm.fromJson(e as Map<String, dynamic>))
          .toList(),
      location: json['location'] as String?,
      ownerId: json['owner_id'] as String?,
    );

Map<String, dynamic> _$$TodoInputImplToJson(_$TodoInputImpl instance) =>
    <String, dynamic>{
      'title': instance.title,
      'description': instance.description,
      'due_at': dateTimeToJson(instance.dueAt),
      'priority': priorityToJson(instance.priority),
      'status': statusToJson(instance.status),
      'tags': instance.tags,
      'repeat': instance.repeat,
      'progress': instance.progress,
      'assignee_id': instance.assigneeId,
      'projects': instance.projects,
      'location': instance.location,
      'owner_id': instance.ownerId,
    };
