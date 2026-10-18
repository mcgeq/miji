import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'package:miji/core/ocr/ocr_line.dart';

/// 端侧文字识别（ML Kit）在 Android / iOS 之外都没有原生实现。
///
/// 桌面端（Windows / macOS / Linux）虽然能编译这份 Dart 代码，
/// 但调用时会因为插件未注册而抛 `MissingPluginException`，
/// 所以这里统一由这个判断兜住，调用方据此决定是否展示入口。
bool get isTextRecognitionSupported =>
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS;

/// 端侧文字识别。识别器内部持有原生句柄，同一个实例可以反复使用，
/// 用完记得 [dispose]（否则原生侧的内存不会释放）。
class AppTextRecognizer {
  TextRecognizer? _recognizer;

  /// 识别图片里的文字，**连同每行的位置一起返回**。
  ///
  /// 坐标不是装饰品：支付截图是「左侧标签 + 右侧值」的两列布局，而识别引擎
  /// 给出的块顺序并不保证是阅读顺序。只有拿到坐标，才能把同一水平行上的标签
  /// 和值还原成一句（见 [OcrPage.mergeVisualLines]），否则「付款方式」和
  /// 「招商银行信用卡(9892)」会错位，下游取值必然取到隔壁字段。
  ///
  /// 中文脚本同时覆盖拉丁字母与数字，足以应付「¥38.50」「2026-10-11 12:35」
  /// 这类混排内容。
  Future<OcrPage> recognizeFile(String path) async {
    if (!isTextRecognitionSupported) {
      throw UnsupportedError('当前平台不支持端侧文字识别');
    }
    final recognizer = _recognizer ??= TextRecognizer(
      script: TextRecognitionScript.chinese,
    );
    final recognized = await recognizer.processImage(
      InputImage.fromFilePath(path),
    );

    final lines = <OcrLine>[];
    for (final block in recognized.blocks) {
      if (block.lines.isEmpty) {
        // 兜底：极少数情况下块没有细分出行，直接用块本身的框，
        // 总比整块丢掉强。
        final box = block.boundingBox;
        lines.add(
          OcrLine(
            text: block.text,
            left: box.left,
            top: box.top,
            right: box.right,
            bottom: box.bottom,
          ),
        );
        continue;
      }
      for (final line in block.lines) {
        final box = line.boundingBox;
        lines.add(
          OcrLine(
            text: line.text,
            left: box.left,
            top: box.top,
            right: box.right,
            bottom: box.bottom,
          ),
        );
      }
    }
    return OcrPage(lines);
  }

  Future<void> dispose() async {
    final recognizer = _recognizer;
    _recognizer = null;
    await recognizer?.close();
  }
}
