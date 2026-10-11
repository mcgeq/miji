import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum AppDeviceClass { compact, medium, expanded }

class AppResponsive {
  const AppResponsive._();

  static const compactBreakpoint = 700.0;
  static const expandedBreakpoint = 1024.0;

  static AppResponsiveData of(BuildContext context, {double? width}) {
    final size = MediaQuery.sizeOf(context);
    return AppResponsiveData(
      width: width ?? size.width,
      height: size.height,
      platform: defaultTargetPlatform,
    );
  }
}

@immutable
class AppResponsiveData {
  const AppResponsiveData({
    required this.width,
    required this.height,
    required this.platform,
  });

  final double width;
  final double height;
  final TargetPlatform platform;

  AppDeviceClass get deviceClass {
    if (width < AppResponsive.compactBreakpoint) {
      return AppDeviceClass.compact;
    }
    if (width < AppResponsive.expandedBreakpoint) {
      return AppDeviceClass.medium;
    }
    return AppDeviceClass.expanded;
  }

  bool get isCompact => deviceClass == AppDeviceClass.compact;

  bool get isMedium => deviceClass == AppDeviceClass.medium;

  bool get isExpanded => deviceClass == AppDeviceClass.expanded;

  bool get isDesktopPlatform {
    if (kIsWeb) {
      return false;
    }
    return switch (platform) {
      TargetPlatform.windows ||
      TargetPlatform.macOS ||
      TargetPlatform.linux => true,
      _ => false,
    };
  }

  bool get supportsHover => isDesktopPlatform;

  bool get prefersRailNavigation => isExpanded || isDesktopPlatform;
}
