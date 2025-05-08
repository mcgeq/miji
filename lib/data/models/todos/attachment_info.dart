import 'package:freezed_annotation/freezed_annotation.dart';

part 'attachment_info.freezed.dart';

@freezed
class AttachmentInfo with _$AttachmentInfo {
  const factory AttachmentInfo({
    required String serialNum,
    String? filePath,
    String? url,
  }) = _AttachmentInfo;

  factory AttachmentInfo.fromJson(Map<String, dynamic> json) =>
      _$AttachmentInfoFromJson(json);
}