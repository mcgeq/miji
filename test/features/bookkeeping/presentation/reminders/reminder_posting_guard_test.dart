// 「完成一个提醒必须同时产生一笔流水」是这次改造的核心约束，但它靠的是
// 代码纪律（UI 侧只允许 `_runRecordFlow` 调用 `complete`），靠 review 守不住。
// 这里用源码扫描把它固化成测试：一旦有人为了方便又加一条「直接标记完成」，
// 测试会立刻红。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const guardRoot = 'lib';
  const entryPoint = '_runRecordFlow';

  test('UI 侧只有一个地方能把提醒推到 completed', () {
    final hits = <_SourceHit>[];
    for (final file in _dartFilesUnder(guardRoot)) {
      final lines = file.readAsLinesSync();
      for (var index = 0; index < lines.length; index++) {
        if (_isCompleteCall(lines[index])) {
          hits.add(_SourceHit(file.path, index + 1, lines[index].trim()));
        }
      }
    }

    expect(
      hits,
      hasLength(1),
      reason:
          '发现多处 completed 调用，必须全部收敛到 $entryPoint：'
          '${hits.map((hit) => '\n  ${hit.path}:${hit.line}  ${hit.text}').join()}',
    );

    final hit = hits.single;
    expect(hit.path, endsWith('money_reminder_center_section.dart'));
    expect(
      _isInside(hit, entryPoint),
      isTrue,
      reason:
          '${hit.path}:${hit.line} 不在 $entryPoint 里 —— '
          '绕开它的完成动作不会产生流水，正是这次要修的问题。',
    );
  });

  test('界面层不直接写处理状态表', () {
    // setReminderCenterState 是仓储 API：UI 直调它会跳过 ⬆ 那条必经之路。
    final offenders = <String>[];
    for (final file in _dartFilesUnder('$guardRoot/features')) {
      if (!file.path.contains('presentation')) {
        continue;
      }
      final content = file.readAsStringSync();
      if (content.contains('setReminderCenterState')) {
        offenders.add(file.path);
      }
    }
    expect(offenders, isEmpty, reason: '界面层应通过 actions 操作，而不是直调仓储');
  });
}

Iterable<File> _dartFilesUnder(String root) {
  final directory = Directory(root);
  expect(directory.existsSync(), isTrue, reason: '必须在包根目录运行 flutter test');
  return directory
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'));
}

/// `.complete(` 的同名调用很多（Completer、AnimationController 等），这里只认
/// 提醒动作的调用形式，并且跨多行时也能命中（`actions\n  .complete(item)`）。
bool _isCompleteCall(String line) {
  final trimmed = line.trim();
  if (trimmed.contains('Completer') || trimmed.contains('completeError')) {
    return false;
  }
  return trimmed.startsWith('.complete(') ||
      RegExp(r'\w\.complete\($').hasMatch(trimmed);
}

/// 命中点是否落在 [method] 这个方法体内。
///
/// 不做真正的语法解析，但缩进要算准：方法定义是两空格缩进，
/// 而 `_runRecordFlow(item)` 这样的调用点深得多，用 startsWith('  ') 会误命中。
bool _isInside(_SourceHit hit, String method) {
  final file = File(hit.path);
  final lines = file.readAsLinesSync();

  // 方法定义：两空格缩进，且紧跟着参数列表。
  var start = -1;
  for (var index = 0; index < lines.length; index++) {
    if (_indentOf(lines[index]) != 2) {
      continue;
    }
    // 含返回类型，所以是 contains 而非 startsWith；缩进限制已经排除了调用点。
    if (lines[index].contains('$method(')) {
      start = index;
      break;
    }
  }
  if (start < 0) {
    return false;
  }

  // 边界：下一个缩进 ≤ 2 的成员（方法体上收口的 `  }` 算，体内嵌套的不算）。
  // 空行必须跳过——它的缩进算出来是 0，会被当成方法已经收口。
  for (var index = start + 1; index < lines.length; index++) {
    if (lines[index].trim().isEmpty) {
      continue;
    }
    if (_indentOf(lines[index]) <= 2) {
      return hit.line - 1 < index;
    }
  }
  return hit.line - 1 >= start;
}

int _indentOf(String line) => line.length - line.trimLeft().length;

class _SourceHit {
  const _SourceHit(this.path, this.line, this.text);

  final String path;
  final int line;
  final String text;

  @override
  String toString() => '$path:$line  $text';
}
