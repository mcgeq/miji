import 'package:freezed_annotation/freezed_annotation.dart';

part 'project_core.freezed.dart';

@freezed
class ProjectCore with _$ProjectCore {
  const factory ProjectCore({
    required String serialNum,
    required String name,
    String? description,
  }) = _ProjectCore;

  factory ProjectCore.fromJson(Map<String, dynamic> json) =>
      _$ProjectCoreFromJson(json);
}