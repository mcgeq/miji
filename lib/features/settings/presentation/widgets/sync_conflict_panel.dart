import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/core/presentation/app_page_layout.dart';
import 'package:miji/core/presentation/components/app_list_item.dart';
import 'package:miji/core/presentation/components/app_responsive_dialog.dart';
import 'package:miji/core/sync/delta_sync/delta_conflict_models.dart';
import 'package:miji/core/sync/delta_sync/delta_conflict_resolver.dart';
import 'package:miji/core/sync/delta_sync/delta_conflict_store.dart';
import 'package:miji/core/sync/delta_sync/delta_sync_providers.dart';
import 'package:miji/core/sync/delta_sync/sync_change_logger.dart';
import 'package:miji/core/sync/background_sync/background_sync_dispatcher.dart';
import 'package:miji/core/sync/background_sync/background_sync_providers.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';

class SyncConflictPanel extends ConsumerWidget {
  const SyncConflictPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conflicts = ref.watch(currentUserOpenDeltaConflictsProvider);

    return AppDialogScaffold(
      title: '同步冲突',
      titleTextAlign: TextAlign.center,
      maxWidth: 500,
      body: SizedBox(
        width: 460,
        child: conflicts.when(
          data: (items) => _ConflictList(conflicts: items),
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stackTrace) => AppErrorState(
            title: '同步冲突读取失败',
            onRetry: () =>
                ref.invalidate(currentUserOpenDeltaConflictsProvider),
          ),
        ),
      ),
      actionsAlignment: WrapAlignment.center,
      actions: appDialogIconActions(
        onCancel: () => Navigator.of(context).pop(),
        onConfirm: () => Navigator.of(context).pop(),
        cancelTooltip: '关闭',
        confirmTooltip: '完成',
      ),
    );
  }
}

class _ConflictList extends StatelessWidget {
  const _ConflictList({required this.conflicts});

  final List<StoredDeltaConflict> conflicts;

  @override
  Widget build(BuildContext context) {
    if (conflicts.isEmpty) {
      return const AppEmptyState(
        title: '暂无同步冲突',
        message: '当两台设备修改同一条记录时，这里会显示需要人工处理的冲突。',
        icon: Icons.task_alt_rounded,
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 420),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: conflicts.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          return _ConflictTile(conflict: conflicts[index]);
        },
      ),
    );
  }
}

class _ConflictTile extends StatelessWidget {
  const _ConflictTile({required this.conflict});

  final StoredDeltaConflict conflict;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final groups = _groupsForConflict(conflict);
    final changedFields = conflict.remoteChange.changedFields.keys.join('、');

