import 'package:hive_flutter/adapters.dart';

part 'todo.g.dart';

@HiveType(typeId: 0)
class Todo {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  bool isCompleted;

  @HiveField(3)
  DateTime? completedAt;

  @HiveField(4)
  DateTime createdAt;

  @HiveField(5)
  DateTime? dueDate;

  @HiveField(6)
  Priority priority;

  @HiveField(7)
  String? description;

  @HiveField(8)
  List<String> tags;

  @HiveField(9)
  DateTime? reminder;

  Todo({
    required this.title,
    this.isCompleted = false,
    this.completedAt,
    required this.createdAt,
    this.dueDate,
    this.priority = Priority.medium,
    this.description,
    this.tags = const [],
    required this.id,
    this.reminder,
  });

  void toggleCompletion() {
    isCompleted = !isCompleted;
    completedAt = isCompleted ? DateTime.now() : null;
  }

  // 可选：添加 toJson 和 fromJson 方法，便于持久化存储
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'isCompleted': isCompleted,
      'completedAt': completedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'priority': priority.toString(),
      'description': description,
      'tags': tags,
      'reminder': reminder?.toIso8601String(),
    };
  }

  factory Todo.fromJson(Map<String, dynamic> json) {
    return Todo(
      id: json['id'],
      title: json['title'],
      isCompleted: json['isCompleted'],
      completedAt:
          json['completedAt'] != null
              ? DateTime.parse(json['completedAt'])
              : null,
      createdAt: DateTime.parse(json['createdAt']),
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
      priority: Priority.values.firstWhere(
        (e) => e.toString() == json['priority'],
        orElse: () => Priority.medium,
      ),
      description: json['description'],
      tags: List<String>.from(json['tags']),
      reminder:
          json['reminder'] != null ? DateTime.parse(json['reminder']) : null,
    );
  }
}

@HiveType(typeId: 1)
enum Priority {
  @HiveField(0)
  high,
  @HiveField(1)
  medium,
  @HiveField(2)
  low,
}
