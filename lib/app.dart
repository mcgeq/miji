// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           app.dart
// Description:    About App
// Create   Date:  2025-04-12 10:59:00
// Last Modified:  2025-04-12 10:59:12
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miji/providers/theme_provider.dart'; // Adjust paths
import 'package:miji/presentation/screens/todo_screen.dart';
import 'package:miji/presentation/theme/theme_button.dart';

class PiscesApp extends ConsumerWidget {
  const PiscesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the theme provider state
    final themeState = ref.watch(themeNotifierProvider);
    final themeNotifier = ref.read(themeNotifierProvider.notifier);

    return themeState.when(
      data:
          (themeMode) => MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Pisces Note', // Use constant if available
            theme:
                themeNotifier
                    .lightTheme, // Access themes via notifier or AppThemes
            darkTheme: themeNotifier.darkTheme,
            themeMode: themeMode,
            home: const Scaffold(
              // appBar: AppBar(title: Text('Pisces Todo')), // Optional AppBar
              body: TodoScreen(),
              floatingActionButton: ThemeToggleButton(),
              floatingActionButtonLocation:
                  FloatingActionButtonLocation.endFloat,
            ),
          ),
      loading:
          () => const MaterialApp(
            // Show a loading indicator while theme loads
            debugShowCheckedModeBanner: false,
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
          ),
      error:
          (error, stackTrace) => MaterialApp(
            // Show an error message
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(child: Text('Error loading theme: $error')),
            ),
          ),
    );
  }
}
