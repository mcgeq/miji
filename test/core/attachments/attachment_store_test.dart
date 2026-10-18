import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:miji/core/attachments/attachment_store.dart';

void main() {
  late Directory tempDir;
  late Directory rootDir;
  late AttachmentStore store;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('miji_attachment_store_test');
    rootDir = Directory('${tempDir.path}/attachments');
    // 注入根目录：测试不该依赖 path_provider 的平台通道。
    store = AttachmentStore(
      rootDirectory: () async => rootDir,
      createId: () => 'att-1',
    );
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  File writeSource(String name, int size) {
    return File('${tempDir.path}/$name')
      ..writeAsBytesSync(List<int>.filled(size, 7));
  }

  test('收进附件目录后返回相对路径，字节数与源文件一致', () async {
    final source = writeSource('IMG_1.PNG', 2048);

    final relative = await store.importFile(
      userId: 'user-1',
      sourcePath: source.path,
      createdAt: DateTime(2026, 10, 11),
    );

    expect(relative, 'user-1/202610/att-1.png');
    final stored = await store.existingFile(relative);
    expect(stored, isNotNull);
    expect(await stored!.length(), 2048);
    // 是拷贝不是搬家：image_picker 的临时文件不该被我们挪走。
    expect(source.existsSync(), isTrue);
  });

  test('不留 .tmp 残骸', () async {
    final source = writeSource('IMG_2.png', 16);

    await store.importFile(userId: 'user-1', sourcePath: source.path);

    final leftovers = rootDir
        .listSync(recursive: true)
        .where((entry) => entry.path.endsWith('.tmp'))
        .toList();
    expect(leftovers, isEmpty);
  });

  test('同一个 id 重复导入是覆盖，不会留下半个文件', () async {
    final first = writeSource('IMG_3.png', 32);
    final relative = await store.importFile(
      userId: 'user-1',
      sourcePath: first.path,
    );
    final second = File('${tempDir.path}/IMG_4.png')
      ..writeAsBytesSync(List<int>.filled(64, 9));

    await store.importFile(
      userId: 'user-1',
      sourcePath: second.path,
      id: 'att-1',
    );

    final stored = await store.existingFile(relative);
    expect(await stored!.length(), 64);
    expect(rootDir.listSync(recursive: true).whereType<File>().length, 1);
  });

  test('相对路径解析到附件根目录之下', () async {
    final resolved = await store.resolveStoredPath('user-1/202610/att-1.jpg');

    expect(resolved.startsWith(rootDir.path), isTrue);
    expect(resolved.endsWith('att-1.jpg'), isTrue);
  });

  test('存量绝对路径原样放行，不被拼到根目录后面', () async {
    // GTD 打卡照片的历史行就是这样，拼错了老照片就全读不出来。
    const legacy = '/legacy/abs/photo.jpg';
    expect(await store.resolveStoredPath(legacy), legacy);
    expect(await store.existingFile(legacy), isNull);
  });

  test('文件不在时 existingFile 返回 null，而不是抛异常', () async {
    expect(await store.existingFile('user-1/202610/missing.jpg'), isNull);
  });

  test('删除是幂等的', () async {
    final source = writeSource('IMG_5.png', 8);
    final relative = await store.importFile(
      userId: 'user-1',
      sourcePath: source.path,
    );
    expect(await store.existingFile(relative), isNotNull);

    await store.deleteStored(relative);
    expect(await store.existingFile(relative), isNull);
    // 再删一次不该炸。
    await store.deleteStored(relative);
  });

  test('源文件不存在时明确报错，不静默写一条空记录', () async {
    expect(
      () => store.importFile(
        userId: 'user-1',
        sourcePath: '${tempDir.path}/not-there.png',
      ),
      throwsA(isA<AttachmentStoreException>()),
    );
  });
}
