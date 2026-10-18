import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:miji/core/presentation/app_page_layout.dart';
import 'package:miji/core/presentation/components/app_icon_action_button.dart';
import 'package:miji/core/presentation/components/app_surface.dart';
import 'package:miji/core/presentation/components/money_text.dart';
import 'package:miji/core/presentation/components/app_skeleton.dart';
import 'package:miji/core/presentation/components/app_sliding_segmented_control.dart';
import 'package:miji/core/router/app_routes.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_summary_entity.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';
import 'package:miji/features/life_energy/application/life_energy_format.dart';
import 'package:miji/features/life_energy/domain/overtime_record.dart';
import 'package:miji/features/life_energy/domain/work_profile.dart';
import 'package:miji/features/life_energy/presentation/wishlist_list_body.dart';
import 'package:miji/features/life_energy/presentation/overtime_entry_sheet.dart';
import 'package:miji/features/life_energy/providers/life_energy_providers.dart';

/// 记账模块的第 9 个面板：时薪。
///
/// 这个面板只回答三个问题：我一小时值多少、这个月花掉了多少钱、清单里那些
/// 东西加起来要干多久。
/// 想买清单与收入与工时各有自己的页面，这里只放摘要与入口 —— 面板是每天会打开
/// 的地方，不该被一张 12 个字段的表单占满。
class LifeEnergySection extends ConsumerWidget {
  const LifeEnergySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentWorkProfileProvider);
    final summary = ref.watch(currentMonthMoneySummaryProvider);

    return profile.when(
      loading: () => const AppSkeletonList(rows: 3),
      error: (error, stackTrace) => AppErrorState(
        title: '读取收入与工时失败',
        onRetry: () => ref.invalidate(currentWorkProfileProvider),
      ),
      data: (value) => _LifeEnergyContent(
        profile: value,
        summary: summary.asData?.value ?? const MoneyTransactionSummary.empty(),
      ),
    );
  }
}

/// 面板里的两段：换算（回顾这个月）/ 想买（决定之前）。
///
/// 想买不是「另一个页面」：决定买不买这件事，发生在他正看着自己一小时值多少的
/// 时候 —— 分成两个页面，等于把「代价」和「决定」拆开放在两个地方。
enum _LifeEnergyTab {
  convert('convert', '换算'),
  wishlist('wishlist', '想买');

  const _LifeEnergyTab(this.storage, this.label);

  /// 存进 `life_energy_prefs` 的值；用字符串而不是 index，理由同清单排序。
  final String storage;
  final String label;

  static _LifeEnergyTab fromStorage(String? raw) {
    for (final value in values) {
      if (value.storage == raw) {
        return value;
      }
    }
    return convert;
  }
}

class _LifeEnergyContent extends ConsumerStatefulWidget {
  const _LifeEnergyContent({required this.profile, required this.summary});

  final WorkProfile? profile;
  final MoneyTransactionSummary summary;

  @override
  ConsumerState<_LifeEnergyContent> createState() => _LifeEnergyContentState();
}

class _LifeEnergyContentState extends ConsumerState<_LifeEnergyContent> {
  /// 本地先改、写库在后台：偏好的读取是异步的，等它回来再切 tab 会闪。
  _LifeEnergyTab? _tabOverride;

  _LifeEnergyTab get _tab =>
      _tabOverride ??
      _LifeEnergyTab.fromStorage(ref.watch(lifeEnergyPrefsProvider).tab);

  void _selectTab(_LifeEnergyTab tab) {
    setState(() => _tabOverride = tab);
    final prefs = ref.read(lifeEnergyPrefsProvider);
    ref
        .read(lifeEnergyActionsProvider)
        .saveLifeEnergyPrefs(prefs.copyWith(tab: tab.storage));
  }

