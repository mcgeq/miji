import 'package:freezed_annotation/freezed_annotation.dart';

part 'project_core.freezed.dart';
part 'project_core.g.dart';

@freezed
class ProjectCore with _$ProjectCore {
  const factory ProjectCore({
    @JsonKey(name: 'serial_num', required: true) required String serialNum,
    @JsonKey(name: 'name', required: true) required String name,
    @JsonKey(name: 'description') String? description,
  }) = _ProjectCore;

  factory ProjectCore.fromJson(Map<String, dynamic> json) =>
      _$ProjectCoreFromJson(json);
}
