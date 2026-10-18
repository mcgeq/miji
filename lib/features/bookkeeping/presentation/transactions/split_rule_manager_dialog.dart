import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miji/core/presentation/components/app_confirm_dialog.dart';
import 'package:miji/core/presentation/components/app_icon_action_button.dart';
import 'package:miji/core/presentation/components/app_responsive_dialog.dart';
import 'package:miji/core/presentation/components/app_surface.dart';
import 'package:miji/shared/widgets/app_form_layout.dart';
import 'package:miji/shared/widgets/app_switch_field.dart';
import 'package:miji/shared/widgets/app_text_field.dart';
import 'package:miji/shared/widgets/form_dropdown.dart';

import 'package:miji/features/bookkeeping/domain/money_split_entity.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';

class SplitRuleManagerDialog extends ConsumerStatefulWidget {
  const SplitRuleManagerDialog({super.key, required this.ledgerId});

  final String ledgerId;

  @override
  ConsumerState<SplitRuleManagerDialog> createState() =>
      _SplitRuleManagerDialogState();
}

class _SplitRuleManagerDialogState
    extends ConsumerState<SplitRuleManagerDialog> {
  final _nameController = TextEditingController();
  final _configController = TextEditingController(text: '{}');
  final _priorityController = TextEditingController(text: '0');
  MoneySplitRuleType _ruleType = MoneySplitRuleType.equal;
  bool _isActive = true;
  String? _editingId;
  String? _errorText;

  @override
  void dispose() {
    _nameController.dispose();
    _configController.dispose();
    _priorityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rules = ref.watch(currentUserSplitRulesProvider(widget.ledgerId));
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppDialogScaffold(
      title: '分摊模板',
      subtitle: '管理当前家庭账本的分摊规则',
      maxWidth: 760,
      titleTextAlign: TextAlign.center,
      actionsAlignment: WrapAlignment.center,
      body: rules.when(
        data: (items) => AppFormColumn(
          children: [
            _buildEditor(theme, colorScheme),
            Text(
              '已有模板',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            if (items.isEmpty)
              AppSurface(
                tone: AppSurfaceTone.inset,
                child: Text(
                  '还没有分摊模板',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(letterSpacing: 0),
                ),
              )
            else
              ...items.map(
                (rule) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _RuleTile(
                    rule: rule,
                    onEdit: () => _startEdit(rule),
                    onDelete: () => _confirmDelete(rule),
                  ),
                ),
              ),
          ],
        ),
        loading: () => const LinearProgressIndicator(),
        error: (error, stackTrace) => const Text('分摊模板读取失败'),
      ),
      actions: [
        AppIconActionButton(
          tooltip: '关闭',
          onPressed: () => Navigator.of(context).pop(),
          icon: Icons.close_rounded,
          variant: AppIconActionVariant.outlined,
        ),
      ],
    );
  }

  Widget _buildEditor(ThemeData theme, ColorScheme colorScheme) {
    return AppSurface(
      tone: AppSurfaceTone.subtle,
      child: AppFormColumn(
        children: [
          Row(
            children: [
              Icon(
                _editingId == null ? Icons.tune_rounded : Icons.edit_rounded,
                color: colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _editingId == null ? '新增模板' : '编辑模板',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
              if (_editingId != null)
                AppIconActionButton(
                  tooltip: '取消编辑',
                  onPressed: _resetForm,
                  icon: Icons.close_rounded,
                  variant: AppIconActionVariant.outlined,
                ),
            ],
          ),
          AppTextField(
            controller: _nameController,
            labelText: '模板名称',
            prefixIcon: const Icon(Icons.label_outline_rounded),
          ),
          FormDropdown<MoneySplitRuleType>(
            initialSelection: _ruleType,
            label: '模板类型',
            leadingIcon: const Icon(Icons.category_outlined),
            width: double.infinity,
            entries: MoneySplitRuleType.values
                .map(
                  (type) => DropdownMenuEntry(value: type, label: type.label),
                )
                .toList(),
            onSelected: (value) {
              if (value == null) {
                return;
              }
              setState(() => _ruleType = value);
            },
          ),
          AppTextField(
            controller: _configController,
            labelText: '规则配置 JSON',
            prefixIcon: const Icon(Icons.data_object_rounded),
            minLines: 3,
            maxLines: 5,
          ),
          FormDropdown<int>(
            initialSelection: _priorityController.text.trim().isEmpty
                ? 0
                : int.tryParse(_priorityController.text.trim()) ?? 0,
            label: '优先级',
            leadingIcon: const Icon(Icons.low_priority_rounded),
            width: double.infinity,
            entries: const [
              DropdownMenuEntry(value: 0, label: '0'),
              DropdownMenuEntry(value: 1, label: '1'),
              DropdownMenuEntry(value: 2, label: '2'),
              DropdownMenuEntry(value: 3, label: '3'),
              DropdownMenuEntry(value: 4, label: '4'),
              DropdownMenuEntry(value: 5, label: '5'),
            ],
            onSelected: (value) {
              if (value == null) {
                return;
              }
              setState(() => _priorityController.text = value.toString());
            },
          ),
          AppSwitchField(
            title: '启用模板',
            subtitle: '停用后不会出现在选择列表中',
            icon: Icons.toggle_on_rounded,
            value: _isActive,
            onChanged: (value) => setState(() => _isActive = value),
          ),
          if (_errorText != null)
            Text(
              _errorText!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.error,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: AppIconActionButton(
              tooltip: _editingId == null ? '添加模板' : '保存模板',
              onPressed: _submit,
              icon: _editingId == null
                  ? Icons.add_rounded
                  : Icons.check_rounded,
              variant: AppIconActionVariant.filled,
            ),
          ),
        ],
      ),
    );
  }

  void _startEdit(MoneySplitRuleEntity rule) {
    setState(() {
      _editingId = rule.id;
      _nameController.text = rule.name;
      _ruleType = rule.ruleType;
      _configController.text = rule.ruleConfigJson;
      _priorityController.text = rule.priority.toString();
      _isActive = rule.isActive;
      _errorText = null;
    });
  }

  Future<void> _confirmDelete(MoneySplitRuleEntity rule) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: '删除模板',
      message: '确认删除这个分摊模板？',
      confirmLabel: '删除',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed || !mounted) {
      return;
    }

    try {
      await ref
          .read(currentUserMoneySplitActionsProvider)
          .deleteSplitRule(ruleId: rule.id, ledgerId: widget.ledgerId);
      if (_editingId == rule.id && mounted) {
        _resetForm();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorText = '删除模板失败');
    }
  }

  Future<void> _submit() async {
    setState(() => _errorText = null);

    final name = _nameController.text.trim();
    final configJson = _configController.text.trim();
    final priority = int.tryParse(_priorityController.text.trim()) ?? 0;
    if (name.isEmpty) {
      setState(() => _errorText = '请输入模板名称');
      return;
    }
    if (configJson.isEmpty) {
      setState(() => _errorText = '请输入规则配置');
      return;
    }
    try {
      final decoded = jsonDecode(configJson);
      if (decoded is! Map && decoded is! List) {
        throw const FormatException();
      }
    } on FormatException {
      setState(() => _errorText = '规则配置 JSON 不正确');
      return;
    }

    try {
      final actions = ref.read(currentUserMoneySplitActionsProvider);
      if (_editingId == null) {
        await actions.createSplitRule(
          MoneySplitRuleDraft(
            ledgerId: widget.ledgerId,
            name: name,
            ruleType: _ruleType,
            ruleConfigJson: configJson,
            isActive: _isActive,
            priority: priority,
          ),
        );
      } else {
        await actions.updateSplitRule(
          MoneySplitRuleUpdate(
            id: _editingId!,
            name: name,
            ruleType: _ruleType,
            ruleConfigJson: configJson,
            isActive: _isActive,
            priority: priority,
          ),
          ledgerId: widget.ledgerId,
        );
      }
      if (mounted) {
        _resetForm();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorText = '保存模板失败');
    }
  }

  void _resetForm() {
    setState(() {
      _editingId = null;
      _nameController.clear();
      _configController.text = '{}';
      _priorityController.text = '0';
      _ruleType = MoneySplitRuleType.equal;
      _isActive = true;
      _errorText = null;
    });
  }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({
    required this.rule,
    required this.onEdit,
    required this.onDelete,
  });

  final MoneySplitRuleEntity rule;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppSurface(
      tone: AppSurfaceTone.plain,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(
            rule.isActive ? Icons.rule_rounded : Icons.rule_outlined,
            color: rule.isActive ? colorScheme.primary : colorScheme.outline,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rule.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${rule.ruleType.label} · 优先级 ${rule.priority}${rule.isActive ? '' : ' · 已停用'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  rule.ruleConfigJson,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AppIconActionButton(
            tooltip: '编辑模板',
            onPressed: onEdit,
            icon: Icons.edit_rounded,
            variant: AppIconActionVariant.outlined,
          ),
          AppIconActionButton(
            tooltip: '删除模板',
            onPressed: onDelete,
            icon: Icons.delete_outline_rounded,
            variant: AppIconActionVariant.outlined,
          ),
        ],
      ),
    );
  }
}
