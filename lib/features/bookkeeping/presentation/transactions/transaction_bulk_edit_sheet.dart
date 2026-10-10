import 'package:flutter/material.dart';
import 'package:miji/core/presentation/components/app_form_hint.dart';
import 'package:miji/core/presentation/components/app_responsive_dialog.dart';
import 'package:miji/core/presentation/components/app_sliding_segmented_control.dart';
import 'package:miji/core/presentation/components/app_surface.dart';

import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_category_usage.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';
import 'package:miji/features/bookkeeping/presentation/accounts/components/account_selector.dart';
import 'package:miji/features/bookkeeping/presentation/categories/components/category_leaf_selector.dart';
import 'package:miji/features/bookkeeping/presentation/transactions/suggestion_autocomplete_field.dart';

/// 打开「批量修改」面板，返回用户勾选的补丁；取消返回 null。
///
/// 分类 / 账户都用开关控制是否修改：批量场景下最常见的操作是「只改分类」，
/// 如果三个字段都是必填，用户就得先把账户和标签原样再选一遍。
/// 返回值为 null 或 [MoneyTransactionBatchUpdate.isEmpty] 时调用方无需写入。
Future<MoneyTransactionBatchUpdate?> showTransactionBulkEditSheet({
  required BuildContext context,
  required int selectedCount,
  required MoneyTransactionType? type,
  required MoneyCategoryCatalog expenseCatalog,
  required MoneyCategoryCatalog incomeCatalog,
  required MoneyCategoryUsage? usage,
  required List<MoneyAccountEntity> accounts,
  required List<String> tagCandidates,
  required List<String> existingTags,
}) {
  return showAppResponsiveDialog<MoneyTransactionBatchUpdate>(
    context: context,
    expandCompactSheet: true,
    builder: (dialogContext) => _TransactionBulkEditSheet(
      selectedCount: selectedCount,
      type: type,
      expenseCatalog: expenseCatalog,
      incomeCatalog: incomeCatalog,
      usage: usage,
      accounts: accounts,
      tagCandidates: tagCandidates,
      existingTags: existingTags,
    ),
  );
}

class _TransactionBulkEditSheet extends StatefulWidget {
  const _TransactionBulkEditSheet({
    required this.selectedCount,
    required this.type,
    required this.expenseCatalog,
    required this.incomeCatalog,
    required this.usage,
    required this.accounts,
    required this.tagCandidates,
    required this.existingTags,
  });

  final int selectedCount;
  final MoneyTransactionType? type;
  final MoneyCategoryCatalog expenseCatalog;
  final MoneyCategoryCatalog incomeCatalog;
  final MoneyCategoryUsage? usage;
  final List<MoneyAccountEntity> accounts;
  final List<String> tagCandidates;
  final List<String> existingTags;

  @override
  State<_TransactionBulkEditSheet> createState() =>
      _TransactionBulkEditSheetState();
}

class _TransactionBulkEditSheetState extends State<_TransactionBulkEditSheet> {
  late final TextEditingController _tagController;
  late MoneyTransactionType _type;
  bool _changeCategory = false;
  String? _categoryId;
  String? _subCategoryId;
  bool _changeAccount = false;
  String? _accountId;
  final Set<String> _tagsToRemove = <String>{};
  String? _errorText;

  bool get _isMixedType => widget.type == null;

  MoneyCategoryCatalog get _catalog => _type == MoneyTransactionType.income
      ? widget.incomeCatalog
      : widget.expenseCatalog;

  @override
  void initState() {
    super.initState();
    _tagController = TextEditingController();
    _type = widget.type ?? MoneyTransactionType.expense;
  }

