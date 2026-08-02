import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/features/todo/domain/todo_models.dart';
import 'package:miji/features/todo/providers/todo_providers.dart';
import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/shared/widgets/app_text_field.dart';
import 'package:miji/shared/widgets/date_picker.dart';
import 'package:miji/shared/widgets/form_dropdown.dart';

/// 任务详情/编辑页
class TodoTaskDetailPage extends ConsumerStatefulWidget {
  const TodoTaskDetailPage({super.key, required this.taskId});

  final String taskId;

  @override
  ConsumerState<TodoTaskDetailPage> createState() => _TodoTaskDetailPageState();
}

class _TodoTaskDetailPageState extends ConsumerState<TodoTaskDetailPage> {
  late TextEditingController _titleController;
  late TextEditingController _notesController;
  TodoTaskStatus _status = TodoTaskStatus.todo;
  TodoTaskPriority _priority = TodoTaskPriority.none;
  DateTime? _scheduledDate;
  DateTime? _dueAt;
  String? _categoryId;
  bool _isLoading = false;
  bool _isNew = false;
  String? _userId;
  // V1.1
  List<String> _selectedTagIds = [];
  DateTime? _reminderAt;
  // Tab + Markdown
  var _selectedTab = 0;
  late TextEditingController _markdownBodyController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _notesController = TextEditingController();
    _markdownBodyController = TextEditingController();
    _loadTask();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _markdownBodyController.dispose();
    super.dispose();
  }

  Future<void> _loadTask() async {
    final session = ref.read(authSessionControllerProvider);
    _userId = session.userId;

    if (widget.taskId == 'new') {
      _isNew = true;
      return;
    }

    setState(() => _isLoading = true);
    final repo = ref.read(todoRepositoryProvider);
    final task = await repo.getTask(widget.taskId);
    if (task != null && mounted) {
      setState(() {
        _titleController.text = task.title;
        _notesController.text = task.notes ?? '';
        _status = task.status;
        _priority = task.priority;
        _scheduledDate = task.scheduledDate;
        _dueAt = task.dueAt;
        _categoryId = task.categoryId;
        _selectedTagIds = task.tags.map((t) => t.id).toList();
        _reminderAt = task.reminderAt;
        _markdownBodyController.text = task.markdownBody ?? '';
        _isLoading = false;
      });
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('任务详情')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? '新建任务' : '任务详情'),
        actions: [
          if (!_isNew) ...[
            // 状态切换按钮
            if (_status == TodoTaskStatus.todo)
              IconButton(
                icon: const Icon(Icons.check_circle_outline_rounded),
                tooltip: '完成任务',
                onPressed: _completeTask,
              )
            else if (_status == TodoTaskStatus.completed)
              IconButton(
                icon: const Icon(Icons.undo_rounded),
                tooltip: '重新打开',
                onPressed: _reopenTask,
              ),
            if (_status == TodoTaskStatus.todo)
              IconButton(
                icon: const Icon(Icons.cancel_outlined),
                tooltip: '取消任务',
                onPressed: _cancelTask,
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: '删除任务',
              onPressed: _deleteTask,
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          Row(
            children: [
              _TabButton(
                label: '属性',
                selected: _selectedTab == 0,
                onTap: () => setState(() => _selectedTab = 0),
              ),
              _TabButton(
                label: '内容',
                selected: _selectedTab == 1,
                onTap: () => setState(() => _selectedTab = 1),
              ),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: _selectedTab == 0
                ? SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppTextField(
                          controller: _titleController,
                          labelText: '标题',
                        ),
                        const SizedBox(height: 16),
                        AppTextField(
                          controller: _notesController,
                          labelText: '备注',
                          maxLines: 3,
                          minLines: 2,
                        ),
                        const SizedBox(height: 16),
                        _buildPrioritySelector(theme, colorScheme),
                        const SizedBox(height: 16),
                        DateTimePicker(
                          selectedDate: _scheduledDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                          showTime: false,
                          label: _scheduledDate == null
                              ? '计划日期 · 未设置'
                              : '计划日期 · ${_formatDate(_scheduledDate!)}',
                          clearable: _scheduledDate != null,
                          onClear: () => setState(() => _scheduledDate = null),
                          onChanged: (d) => setState(() => _scheduledDate = d),
                        ),
                        const SizedBox(height: 12),
                        DateTimePicker(
                          selectedDate: _dueAt ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                          label: _dueAt == null
                              ? '截止时间 · 未设置'
                              : '截止时间 · ${_formatDateTime(_dueAt!)}',
                          clearable: _dueAt != null,
                          onClear: () => setState(() => _dueAt = null),
                          onChanged: (d) => setState(() => _dueAt = d),
                        ),
                        const SizedBox(height: 16),
                        _buildCategorySelector(),
                        const SizedBox(height: 16),
                        _buildTagSelector(theme, colorScheme),
                        const SizedBox(height: 16),
                        DateTimePicker(
                          selectedDate:
                              _reminderAt ??
                              DateTime.now().add(const Duration(hours: 1)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2100),
                          label: _reminderAt == null
                              ? '提醒 · 未设置'
                              : '提醒 · ${_formatDateTime(_reminderAt!)}',
                          clearable: _reminderAt != null,
                          onClear: () => setState(() => _reminderAt = null),
                          onChanged: (d) => setState(() => _reminderAt = d),
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _titleController.text.trim().isNotEmpty
                              ? _save
                              : null,
                          child: Text(_isNew ? '创建任务' : '保存'),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppTextField(
                          controller: _markdownBodyController,
                          labelText: '正文 (Markdown)',
                          hintText:
                              '支持 Markdown 格式：\n# 标题\n**加粗** *斜体*\n- 列表\n- [ ] 待办',
                          maxLines: 15,
                          minLines: 5,
                        ),
                        const SizedBox(height: 16),
                        if (!_isNew) _buildSubTasks(theme, colorScheme),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _titleController.text.trim().isNotEmpty
                              ? _save
                              : null,
                          child: Text(_isNew ? '创建任务' : '保存'),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrioritySelector(ThemeData theme, ColorScheme colorScheme) {
    return Row(
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
                if (selected) setState(() => _priority = p);
              },
              selectedColor: _priorityColor(p).withValues(alpha: 0.2),
              labelStyle: TextStyle(
                color: isSelected ? _priorityColor(p) : null,
                fontWeight: isSelected ? FontWeight.w600 : null,
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCategorySelector() {
    final categoriesAsync = ref.watch(todoCategoriesProvider);

    return categoriesAsync.when(
      data: (categories) {
        return FormDropdown<String>(
          initialSelection: _categoryId ?? '',
          label: '分类',
          leadingIcon: const Icon(Icons.category_rounded),
          enableFilter: true,
          onSelected: (value) {
            setState(() {
              _categoryId = (value == null || value.isEmpty) ? null : value;
            });
          },
          entries: [
            const DropdownMenuEntry(
              value: '',
              label: '无分类',
              labelWidget: _NoCategoryOption(),
            ),
            ...categories.map(
              (c) => DropdownMenuEntry(
                value: c.id,
                label: c.name,
                labelWidget: _CategoryOption(
                  icon: c.icon,
                  name: c.name,
                  color: Color(int.parse(c.color.replaceFirst('#', '0xff'))),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildTagSelector(ThemeData theme, ColorScheme colorScheme) {
    final tagsAsync = ref.watch(todoTagsProvider);

    return tagsAsync.when(
      data: (allTags) {
        final selectedTags = allTags
            .where((t) => _selectedTagIds.contains(t.id))
            .toList();

        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showTagPicker(allTags),
          child: InputDecorator(
            decoration: appInputDecoration(
              context,
              labelText: '标签',
              enabled: true,
              suffixIcon: const Icon(Icons.chevron_right_rounded, size: 18),
            ),
            child: selectedTags.isEmpty
                ? Text(
                    '未设置',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.outline,
                    ),
                  )
                : Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: selectedTags
                        .map(
                          (tag) => Chip(
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            label: Text(
                              tag.name,
                              style: const TextStyle(fontSize: 12),
                            ),
                            backgroundColor: Color(
                              int.parse(tag.color.replaceFirst('#', '0xff')),
                            ).withValues(alpha: 0.15),
                            side: BorderSide.none,
                            deleteIcon: const Icon(Icons.close, size: 14),
                            onDeleted: () {
                              setState(() => _selectedTagIds.remove(tag.id));
                            },
                          ),
                        )
                        .toList(),
                  ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Future<void> _showTagPicker(List<TodoTag> allTags) async {
    final result = await showModalBottomSheet(
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '选择标签',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            ...allTags.map(
              (tag) => CheckboxListTile(
                title: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Color(
                          int.parse(tag.color.replaceFirst('#', '0xff')),
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(tag.name),
                  ],
                ),
                value: _selectedTagIds.contains(tag.id),
                onChanged: (checked) {
                  Navigator.pop(context, [tag.id, checked == true]);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('完成'),
                ),
              ),
            ),
          ],
        );
      },
    );
    if (result != null && result is List && result.length == 2) {
      final tagId = result[0] as String;
      final add = result[1] as bool;
      setState(() {
        if (add) {
          if (!_selectedTagIds.contains(tagId)) _selectedTagIds.add(tagId);
        } else {
          _selectedTagIds.remove(tagId);
        }
      });
    }
  }

  Widget _buildSubTasks(ThemeData theme, ColorScheme colorScheme) {
    final taskAsync = ref.watch(todoTaskDetailProvider(widget.taskId));

    return taskAsync.when(
      data: (task) {
        if (task == null) return const SizedBox.shrink();
        final subTasks = task.subTasks;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '子任务',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('添加'),
                  onPressed: () => _addSubTask(task.id),
                ),
              ],
            ),
            if (subTasks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '暂无子任务',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.outline,
                  ),
                ),
              ),
            ...subTasks.map(
              (sub) => _SubTaskTile(
                subTask: sub,
                onToggle: () => _toggleSubTask(sub),
                onDelete: () => _deleteSubTask(sub.id),
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Future<void> _addSubTask(String parentTaskId) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加子任务'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '子任务标题'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('添加'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && _userId != null) {
      final repo = ref.read(todoRepositoryProvider);
      final draft = TodoTaskDraft(title: result, parentTaskId: parentTaskId);
      await repo.createTask(draft, _userId!);
      ref.invalidate(todoTaskDetailProvider(widget.taskId));
    }
  }

  Future<void> _toggleSubTask(TodoTask subTask) async {
    final repo = ref.read(todoRepositoryProvider);
    if (subTask.status == TodoTaskStatus.todo) {
      await repo.completeTask(subTask.id);
    } else {
      await repo.reopenTask(subTask.id);
    }
    ref.invalidate(todoTaskDetailProvider(widget.taskId));
    invalidateTodayActionData(ref);
  }

  Future<void> _deleteSubTask(String subTaskId) async {
    final repo = ref.read(todoRepositoryProvider);
    await repo.softDeleteTask(subTaskId);
    ref.invalidate(todoTaskDetailProvider(widget.taskId));
    invalidateTodayActionData(ref);
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final repo = ref.read(todoRepositoryProvider);

    if (_isNew) {
      if (_userId == null) return;
      final draft = TodoTaskDraft(
        title: title,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        priority: _priority,
        scheduledDate: _scheduledDate,
        dueAt: _dueAt,
        categoryId: _categoryId,
        reminderAt: _reminderAt,
        tagIds: _selectedTagIds.isNotEmpty ? _selectedTagIds : null,
        markdownBody: _markdownBodyController.text.trim().isEmpty
            ? null
            : _markdownBodyController.text.trim(),
      );
      final task = await repo.createTask(draft, _userId!);
      if (_selectedTagIds.isNotEmpty) {
        await repo.setTaskTags(task.id, _selectedTagIds);
      }
    } else {
      final existing = await repo.getTask(widget.taskId);
      if (existing == null) return;

      final updated = existing.copyWith(
        title: title,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        priority: _priority,
        scheduledDate: _scheduledDate,
        dueAt: _dueAt,
        categoryId: _categoryId,
        reminderAt: _reminderAt,
        markdownBody: _markdownBodyController.text.trim().isEmpty
            ? null
            : _markdownBodyController.text.trim(),
      );
      await repo.updateTask(updated);
      await repo.setTaskTags(widget.taskId, _selectedTagIds);
    }

    if (mounted) {
      invalidateTodayActionData(ref);
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _completeTask() async {
    final repo = ref.read(todoRepositoryProvider);
    await repo.completeTask(widget.taskId);
    setState(() => _status = TodoTaskStatus.completed);
    invalidateTodayActionData(ref);
  }

  Future<void> _reopenTask() async {
    final repo = ref.read(todoRepositoryProvider);
    await repo.reopenTask(widget.taskId);
    setState(() => _status = TodoTaskStatus.todo);
    invalidateTodayActionData(ref);
  }

  Future<void> _cancelTask() async {
    final repo = ref.read(todoRepositoryProvider);
    await repo.cancelTask(widget.taskId);
    setState(() => _status = TodoTaskStatus.cancelled);
    invalidateTodayActionData(ref);
  }

  Future<void> _deleteTask() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除任务'),
        content: const Text('确定要删除这个任务吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final repo = ref.read(todoRepositoryProvider);
      await repo.softDeleteTask(widget.taskId);
      invalidateTodayActionData(ref);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('任务已删除'),
            action: SnackBarAction(
              label: '撤销',
              onPressed: () async {
                await repo.restoreTask(widget.taskId);
                invalidateTodayActionData(ref);
              },
            ),
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  String _formatDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime d) {
    return '${_formatDate(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
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

class _CategoryOption extends StatelessWidget {
  const _CategoryOption({
    required this.icon,
    required this.name,
    required this.color,
  });

  final String icon;
  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: 22,
          child: Center(
            child: Text(
              icon,
              overflow: TextOverflow.clip,
              style: theme.textTheme.bodyMedium?.copyWith(letterSpacing: 0),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            name,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(letterSpacing: 0),
          ),
        ),
        const SizedBox(width: 6),
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ],
    );
  }
}

class _NoCategoryOption extends StatelessWidget {
  const _NoCategoryOption();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      children: [
        Icon(Icons.block_rounded, size: 16, color: colorScheme.outline),
        const SizedBox(width: 8),
        Text(
          '无分类',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected
                    ? theme.colorScheme.primary
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _SubTaskTile extends StatelessWidget {
  const _SubTaskTile({
    required this.subTask,
    required this.onToggle,
    required this.onDelete,
  });
  final TodoTask subTask;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isCompleted = subTask.status == TodoTaskStatus.completed;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: onToggle,
            child: Icon(
              isCompleted
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: isCompleted ? Colors.green.shade400 : colorScheme.outline,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              subTask.title,
              style: theme.textTheme.bodyMedium?.copyWith(
                decoration: isCompleted ? TextDecoration.lineThrough : null,
                color: isCompleted
                    ? colorScheme.outline
                    : colorScheme.onSurface,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close_rounded,
              size: 16,
              color: colorScheme.outline,
            ),
            onPressed: onDelete,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
