import 'package:flutter/material.dart';

import 'package:miji/core/presentation/components/app_surface.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/features/home/application/home_money_dashboard_models.dart';

/// 首页洞察列表。
///
/// 每条只讲一件事，自带语气色与图标；可跳转的条目右侧给出动作与箭头，
/// 让「看懂了」能直接变成「去看一眼」。
class HomeInsightStrip extends StatelessWidget {
  const HomeInsightStrip({
    super.key,
    required this.insight,
    this.onSelectTarget,
  });

  final HomeInsight? insight;
  final ValueChanged<HomeInsightTarget>? onSelectTarget;

  @override
  Widget build(BuildContext context) {
    final insight = this.insight;
    if (insight == null || insight.isEmpty) {
      return const SizedBox.shrink();
    }

    final items = insight.items;

    return AppSurface(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < items.length; index++) ...[
            _InsightRow(
              item: items[index],
              onTap: items[index].target == null || onSelectTarget == null
                  ? null
                  : () => onSelectTarget!(items[index].target!),
            ),
            if (index != items.length - 1)
              Divider(
                height: 1,
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.34),
              ),
          ],
        ],
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({required this.item, required this.onTap});

  final HomeInsightItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _toneColor(theme, item.tone);
    final actionLabel = item.actionLabel;

    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(_kindIcon(item.kind), size: 15, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  for (final segment in item.segments)
                    TextSpan(
                      text: segment.text,
                      style: segment.emphasis
                          ? TextStyle(color: color, fontWeight: FontWeight.w900)
                          : null,
                    ),
                ],
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w700,
                height: 1.45,
                letterSpacing: 0,
              ),
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(width: 8),
            Text(
              actionLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 16, color: color),
          ],
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }

    return Semantics(
      button: true,
      label: '${item.plainText} $actionLabel',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: content,
        ),
      ),
    );
  }

  IconData _kindIcon(HomeInsightKind kind) {
    return switch (kind) {
      HomeInsightKind.budgetExceeded => Icons.warning_amber_rounded,
      HomeInsightKind.budgetPace => Icons.speed_rounded,
      HomeInsightKind.spendingVsAverage => Icons.insights_rounded,
      HomeInsightKind.noSpendingToday => Icons.edit_calendar_outlined,
      HomeInsightKind.topCategory => Icons.donut_small_rounded,
    };
  }

  Color _toneColor(ThemeData theme, HomeInsightTone tone) {
    return switch (tone) {
      HomeInsightTone.danger => theme.colorScheme.error,
      HomeInsightTone.warning => theme.moneyColors.warning,
      HomeInsightTone.positive => theme.moneyColors.success,
      HomeInsightTone.neutral => theme.colorScheme.onSurfaceVariant,
    };
  }
}