  @override
  void dispose() {
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppDialogScaffold(
      title: '批量修改',
      subtitle: '已选 ${widget.selectedCount} 笔',
      maxWidth: 440,
      titleTextAlign: TextAlign.center,
      actionsAlignment: WrapAlignment.center,
      errorText: _errorText,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isMixedType) ...[
              Text(
                '所选流水包含多种类型，分类目录按下面选择的类型给；'
                '只有该类型的流水会被修改。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 8),
              AppSlidingSegmentedControl<MoneyTransactionType>(
                value: _type,
                onChanged: (value) {
                  setState(() {
                    _type = value;
                    _categoryId = null;
                    _subCategoryId = null;
                  });
                },
                segments: const [
                  AppSlidingSegment(
                    value: MoneyTransactionType.expense,
                    label: '支出',
                  ),
                  AppSlidingSegment(
                    value: MoneyTransactionType.income,
                    label: '收入',
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            _ToggleSection(
              title: '修改分类',
              value: _changeCategory,
              onChanged: (value) {
                setState(() {
                  _changeCategory = value;
                  if (!value) {
                    _categoryId = null;
                    _subCategoryId = null;
                  }
                });
              },
              child: CategoryLeafSelector(
                catalog: _catalog,
                selectedCategoryId: _categoryId,
                selectedSubCategoryId: _subCategoryId,
                usage: widget.usage,
                onChanged: (categoryId, subCategoryId) {
                  setState(() {
                    _categoryId = categoryId;
                    _subCategoryId = subCategoryId;
                  });
                },
              ),
            ),
            const SizedBox(height: 10),
            _ToggleSection(
              title: '修改账户',
              value: _changeAccount,
              onChanged: (value) {
                setState(() {
                  _changeAccount = value;
                  if (!value) {
                    _accountId = null;
                  }
                });
              },
              child: AccountSelector(
                accounts: widget.accounts,
                selectedAccountId: _accountId,
                onChanged: (account) {
                  setState(() => _accountId = account?.id);
                },
                labelText: '目标账户',
                emptyText: '暂无可选账户',
                showQuickSelect: true,
              ),
            ),
            const SizedBox(height: 10),
            AppSurface(
              tone: AppSurfaceTone.subtle,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '标签',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SuggestionAutocompleteField(
                    controller: _tagController,
                    suggestions: widget.tagCandidates,
                    labelText: '添加标签',
                    hintText: '留空表示不添加',
                    prefixIcon: const Icon(Icons.local_offer_rounded),
                    textInputAction: TextInputAction.done,
                  ),
                  if (widget.existingTags.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      '移除标签',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final tag in widget.existingTags)
                          FilterChip(
                            label: Text(tag),
                            selected: _tagsToRemove.contains(tag),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _tagsToRemove.add(tag);
                                } else {
                                  _tagsToRemove.remove(tag);
                                }
                              });
                            },
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            const AppFormHint(
              text: '转账与分期入账流水不会参与批量修改',
              icon: Icons.info_outline_rounded,
            ),
          ],
        ),
      ),
      actions: appDialogIconActions(
        onCancel: () => Navigator.of(context).pop(),
        onConfirm: _submit,
        confirmTooltip: '应用',
      ),
    );
  }

  void _submit() {
    final tagsToAdd = _tagController.text.trim();
    final patch = MoneyTransactionBatchUpdate(
      categoryId: _changeCategory ? _categoryId : null,
      subCategoryId: _changeCategory ? _subCategoryId : null,
      accountId: _changeAccount ? _accountId : null,
      tagsToAdd: tagsToAdd.isEmpty ? const <String>[] : <String>[tagsToAdd],
      tagsToRemove: _tagsToRemove.toList(growable: false),
    );

    if (_changeCategory && _categoryId == null) {
      setState(() => _errorText = '请选择要改成的分类');
      return;
    }
    if (_changeAccount && _accountId == null) {
      setState(() => _errorText = '请选择要改成的账户');
      return;
    }
    if (patch.isEmpty) {
      setState(() => _errorText = '请至少选择一项修改');
      return;
    }
    Navigator.of(context).pop(patch);
  }
}

class _ToggleSection extends StatelessWidget {
  const _ToggleSection({
    required this.title,
    required this.value,
    required this.onChanged,
    required this.child,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppSurface(
      tone: AppSurfaceTone.subtle,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: value,
            onChanged: onChanged,
            title: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
          if (value) ...[
            const SizedBox(height: 4),
            child,
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}
