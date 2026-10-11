import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/core/attachments/attachment_store.dart';

/// 附件存储。无状态、无依赖，进程内一个实例就够。
///
/// 目录取自 `getApplicationSupportDirectory()`：**不能放缓存目录**——系统会
/// 在空间紧张时清掉缓存，而打卡照片被清掉就等于用户的记录对不上账。
final attachmentStoreProvider = Provider<AttachmentStore>((ref) {
  return AttachmentStore();
});
