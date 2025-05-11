import 'package:miji/data/models/projects.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'todos.freezed.dart';
part 'todos.g.dart';

@freezed
abstract class Todos with _$Todos {
  const factory Todos({
    @JsonKey(name: 'assignee_id') String? assigneeId,
    @JsonKey(name: 'attachments') @Default([]) List<dynamic> attachments,
    @JsonKey(name: 'completed_at') DateTime? completedAt,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'description') String? description,
    @JsonKey(name: 'due_at') required DateTime dueAt,
    @JsonKey(name: 'location') String? location,
    @JsonKey(name: 'owner_id') String? ownerId,
    @JsonKey(name: 'priority') @Default(0) int priority,
    @JsonKey(name: 'progress') @Default(0) int progress,
    @JsonKey(name: 'projects') @Default([]) List<Projects> projects,
    @JsonKey(name: 'reminders') @Default([]) List<dynamic> reminders,
    @JsonKey(name: 'repeat') String? repeat,
    @JsonKey(name: 'serial_num') required String serialNum,
    @JsonKey(name: 'status') required int status,
    @JsonKey(name: 'tags') @Default([]) List<dynamic> tags,
    @JsonKey(name: 'title') required String title,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _Todos;

  factory Todos.fromJson(Map<String, dynamic> json) => _$TodosFromJson(json);

factory Todos.empty() {
    final now = DateTime.now();
    return Todos(
      assigneeId: null,
      attachments: [],
      completedAt: null,
      createdAt: now,
      description: null,
      dueAt: now,
      location: null,
      ownerId: null,
      priority: 0,
      progress: 0,
      projects: [],
      reminders: [],
      repeat: null,
      serialNum: '',
      status: 0,
      tags: [],
      title: '',
      updatedAt: null,
    );
  }
}