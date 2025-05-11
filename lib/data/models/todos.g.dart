// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'todos.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Todos _$TodosFromJson(Map<String, dynamic> json) => _Todos(
      assigneeId: json['assignee_id'] as String?,
      attachments: json['attachments'] as List<dynamic>? ?? const [],
      completedAt: json['completed_at'] == null
          ? null
          : DateTime.parse(json['completed_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      description: json['description'] as String?,
      dueAt: DateTime.parse(json['due_at'] as String),
      location: json['location'] as String?,
      ownerId: json['owner_id'] as String?,
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      progress: (json['progress'] as num?)?.toInt() ?? 0,
      projects: (json['projects'] as List<dynamic>?)
              ?.map((e) => Projects.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      reminders: json['reminders'] as List<dynamic>? ?? const [],
      repeat: json['repeat'] as String?,
      serialNum: json['serial_num'] as String,
      status: (json['status'] as num).toInt(),
      tags: json['tags'] as List<dynamic>? ?? const [],
      title: json['title'] as String,
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$TodosToJson(_Todos instance) => <String, dynamic>{
      'assignee_id': instance.assigneeId,
      'attachments': instance.attachments,
      'completed_at': instance.completedAt?.toIso8601String(),
      'created_at': instance.createdAt.toIso8601String(),
      'description': instance.description,
      'due_at': instance.dueAt.toIso8601String(),
      'location': instance.location,
      'owner_id': instance.ownerId,
      'priority': instance.priority,
      'progress': instance.progress,
      'projects': instance.projects,
      'reminders': instance.reminders,
      'repeat': instance.repeat,
      'serial_num': instance.serialNum,
      'status': instance.status,
      'tags': instance.tags,
      'title': instance.title,
      'updated_at': instance.updatedAt?.toIso8601String(),
    };
