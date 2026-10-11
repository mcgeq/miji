import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fluttertoast/fluttertoast.dart';

import 'package:miji/core/presentation/app_page_layout.dart';
import 'package:miji/core/presentation/app_toast.dart';
import 'package:miji/core/presentation/components/app_icon_action_button.dart';
import 'package:miji/core/presentation/components/app_list_item.dart';
import 'package:miji/core/presentation/components/app_skeleton.dart';
import 'package:miji/core/presentation/components/money_text.dart';
import 'package:miji/core/presentation/components/app_responsive_dialog.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/features/bookkeeping/application/auto_posting_conflict_ignore_store.dart';
import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/domain/money_auto_posting_conflict_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_repository.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';

/// 处置「同一笔还款登记了两遍」的冲突。
///
/// 每一行只有一个主出口：交给分期独占。没有「交给自动记账」的选项——
/// 分期还款必须走分期引擎，它才知道本金是多少、要释放多少冻结额度；
/// 换成自动记账来记，信用卡可用额度会永久错掉。
class AutoPostingConflictSheet extends ConsumerStatefulWidget {
  const AutoPostingConflictSheet({super.key});

  @override
  ConsumerState<AutoPostingConflictSheet> createState() =>
      _AutoPostingConflictSheetState();
}

class _AutoPostingConflictSheetState
    extends ConsumerState<AutoPostingConflictSheet> {
  final _busyKeys = <String>{};
  FToast? _toast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final conflicts = ref.watch(
      currentUserAutoPostingInstallmentConflictsProvider,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '重复登记的还款',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ),
            AppIconActionButton(
              tooltip: '重新检测',
              icon: Icons.refresh_rounded,
              onPressed: () => ref.invalidate(
                currentUserAutoPostingInstallmentConflictsProvider,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '同一笔还款既登记成分期期次、又登记成自动记账模板时，到期当天会记两遍账，'
          '预算额度也会被占两次。分期自带本金与利息拆分，还款一律交给分期来记。',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: conflicts.when(
            data: (items) {
              if (items.isEmpty) {
                return const AppEmptyState(
                  title: '没有重复登记',
                  message: '自动记账模板与分期计划之间没有冲突。',
                  icon: Icons.check_circle_outline_rounded,
                );
              }
              return ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 12),
                itemCount: items.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 10),
                itemBuilder: (context, index) => _ConflictCard(
                  conflict: items[index],
                  busy: _busyKeys.contains(items[index].conflictKey),
                  onTakeOver: () => _takeOver(items[index]),
                  onIgnore: () => _ignore(items[index]),
                ),
              );
            },
            loading: () => const AppSkeletonList(),
            error: (error, stackTrace) => AppErrorState(
              title: '读取冲突失败',
              onRetry: () => ref.invalidate(
                currentUserAutoPostingInstallmentConflictsProvider,
              ),
            ),
          ),
        ),
        _IgnoredConflictsFooter(),
      ],
    );
  }

  Future<void> _takeOver(MoneyAutoPostingInstallmentConflict conflict) async {
    setState(() => _busyKeys.add(conflict.conflictKey));
    try {
      await ref
          .read(currentUserMoneyAutoPostingActionsProvider)
          .takeOverByInstallment(conflict.templateId, conflict.planId);
      if (!mounted) return;
      AppToast.success(
        _ensureToast(),
        context,
        '已交给分期「${conflict.planName}」记账，模板停用',
      );
    } catch (error) {
      if (!mounted) return;
      AppToast.error(_ensureToast(), context, _errorText(error));
    } finally {
      if (mounted) {
        setState(() => _busyKeys.remove(conflict.conflictKey));
      }
    }
  }

  Future<void> _ignore(MoneyAutoPostingInstallmentConflict conflict) async {
    await ref
        .read(autoPostingConflictIgnoreProvider.notifier)
        .ignore(conflict.conflictKey);
    if (!mounted) return;
    AppToast.success(_ensureToast(), context, '已标记为两笔不同支出');
  }

  FToast _ensureToast() {
    return _toast ??= (FToast()..init(context));
  }

  String _errorText(Object error) {
    if (error is MoneyRepositoryException) {
      return switch (error.code) {
        MoneyRepositoryErrorCode.installmentPlanNotFound => '分期计划不可用',
        MoneyRepositoryErrorCode.invalidInstallmentTakeOver => '币种不一致，无法交给该分期',
        MoneyRepositoryErrorCode.autoPostingTemplateNotFound => '模板不可用',
        MoneyRepositoryErrorCode.databaseWriteFailed => '保存失败',
        _ => '操作失败',
      };
    }
    return '操作失败';
  }
}

/// 被忽略的冲突给一个回来的路：误点「两笔不同支出」不应该不可逆。
class _IgnoredConflictsFooter extends ConsumerWidget {
  const _IgnoredConflictsFooter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ignored =
        ref.watch(autoPostingConflictIgnoreProvider).value ?? const <String>{};
    if (ignored.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '已忽略 ${ignored.length} 处，不再提示',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                letterSpacing: 0,
              ),
            ),
          ),
          TextButton(
            onPressed: () =>
                ref.read(autoPostingConflictIgnoreProvider.notifier).clear(),
            child: const Text('恢复提示', style: TextStyle(letterSpacing: 0)),
          ),
        ],
      ),
    );
  }
}

class _ConflictCard extends StatelessWidget {
  const _ConflictCard({
    required this.conflict,
    required this.busy,
    required this.onTakeOver,
    required this.onIgnore,
  });

  final MoneyAutoPostingInstallmentConflict conflict;
  final bool busy;
  final VoidCallback onTakeOver;
  final VoidCallback onIgnore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final radiusTokens = theme.radiusTokens;

    return AppListItemPanel(
      padding: const EdgeInsets.all(12),
      backgroundColor: colorScheme.errorContainer.withValues(alpha: 0.28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 18,
                color: colorScheme.error,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '可能记两遍账',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.error,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _ConflictLine(
            icon: Icons.event_repeat_rounded,
            label: '自动记账',
            title: conflict.templateName,
            trailing: maskedMoneyOr(
              formatMoneyMinor(
                conflict.templateAmountMinor,
                conflict.currencyCode,
              ),
              MoneyPrivacy.of(context),
            ),
          ),
          const SizedBox(height: 6),
          _ConflictLine(
            icon: Icons.credit_card_rounded,
            label: '分期第${conflict.periodNumber}期',
            title: conflict.planName,
            trailing: maskedMoneyOr(
              formatMoneyMinor(
                conflict.detailAmountMinor,
                conflict.currencyCode,
              ),
              MoneyPrivacy.of(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${_dateText(conflict.dueDate)} · ${conflict.kind.label}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: busy ? null : onTakeOver,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(radiusTokens.md),
                    ),
                  ),
                  child: Text(
                    busy ? '处理中…' : '改由分期入账',
                    style: const TextStyle(letterSpacing: 0),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: busy ? null : onIgnore,
                child: const Text('两笔不同支出', style: TextStyle(letterSpacing: 0)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _dateText(DateTime date) {
    return '${date.year}年${date.month}月${date.day}日';
  }
}

class _ConflictLine extends StatelessWidget {
  const _ConflictLine({
    required this.icon,
    required this.label,
    required this.title,
    required this.trailing,
  });

  final IconData icon;
  final String label;
  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ),
        Text(
          trailing,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

Future<void> showAutoPostingConflictSheet(BuildContext context) {
  return showAppResponsiveDialog<void>(
    context: context,
    expandCompactSheet: true,
    builder: (context) => const AutoPostingConflictSheet(),
  );
}