  /// 两段切换。放在面板最上面、标题之上：一眼看得见「这个面板有两半」，
  /// 而不是藏在页面深处。
  Widget _tabSwitcher() {
    final spacing = Theme.of(context).spacingTokens;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        spacing.pageCompact,
        spacing.sectionGap / 2,
        spacing.pageCompact,
        0,
      ),
      child: AppSlidingSegmentedControl<_LifeEnergyTab>(
        segments: [
          for (final tab in _LifeEnergyTab.values)
            AppSlidingSegment(value: tab, label: tab.label),
        ],
        value: _tab,
        onChanged: _selectTab,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.spacingTokens;
    final profile = widget.profile;
    final summary = widget.summary;
    final resolved = profile;
    final period = ref.watch(currentLifeEnergyPeriodProvider);
    final masked = MoneyPrivacy.of(context);
    final configured = resolved != null && resolved.isConfigured;

    if (_tab == _LifeEnergyTab.wishlist) {
      // 想买这一段不放面板标题：切到这儿就是一堆待决定的东西，再压一行
      // 「时薪」和一句说明，只是把内容往下推。加一件挪进清单顶部那一行。
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _tabSwitcher(),
          const Expanded(child: WishlistListBody()),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: () => refreshMoneyData(ref),
      child: ListView(
        padding: EdgeInsets.only(bottom: spacing.pageRegular),
        children: [
          _tabSwitcher(),
          _PanelHeader(
            subtitle: configured
                ? '把价格换回时间：${formatLifeEnergyWage(resolved.hourlyWageMinor, resolved.currencyCode)} / 小时'
                : '先填好收入和工时，才有可用的尺子',
            actions: [
              AppIconActionButton(
                icon: Icons.tune_rounded,
                tooltip: '收入与工时',
                variant: AppIconActionVariant.outlined,
                onPressed: () => _openProfile(context),
              ),
              AppIconActionButton(
                icon: Icons.more_time_rounded,
                tooltip: '记录加班',
                variant: AppIconActionVariant.outlined,
                onPressed: configured
                    ? () => showOvertimeEntrySheet(context)
                    : null,
              ),
            ],
          ),
          SizedBox(height: spacing.sectionGap),
          if (!configured)
            const _SetupGuide()
          else ...[
            _HourlyWageHero(
              profile: resolved,
              onEdit: () => _openProfile(context),
            ),
            const SizedBox(height: 12),
            _MonthSpendCard(
              profile: resolved,
              summary: summary,
              masked: masked,
            ),
            if (period != null && period.hasRecords) ...[
              const SizedBox(height: 12),
              _OvertimePeriodCard(
                period: period,
                summary: summary,
                masked: masked,
              ),
            ],
          ],
        ],
      ),
    );
  }

  void _openProfile(BuildContext context) {
    context.push(AppRoutes.bookkeepingLifeEnergyProfile);
  }
}

/// 空态：三步说明 + 一颗按钮。
///
/// 三步的标题就是档案表单的三组字段（收入 / 时间 / 开销），用户点进去不会
/// 遇到意外的字段。灰字「我们不猜你的时薪」要保留：它解释的是「为什么这里
/// 空着」，而不是「坏了」。
/// 面板页头：标题 + 一句话口径，动作靠右。
///
/// 不用 `AppSectionHeader`：它在窄屏会把动作折到下一行、左对齐，于是 390 屏
/// 上「两个图标 + 一大块空白」先占掉 46px，再往下才是内容。这个面板的内容
/// 本身就是一行行数字，不该在开头先浪费一屏的零头。
class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.subtitle, required this.actions});

  final String subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '时薪',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        for (var index = 0; index < actions.length; index++) ...[
          if (index > 0) const SizedBox(width: 8),
          actions[index],
        ],
      ],
    );
  }
}

class _SetupGuide extends StatelessWidget {
  const _SetupGuide();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final spacing = theme.spacingTokens;

