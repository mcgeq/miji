import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/features/life_energy/application/life_energy_format.dart';
import 'package:miji/features/life_energy/domain/payroll.dart';
import 'package:miji/features/life_energy/presentation/life_energy_group_card.dart';
import 'package:miji/features/life_energy/providers/life_energy_providers.dart';

/// 到手明细：12 个月的个税柱 + 一年的缴费账。
///
/// 入口只在档案页底部一行「看看是怎么算的」，**不进主面板**：主面板第一屏只
/// 回答「一小时值多少」，这一页回答的是完全不同的问题（钱去哪了）。两个问题
/// 混在一屏，用户会先被年度数字吓到，然后忘了自己本来要问什么。
///
/// 这一页存在的真正理由不是展示，是**自查**：每一行的口径都写得能在工资条上
/// 找到对应行，对不上就说明参数要改 —— 或者干脆切回「直接填到手」。
/// 年度账：12 个月的个税与到手，加一年的缴费账。
///
/// 年份可切：档案页默认进今年，但「去年个税交了多少」是个真实问题 —— 薪资
/// 历史能回看每一段，扣缴明细不能回看的话，两页的口径就对不上了。
class LifeEnergyPayrollPage extends ConsumerStatefulWidget {
  const LifeEnergyPayrollPage({super.key});

  @override
  ConsumerState<LifeEnergyPayrollPage> createState() =>
      _LifeEnergyPayrollPageState();
}

class _LifeEnergyPayrollPageState extends ConsumerState<LifeEnergyPayrollPage> {
  /// 本轮刚选的年份。null = 用偏好里存的，再没有就跟随「今年」。
  int? _year;

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(lifeEnergyClockProvider)();
    final year =
        _year ?? ref.watch(lifeEnergyPrefsProvider).payrollYear ?? now.year;
    final plan = ref.watch(annualPayrollProvider(year));
    final currency =
        ref.watch(currentWorkProfileProvider).asData?.value?.currencyCode ??
        'CNY';
    // 有段的最早年份：再往前既没有段、也没有可比的数，给个空年份没意义。
    final history = ref.watch(salaryHistoryProvider);
    final earliestYear = history == null || history.segments.isEmpty
        ? now.year
        : history.segments.first.effectiveYear;
    final years = [for (var y = now.year; y >= earliestYear; y--) y];

    return Scaffold(
      appBar: AppBar(
        title: const Text('这一年是怎么算的'),
        actions: [
          if (years.length > 1)
            PopupMenuButton<int>(
              tooltip: '换年份',
              initialValue: year,
              onSelected: (value) {
                setState(() => _year = value);
                final prefs = ref.read(lifeEnergyPrefsProvider);
                ref
                    .read(lifeEnergyActionsProvider)
                    .saveLifeEnergyPrefs(prefs.copyWith(payrollYear: value));
              },
              itemBuilder: (context) => [
                for (final option in years)
                  PopupMenuItem<int>(value: option, child: Text('$option 年')),
              ],
              icon: Row(
                children: [
                  Text(
                    '$year 年',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const Icon(Icons.arrow_drop_down_rounded),
                ],
              ),
            ),
        ],
      ),
      body: plan == null
          ? const _EmptyPayroll()
          : _PayrollBody(
              plan: plan,
              currencyCode: currency,
              bonusSource: _bonusSource(ref, year),
            ),
    );
  }
}

/// 没填税前 / 用的是「直接填到手」：这一页不存在内容。
///
/// 不显示「请先切换到税前推算」并给个按钮跳走：那种引导会把用户推到一个他
/// 没打算做的决定上。只说明这一页是干嘛的、什么时候会有东西。
class _EmptyPayroll extends StatelessWidget {
  const _EmptyPayroll();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              '这一页要等填了税前才有',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '现在用的是「直接填到手」—— 到手是你填的，没有扣缴过程可以拆。'
              '想看每月个税和五险一金，去档案页把计算方式换成「税前推算」。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 这一年年终奖的发放方。没记来源就返回 null（那一行小字不显示），
/// 不写「未填写」—— 账页上多一行「未填写」只会让人以为哪里坏了。
String? _bonusSource(WidgetRef ref, int year) {
  final bonuses = ref.watch(bonusPaymentsProvider).asData?.value;
  if (bonuses == null) {
    return null;
  }
  for (final bonus in bonuses) {
    if (bonus.taxYear == year) {
      return bonus.hasSource ? bonus.sourceLabel!.trim() : null;
    }
  }
  return null;
}

class _PayrollBody extends StatelessWidget {
  const _PayrollBody({
    required this.plan,
    required this.currencyCode,
    this.bonusSource,
  });

  final AnnualPayroll plan;
  final String currencyCode;

