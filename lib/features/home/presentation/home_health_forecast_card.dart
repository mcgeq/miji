import 'package:flutter/material.dart';

import 'package:miji/core/presentation/components/app_surface.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/features/health/domain/health_cycle_phase.dart';
import 'package:miji/features/health/presentation/health_theme.dart';
import 'package:miji/features/home/application/home_health_forecast_providers.dart';

/// 「未来 7 天」预测条。
///
/// 原来每个日期下面挂一个 26px 的圆角色块表示经期 / 易孕 / PMS，三个问题：
/// 色块和日期是两块要对照着读的东西；色块里没有字，四种状态有三种只能反查图例；
/// 图例又是固定三条，「这 7 天根本没有 PMS」也照样挂着 PMS。
///
/// 现在把状态画在**日期格本身**上（沿用健康月历的写法：阶段淡底 + 阶段色字），
/// 日期下面不再有任何色块；底部换成**带日期的区间摘要**——
/// 「经期 10/14–15 · 易孕 10/16–17」，且只列这 7 天里真正存在的状态。
///
/// 颜色全部走 [HealthPalette]（不是 `colorScheme.error` / `moneyColors`）：
/// 这是**健康**域的状态，之前拿记账的语义红当经期色、拿警告黄当 PMS 色，
/// 跟健康页/日历页的经期粉、经前紫对不上。
class HomeHealthForecastCard extends StatelessWidget {
  const HomeHealthForecastCard({
    super.key,
    required this.forecast,
    required this.onOpenHealth,
  });

  final HomeHealthForecast forecast;
  final VoidCallback onOpenHealth;

  static const _weekdays = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = forecast.days;
    if (days.isEmpty) {
      return const SizedBox.shrink();
    }
    final runs = _buildRuns(days);
    final today = days.first.date;

    return AppSurface(
      onTap: onOpenHealth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                '📅 未来 7 天',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '查看健康 ›',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < days.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: _ForecastCell(
                    day: days[i],
                    isToday: days[i].date == today,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          if (runs.isEmpty)
            Text(
              '未来 7 天暂无经期 / 易孕期预测',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            )
          else
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [for (final run in runs) _RunLegend(run: run)],
            ),
        ],
      ),
    );
  }
}

/// 把连续的同状态日期合并成一段。
///
/// 逐日列表说不出「14 到 15 号是经期」这件事 —— 用户得自己数格子。
/// 合并之后摘要既能当天数用，也不会出现「3 个格子写 3 遍经期」。
List<_KindRun> _buildRuns(List<HomeForecastDay> days) {
  final runs = <_KindRun>[];
  for (final day in days) {
    if (day.kind == HomeForecastKind.normal) {
      continue;
    }
    final last = runs.isEmpty ? null : runs.last;
    if (last != null &&
        last.kind == day.kind &&
        _isNextDay(last.end, day.date)) {
      runs[runs.length - 1] = _KindRun(
        kind: last.kind,
        start: last.start,
        end: day.date,
      );
    } else {
      runs.add(_KindRun(kind: day.kind, start: day.date, end: day.date));
    }
  }
  return runs;
}

/// 次日判定用「日历日 +1」而不是 `difference().inDays == 1`：
/// 本地时区跨夏令时那一晚只有 23 小时，`inDays` 会算成 0，区间就被切断了。
bool _isNextDay(DateTime previous, DateTime next) {
  final expected = DateTime(previous.year, previous.month, previous.day + 1);
  return next.year == expected.year &&
      next.month == expected.month &&
      next.day == expected.day;
}

/// 一段连续的同状态区间。
class _KindRun {
  const _KindRun({required this.kind, required this.start, required this.end});

  final HomeForecastKind kind;
  final DateTime start;
  final DateTime end;

  String get label => switch (kind) {
    HomeForecastKind.period => '经期',
    HomeForecastKind.fertile => '易孕',
    HomeForecastKind.pms => 'PMS',
    HomeForecastKind.normal => '',
  };

  /// `10/14`（单天）/ `10/14–15`（同月）/ `10/30–11/1`（跨月）。
  /// 窗口只有 7 天，省略年份不会歧义；跨月时才把月份补上。
  String get rangeLabel {
    if (start.year == end.year && start.month == end.month) {
      if (start.day == end.day) {
        return '${start.month}/${start.day}';
      }
      return '${start.month}/${start.day}–${end.day}';
    }
    return '${start.month}/${start.day}–${end.month}/${end.day}';
  }
}

/// 日期格：状态直接画在格子上，格子下面不放任何东西。
class _ForecastCell extends StatelessWidget {
  const _ForecastCell({required this.day, required this.isToday});

  final HomeForecastDay day;
  final bool isToday;

  static const _height = 40.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final palette = HealthPalette.of(context);
    final phase = day.kind.phase;
    final label = day.kind.accessibleLabel;

    return Semantics(
      label: '${day.date.month}月${day.date.day}日 $label',
      excludeSemantics: true,
      child: Column(
        children: [
          Text(
            isToday
                ? '今天'
                : '周${HomeHealthForecastCard._weekdays[day.date.weekday - 1]}',
            maxLines: 1,
            style: theme.textTheme.labelSmall?.copyWith(
              color: isToday
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
              fontWeight: isToday ? FontWeight.w900 : FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: _height,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: phase == null ? null : palette.phaseSurface(phase),
              borderRadius: BorderRadius.circular(theme.radiusTokens.md),
              // 今天只加一圈描边，不填色：填色会被误读成「今天有预测」。
              border: isToday
                  ? Border.all(color: colorScheme.primary, width: 2)
                  : null,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${day.date.day}',
                maxLines: 1,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontSize: 13.5,
                  color: phase == null
                      ? colorScheme.onSurfaceVariant
                      : palette.phaseInk(phase),
                  fontWeight: phase == null ? FontWeight.w700 : FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 摘要项：「● 经期 10/14–15」。
class _RunLegend extends StatelessWidget {
  const _RunLegend({required this.run});

  final _KindRun run;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = HealthPalette.of(context);
    final phase = run.kind.phase;
    // 圆点用本色（对应日期格的淡底来源），文字用文字档（对应格子里那个数字）。
    final dot = phase == null
        ? theme.colorScheme.outline
        : palette.phase(phase);
    final ink = phase == null
        ? theme.colorScheme.onSurfaceVariant
        : palette.phaseInk(phase);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          '${run.label} ${run.rangeLabel}',
          maxLines: 1,
          style: theme.textTheme.labelSmall?.copyWith(
            color: ink,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

extension on HomeForecastKind {
  HealthCyclePhase? get phase => switch (this) {
    HomeForecastKind.period => HealthCyclePhase.period,
    HomeForecastKind.fertile => HealthCyclePhase.fertile,
    HomeForecastKind.pms => HealthCyclePhase.pms,
    HomeForecastKind.normal => null,
  };

  /// 读屏用全称（与健康模块的文案一致）；界面上显示的是 [_KindRun.label] 的短名。
  String get accessibleLabel => switch (this) {
    HomeForecastKind.period => '经期',
    HomeForecastKind.fertile => '易孕期',
    HomeForecastKind.pms => '经前期',
    HomeForecastKind.normal => '无预测',
  };
}
