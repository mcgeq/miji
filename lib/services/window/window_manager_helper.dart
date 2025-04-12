// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           window_manager_helper.dart
// Description:    About WindowManagerHelper
// Create   Date:  2025-04-12 10:57:48
// Last Modified:  2025-04-12 10:57:54
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter/services.dart';
import 'package:toml/toml.dart';
mixin WindowManagerHelper {
  static Future<void> initialize() async {
    if (kIsWeb || !Platform.isWindows) return;
    await windowManager.ensureInitialized();
    final Map<String, dynamic> config = await _loadWindowConfig();
    final windowConfig = config['window'] ?? {};
    final positionConfig = windowConfig['position'] ?? {};
    final behaviorConfig = windowConfig['behavior'] ?? {};
    await windowManager.waitUntilReadyToShow();
    final Size windowSize = Size(
      (windowConfig['width'] ?? 800).toDouble(),
      (windowConfig['height'] ?? 600).toDouble(),
    );
    await windowManager.setSize(windowSize);
    if (windowConfig['center'] ?? true) {
      await windowManager.center();
    } else if (positionConfig['x'] != null && positionConfig['y'] != null) {
      await windowManager.setPosition(
        Offset(positionConfig['x'].toDouble(), positionConfig['y'].toDouble()),
      );
    }
    await windowManager.setResizable(behaviorConfig['resizable'] ?? false);
    await windowManager.setMaximizable(behaviorConfig['maximizable'] ?? false);
    await windowManager.show();
  }
  static Future<Map<String, dynamic>> _loadWindowConfig() async {
    final String tomlString = await rootBundle.loadString(
      'assets/window_config.toml',
    );
    return TomlDocument.parse(tomlString).toMap();
  }
}
