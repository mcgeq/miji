import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/core/presentation/components/app_icon_action_button.dart';
import 'package:miji/core/presentation/components/money_text.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/life_energy/application/life_energy_format.dart';
import 'package:miji/features/life_energy/domain/life_energy_enums.dart';
import 'package:miji/features/life_energy/domain/wishlist_entry.dart';
import 'package:miji/features/life_energy/domain/wishlist_insight.dart';
import 'package:miji/features/life_energy/presentation/wishlist_status_chip.dart';
import 'package:miji/features/life_energy/providers/life_energy_providers.dart';

/// 一件想买的东西，摊开看。
///
/// 为什么需要这一层：卡片上只能放三样东西（名字、代价、状态）。而这件东西
/// 真正值得看的是**它凭什么还留在清单里** —— 三个问题答成什么样、当初为什么
/// 想买、加了多久、冷却还剩几天。挤在列表行里全是灰字，摊开才读得下去。
///
/// 操作也放在这里：买了 / 放弃是**决定**，决定之前应该先看见全部信息，而不是
/// 在列表上长按弹一个菜单。
Future<void> showWishlistDetailSheet(
  BuildContext context, {
  required WishlistEntry entry,
  required WishlistInsight? insight,
  required ValueChanged<WishlistItemStatus> onSettle,
  required VoidCallback onEdit,
  required VoidCallback onDelete,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    // 带刘海/挖孔的手机上，不设这个高度够的时候面板会顶进状态栏。
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => _WishlistDetail(
      entry: entry,
      insight: insight,
      onSettle: onSettle,
      onEdit: onEdit,
      onDelete: onDelete,
    ),
  );
}

class _WishlistDetail extends ConsumerWidget {
  const _WishlistDetail({
    required this.entry,
    required this.insight,
    required this.onSettle,
    required this.onEdit,
    required this.onDelete,
  });

  final WishlistEntry entry;
  final WishlistInsight? insight;
  final ValueChanged<WishlistItemStatus> onSettle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final masked = MoneyPrivacy.of(context);
    final profile = ref.watch(currentWorkProfileProvider).asData?.value;
    final now = ref.watch(lifeEnergyClockProvider)();
    final status = entry.statusAt(now);
    final days = profile == null ? null : entry.daysFor(profile);
    final hours = profile == null ? null : entry.hoursFor(profile);
    final wageLine = profile == null
        ? null
        : '按 ${now.month} 月 ${formatLifeEnergyWage(profile.hourlyWageMinor, profile.currencyCode)} / 小时';
    final currency = profile?.currencyCode ?? 'CNY';
    final settled = status.isSettled;

