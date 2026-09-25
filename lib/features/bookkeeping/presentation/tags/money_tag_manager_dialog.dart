import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'package:miji/core/presentation/app_toast.dart';
import 'package:miji/core/presentation/components/app_confirm_dialog.dart';
import 'package:miji/core/presentation/components/app_icon_action_button.dart';
import 'package:miji/core/presentation/components/app_responsive_dialog.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';
import 'package:miji/shared/widgets/app_form_layout.dart';
import 'package:miji/shared/widgets/app_text_field.dart';

/// 标签管理：列出历史交易标签与预算标签，支持重命名（级联更新引用）与删除。
class MoneyTagManagerDialog extends ConsumerStatefulWidget {
  const MoneyTagManagerDialog({super.key});

  @override
  ConsumerState<MoneyTagManagerDialog> createState() =>
      _MoneyTagManagerDialogState();
}

class _MoneyTagManagerDialogState extends ConsumerState<MoneyTagManagerDialog> {
  FToast? _toast;
  bool _busy = false;

  FToast _ensureToast() => _toast ??= (FToast()..init(context));

  Future<void> _rename(String oldName) async {
    final newName = await showAppResponsiveDialog<String>(
      context: context,
      builder: (context) => _RenameTagDialog(initialName: oldName),
    );
    if (!mounted || newName == null || newName.trim() == oldName) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(currentUserTagActionsProvider)
          .renameTag(oldName, newName.trim());
      if (!mounted) return;
      AppToast.success(_ensureToast(), context, '标签已重命名');
    } catch (_) {
      if (!mounted) return;
      AppToast.error(_ensureToast(), context, '重命名失败');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(String name) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: '删除标签',
      message: '确定删除标签“$name”？引用该标签的流水与预算会被移除该标签。',
      confirmLabel: '删除',
      destructive: true,
      icon: Icons.label_off_rounded,
    );
    if (!confirmed || !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(currentUserTagActionsProvider).deleteTag(name);
      if (!mounted) return;
      AppToast.success(_ensureToast(), context, '标签已删除');
    } catch (_) {
      if (!mounted) return;
      AppToast.error(_ensureToast(), context, '删除失败');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tags = ref.watch(currentUserTagCandidatesProvider);
    return AppDialogScaffold(
      title: '标签管理',
      subtitle: '重命名会同步更新所有引用该标签的流水与预算',
      maxWidth: 460,
      titleTextAlign: TextAlign.center,
      body: tags.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('读取标签失败')),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: Text('暂无标签')),
            );
          }
          return ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final tag = items[index];
                return _TagRow(
                  name: tag,
                  enabled: !_busy,
                  onRename: () => _rename(tag),
                  onDelete: () => _delete(tag),
                );
              },
            ),
          );
        },
      ),
      actions: [
        AppIconActionButton(
          tooltip: '关闭',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: Icons.close_rounded,
          variant: AppIconActionVariant.outlined,
        ),
      ],
    );
  }
}

class _TagRow extends StatelessWidget {
  const _TagRow({
    required this.name,
    required this.enabled,
    required this.onRename,
    required this.onDelete,
  });

  final String name;
  final bool enabled;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(theme.radiusTokens.md),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.label_rounded, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(letterSpacing: 0),
            ),
          ),
          AppIconActionButton(
            tooltip: '重命名',
            onPressed: enabled ? onRename : null,
            icon: Icons.edit_rounded,
            iconSize: 18,
          ),
          AppIconActionButton(
            tooltip: '删除',
            onPressed: enabled ? onDelete : null,
            icon: Icons.delete_outline_rounded,
            iconSize: 18,
            variant: AppIconActionVariant.outlined,
          ),
        ],
      ),
    );
  }
}

class _RenameTagDialog extends StatefulWidget {
  const _RenameTagDialog({required this.initialName});

  final String initialName;

  @override
  State<_RenameTagDialog> createState() => _RenameTagDialogState();
}

class _RenameTagDialogState extends State<_RenameTagDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      setState(() => _errorText = '请输入标签名称');
      return;
    }
    if (value == widget.initialName) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AppDialogScaffold(
      title: '重命名标签',
      maxWidth: 380,
      titleTextAlign: TextAlign.center,
      errorText: _errorText,
      body: AppFormColumn(
        children: [
          AppTextField(
            controller: _controller,
            autofocus: true,
            labelText: '标签名称',
            prefixIcon: const Icon(Icons.label_rounded),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: appDialogIconActions(
        onCancel: () => Navigator.of(context).pop(),
        onConfirm: _submit,
        confirmTooltip: '保存',
      ),
    );
  }
}
