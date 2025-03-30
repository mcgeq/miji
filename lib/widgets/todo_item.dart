import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mcge_pisces/models/todo.dart';

class TodoItem extends StatelessWidget {
  final Todo todo;
  final int index;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onMoveToTomorrow;
  final bool isYesterday;

  const TodoItem({
    super.key,
    required this.todo,
    required this.index,
    required this.onToggle,
    required this.onDelete,
    required this.onMoveToTomorrow,
    this.isYesterday = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    final isCompleted = todo.isCompleted;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      color: isCompleted ? Colors.grey.shade300 : null, // 背景为灰色
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            vertical: 6,
            horizontal: 16,
          ),
          leading:
              isYesterday
                  ? const Icon(Icons.lock, color: Colors.grey) // "昨" 不能编辑
                  : Checkbox(
                    value: isCompleted,
                    onChanged:
                        isCompleted ? null : (value) => onToggle(), // 复选框禁用
                    activeColor:
                        isCompleted
                            ? Colors.grey.shade600
                            : Theme.of(context).colorScheme.primary,
                    checkColor:
                        Theme.of(context).brightness == Brightness.dark
                            ? Colors
                                .white // 在暗黑模式下设置对钩颜色为白色
                            : Theme.of(
                              context,
                            ).colorScheme.onSurface, // 在浅色模式下使用默认颜色
                  ),
          title: Align(
            // 让 title 左对齐，同时垂直居中
            alignment: Alignment.centerLeft,
            child: Text(
              todo.title,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color:
                    todo.isCompleted
                        ? Colors.grey.shade600
                        : todo.priority == Priority.high
                        ? Colors.red
                        : theme.colorScheme.onSurface,
              ),
            ),
          ),
          trailing:
              isCompleted && (todo.completedAt != null || todo.reminder != null)
                  ? Column(
                    mainAxisAlignment: MainAxisAlignment.center, // 保持居中对齐
                    crossAxisAlignment: CrossAxisAlignment.end, // 右对齐
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
                        ),
                      ),
                      if (todo.reminder != null)
                        Text(
                          '提醒: ${dateFormat.format(todo.reminder!)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.blue,
                          ),
                        ),
                    ],
                  )
                  : isYesterday
                  ? const SizedBox.shrink() // "昨" 隐藏删除按钮
                  : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: onDelete,
                      ),
                      TextButton(
                        onPressed: onMoveToTomorrow, // 迁移到明天按钮
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
    );
  }
}
