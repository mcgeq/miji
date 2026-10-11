/// Web 上的空实现：浏览器端没有端侧 OCR 能力。
///
/// 与 `app_text_recognizer_io.dart` 保持同一套对外名称，
/// 由 `app_text_recognizer.dart` 条件导出，二选一生效。
library;

import 'package:miji/core/ocr/ocr_line.dart';

/// 当前平台是否支持端侧文字识别。Web 恒为 false。
const bool isTextRecognitionSupported = false;

class AppTextRecognizer {
  const AppTextRecognizer();

  /// 永远不可用——调用方应先用 [isTextRecognitionSupported] 判断。
  Future<OcrPage> recognizeFile(String path) {
    throw UnsupportedError('当前平台不支持端侧文字识别');
  }

  Future<void> dispose() async {}
}
