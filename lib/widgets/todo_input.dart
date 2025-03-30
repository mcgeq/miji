import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mcge_pisces/providers/todo_provider.dart';

class TodoInput extends StatefulWidget {
  const TodoInput({super.key});

  @override
  TodoInputState createState() => TodoInputState(); // ✅ 去掉 `_`
}

class TodoInputState extends State<TodoInput> {
  // ✅ 去掉 `_`
  final TextEditingController _controller = TextEditingController();
  DateTime? _selectedReminder;

  Future<void> _selectReminder() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (!mounted || pickedDate == null) return; // ✅ 确保组件仍然存在

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '输入待办任务',
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(icon: const Icon(Icons.alarm), onPressed: _selectReminder),
          ElevatedButton(
            onPressed: () {
              if (_controller.text.isNotEmpty) {
                Provider.of<TodoProvider>(
                  context,
                  listen: false,
                ).addTodo(_controller.text, reminder: _selectedReminder);
                _controller.clear();
                setState(() {
                  _selectedReminder = null;
                });
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
