import 'package:freezed_annotation/freezed_annotation.dart';

part 'tag_core.freezed.dart';
part 'tag_core.g.dart';

@freezed
class TagCore with _$TagCore {
  const factory TagCore({
    @JsonKey(name: 'serial_num', required: true) required String serialNum,
    @JsonKey(name: 'name', required: true) required String name,
  }) = _TagCore;

  factory TagCore.fromJson(Map<String, dynamic> json) =>
      _$TagCoreFromJson(json);
}
