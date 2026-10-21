import 'dart:io';

/// 桌面小组件只存在于 Android / iOS。
///
/// 桌面端（Windows / macOS / Linux）也返回 false：桌面小组件是另一个体系
/// （Windows Widgets Board / macOS 通知中心），这里没有实现。
bool get isMobilePlatform => Platform.isAndroid || Platform.isIOS;
