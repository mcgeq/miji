import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:miji/data/models/todos/project_core.dart';

part 'project_info.freezed.dart';

@freezed
class ProjectInfo with _$ProjectInfo {
  const ProjectInfo._();
  const factory ProjectInfo({required ProjectCore core}) = _ProjectInfo;

  factory ProjectInfo.fromJson(Map<String, dynamic> json) {
    return ProjectInfo(core: ProjectCore.fromJson(json));
  }

  Map<String, dynamic> toJson() => core.toJson();
}