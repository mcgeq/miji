import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:miji/data/models/todos/project_core.dart';

part 'project_info.freezed.dart';

@freezed
class ProjectInfo with _$ProjectInfo {
  const factory ProjectInfo({required ProjectCore core}) = _ProjectInfo;

  factory ProjectInfo.fromJson(Map<String, dynamic> json) {
    return ProjectInfo(
      core: ProjectCore.fromJson(json), // 把整个扁平 JSON 传给 core
    );
  }

  @override
  Map<String, dynamic> toJson() => core.toJson();
}