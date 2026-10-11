import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'package:miji/core/attachments/attachment_paths.dart';

/// 附件存储层出错（源文件不存在、目录建不出来、拷贝失败…）。
class AttachmentStoreException implements Exception {
  const AttachmentStoreException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() {
    return 'AttachmentStoreException($message'
        '${cause == null ? '' : ', cause: $cause'})';
  }
}

/// 把外部文件收进 App 私有目录，并能把它读回来、删掉。
///
/// 只做四件事：算路径（纯函数，在 [attachment_paths.dart]）、原子拷贝、
/// 把存下来的路径解析回本机绝对路径、删除。
///
/// **它刻意不认识任何领域概念**——文件属于谁、挂在哪条记录上，都是调用方的事。
/// 把这层塞进来的话，换一个调用方（比如 GTD 打卡照片）就没法复用了。
class AttachmentStore {
  AttachmentStore({
    Future<Directory> Function()? rootDirectory,
    String Function()? createId,
  }) : _rootDirectoryOverride = rootDirectory,
       _createId = createId ?? const Uuid().v4;

  /// 测试用的根目录注入点：单测里给一个临时目录，就不必拉起 path_provider。
  final Future<Directory> Function()? _rootDirectoryOverride;

  final String Function() _createId;

  /// 附件根目录，不存在就建。
  Future<Directory> ensureRootDirectory() async {
    final root = await _resolveRootDirectory();
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    return root;
  }

  /// 附件根目录的位置：优先用注入点（单测），否则取
  /// `getApplicationSupportDirectory()/attachments`。
  ///
  /// 用 support 目录而不是缓存目录：缓存会在系统空间紧张时被清掉，
  /// 而打卡照片被清掉就等于用户的记录对不上账。
  Future<Directory> _resolveRootDirectory() async {
    final override = _rootDirectoryOverride;
    if (override != null) {
      return override();
    }
    final support = await getApplicationSupportDirectory();
    return Directory(
      '${support.path}${Platform.pathSeparator}$attachmentRootFolderName',
    );
  }

  /// 把 [sourcePath] 指的文件收进附件目录，返回**相对路径**（存库用这个）。
  ///
  /// 返回值是相对路径而不是绝对路径：iOS 沙盒的容器路径每次版本升级都会变，
  /// 存绝对路径的话，用户升级一次 App，所有附件就全部指向不存在的位置。
  Future<String> importFile({
    required String userId,
    required String sourcePath,
    String? mimeType,
    DateTime? createdAt,
    String? id,
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw AttachmentStoreException('要收进附件目录的源文件不存在：$sourcePath');
    }
    final at = createdAt ?? DateTime.now().toUtc();
    final extension = attachmentExtension(
      mimeType: mimeType,
      sourcePath: sourcePath,
    );
    final relativePath = attachmentRelativePath(
      userId: userId,
      id: id ?? _createId(),
      extension: extension,
      createdAt: at,
    );
    final target = await fileFor(relativePath, createParent: true);
    try {
      await _copyAtomically(source, target);
    } catch (error) {
      throw AttachmentStoreException('附件落盘失败：$relativePath', error);
    }
    return relativePath;
  }

  /// 相对路径 → 本机绝对路径（顺带按需建好上级目录）。
  Future<File> fileFor(String storedPath, {bool createParent = false}) async {
    final root = await ensureRootDirectory();
    final segments = <String>[root.path, ...attachmentPathSegments(storedPath)];
    final target = File(segments.join(Platform.pathSeparator));
    if (createParent) {
      final parent = target.parent;
      if (!await parent.exists()) {
        await parent.create(recursive: true);
      }
    }
    return target;
  }

  /// 把库里存的路径解析成本机可用路径。
  ///
  /// 存量数据里可能是绝对路径（GTD 打卡照片的历史行就是这样），那种原样返回——
  /// 硬拼上附件根目录会把老照片全部读废。
  Future<String> resolveStoredPath(String storedPath) async {
    if (isAbsoluteStoredPath(storedPath)) {
      return storedPath;
    }
    return (await fileFor(storedPath)).path;
  }

  /// 库里那条路径对应的文件；文件不在（换过设备、被系统清过）返回 null。
  ///
  /// 调用方要能区分「没有附件」和「附件文件丢了」，所以这里不抛异常。
  Future<File?> existingFile(String storedPath) async {
    final resolved = await resolveStoredPath(storedPath);
    final file = File(resolved);
    return await file.exists() ? file : null;
  }

  /// 删掉文件本体；文件本来就不在也算成功（幂等）。
  Future<void> deleteStored(String storedPath) async {
    final resolved = await resolveStoredPath(storedPath);
    final file = File(resolved);
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (error) {
      throw AttachmentStoreException('附件删除失败：$storedPath', error);
    }
  }

  /// 先写 `.tmp` 再 rename，保证目录里永远不会出现「半个文件」。
  ///
  /// 拷贝中途被杀进程（用户切走、系统回收）是很常见的：直接往目标路径写，
  /// 留下的是张解码失败的破图，读的时候既不像「没存」也不像「存好了」。
  Future<void> _copyAtomically(File source, File target) async {
    final temp = File('${target.path}.tmp');
    if (await temp.exists()) {
      await temp.delete();
    }
    await source.copy(temp.path);
    if (await target.exists()) {
      await target.delete();
    }
    await temp.rename(target.path);
  }
}
