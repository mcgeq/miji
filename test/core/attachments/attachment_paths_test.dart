import 'package:flutter_test/flutter_test.dart';

import 'package:miji/core/attachments/attachment_paths.dart';

void main() {
  group('attachmentMonthFolder', () {
    test('补零到 yyyyMM', () {
      expect(attachmentMonthFolder(DateTime(2026, 10, 11)), '202610');
      expect(attachmentMonthFolder(DateTime(2026, 1, 5)), '202601');
      expect(attachmentMonthFolder(DateTime(2026, 12, 31)), '202612');
    });
  });

  group('attachmentRelativePath', () {
    test('按 <userId>/<yyyyMM>/<id>.<ext> 组织', () {
      expect(
        attachmentRelativePath(
          userId: 'user-1',
          id: 'att-1',
          extension: 'jpg',
          createdAt: DateTime(2026, 10, 11),
        ),
        'user-1/202610/att-1.jpg',
      );
    });

    test('分隔符固定用 /，与平台无关', () {
      // 存平台分隔符的话，同一个库换到另一平台解析必然失败。
      final path = attachmentRelativePath(
        userId: 'user-1',
        id: 'att-1',
        extension: 'png',
        createdAt: DateTime(2026, 3, 1),
      );
      expect(path.contains(r'\'), isFalse);
      expect(path.split('/'), <String>['user-1', '202603', 'att-1.png']);
    });

    test('用户 id 里的危险字符被抹掉，挡住目录穿越', () {
      final path = attachmentRelativePath(
        userId: '../../etc',
        id: 'att-1',
        extension: 'jpg',
        createdAt: DateTime(2026, 10, 11),
      );
      expect(path.contains('..'), isFalse);
      expect(path.startsWith('_'), isTrue);
      // 抹掉之后仍然是一段纯文件名，不会变成多层目录。
      expect(attachmentPathSegments(path).length, 3);
    });

    test('空 id 落到 unknown，不会生成一个没有名字的文件', () {
      expect(
        attachmentRelativePath(
          userId: '',
          id: '',
          extension: 'jpg',
          createdAt: DateTime(2026, 10, 11),
        ),
        'unknown/202610/unknown.jpg',
      );
    });
  });

  group('attachmentPathSegments', () {
    test('两种分隔符都认', () {
      expect(attachmentPathSegments('a/b\\c'), <String>['a', 'b', 'c']);
      expect(attachmentPathSegments('/a/b/'), <String>['a', 'b']);
      expect(attachmentPathSegments(''), isEmpty);
    });
  });

  group('isAbsoluteStoredPath', () {
    test('认得出历史上存下来的绝对路径', () {
      // GTD 打卡照片的老数据就是这种，读的时候要原样放行。
      expect(isAbsoluteStoredPath('/var/mobile/Containers/Data/x.jpg'), isTrue);
      expect(
        isAbsoluteStoredPath(r'C:\Users\me\AppData\Local\Temp\x.jpg'),
        isTrue,
      );
      expect(isAbsoluteStoredPath('C:/Users/me/x.jpg'), isTrue);
    });

    test('相对路径不会被误判成绝对路径', () {
      expect(isAbsoluteStoredPath('user-1/202610/att-1.jpg'), isFalse);
      expect(isAbsoluteStoredPath(''), isFalse);
    });
  });

  group('attachmentExtension', () {
    test('优先看原文件名', () {
      expect(
        attachmentExtension(sourcePath: '/tmp/IMG_4562.PNG'),
        'png',
        reason: '大写要归一成小写',
      );
      expect(attachmentExtension(sourcePath: r'D:\shots\a.jpeg'), 'jpeg');
    });

    test('文件名认不出来时退回 mime', () {
      expect(
        attachmentExtension(sourcePath: '/tmp/noext', mimeType: 'image/jpeg'),
        'jpg',
      );
      expect(
        attachmentExtension(mimeType: 'image/jpeg; charset=binary'),
        'jpg',
        reason: '带参数的 mime 要砍掉尾巴再查表',
      );
    });

    test('都不认识就用兜底扩展名，不猜', () {
      expect(attachmentExtension(sourcePath: '/tmp/a.xyz'), 'bin');
      expect(attachmentExtension(mimeType: 'application/octet-stream'), 'bin');
      expect(attachmentExtension(), 'bin');
      // 末尾只有个点，不算扩展名。
      expect(attachmentExtension(sourcePath: '/tmp/a.'), 'bin');
    });

    test('未知扩展名不会冒充已知扩展名', () {
      // `.xyz` 不在白名单里，但 mime 认识的话以 mime 为准。
      expect(
        attachmentExtension(sourcePath: '/tmp/a.xyz', mimeType: 'image/png'),
        'png',
      );
    });
  });
}
