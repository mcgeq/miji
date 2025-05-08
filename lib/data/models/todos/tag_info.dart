import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:miji/data/models/todos/tag_core.dart';

part 'tag_info.freezed.dart';

@freezed
class TagInfo with _$TagInfo {
  const factory TagInfo({required TagCore core}) = _TagInfo;

  /// 自定义反序列化：把 flat JSON 映射到 TagCore
  factory TagInfo.fromJson(Map<String, dynamic> json) {
    return TagInfo(core: TagCore.fromJson(json));
  }

  /// 自定义序列化：将 core 的字段“展开”
  Map<String, dynamic> toJson() => core.toJson();
}