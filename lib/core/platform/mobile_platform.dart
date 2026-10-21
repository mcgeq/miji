/// 「当前是不是真的跑在手机上」。
///
/// 不能用 `defaultTargetPlatform`：`flutter test` 里它恒为 android，
/// 于是任何 pump 了 `MijiApp` 的测试都会去连桌面小组件的 EventChannel，
/// 通道不存在 → `MissingPluginException` 被 `FlutterError.reportError` 抛出来
/// → 测试直接红。这里用 `dart:io` 的 `Platform` 判断，测试跑在宿主机上
/// （Windows / macOS / Linux），自然是 false。
///
/// Web 上没有 `dart:io`，走 stub 分支恒为 false。
library;

export 'mobile_platform_stub.dart'
    if (dart.library.io) 'mobile_platform_io.dart';
