// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           filter_buttons.dart
// Description:    About FilterButtons
// Create   Date:  2025-04-12 10:55:29
// Last Modified:  2025-04-12 10:55:37
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miji/providers/todo_filter_provider.dart'; // Adjust path
import 'package:miji/providers/todo_page_provider.dart'; // Adjust path

class FilterButtons extends ConsumerWidget {
  // Change to ConsumerWidget
  const FilterButtons({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Add WidgetRef
    final currentFilter = ref.watch(
      todoFilterProvider,
    ); // Watch filter provider
    final filters = ['昨', '今', '明']; // Define filters

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0), // Adjusted padding
      child: SegmentedButton<String>(
        // Use SegmentedButton for modern look
        segments:
            filters.map((filter) {
              return ButtonSegment<String>(
                value: filter,
                label: Text(filter),
                // icon: Icon(filter == '昨' ? Icons.history : filter == '今' ? Icons.today : Icons.event), // Optional icons
              );
            }).toList(),
        selected: {currentFilter},
        onSelectionChanged: (newSelection) {
          if (newSelection.isNotEmpty) {
            ref.read(todoFilterProvider.notifier).setFilter(newSelection.first);
            // Reset to first page when filter changes
            ref.read(todoPageProvider.notifier).firstPage();
          }
        },
        style: SegmentedButton.styleFrom(
          // backgroundColor: Theme.of(context).colorScheme.surfaceVariant, // Example background
          // foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant, // Example text color
          // selectedBackgroundColor: Theme.of(context).colorScheme.primary, // Example selected background
          // selectedForegroundColor: Theme.of(context).colorScheme.onPrimary, // Example selected text
        ),
      ),
    );
  }
}
