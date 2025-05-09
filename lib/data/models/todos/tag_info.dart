import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:miji/data/models/todos/tag_core.dart';

part 'tag_info.freezed.dart';

@freezed
class TagInfo with _$TagInfo {
  const TagInfo._();
  const factory TagInfo({required TagCore core}) = _TagInfo;

  factory TagInfo.fromJson(Map<String, dynamic> json) {
    return TagInfo(core: TagCore.fromJson(json));
  }

  Map<String, dynamic> toJson() => core.toJson();
}