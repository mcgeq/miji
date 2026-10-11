import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/core/presentation/components/app_confirm_dialog.dart';
import 'package:miji/features/gtd/domain/checkin_models.dart';
import 'package:miji/features/gtd/providers/checkin_providers.dart';

/// 展示一条打卡记录的详情，支持删除。
Future<void> showCheckinRecordDetailSheet(
  BuildContext context,
  WidgetRef ref,
  CheckinRecord record,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => _RecordDetailSheet(record: record),
  );
}

class _RecordDetailSheet extends ConsumerStatefulWidget {
  const _RecordDetailSheet({required this.record});

  final CheckinRecord record;

  @override
  ConsumerState<_RecordDetailSheet> createState() => _RecordDetailSheetState();
}

class _RecordDetailSheetState extends ConsumerState<_RecordDetailSheet> {
  bool _deleting = false;

  Future<void> _delete() async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: '删除打卡记录',
      message: '删除后无法恢复，确认删除这条打卡记录？',
      confirmLabel: '删除',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed || !mounted) return;

    setState(() => _deleting = true);
    try {
      await ref.read(checkinRepositoryProvider).deleteRecord(widget.record.id);
      if (!mounted) return;
      invalidateCheckinData(ref);
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final record = widget.record;
    final plan = record.plan;

    final detailLines = <String>[
      '时间：${_formatDateTime(record.completedAt)}',
      if (plan != null && plan.targetUnit == '分钟')
        '时长：${_formatDuration(record.durationSeconds)}'
      else if (record.count > 1 || plan == null)
        '数量：${record.count} ${plan?.targetUnit ?? '次'}',
    ];

    final checkinTimes = _checkinTimes(record);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(plan?.icon ?? '📌', style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    plan?.name ?? '未知计划',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            for (final line in detailLines)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  line,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (checkinTimes.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '打卡时间：${checkinTimes.join(' · ')}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (record.notes != null && record.notes!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('备注：${record.notes}', style: theme.textTheme.bodyMedium),
            ],
            if (record.mood != null) ...[
              const SizedBox(height: 6),
              Text(
                '心情：${_moodLabel(record.mood!)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (record.photos.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                '照片（${record.photos.length}）',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: record.photos
                    .map(
                      (photo) => ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          File(photo.localPath),
                          width: 96,
                          height: 96,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            width: 96,
                            height: 96,
                            color: colorScheme.surfaceContainerHighest,
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: colorScheme.outline,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _deleting ? null : _delete,
              icon: Icon(
                Icons.delete_outline_rounded,
                color: _deleting ? null : colorScheme.error,
              ),
              label: Text(
                _deleting ? '删除中…' : '删除这条记录',
                style: TextStyle(color: _deleting ? null : colorScheme.error),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.error,
                side: BorderSide(
                  color: colorScheme.error.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _checkinTimes(CheckinRecord record) {
    if (record.extraJson == null || record.extraJson!.isEmpty) {
      return const [];
    }
    try {
      final map = jsonDecode(record.extraJson!) as Map<String, dynamic>;
      final times = (map['checkinTimes'] as List?)?.cast<String>();
      if (times == null || times.isEmpty) return const [];
      return times
          .map((t) {
            final parsed = DateTime.tryParse(t);
            return parsed == null ? null : _formatTime(parsed.toLocal());
          })
          .whereType<String>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  String _formatTime(DateTime t) {
    final hour = t.hour.toString().padLeft(2, '0');
    final minute = t.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatDateTime(DateTime t) {
    final local = t.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day ${_formatTime(local)}';
  }

  String _formatDuration(int? seconds) {
    final total = seconds ?? 0;
    final minutes = total ~/ 60;
    if (minutes < 60) return '$minutes 分钟';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '$hours 小时' : '$hours 小时 $rest 分钟';
  }

  String _moodLabel(int mood) {
    return switch (mood) {
      1 => '😀',
      2 => '😐',
      3 => '😔',
      _ => '😀',
    };
  }
}
