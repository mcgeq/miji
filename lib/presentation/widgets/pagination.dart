// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           pagination.dart
// Description:    About Pagination
// Create   Date:  2025-04-12 10:55:46
// Last Modified:  2025-04-12 10:55:54
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miji/providers/todo_provider.dart';
import 'package:miji/providers/todo_page_provider.dart';

class Pagination extends ConsumerWidget {
  const Pagination({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPage = ref.watch(todoPageProvider);
    final totalPages = ref.watch(totalTodoPagesProvider);
    final pageNotifier = ref.read(todoPageProvider.notifier);

    final bool disableButtons = totalPages <= 1;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildPageIconButton(
          context,
          icon: Icons.first_page,
          tooltip: '首页',
          onPressed:
              disableButtons || currentPage == 1
                  ? null
                  : pageNotifier.firstPage,
        ),
        _buildPageIconButton(
          context,
          icon: Icons.chevron_left,
          tooltip: '上一页',
          onPressed:
              disableButtons || currentPage == 1
                  ? null
                  : pageNotifier.previousPage,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          // Break long line
          child: Text(
            '$currentPage / $totalPages',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        _buildPageIconButton(
          context,
          icon: Icons.chevron_right,
          tooltip: '下一页',
          onPressed:
              disableButtons || currentPage == totalPages
                  ? null
                  : () => pageNotifier.nextPage(totalPages),
        ),
        _buildPageIconButton(
          context,
          icon: Icons.last_page,
          tooltip: '末页',
          onPressed:
              disableButtons || currentPage == totalPages
                  ? null
                  : () => pageNotifier.lastPage(totalPages),
        ),
      ],
    );
  }

  Widget _buildPageIconButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    VoidCallback? onPressed,
  }) {
    return IconButton(icon: Icon(icon), tooltip: tooltip, onPressed: onPressed);
  }
}
