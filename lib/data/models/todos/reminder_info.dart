import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:miji/shared/utils/date_utils.dart';

part 'reminder_info.freezed.dart';
part 'reminder_info.g.dart';

@freezed
class ReminderInfo with _$ReminderInfo {
  const factory ReminderInfo({
    @JsonKey(name: 'serial_num', required: true) required String serialNum,
    @JsonKey(
      name: 'remind_at',
      fromJson: dateTimeFromJson,
      toJson: dateTimeToJson,
    )
    required DateTime remindAt,
  }) = _ReminderInfo;

  factory ReminderInfo.fromJson(Map<String, dynamic> json) =>
      _$ReminderInfoFromJson(json);
}
