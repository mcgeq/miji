import 'package:freezed_annotation/freezed_annotation.dart';

part 'projects.freezed.dart';
part 'projects.g.dart';

@freezed
abstract class Projects with _$Projects {
  const factory Projects({
    @JsonKey(name: 'description') @Default(null) String? description,
    @JsonKey(name: 'name') required String name,
    @JsonKey(name: 'serial_num') required String serialNum,
  }) = _Projects;

  factory Projects.fromJson(Map<String, dynamic> json) =>
      _$ProjectsFromJson(json);
}