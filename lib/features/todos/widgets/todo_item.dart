// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           todo_item.dart
// Description:    About TodoItem
// Create   Date:  2025-04-12 10:56:25
// Last Modified:  2025-05-09 22:23:23
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:miji/data/models/enums/priority.dart';


import 'package:miji/providers/todo_provider.dart';
import 'package:miji/utils/date_time_extensions.dart';

class TodoItem extends StatelessWidget {
  final Todo todo;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onMoveToTomorrow;
  final VoidCallback onMoveToToday;
  final VoidCallback onEdit;
  final bool isYesterday;

  const TodoItem({
    super.key,
    required this.todo,
    required this.onToggle,
    required this.onDelete,
    required this.onMoveToTomorrow,
    required this.onMoveToToday,
    required this.onEdit,
    this.isYesterday = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    final isCompleted = todo.isCompleted;

    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final tomorrowStart = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
    final bool isDueTomorrow = todo.dueDate.isSameDay(tomorrowStart);

    final bool canInteract = !isCompleted && !isYesterday;

    return GestureDetector(
      onDoubleTap: () {
        if (canInteract) {
          onEdit();
        }
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 3,
        color: isCompleted ? Colors.grey.shade300 : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              vertical: 6,
              horizontal: 16,
            ),
            leading:
                isYesterday || isDueTomorrow
                    ? const Icon(Icons.schedule, color: Colors.grey)
                    : Checkbox(
                      value: isCompleted,
                      onChanged: canInteract ? (value) => onToggle() : null,
                      activeColor:
                          isCompleted
                              ? Colors.grey.shade600
                              : Theme.of(context).colorScheme.primary,
                      checkColor:
                          Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurface,
                    ),
            title: Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onLongPress: () {
                  if (MediaQuery.of(context).size.width < 600) {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: theme.cardColor,
                      builder:
                          (context) => Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              todo.title,
                              style: theme.textTheme.bodyLarge,
                            ),
                          ),
                    );
                  }
                },
                child: Tooltip(
                  message: todo.title,
                  waitDuration: const Duration(microseconds: 500),
                  child: Text(
                    todo.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color:
                          isCompleted
                              ? Colors.grey.shade600
                              : todo.priority == Priority.high
                              ? Colors.red
                              : theme.colorScheme.onSurface,
                      // REMOVED decoration property to disable strikethrough:
                      // decoration: isCompleted
                      // ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
              ),
            ),
            trailing:
                isCompleted
                    ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (todo.completedAt != null)
                          Text(
                            '完成: ${dateFormat.format(todo.completedAt!)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                          ),
                        Text(
                          '截止: ${dateFormat.format(todo.dueDate)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.orange,
                            // Removed strikethrough from due date as well
                            // decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        if (todo.reminder != null)
                          Text(
                            '提醒: ${dateFormat.format(todo.reminder!)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.blue[600],
                              // Removed strikethrough from reminder
                              // decoration: TextDecoration.lineThrough,
                            ),
                          ),
                      ],
                    )
                    : isYesterday
                    ? const SizedBox.shrink()
                    : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isDueTomorrow)
                          TextButton(
                            onPressed: onMoveToToday,
                            style: TextButton.styleFrom(
                              shape: const CircleBorder(),
                              padding: const EdgeInsets.all(16),
                              side: BorderSide(
                                color: Colors.grey.shade400,
                                width: 2,
                              ),
                            ),
                            child: const Text(
                              '今',
                              style: TextStyle(color: Colors.green),
                            ),
                          ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.redAccent,
                          ),
                          onPressed: onDelete,
                        ),
                        TextButton(
                          onPressed: onMoveToTomorrow,
                          style: TextButton.styleFrom(
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(16),
                            side: BorderSide(
                              color: Colors.grey.shade400,
                              width: 2,
                            ),
                          ),
                          child: const Text(
                            '明',
                            style: TextStyle(color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
          ),
        ),
      ),
    );
  }
}