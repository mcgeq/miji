/// 端侧文字识别（OCR）门面。
///
/// 真实实现只在 Android / iOS 上可用：`google_mlkit_text_recognition` 是移动端
/// 插件，其 Dart 实现还依赖 `dart:io`。为了让 Web 仍然能编译，这里用条件导入
/// 把实现隔离出去——Web 走 [_stub]，其余平台走 ML Kit 实现，再由
/// [isTextRecognitionSupported] 在运行时把桌面端挡在门外（桌面有 `dart:io`，
/// 能编译但没有原生实现）。
///
/// 调用方应当先问 [isTextRecognitionSupported] 再决定是否展示入口，
/// 而不是调用了再去接异常。
library;

export 'app_text_recognizer_stub.dart'
    if (dart.library.io) 'app_text_recognizer_io.dart';
export 'ocr_line.dart';
