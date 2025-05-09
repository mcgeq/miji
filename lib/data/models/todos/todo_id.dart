import 'package:freezed_annotation/freezed_annotation.dart';

part 'todo_id.freezed.dart';
part 'todo_id.g.dart';

@freezed
class TodoId with _$TodoId {
  const factory TodoId({
    @JsonKey(name: 'serial_num', required: true) required String serialNum,
  }) = _TodoId;

  factory TodoId.fromJson(Map<String, dynamic> json) => _$TodoIdFromJson(json);

  String? validate() {
    if (serialNum.length < 32 || serialNum.length > 38) {
      return 'serial_num must be between 32 and 38 characters';
    }
    return null;
  }
}