    return AppListItemPanel(
      onTap: () => showAppResponsiveDialog<void>(
        context: context,
        builder: (_) => _ConflictDetailDialog(conflict: conflict),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppListItemIcon(
            icon: Icons.merge_type_rounded,
            color: colorScheme.tertiary,
            size: 36,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${conflict.tableName} · ${conflict.recordId}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _fieldGroupText(groups),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
                if (changedFields.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '远端字段：$changedFields',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConflictDetailDialog extends ConsumerStatefulWidget {
  const _ConflictDetailDialog({required this.conflict});

  final StoredDeltaConflict conflict;

  @override
  ConsumerState<_ConflictDetailDialog> createState() =>
      _ConflictDetailDialogState();
}

class _ConflictDetailDialogState extends ConsumerState<_ConflictDetailDialog> {
  late final Map<TransactionConflictFieldGroup, DeltaConflictSide> _choices;
  bool _saving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _choices = {
      for (final group in _groupsForConflict(widget.conflict))
        group: DeltaConflictSide.local,
    };
  }

  @override
  Widget build(BuildContext context) {
    return AppDialogScaffold(
      title: '处理冲突',
      subtitle: '${widget.conflict.tableName} · ${widget.conflict.recordId}',
      titleTextAlign: TextAlign.center,
      maxWidth: 620,
      body: SizedBox(
        width: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_errorText != null) ...[
              _ConflictResolveErrorBanner(message: _errorText!),
              const SizedBox(height: 10),
            ],
            for (final group in _groupsForConflict(widget.conflict)) ...[
              _ConflictFieldGroupCard(
                group: group,
                conflict: widget.conflict,
                choice: _choices[group] ?? DeltaConflictSide.local,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _choices[group] = value),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
      actionsAlignment: WrapAlignment.center,
      actions: appDialogIconActions(
        onCancel: _saving ? () {} : () => Navigator.of(context).pop(),
        onConfirm: _saving ? null : _resolve,
        cancelTooltip: '取消',
        confirmTooltip: '确认',
      ),
    );
  }

  Future<void> _resolve() async {
    setState(() {
      _saving = true;
      _errorText = null;
    });
    try {
      final identity = await ref
          .read(syncIdentityResolverProvider)
          .readIdentity();
      final service = ref.read(moneyDeltaConflictApplyServiceProvider);
      if (widget.conflict.tableName ==
          SyncChangeLogger.moneyTransactionsTableName) {
        await service.applyTransactionConflict(
          conflict: widget.conflict,
          deviceId: identity.deviceId,
          choices: _choices.entries
              .map(
                (entry) => DeltaConflictFieldChoice(
                  group: entry.key,
                  side: entry.value,
                ),
              )
              .toList(growable: false),
        );
      } else {
        await service.applyRecordConflict(
          conflict: widget.conflict,
          deviceId: identity.deviceId,
          side: _choices.values.first,
        );
      }
      ref.invalidate(currentUserOpenDeltaConflictsProvider);
      if (mounted) {
        Navigator.of(context).pop();
      }
      unawaited(
        ref.read(backgroundSyncTriggerProvider)(
          BackgroundSyncReason.conflictResolved,
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _errorText = '冲突处理失败，请检查字段选择后重试');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}

class _ConflictResolveErrorBanner extends StatelessWidget {
  const _ConflictResolveErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: colorScheme.onErrorContainer,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConflictFieldGroupCard extends StatelessWidget {
  const _ConflictFieldGroupCard({
    required this.group,
    required this.conflict,
    required this.choice,
    required this.onChanged,
  });

  final TransactionConflictFieldGroup group;
  final StoredDeltaConflict conflict;
  final DeltaConflictSide choice;
  final ValueChanged<DeltaConflictSide>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final fields = _fieldsForGroup(group, conflict.remoteChange.changedFields);
    final supportsRemoteChoice = _supportsRemoteChoice(group);

    return AppListItemPanel(
      padding: const EdgeInsets.all(12),
      backgroundColor: colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.38,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _fieldGroupLabel(group),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
              if (supportsRemoteChoice)
                SegmentedButton<DeltaConflictSide>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  segments: const [
                    ButtonSegment(
                      value: DeltaConflictSide.local,
                      label: Text('本地'),
                    ),
                    ButtonSegment(
                      value: DeltaConflictSide.remote,
                      label: Text('远端'),
                    ),
                  ],
                  selected: {choice},
                  onSelectionChanged: onChanged == null
                      ? null
                      : (values) => onChanged!(values.single),
                )
              else
                Text(
                  '暂不支持远端应用',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          for (final field in fields) ...[
            _ConflictFieldCompareRow(
              field: field,
              localValue: conflict.localSnapshot[field],
              remoteValue: conflict.remoteChange.changedFields[field],
              remoteLabel: supportsRemoteChoice ? '远端' : '云端值',
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _ConflictFieldCompareRow extends StatelessWidget {
  const _ConflictFieldCompareRow({
    required this.field,
    required this.localValue,
    required this.remoteValue,
    this.remoteLabel = '远端',
  });

  final String field;
  final Object? localValue;
  final Object? remoteValue;
  final String remoteLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          field,
          style: theme.textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: _ConflictValuePill(label: '本地', value: localValue),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ConflictValuePill(label: remoteLabel, value: remoteValue),
            ),
          ],
        ),
      ],
    );
  }
}

class _ConflictValuePill extends StatelessWidget {
  const _ConflictValuePill({required this.label, required this.value});

  final String label;
  final Object? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.42),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              _valueText(value),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

bool _supportsRemoteChoice(TransactionConflictFieldGroup group) {
  return switch (group) {
    TransactionConflictFieldGroup.record ||
    TransactionConflictFieldGroup.basic ||
    TransactionConflictFieldGroup.account ||
    TransactionConflictFieldGroup.category ||
    TransactionConflictFieldGroup.text => true,
    TransactionConflictFieldGroup.ledger ||
    TransactionConflictFieldGroup.split ||
    TransactionConflictFieldGroup.installment ||
    TransactionConflictFieldGroup.deleteState => false,
  };
}

String _fieldGroupText(Set<TransactionConflictFieldGroup> groups) {
  if (groups.isEmpty) {
    return '记录整体';
  }
  return groups.map(_fieldGroupLabel).join('、');
}

Set<TransactionConflictFieldGroup> _groupsForConflict(
  StoredDeltaConflict conflict,
) {
  if (conflict.fieldGroups.isNotEmpty) {
    return conflict.fieldGroups;
  }
  if (conflict.tableName == SyncChangeLogger.moneyTransactionsTableName) {
    return conflict.fieldGroups;
  }
  return const <TransactionConflictFieldGroup>{
    TransactionConflictFieldGroup.record,
  };
}

List<String> _fieldsForGroup(
  TransactionConflictFieldGroup group,
  Map<String, Object?> changedFields,
) {
  if (group == TransactionConflictFieldGroup.record) {
    return changedFields.keys.toList(growable: false);
  }
  final classifier = const TransactionConflictFieldClassifier();
  return changedFields.keys
      .where((field) => classifier.classify([field]).contains(group))
      .toList(growable: false);
}

String _valueText(Object? value) {
  if (value == null) {
    return '空';
  }
  if (value is DateTime) {
    return value.toLocal().toString();
  }
  return value.toString();
}

String _fieldGroupLabel(TransactionConflictFieldGroup group) {
  return switch (group) {
    TransactionConflictFieldGroup.record => '记录整体',
    TransactionConflictFieldGroup.basic => '基础信息',
    TransactionConflictFieldGroup.account => '账户',
    TransactionConflictFieldGroup.category => '分类',
    TransactionConflictFieldGroup.ledger => '账本',
    TransactionConflictFieldGroup.split => '分摊',
    TransactionConflictFieldGroup.installment => '分期',
    TransactionConflictFieldGroup.text => '备注',
    TransactionConflictFieldGroup.deleteState => '删除状态',
  };
}
