import 'package:freezed_annotation/freezed_annotation.dart';

part 'tag_core.freezed.dart';

@freezed
class TagCore with _$TagCore {
  const factory TagCore({required String serialNum, required String name}) =
      _TagCore;

  factory TagCore.fromJson(Map<String, dynamic> json) =>
      _$TagCoreFromJson(json);
}