  /// 这一年那笔奖金是谁发的（可空）。奖金按年度记，不挂在段上 —— 换过公司
  /// 的人最需要这一行：否则「含年终奖」那三个字里，混着两家公司的钱。
  final String? bonusSource;

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).spacingTokens;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        spacing.pageCompact,
        8,
        spacing.pageCompact,
        24,
      ),
      children: [
        _AnnualCard(plan: plan, currencyCode: currencyCode),
        const SizedBox(height: 12),
        LifeEnergyGroupCard(
          title: '一年的账',
          hint: '这五个数加起来就是全年到手。每一项都能在工资条上找到对应行。',
          children: [
            _Row(
              label: '年应发${plan.bonusMinor > 0 ? '（含年终奖）' : ''}',
              subLabel: plan.bonusMinor > 0 && bonusSource != null
                  ? '年终奖 ${formatLifeEnergyMoney(plan.bonusMinor, currencyCode)}'
                        ' · $bonusSource'
                  : null,
              value: formatLifeEnergyMoney(
                plan.grossMinor + plan.bonusMinor,
                currencyCode,
              ),
            ),
            const SizedBox(height: 10),
            _Row(
              label: '五险一金（个人）',
              subLabel:
                  '公积金 ${formatLifeEnergyMoney(plan.individual.housingFundMinor, currencyCode)}'
                  ' · 养老 ${formatLifeEnergyMoney(plan.individual.pensionMinor, currencyCode)}'
                  ' · 其余 ${formatLifeEnergyMoney(plan.individual.othersMinor, currencyCode)}',
              value:
                  '−${formatLifeEnergyMoney(plan.individual.totalMinor, currencyCode)}',
              negative: true,
            ),
            const SizedBox(height: 10),
            _Row(
              label: '个人所得税${plan.bonusTaxMinor > 0 ? '（含年终奖）' : ''}',
              value:
                  '−${formatLifeEnergyMoney(plan.taxMinor + plan.bonusTaxMinor, currencyCode)}',
              negative: true,
            ),
            const SizedBox(height: 10),
            // 公积金单列：它是支出，但**不是消耗** —— 两边的钱都在你名下。
            // 不单列的话，用户会把它和税归成一类，然后得出「一半的钱没了」。
            _Row(
              label: '公积金（个人 + 单位）',
              subLabel: '都在你名下，只是取不出来',
              value: formatLifeEnergyMoney(
                plan.housingFundBothSidesMinor,
                currencyCode,
              ),
            ),
            const SizedBox(height: 10),
            _Row(
              label: '公司另付',
              subLabel: '单位五险一金，不在你的工资里',
              value: formatLifeEnergyMoney(
                plan.employerTotalMinor,
                currencyCode,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const _SelfCheckNote(),
      ],
    );
  }
}

/// 全年到手 + 12 根个税柱。
class _AnnualCard extends StatelessWidget {
  const _AnnualCard({required this.plan, required this.currencyCode});

  final AnnualPayroll plan;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(theme.radiusTokens.card),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '全年到手',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatLifeEnergyMoney(plan.totalNetMinor, currencyCode),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatLifeEnergyPercent(plan.netRatio),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                      color: colorScheme.primary,
                    ),
                  ),
                  Text(
                    '占应发 ${formatLifeEnergyMoney(plan.grossMinor + plan.bonusMinor, currencyCode)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _TaxBars(plan: plan),
          const SizedBox(height: 9),
          Text(
            _bracketSummary(plan),
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

  /// 「3% 档 · 4 个月 → 10% 档 · 8 个月」。
  ///
  /// 写档位而不是写「5 月税变多了」：档位解释了**为什么**会变，而「变多了」
  /// 只是陈述结果 —— 用户看不出这是模型噪声还是真涨薪。
  String _bracketSummary(AnnualPayroll plan) {
    final months = plan.months.where((m) => !m.isNetCalibrated).toList();
    if (months.isEmpty) {
      return '柱高 = 当月个税';
    }
    final counts = <int, int>{};
    for (final month in months) {
      counts[month.rateBp] = (counts[month.rateBp] ?? 0) + 1;
    }
    final segments = counts.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final text = segments
        .map(
          (entry) =>
              '${(entry.key / 100).toStringAsFixed(0)}% 档 · ${entry.value} 个月',
        )
        .join(' → ');
    return '柱高 = 当月个税 · $text';
  }
}

/// 12 根柱子画的是**当月个税**，不是到手。
///
/// 到手从 15,245 到 14,650 只差 3.9%，十二根柱子几乎一样高；个税从 255 到
/// 850 差 3.3 倍，一眼就能看出「5 月跨档了」。画错对象这一页就白做了。
class _TaxBars extends StatelessWidget {
  const _TaxBars({required this.plan});

  final AnnualPayroll plan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final maxTax = plan.months
        .map((month) => month.taxMinor)
        .fold(0, (a, b) => a > b ? a : b);
    return Column(
      children: [
        SizedBox(
          height: 74,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final month in plan.months)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.5),
                    child: FractionallySizedBox(
                      heightFactor: maxTax <= 0
                          ? 0.02
                          : (month.taxMinor / maxTax).clamp(0.02, 1.0),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          // 跨档之后（10% 及以上）用实心色：柱子的形状本身
                          // 就在讲「前几个月按 3% 扣，之后一直按 10% 扣」。
                          color: month.rateBp >= 1000
                              ? colorScheme.primary
                              : colorScheme.primaryContainer,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            for (var i = 1; i <= 12; i++)
              Expanded(
                child: Text(
                  '$i',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 0,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.subLabel,
    this.negative = false,
  });

  final String label;
  final String value;
  final String? subLabel;
  final bool negative;

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
                label,
                style: theme.textTheme.bodyMedium?.copyWith(letterSpacing: 0),
              ),
              if (subLabel != null) ...[
                const SizedBox(height: 2),
                Text(
                  subLabel!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 0,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
            color: negative ? colorScheme.error : null,
          ),
        ),
      ],
    );
  }
}

/// 全案唯一一处「怎么自查」的引导。
///
/// 三句话必须挨着：拿工资条对 → 差 5% 以内继续用 → 差得多切回「直接填到手」。
/// 缺最后一句，用户就会卡在「我知道不准，然后呢」。
class _SelfCheckNote extends StatelessWidget {
  const _SelfCheckNote();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        '这些是按档案参数估算的。拿一张工资条对一遍「实发合计」，差 5% 以内就'
        '继续用（补充公积金、大额互助、专项扣除年中才申报都会造成偏差）；'
        '差得多就去档案页改成「直接填到手」。',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          height: 1.6,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
