import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/features/todo/domain/todo_models.dart';
import 'package:miji/features/todo/providers/todo_providers.dart';
import 'package:miji/core/auth/application/auth_session_controller.dart';

/// 快速创建任务的 BottomSheet
class TodoQuickCreateSheet extends ConsumerStatefulWidget {
  const TodoQuickCreateSheet({super.key});

  @override
  ConsumerState<TodoQuickCreateSheet> createState() =>
      _TodoQuickCreateSheetState();
}

class _TodoQuickCreateSheetState extends ConsumerState<TodoQuickCreateSheet> {
  final _titleController = TextEditingController();
  final _focusNode = FocusNode();
  var _scheduleToday = true;
  var _priority = TodoTaskPriority.none;

  @override
  void initState() {
    super.initState();
    // 自动聚焦输入框
    Future.microtask(() => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _titleController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 标题栏
              Row(
                children: [
                  Text(
                    '快速创建任务',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 标题输入
              TextField(
                controller: _titleController,
                focusNode: _focusNode,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '输入任务标题',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 16),
              // 安排到今天
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('安排到今天'),
                subtitle: const Text('默认将任务计划日期设为今天'),
                value: _scheduleToday,
                onChanged: (value) {
                  setState(() => _scheduleToday = value);
                },
              ),
              // 优先级选择
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Text('优先级', style: theme.textTheme.bodyMedium),
                    const SizedBox(width: 12),
                    ...TodoTaskPriority.values.map((p) {
                      final isSelected = _priority == p;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(_priorityLabel(p)),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _priority = p);
                            }
                          },
                          selectedColor: _priorityColor(
                            p,
                          ).withValues(alpha: 0.2),
                          labelStyle: TextStyle(
                            color: isSelected ? _priorityColor(p) : null,
                            fontWeight: isSelected ? FontWeight.w600 : null,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // 保存按钮
              FilledButton(
                onPressed: _titleController.text.trim().isNotEmpty
                    ? _save
                    : null,
                child: const Text('创建任务'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final repo = ref.read(todoRepositoryProvider);
    final session = ref.read(authSessionControllerProvider);
    final userId = session.userId;
    if (userId == null) return;

    final draft = TodoTaskDraft(
      title: title,
      priority: _priority,
      scheduledDate: _scheduleToday ? DateTime.now() : null,
    );

    await repo.createTask(draft, userId);

    if (mounted) {
      // 刷新数据
      invalidateTodayActionData(ref);
      Navigator.of(context).pop(true);
    }
  }

  String _priorityLabel(TodoTaskPriority p) {
    return switch (p) {
      TodoTaskPriority.none => '无',
      TodoTaskPriority.low => '低',
      TodoTaskPriority.medium => '中',
      TodoTaskPriority.high => '高',
    };
  }

  Color _priorityColor(TodoTaskPriority p) {
    return switch (p) {
      TodoTaskPriority.high => Colors.red,
      TodoTaskPriority.medium => Colors.orange,
      TodoTaskPriority.low => Colors.blue,
      TodoTaskPriority.none => Colors.grey,
    };
  }
}

/// 显示快速创建任务的 BottomSheet
Future<bool?> showTodoQuickCreateSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => const TodoQuickCreateSheet(),
  );
}
