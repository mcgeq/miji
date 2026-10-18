/// 附件在 App 私有目录下的落盘规则。
///
/// 这里**刻意不依赖 `dart:io`**：算路径全是字符串运算，把它从写文件里拆出来
/// 有两个好处——纯函数能被单测直接覆盖；而真正需要 io 的那半边（
/// `attachment_store.dart`）薄到只剩「拷贝 / 重命名 / 删」，出错的余地很小。
library;

/// 附件根目录名，位于 `getApplicationSupportDirectory()` 之下。
const String attachmentRootFolderName = 'attachments';

/// 存进库里的路径**固定**用 `/` 分隔，与平台无关。
///
/// 附件文件本身不参与同步，但同一个库会出现在 Android / iOS / 桌面之间
/// （快照恢复），存平台相关的分隔符会让另一边解析直接失败。
const String attachmentStoredSeparator = '/';

/// 附件按 `<userId>/<yyyyMM>/<id>.<ext>` 分月存放。
///
/// 分月的理由不是好看：这类文件只增不减（打卡记录删了，底片也没人回头清理），
/// 单目录堆到几万个小文件后，任何一次目录枚举都会明显变慢。
String attachmentMonthFolder(DateTime at) {
  final year = at.year.toString().padLeft(4, '0');
  final month = at.month.toString().padLeft(2, '0');
  return '$year$month';
}

/// 把一段路径拆成不含分隔符的片段。
///
/// 两种分隔符都认：存量数据里躺着 Windows 反斜杠路径（见
/// [isAbsoluteStoredPath]），只按 `/` 拆会把整条路径当成一段。
List<String> attachmentPathSegments(String storedPath) {
  return storedPath
      .split(RegExp(r'[\\/]'))
      .where((segment) => segment.isNotEmpty)
      .toList(growable: false);
}

/// 目录名会直接变成磁盘上的路径片段，必须挡住穿越与非法字符。
///
/// `userId` 目前是 uuid，看着很安全；但它是从库里读出来的字符串，而库里
/// 的字符串来自同步与快照恢复——不能假设它一定干净。名字里混进 `../`
/// 就是把附件写到目录外面去。
String sanitizeAttachmentSegment(String raw) {
  final cleaned = raw.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  return cleaned.isEmpty ? 'unknown' : cleaned;
}

/// 由「用户 + 附件 id + 扩展名 + 时间」拼出存储用的相对路径。
String attachmentRelativePath({
  required String userId,
  required String id,
  required String extension,
  required DateTime createdAt,
}) {
  return [
    sanitizeAttachmentSegment(userId),
    attachmentMonthFolder(createdAt),
    '${sanitizeAttachmentSegment(id)}.$extension',
  ].join(attachmentStoredSeparator);
}

/// 存量数据里可能躺着**绝对路径**。
///
/// GTD 打卡照片的历史行（`checkin_photos.local_path`）就是把 image_picker 的
/// 临时绝对路径原样写进去的。读的时候要靠这条判断决定「要不要拼上附件根目录」，
/// 丢掉历史行等于让用户的老照片直接读不出来。
bool isAbsoluteStoredPath(String storedPath) {
  if (storedPath.isEmpty) {
    return false;
  }
  if (storedPath.startsWith('/') || storedPath.startsWith(r'\')) {
    return true;
  }
  // Windows 盘符：`C:\...` 或 `C:/...`。
  return RegExp(r'^[A-Za-z]:[\\/]').hasMatch(storedPath);
}

/// 认识的扩展名。不在这张表里的一律按 [fallbackAttachmentExtension] 处理。
const Set<String> knownAttachmentExtensions = <String>{
  'jpg',
  'jpeg',
  'png',
  'heic',
  'heif',
  'webp',
  'gif',
  'bmp',
  'tif',
  'tiff',
  'pdf',
  'txt',
};

/// 认不出格式时的兜底扩展名。
const String fallbackAttachmentExtension = 'bin';

const Map<String, String> _extensionByMimeType = <String, String>{
  'image/jpeg': 'jpg',
  'image/jpg': 'jpg',
  'image/png': 'png',
  'image/heic': 'heic',
  'image/heif': 'heif',
  'image/webp': 'webp',
  'image/gif': 'gif',
  'image/bmp': 'bmp',
  'image/tiff': 'tiff',
  'application/pdf': 'pdf',
  'text/plain': 'txt',
};

/// 推断落盘用的扩展名：先看原文件名，再看 mime，都没有就 `bin`。
///
/// 先看文件名而不是 mime，是因为这里拿到的 mime 往往是调用方抄进来的一条
/// 常量（`image/jpeg`），而原文件名是系统给的、跟着真实内容走。
String attachmentExtension({String? mimeType, String? sourcePath}) {
  final fromPath = _extensionFromPath(sourcePath);
  if (fromPath != null) {
    return fromPath;
  }
  final fromMime = _extensionFromMimeType(mimeType);
  if (fromMime != null) {
    return fromMime;
  }
  return fallbackAttachmentExtension;
}

String? _extensionFromPath(String? sourcePath) {
  if (sourcePath == null || sourcePath.isEmpty) {
    return null;
  }
  final segments = attachmentPathSegments(sourcePath);
  if (segments.isEmpty) {
    return null;
  }
  final name = segments.last;
  final dot = name.lastIndexOf('.');
  if (dot < 0 || dot == name.length - 1) {
    return null;
  }
  final extension = name.substring(dot + 1).toLowerCase();
  return knownAttachmentExtensions.contains(extension) ? extension : null;
}

String? _extensionFromMimeType(String? mimeType) {
  if (mimeType == null) {
    return null;
  }
  // `image/jpeg; charset=binary` 这种带参数的要砍掉尾巴。
  final normalized = mimeType.split(';').first.trim().toLowerCase();
  final mapped = _extensionByMimeType[normalized];
  if (mapped != null) {
    return mapped;
  }
  return knownAttachmentExtensions.contains(normalized) ? normalized : null;
}
