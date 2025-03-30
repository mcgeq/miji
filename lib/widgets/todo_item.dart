import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mcge_pisces/models/todo.dart';
import 'package:mcge_pisces/utils/date_time_extensions.dart';

class TodoItem extends StatelessWidget {
  final Todo todo;
  final int index;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onMoveToTomorrow;
  final VoidCallback onMoveToToday;
  final VoidCallback onEdit;
  final bool isYesterday;

  const TodoItem({
    super.key,
    required this.todo,
    required this.index,
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
    // 获取明天的日期（不包含时间部分）
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final tomorrowStart = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);

    return GestureDetector(
      onDoubleTap: () {
        if (!isCompleted) {
          onEdit();
        }
      },
      child: Card(
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
                isYesterday || todo.dueDate.isSameDay(tomorrowStart)
                    ? const Icon(Icons.schedule, color: Colors.grey) // "昨" 不能编辑
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
              child: GestureDetector(
                onLongPress: () {
                  if (MediaQuery.of(context).size.width < 600) {
                    showModalBottomSheet(
                      context: context,
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
                          todo.isCompleted
                              ? Colors.grey.shade600
                              : todo.priority == Priority.high
                              ? Colors.red
                              : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
            trailing:
                isCompleted &&
                        (todo.completedAt != null || todo.reminder != null)
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
                        // 判断 dueDate 是否是明天来决定是否显示 "今" 按钮
                        if (todo.dueDate.isSameDay(tomorrowStart))
                          TextButton(
                            onPressed: onMoveToToday, // 迁移到今天按钮
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
      ),
    );
  }
}
