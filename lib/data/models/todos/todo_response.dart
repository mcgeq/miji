import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:miji/data/models/enums/priority.dart';
import 'package:miji/data/models/enums/status.dart';
import 'package:miji/data/models/todos/attachment_info.dart';
import 'package:miji/data/models/todos/project_info.dart';
import 'package:miji/data/models/todos/reminder_info.dart';
import 'package:miji/data/models/todos/tag_info.dart';
import 'package:miji/shared/utils/date_utils.dart';

part 'todo_response.freezed.dart';
part 'todo_response.g.dart';

@freezed
class TodoResponse with _$TodoResponse {
  const factory TodoResponse({
    @JsonKey(name: 'serial_num', required: true) required String serialNum,
    @JsonKey(name: 'title', required: true) required String title,
    @JsonKey(name: 'description') String? description,
    @JsonKey(
      name: 'created_at',
      fromJson: dateTimeFromJson,
      toJson: dateTimeToJson,
    )
    required DateTime createdAt,
    @JsonKey(
      name: 'updated_at',
      fromJson: dateTimeFromJson,
      toJson: dateTimeToJson,
    )
    DateTime? updatedAt,
    @JsonKey(name: 'due_at', fromJson: dateTimeFromJson, toJson: dateTimeToJson)
    required DateTime dueAt,
    @JsonKey(fromJson: Priority.fromJson, toJson: priorityToJson)
    required Priority priority,
    @JsonKey(fromJson: Status.fromJson, toJson: statusToJson)
    required Status status,
    @JsonKey(name: 'repeat') String? repeat,
    @JsonKey(
      name: 'completed_at',
      fromJson: dateTimeFromJson,
      toJson: dateTimeToJson,
    )
    DateTime? completedAt,
    @JsonKey(name: 'assignee_id') String? assigneeId,
    @JsonKey(name: 'progress', required: true) required int progress,
    @JsonKey(name: 'location') String? location,
    @JsonKey(name: 'owner_id') String? ownerId,
    @JsonKey(name: 'projects', required: true)
    required List<ProjectInfo> projects,
    @JsonKey(name: 'tags', required: true) required List<TagInfo> tags,
    @JsonKey(name: 'reminders', required: true)
    required List<ReminderInfo> reminders,
    @JsonKey(name: 'attachments', required: true)
    required List<AttachmentInfo> attachments,
  }) = _TodoResponse;

  factory TodoResponse.fromJson(Map<String, dynamic> json) =>
      _$TodoResponseFromJson(json);
}