    String dayText() {
      if (masked) {
        return '••••';
      }
      if (days == null) {
        return '先填收入与工时';
      }
      return '${formatLifeEnergyWorkdays(days)} 个工作日';
    }

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${entry.desire.label} · '
                        '${masked ? '••••' : formatMoneyMinor(entry.targetAmountMinor, currency)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                WishlistStatusChip(status: status, entry: entry, now: now),
              ],
            ),
            const SizedBox(height: 14),
            // 代价：这一页的主角，字号最大。
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  dayText(),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                if (hours != null && !masked) ...[
                  const SizedBox(width: 8),
                  Text(
                    '≈ ${formatLifeEnergyHours(hours)} 小时',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ],
            ),
            if (days != null && wageLine != null) ...[
              const SizedBox(height: 2),
              Text(
                wageLine,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  letterSpacing: 0,
                ),
              ),
            ],
            if (entry.transactionId != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '已记入流水',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ],
            if ((insight?.totalWorkdays ?? 0) > 0 && days != null) ...[
              const SizedBox(height: 2),
              Text(
                '占清单合计 '
                '${_sharePercent(days, insight?.totalWorkdays ?? 0)}%',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  letterSpacing: 0,
                ),
              ),
            ],
            const SizedBox(height: 16),
            _Section(
              title: '三个问题',
              // 答「否」不算淘汰：三个问题全否也照样留在清单里，这里只把
              // 当初的想法摆出来给现在的自己看。
              trailing: '答了 ${entry.answeredQuestionCount}/3',
              children: [
                for (var i = 0; i < wishlistQuestions.length; i++)
                  _QuestionRow(
                    text: wishlistQuestions[i],
                    answer: entry.questionAnswers[i],
                  ),
              ],
            ),
            if ((entry.notes ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              _Section(
                title: '当时记的一句话',
                children: [
                  Text(
                    entry.notes!.trim(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            Text(
              _timeline(now, status),
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                letterSpacing: 0,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            if (!settled) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        onSettle(WishlistItemStatus.dropped);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.onSurfaceVariant,
                      ),
                      child: const Text('放弃'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        onSettle(WishlistItemStatus.bought);
                      },
                      child: const Text('买了'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                status == WishlistItemStatus.waiting
                    ? '还在冷却期里，但决定权在你 —— 冷却只是让「立刻想要」'
                          '多经过一道时间。'
                    : '放弃不写任何账，只从清单里拿掉。',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  letterSpacing: 0,
                  height: 1.5,
                ),
              ),
            ] else
              Text(
                '已经${status.label}。想改回来就再编辑一次。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  letterSpacing: 0,
                ),
              ),
            const SizedBox(height: 10),
            // 编辑 / 删除用图标：这两个是工具性操作，文字按钮会把注意力从
            // 「买了 / 放弃」那两颗按不动的决定上抢走。
            Row(
              children: [
                AppIconActionButton(
                  tooltip: '编辑',
                  icon: Icons.edit_outlined,
                  variant: AppIconActionVariant.outlined,
                  onPressed: () {
                    Navigator.of(context).pop();
                    onEdit();
                  },
                ),
                const SizedBox(width: 8),
                AppIconActionButton(
                  tooltip: '删除',
                  variant: AppIconActionVariant.outlined,
                  child: Icon(
                    Icons.delete_outline_rounded,
                    color: colorScheme.error,
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    onDelete();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 加入 → 冷却到期 的时间线。不写「已等待 3 天」，写具体日期。
  String _timeline(DateTime now, WishlistItemStatus status) {
    final added =
        '${entry.createdAt.year} 年 ${entry.createdAt.month} 月 '
        '${entry.createdAt.day} 日加入';
    final deadline = entry.cooldownUntil;
    if (status.isSettled) {
      final decided = entry.decidedAt;
      if (decided == null) {
        return added;
      }
      return '$added · ${decided.month} 月 ${decided.day} 日${status.label}';
    }
    if (deadline == null) {
      return '$added · 没设冷却，随时可以决定';
    }
    if (status == WishlistItemStatus.waiting) {
      return '$added · 冷却到 ${deadline.year} 年 ${deadline.month} 月 '
          '${deadline.day} 日（还有 ${entry.cooldownDaysLeft(now)} 天）';
    }
    return '$added · 冷却已于 ${deadline.month} 月 ${deadline.day} 日结束';
  }
}

/// 这件东西占整张清单的百分之几（四舍五入到整数，最低 1）。
int _sharePercent(double days, double totalDays) {
  if (totalDays <= 0) {
    return 0;
  }
  final percent = (days / totalDays * 100).round();
  return percent.clamp(1, 100);
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children, this.trailing});

  final String title;
  final String? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
            if (trailing != null) ...[
              const Spacer(),
              Text(
                trailing!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  letterSpacing: 0,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }
}

/// 一个问题 + 它的答案。三态：是 / 否 / 还没答。
class _QuestionRow extends StatelessWidget {
  const _QuestionRow({required this.text, required this.answer});

  final String text;
  final bool? answer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final money = theme.moneyColors;
    final (label, fg, bg) = switch (answer) {
      true => ('是', money.incomeStrong, money.incomeContainer),
      false => (
        '否',
        colorScheme.onSurfaceVariant,
        colorScheme.surfaceContainerHigh,
      ),
      null => (
        '没答',
        colorScheme.onSurfaceVariant,
        colorScheme.surfaceContainerHighest,
      ),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.4,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: fg,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
