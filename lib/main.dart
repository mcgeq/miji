// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           main.dart
// Description:    About Flutter main
// Create   Date:  2025-03-29 16:27:14
// Last Modified:  2025-05-08 14:48:57
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

import 'package:flutter/material.dart';


import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod

import 'package:hive_flutter/hive_flutter.dart';

import 'package:miji/data/models/todo.dart'; // Adjust paths

import 'package:miji/services/logging/logger.dart';

import 'package:miji/services/notifications/notification_service.dart';

import 'package:miji/services/window/window_manager_helper.dart';

import 'package:miji/app.dart'; // Import the new App widget

void main() async {
  WidgetsFlutterBinding.ensureInitialized();


  await dotenv.load(fileName: 'assets/.env');


  // Hive Initialization

  await Hive.initFlutter();

  Hive.registerAdapter(TodoAdapter());

  Hive.registerAdapter(PriorityAdapter());

  await Hive.openBox<Todo>('todos'); // Ensure box is open before app runs

  // Initialize Services

  await NotificationService.initialize();

  await WindowManagerHelper.initialize();

  McgLogger.init(enableFileLogging: true, minLevel: LogLevel.verbose);

  // Run the app within a ProviderScope

  runApp(
    const ProviderScope(
      child: PiscesApp(), // Use the new App widget
    ),
  );
}
