import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:miji/shared/utils/date_utils.dart';

part 'reminder_info.freezed.dart';

@freezed
class ReminderInfo with _$ReminderInfo {
  const factory ReminderInfo({
    required String serialNum,
    @JsonKey(fromJson: dateTimeFromJson, toJson: dateTimeToJson)
    required DateTime remindAt,
  }) = _ReminderInfo;

  factory ReminderInfo.fromJson(Map<String, dynamic> json) =>
      _$ReminderInfoFromJson(json);
}
