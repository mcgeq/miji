import 'dart:math' as math;

/// OCR 识别出的一行文字，以及在图片中的位置。
///
/// 位置信息只有一个用途：**还原版面**。支付截图的字段普遍是「左标签 + 右值」
/// 的两列布局，而 OCR 返回的块顺序**不保证是阅读顺序**——同一行的左右两块
/// 可能相邻，也可能被别的块隔开。丢掉坐标就只能按行序猜，一猜就错位。
class OcrLine {
  const OcrLine({
    required this.text,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final String text;
  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;

  double get height => bottom - top;

  double get centerY => (top + bottom) / 2;

  bool get hasContent => text.trim().isNotEmpty;
}

/// 一次文字识别的完整结果。
class OcrPage {
  const OcrPage(this.lines);

  /// 识别出的文字行（未做版面合并，顺序为识别引擎给出的块顺序）。
  final List<OcrLine> lines;

  factory OcrPage.fromPlainText(String text) {
    // 纯文本入口（单测、旧调用点用）：行序即阅读顺序，无位置信息。
    final rows = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    return OcrPage(<OcrLine>[
      for (var index = 0; index < rows.length; index++)
        OcrLine(
          text: rows[index],
          left: 0,
          top: index.toDouble(),
          right: double.infinity,
          bottom: index + 1,
        ),
    ]);
  }

  bool get isEmpty => lines.every((line) => !line.hasContent);

  /// 原样的行序，供诊断与日志使用。
  String get rawText => lines.map((line) => line.text).join('\n');

  /// 按版面把「同一水平行上的多个块」并成一句。
  ///
  /// 这是整个识别链路里最关键的一步。以支付宝账单详情页为例，ML Kit 会把
  /// `付款方式` 和 `招商银行信用卡(9892)` 识别成**两个独立的块**——只按块顺序
  /// 读，标签和值就会错位，下游「找标签取值」的正则必然取到隔壁字段的值。
  /// 合并到同一行之后，一张截图就还原成了人眼看到的一行行文字。
  ///
  /// 合并判据用 **y 区间重叠**而不是「中心点接近」：上下相邻的两行（行距再小）
  /// y 区间也不会重叠，而左右并排的块一定重叠。这样不会把相邻行误并。
  List<String> mergeVisualLines() {
    final rows = lines.where((line) => line.hasContent).toList()
      ..sort((a, b) => a.centerY.compareTo(b.centerY));

    final merged = <String>[];
    var group = <OcrLine>[];
    var groupTop = 0.0;
    var groupBottom = 0.0;

    void flush() {
      if (group.isEmpty) {
        return;
      }
      group.sort((a, b) => a.left.compareTo(b.left));
      merged.add(group.map((line) => line.text.trim()).join('  '));
      group = <OcrLine>[];
    }

    for (final line in rows) {
      if (group.isEmpty) {
        group = <OcrLine>[line];
        groupTop = line.top;
        groupBottom = line.bottom;
        continue;
      }
      final overlap =
          math.min(groupBottom, line.bottom) - math.max(groupTop, line.top);
      final shorter = math.min(groupBottom - groupTop, line.height);
      if (shorter > 0 && overlap > 0.5 * shorter) {
        group.add(line);
        groupTop = math.min(groupTop, line.top);
        groupBottom = math.max(groupBottom, line.bottom);
      } else {
        flush();
        group = <OcrLine>[line];
        groupTop = line.top;
        groupBottom = line.bottom;
      }
    }
    flush();
    return merged;
  }
}
