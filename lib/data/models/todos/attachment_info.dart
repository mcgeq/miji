import 'package:freezed_annotation/freezed_annotation.dart';

part 'attachment_info.freezed.dart';
part 'attachment_info.g.dart';

@freezed
class AttachmentInfo with _$AttachmentInfo {
  const factory AttachmentInfo({
    @JsonKey(name: 'serial_num', required: true) required String serialNum,
    @JsonKey(name: 'file_path') String? filePath,
    @JsonKey(name: 'url') String? url,
  }) = _AttachmentInfo;

  factory AttachmentInfo.fromJson(Map<String, dynamic> json) =>
      _$AttachmentInfoFromJson(json);
}
