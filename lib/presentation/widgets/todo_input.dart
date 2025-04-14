// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           todo_input.dart
// Description:    About TodoInput
// Create   Date:  2025-04-12 10:56:03
// Last Modified:  2025-04-12 10:56:13
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:miji/providers/todo_provider.dart';

class TodoInput extends ConsumerStatefulWidget {
  const TodoInput({super.key});

  @override
  ConsumerState<TodoInput> createState() => _TodoInputState();
}

class _TodoInputState extends ConsumerState<TodoInput> {
  final TextEditingController _controller = TextEditingController();
  DateTime? _selectedReminder;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _selectReminder() async {
    final now = DateTime.now();
    final initialDate = _selectedReminder ?? now;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(now) ? initialDate : now,
      firstDate: now,
      // Allow selecting dates further in the future
      lastDate: now.add(const Duration(days: 365 * 5)),
    );

    if (!mounted || pickedDate == null) return;

    final initialTime = TimeOfDay.fromDateTime(
      _selectedReminder != null && _selectedReminder!.isAfter(now)
          ? _selectedReminder!
          : now.add(const Duration(minutes: 5)), // Default to 5 mins from now
    );

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (!mounted || pickedTime == null) return;

    setState(() {
      _selectedReminder = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  void _addTodo() {
    final title = _controller.text.trim();
    if (title.isNotEmpty) {
      // Use ref.read to access the notifier and add the todo
      ref
          .read(todoListProvider.notifier)
          .addTodo(
            title,
            reminder: _selectedReminder,
            // dueDate is handled by default in provider, pass if needed:
            // dueDate: _selectedDueDate,
          );
      _controller.clear();
      setState(() {
        _selectedReminder = null; // Clear reminder after adding
      });
      FocusScope.of(context).unfocus(); // Hide keyboard
    }
  }

  @override
  Widget build(BuildContext context) {
    // Break long line
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: '输入新任务...',
                suffixText:
                    _selectedReminder != null
                        ? '提醒: ${dateFormat.format(_selectedReminder!)}'
                        : null,
                suffixStyle: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              onSubmitted: (_) => _addTodo(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              _selectedReminder == null
                  ? Icons.notifications_none
                  : Icons.notifications_active,
              color:
                  _selectedReminder == null
                      ? null
                      : Theme.of(context).colorScheme.primary,
            ),
            tooltip: _selectedReminder == null ? '添加提醒' : '修改/移除提醒',
            onPressed: _selectReminder,
          ),
          if (_selectedReminder != null)
            IconButton(
              icon: const Icon(Icons.clear, size: 18),
              tooltip: '清除提醒',
              onPressed: () {
                setState(() {
                  _selectedReminder = null;
                });
              },
            ),
          const SizedBox(width: 4),
          ElevatedButton(
            onPressed: _addTodo,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }
}
