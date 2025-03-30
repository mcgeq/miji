// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           main.dart
// Description:    About Flutter main
// Create   Date:  2025-03-29 16:27:14
// Last Modified:  2025-03-30 13:10:33
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:mcge_pisces/constants/constants.dart';
import 'package:mcge_pisces/counter_controller.dart';
import 'package:mcge_pisces/theme_controller.dart';
import 'package:mcge_pisces/utils/logger.dart';
import 'package:mcge_pisces/utils/window_manager_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // init window
  await WindowManagerHelper.initialize();
  await ThemeController.loadTheme();

  // init logger
  McgLogger.init(enableFileLogging: false, minLevel: LogLevel.verbose);

  runApp(const PiscesHome());
}

class PiscesHome extends StatelessWidget {
  const PiscesHome({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.themeMode,
      builder: (context, child) {
        return MaterialApp(
          title: AppConstants.appTitle,
          theme: ThemeController.lightTheme,
          darkTheme: ThemeController.darkTheme,
          themeMode: ThemeController.themeMode.value,
          home: const PiscesHomePage(),
        );
      },
    );
  }
}

class PiscesHomePage extends StatelessWidget {
  const PiscesHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final CounterController controller = CounterController();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text(AppConstants.homeTitle),
        actions: [
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeController.themeMode,
            builder: (context, mode, child) {
              return Switch(
                value: mode == ThemeMode.dark,
                onChanged: ThemeController.toggleTheme,
                activeColor: Theme.of(context).colorScheme.primary,
              );
            },
          ),
        ],
      ),
      body: Center(
        child: ValueListenableBuilder<int>(
          valueListenable: controller.counter,
          builder: (context, count, child) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Text('You have pushed the button this many times:'),
                Text(
                  '$count',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: controller.increment,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
