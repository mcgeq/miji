// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           main.dart
// Description:    About Flutter main
// Create   Date:  2025-03-29 16:27:14
// Last Modified:  2025-03-30 17:21:30
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mcge_pisces/models/todo.dart';
import 'package:mcge_pisces/providers/theme_controller.dart';
import 'package:mcge_pisces/providers/todo_provider.dart';
import 'package:mcge_pisces/screens/todo_screen.dart';
import 'package:mcge_pisces/utils/logger.dart';
import 'package:mcge_pisces/utils/notification_service.dart';
import 'package:mcge_pisces/utils/window_manager_helper.dart';
import 'package:mcge_pisces/widgets/theme_button.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // hive
  await Hive.initFlutter();
  Hive.registerAdapter(TodoAdapter());
  Hive.registerAdapter(PriorityAdapter());
  await Hive.openBox<Todo>('todos');

  // 初始化通知
  await NotificationService.initialize();

  // init window
  await WindowManagerHelper.initialize();

  // init logger
  McgLogger.init(enableFileLogging: true, minLevel: LogLevel.verbose);

  runApp(const PiscesHome());
}

class PiscesHome extends StatelessWidget {
  const PiscesHome({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeController()),
        ChangeNotifierProvider(create: (_) => TodoProvider()),
      ],
      child: Consumer<ThemeController>(
        builder: (context, themeController, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeController.lightTheme,
            darkTheme: ThemeController.darkTheme,
            themeMode: themeController.themeMode,
            home: const Scaffold(
              body: TodoScreen(),
              floatingActionButton: ThemeToggleButton(),
              floatingActionButtonLocation:
                  FloatingActionButtonLocation.endFloat,
            ),
          );
        },
      ),
    );
  }
}
