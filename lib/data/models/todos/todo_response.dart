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
    required String serialNum,
    required String title,
    String? description,

    @JsonKey(fromJson: dateTimeFromJson, toJson: dateTimeToJson)
    required DateTime createdAt,

    @JsonKey(fromJson: dateTimeFromJson, toJson: dateTimeToJson)
    DateTime? updatedAt,

    @JsonKey(fromJson: dateTimeFromJson, toJson: dateTimeToJson)
    required DateTime dueAt,

    @JsonKey(fromJson: Priority.fromJson, toJson: _priorityToJson)
    required Priority priority,

    @JsonKey(fromJson: Status.fromJson, toJson: _statusToJson)
    required Status status,
    String? repeat,

    @JsonKey(fromJson: dateTimeFromJson, toJson: dateTimeToJson)
    DateTime? completedAt,

    String? assigneeId,
    required int progress,
    String? location,
    String? ownerId,
    required List<ProjectInfo> projects,
    required List<TagInfo> tags,
    required List<ReminderInfo> reminders,
    required List<AttachmentInfo> attachments,
  }) = _TodoResponse;

  factory TodoResponse.fromJson(Map<String, dynamic> json) =>
      _$TodoResponseFromJson(json);
}

int _priorityToJson(Priority priority) => priority.toJson();
int _statusToJson(Status status) => status.toJson();