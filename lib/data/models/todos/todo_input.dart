import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:miji/data/models/enums/priority.dart';
import 'package:miji/data/models/enums/status.dart';
import 'package:miji/data/models/todos/create_or_update_form.dart';
import 'package:miji/shared/utils/date_utils.dart';

part 'todo_input.freezed.dart';
part 'todo_input.g.dart';

@freezed
class TodoInput with _$TodoInput {
  const factory TodoInput({
    @JsonKey(name: 'title') String? title,
    @JsonKey(name: 'description') String? description,
    @JsonKey(name: 'due_at', fromJson: dateTimeFromJson, toJson: dateTimeToJson)
    DateTime? dueAt,
    @JsonKey(fromJson: Priority.fromJson, toJson: priorityToJson)
    Priority? priority,
    @JsonKey(fromJson: Status.fromJson, toJson: statusToJson) Status? status,
    @JsonKey(name: 'tags') List<CreateOrUpdateForm>? tags,
    @JsonKey(name: 'repeat') String? repeat,
    @JsonKey(name: 'progress') int? progress,
    @JsonKey(name: 'assignee_id') String? assigneeId,
    @JsonKey(name: 'projects') List<CreateOrUpdateForm>? projects,
    @JsonKey(name: 'location') String? location,
    @JsonKey(name: 'owner_id') String? ownerId,
  }) = _TodoInput;

  factory TodoInput.fromJson(Map<String, dynamic> json) =>
      _$TodoInputFromJson(json);

  String? validate() {
    if (title != null && (title!.isEmpty || title!.length > 1000)) {
      return 'title must be between 1 and 1000 characters';
    }
    if (description != null && description!.length > 1000) {
      return 'description must be at most 1000 characters';
    }
    if (progress != null && (progress! < 0 || progress! > 100)) {
      return 'progress must be between 0 and 100';
    }
    if (tags != null) {
      for (var tag in tags!) {
        final error = tag.validate();
        if (error != null) return error;
      }
    }
    if (projects != null) {
      for (var project in projects!) {
        final error = project.validate();
        if (error != null) return error;
      }
    }
    return null;
  }
}
