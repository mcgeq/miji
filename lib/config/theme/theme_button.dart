// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           theme_button.dart
// Description:    About Theme Switch
// Create   Date:  2025-04-12 10:55:08
// Last Modified:  2025-04-12 10:55:16
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miji/providers/theme_provider.dart'; // Adjust import path

class ThemeToggleButton extends ConsumerWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // No need to watch here if only triggering action
    // final themeMode = ref.watch(themeNotifierProvider); // Keep if needed for icon logic

    return FloatingActionButton(
      onPressed: () {
        // Directly call the method on the notifier
        ref.read(themeNotifierProvider.notifier).toggleTheme();
      },
      // Use theme colors for consistency
      // backgroundColor: Theme.of(context).colorScheme.primary, // Handled by FAB Theme
      // foregroundColor: Theme.of(context).colorScheme.onPrimary, // Handled by FAB Theme
      child: ref
          .watch(themeNotifierProvider)
          .when(
            // Watch here for icon state
            data:
                (themeMode) => Icon(
                  themeMode == ThemeMode.dark
                      ? Icons.light_mode
                      : Icons.dark_mode,
                ),
            loading:
                () => const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ), // Show loading
            error: (err, stack) => const Icon(Icons.error), // Show error
          ),
    );
  }
}