    return AppSurface(
      tone: AppSurfaceTone.elevated,
      padding: EdgeInsets.all(spacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.hourglass_bottom_rounded, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '先算出你的真实时薪',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const _SetupStep(index: '1', title: '收入', detail: '全年实际到手多少'),
          const _SetupStep(
            index: '2',
            title: '时间',
            detail: '每月工作几天、每天几小时、通勤多久',
          ),
          const _SetupStep(
            index: '3',
            title: '开销',
            detail: '为了上班多花了什么（交通、工作餐、解压…）',
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () =>
                context.push(AppRoutes.bookkeepingLifeEnergyProfile),
            child: const Text('填写收入与工时'),
          ),
          const SizedBox(height: 10),
          Text(
            '我们不猜你的时薪。没有真实数字时，这一页什么都不显示 —— '
            '一个看起来专业的假时薪，会让你基于假数据做决定。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '想买的东西可以先记下来，填完档案就会自动折成工作日。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _SetupStep extends StatelessWidget {
  const _SetupStep({
    required this.index,
    required this.title,
    required this.detail,
  });

  final String index;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Text(
              index,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              detail,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HourlyWageHero extends StatelessWidget {
  const _HourlyWageHero({required this.profile, required this.onEdit});

  final WorkProfile profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gradient = theme.heroGradients.brand;
    final radius = theme.radiusTokens;
    final masked = MoneyPrivacy.of(context);

    return Container(
      decoration: BoxDecoration(
        gradient: gradient.linear,
        borderRadius: BorderRadius.circular(radius.card),
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '真实时薪',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: gradient.onColor.withValues(
                    alpha: AppHeroGradient.secondaryOpacity,
                  ),
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(width: 8),
              _HeroChip(
                label: '已扣工作开销',
                color: gradient.onColor.withValues(alpha: 0.18),
                textColor: gradient.onColor,
              ),
              const Spacer(),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                color: gradient.onColor,
                tooltip: '编辑收入与工时',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            masked
                ? '••••'
                : formatLifeEnergyWage(
                    profile.hourlyWageMinor,
                    profile.currencyCode,
                  ),
            style: theme.textTheme.displaySmall?.copyWith(
              color: gradient.onColor,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            masked
                ? '1 个工作日 = ••••'
                : '1 个工作日 = ${formatLifeEnergyDayHours(profile.dailyHours)} 小时'
                      '，含每天 ${profile.commuteMinutesPerDay} 分钟通勤',
            style: theme.textTheme.bodySmall?.copyWith(
              color: gradient.onColor.withValues(
                alpha: AppHeroGradient.secondaryOpacity,
              ),
              height: 1.45,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 8),
          _WageLadder(profile: profile, masked: masked),
          // 税前口径下时薪逐月变（年初税还没爬满档，比年末高 4.6%）。挂一行
          // 全年平均，不让用户把预扣节奏当成涨薪 —— 也不让他以为下月还会涨。
          if (profile.isGrossMode) ...[
            const SizedBox(height: 2),
            Text(
              masked
                  ? '全年平均 ••••'
                  : '全年平均 ${formatLifeEnergyWage(profile.averageHourlyWageMinor, profile.currencyCode)}'
                        ' · 个税逐月爬档，年初偏高',
              style: theme.textTheme.labelSmall?.copyWith(
                color: gradient.onColor.withValues(
                  alpha: AppHeroGradient.secondaryOpacity,
                ),
                letterSpacing: 0,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 名义 → 含通勤 → 真实：把两个调整拆开摆出来。
///
/// 为什么非要摆出来：真实时薪是**一个**被改过两次的数（分母加了通勤、分子减了
/// 开销）。只给结果，用户没法核对 —— 而开销那六项本来就是凭感觉填的估算值，
/// 填漏一项，时薪和所有下游（想买清单的天数、本月花掉的小时）都会悄悄变。
///
/// 三级台阶也解释了「为什么我的时薪比工资条低这么多」：通勤吃掉一块，开销再
/// 吃掉一块，不是哪儿算错了。
class _WageLadder extends StatelessWidget {
  const _WageLadder({required this.profile, required this.masked});

  final WorkProfile profile;
  final bool masked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onColor = theme.heroGradients.brand.onColor;
    final color = onColor.withValues(alpha: AppHeroGradient.secondaryOpacity);
    final currency = profile.currencyCode;

    String money(double minor) =>
        masked ? '••••' : formatLifeEnergyWage(minor, currency);

    final steps = <(String, String)>[
      ('名义', money(profile.nominalHourlyWageMinor)),
      ('含通勤', money(profile.hourlyWageBeforeCostMinor)),
      ('扣开销后', money(profile.hourlyWageMinor)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (var i = 0; i < steps.length; i++) ...[
              if (i > 0)
                Text(
                  '→',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    letterSpacing: 0,
                  ),
                ),
              Text(
                '${steps[i].$1} ${steps[i].$2}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: i == steps.length - 1
                      ? FontWeight.w700
                      : FontWeight.w500,
                  letterSpacing: 0,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          masked
              ? '工作开销 •••• / 月 · 通勤 •••• 小时 / 月'
              : '工作开销 ${formatMoneyMinorWithDigits(profile.monthlyWorkCostMinor, currency, 0)} / 月'
                    ' · 通勤 ${formatLifeEnergyHours(profile.commuteHoursPerMonth)} 小时 / 月',
          style: theme.textTheme.labelSmall?.copyWith(
            color: color,
            letterSpacing: 0,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({
    required this.label,
    required this.color,
    required this.textColor,
  });

  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

/// 本月消耗：这个月卖出去多少小时、已经花掉多少、还剩多少。
///
/// 比例刻意不做成百分比条：首页预算卡的「已用 %」已经在讲另一件事（钱花得快不
/// 快），同一屏出现两个百分比会被当成同一件事。
/// 本月花掉：**就是钱**，来自这个月的真实流水。
///
/// 不再把金额折算成小时 / 工作日：这张卡的标题是「花掉」，那就是一个金额；
/// 把 8,420 折成 174.7 小时再当主角，等于用一个**算出来的数**盖住一个**记账
/// 记下来的数** —— 而时薪一旦填错，小时数跟着错，用户还以为账记错了。
/// 换算仍然存在，在想买清单里（每一件值多少天），那里问的才是「这一个值不值」。
class _MonthSpendCard extends StatelessWidget {
  const _MonthSpendCard({
    required this.profile,
    required this.summary,
    required this.masked,
  });

  final WorkProfile profile;
  final MoneyTransactionSummary summary;
  final bool masked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final spacing = theme.spacingTokens;

    return AppSurface(
      padding: EdgeInsets.all(spacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '本月花掉',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  letterSpacing: 0,
                ),
              ),
              const Spacer(),
              Text(
                summary.count == 0 ? '这个月还没有支出' : '${summary.count} 笔支出',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            masked
                ? '••••'
                : formatMoneyMinor(summary.expenseMinor, profile.currencyCode),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '记账里的真实数字，不经过任何换算',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 0,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// 本期（加班月）视角。
///
/// 结论先说人话，「同样的支出多花了 18.9 小时」，数字是证据。明细只留四行：
/// 时长 / 加班费 / 加班开销 / 休息日通勤 —— 补偿方式不单列，因为「加班费 ¥0 ·
/// 全部白干」已经把它说完了。
class _OvertimePeriodCard extends StatelessWidget {
  const _OvertimePeriodCard({
    required this.period,
    required this.summary,
    required this.masked,
  });

  final LifeEnergyPeriod period;
  final MoneyTransactionSummary summary;
  final bool masked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final spacing = theme.spacingTokens;
    final money = theme.moneyColors;
    final profile = period.profile;

    final extraHours = period.extraHoursFor(summary.expenseMinor);
    final extraDays = profile.dailyHours <= 0
        ? 0.0
        : extraHours / profile.dailyHours;
    final raised = extraHours > 0.05;
    final dropped = extraHours < -0.05;
    final deltaColor = raised
        ? money.warningStrong
        : (dropped ? money.incomeStrong : colorScheme.onSurfaceVariant);

    return AppSurface(
      padding: EdgeInsets.all(spacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '本期时薪（含加班）',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  letterSpacing: 0,
                ),
              ),
              const Spacer(),
              if (period.wageDeltaRatio.abs() >= 0.001)
                Text(
                  formatLifeEnergyDelta(period.wageDeltaRatio),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: deltaColor,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                masked
                    ? '••••'
                    : formatLifeEnergyWage(
                        period.hourlyWageMinor,
                        profile.currencyCode,
                      ),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '常规 ${masked ? '••••' : formatLifeEnergyWage(profile.hourlyWageMinor, profile.currencyCode)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            masked
                ? '同样的支出，多花了 •••• 小时'
                : '同样的 ${formatMoneyMinor(summary.expenseMinor, profile.currencyCode)} 支出，'
                      '${raised ? '多花' : (dropped ? '少花' : '持平')} '
                      '${formatLifeEnergyHours(extraHours.abs())} 小时'
                      '（${formatLifeEnergyWorkdays(extraDays.abs())} 个工作日）',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.45,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),
          _MetricRow(
            label: '加班时长',
            value: masked
                ? '••••'
                : formatLifeEnergyMinutes(period.countedOvertimeMinutes),
          ),
          _MetricRow(
            label: '加班费',
            value: masked
                ? '••••'
                : period.paidOvertimeMinor == 0
                ? '¥0 · 全部白干'
                : formatMoneyMinor(
                    period.paidOvertimeMinor,
                    profile.currencyCode,
                  ),
          ),
          _MetricRow(
            label: '加班开销',
            value: masked
                ? '••••'
                : formatMoneyMinor(
                    -period.extraCostMinor,
                    profile.currencyCode,
                  ),
          ),
          _MetricRow(
            label: '休息日通勤',
            value: masked
                ? '••••'
                : '${formatLifeEnergyHours(period.restDayCommuteMinutes / 60)} 小时',
          ),
          if (period.timeOffMinutes > 0)
            _MetricRow(
              label: '调休（不计入）',
              value: masked
                  ? '••••'
                  : formatLifeEnergyMinutes(period.timeOffMinutes),
            ),
          const SizedBox(height: 8),
          Text(
            '本期口径只影响这一页，别处仍按常规 '
            '${masked ? '••••' : formatLifeEnergyWage(profile.hourlyWageMinor, profile.currencyCode)} 算。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.45,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                letterSpacing: 0,
              ),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

/// 想买清单的摘要：几件、多少钱、加起来要干多久。
///
/// 面板第一屏原来还有一张「换算器」（输一个金额看值几小时）。删掉了：那个
/// 数字只在**决定买之前**有用，而那时候用户手上正拿着一件具体的东西 ——
/// 换算该发生在清单里（加一件就看到天数），不是回到面板先做一道算术题。
///
/// 天数恒用**基线**时薪，不随本月加班漂移 —— 尺子的刻度不能天天变。按本期算
/// 的话，加班月里所有东西会一起涨价，用户先怀疑的是功能坏了。
