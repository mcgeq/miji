import 'package:miji/data/models/projects.dart';

class Todo {
  final String? assigneeId;
  final List<dynamic> attachments;
  final String? completedAt;
  final String createdAt;
  final String? description;
  final String dueAt;
  final String? location;
  final String? ownerId;
  final int priority;
  final int progress;
  final List<Project> projects;
  final List<dynamic> reminders;
  final String? repeat;
  final String serialNum;
  final int status;
  final List<dynamic> tags;
  final String title;
  final String updatedAt;

  Todo({
    required this.assigneeId,
    required this.attachments,
    required this.completedAt,
    required this.createdAt,
    required this.description,
    required this.dueAt,
    required this.location,
    required this.ownerId,
    required this.priority,
    required this.progress,
    required this.projects,
    required this.reminders,
    required this.repeat,
    required this.serialNum,
    required this.status,
    required this.tags,
    required this.title,
    required this.updatedAt,
  });

  factory Todo.fromJson(Map<String, dynamic> json) {
    return Todo(
      assigneeId: json['assignee_id'] as String?,
      attachments: json['attachments'] as List<dynamic>? ?? [],
      completedAt: json['completed_at'] as String?,
      createdAt: json['created_at'] as String? ?? '',
      description: json['description'] as String?,
      dueAt: json['due_at'] as String,
      location: json['location'] as String?,
      ownerId: json['owner_id'] as String?,
      priority: json['priority'] as int? ?? 0,
      progress: json['progress'] as int? ?? 0,
      projects:
          (json['projects'] as List<dynamic>)
              .map(
                (project) => Project.fromJson(project as Map<String, dynamic>),
              )
              .toList(),
      reminders: json['reminders'] as List<dynamic>,
      repeat: json['repeat'] as String?,
      serialNum: json['serial_num'] as String,
      status: json['status'] as int,
      tags: json['tags'] as List<dynamic>? ?? [],
      title: json['title'] as String,
      updatedAt: json['updated_at'] as String,
    );
  }
}
