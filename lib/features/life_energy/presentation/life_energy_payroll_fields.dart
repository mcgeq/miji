import 'package:flutter/material.dart';

import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/features/life_energy/domain/life_energy_enums.dart';
import 'package:miji/features/life_energy/domain/payroll.dart';
import 'package:miji/features/life_energy/presentation/life_energy_group_card.dart';
import 'package:miji/shared/widgets/app_amount_field.dart';
import 'package:miji/shared/widgets/app_text_field.dart';

/// 税前推算模式下多出来的两组字段：五险一金 + 专项附加扣除。
///
/// 为什么单独一个文件：这两组有 14 个输入项，塞进档案页会让那个文件变成
/// 一千行，而它们**只在税前模式下出现** —— 从档案页看，它们是一个可插拔的
/// 整块，不是档案本身的一部分。
class PayrollFieldsSection extends StatefulWidget {
  const PayrollFieldsSection({
    super.key,
    required this.config,
    required this.grossMonthlyMinor,
    required this.currencyCode,
    required this.onConfigChanged,
  });

  final SocialInsuranceConfig config;
  final int grossMonthlyMinor;
  final String currencyCode;
  final ValueChanged<SocialInsuranceConfig> onConfigChanged;

  @override
  State<PayrollFieldsSection> createState() => _PayrollFieldsSectionState();
}

class _PayrollFieldsSectionState extends State<PayrollFieldsSection> {
  late TextEditingController _baseOverride;
  late TextEditingController _special;
  late TextEditingController _medicalFixed;

  @override
  void initState() {
    super.initState();
    _baseOverride = _amountController(widget.config.baseOverrideMinor);
    _special = _amountController(widget.config.specialDeductionMinor);
    _medicalFixed = _amountController(widget.config.medicalFixedMinor);
  }

  @override
  void didUpdateWidget(PayrollFieldsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 外面改一个数（比如清空重填）时输入框要跟着变，否则界面上写着一个值、
    // 真正在算的是另一个值。
    _sync(_baseOverride, widget.config.baseOverrideMinor);
    _sync(_special, widget.config.specialDeductionMinor);
    _sync(_medicalFixed, widget.config.medicalFixedMinor);
  }

  void _sync(TextEditingController controller, int minor) {
    final text = minor == 0 ? '' : (minor / 100).toStringAsFixed(2);
    if (controller.text.trim() != text) {
      controller.text = text;
    }
  }

  TextEditingController _amountController(int minor) {
    return TextEditingController(
      text: minor == 0 ? '' : (minor / 100).toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    for (final controller in [_baseOverride, _special, _medicalFixed]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _emit(SocialInsuranceConfig config) {
    widget.onConfigChanged(config);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = widget.config;

    return Column(
      children: [
        LifeEnergyGroupCard(
          title: '五险一金 · 个人承担的部分',
          hint:
              '全部自己填。缺的数请对着工资条或当地社保局公告填 —— '
              '缴费基数不等于月薪，它按上年度月平均工资核定，再夹到上下限之间。',
          children: [
            _BaseRow(
              config: config,
              grossMonthlyMinor: widget.grossMonthlyMinor,
              controller: _baseOverride,
              currencyCode: widget.currencyCode,
              onModeChanged: (mode) => _emit(config.copyWith(baseMode: mode)),
              onBaseChanged: (minor) =>
                  _emit(config.copyWith(baseOverrideMinor: minor)),
            ),
            const SizedBox(height: 10),
            _ExpandableRates(
              title: '个人合计',
              valueText: '${_formatRate(config.individualRateBp)}%',
              subtitle:
                  '养老 ${_formatRate(config.pensionBp)} · '
                  '医疗 ${_formatRate(config.medicalBp)} · '
                  '失业 ${_formatRate(config.unemploymentBp)} · '
                  '公积金 ${_formatRate(config.housingFundBp)}',
              leading: Icon(
                Icons.account_balance_wallet_outlined,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              children: [
                _PercentField(
                  label: '养老',
                  bp: config.pensionBp,
                  onChanged: (bp) => _emit(config.copyWith(pensionBp: bp)),
                ),
                const SizedBox(height: 10),
                _PercentField(
                  label: '医疗',
                  bp: config.medicalBp,
                  onChanged: (bp) => _emit(config.copyWith(medicalBp: bp)),
                ),
                const SizedBox(height: 10),
                _PercentField(
                  label: '失业',
                  bp: config.unemploymentBp,
                  onChanged: (bp) => _emit(config.copyWith(unemploymentBp: bp)),
                ),
                const SizedBox(height: 10),
                _PercentField(
                  label: '公积金',
                  bp: config.housingFundBp,
                  onChanged: (bp) => _emit(config.copyWith(housingFundBp: bp)),
                ),
                const SizedBox(height: 10),
                AppAmountField(
                  controller: _medicalFixed,
                  labelText: '大额医疗互助',
                  currencyCode: widget.currencyCode,
                  helperText: '各地 3 元或按比例不等，没有就填 0',
                  onChanged: (value) {
                    _emit(
                      config.copyWith(medicalFixedMinor: parseAmount(value)),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            _ExpandableRates(
              title: '单位合计',
              valueText: '${_formatRate(config.employerRateBp)}%',
              subtitle: '只进年度账，不影响时薪',
              muted: true,
              leading: Icon(
                Icons.business_center_outlined,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              children: [
                _PercentField(
                  label: '养老（单位）',
                  bp: config.pensionErBp,
                  onChanged: (bp) => _emit(config.copyWith(pensionErBp: bp)),
                ),
                const SizedBox(height: 10),
                _PercentField(
                  label: '医疗（单位）',
                  bp: config.medicalErBp,
                  onChanged: (bp) => _emit(config.copyWith(medicalErBp: bp)),
                ),
                const SizedBox(height: 10),
                _PercentField(
                  label: '失业（单位）',
                  bp: config.unemploymentErBp,
                  onChanged: (bp) =>
                      _emit(config.copyWith(unemploymentErBp: bp)),
                ),
                const SizedBox(height: 10),
                _PercentField(
                  label: '工伤（单位）',
                  bp: config.injuryErBp,
                  onChanged: (bp) => _emit(config.copyWith(injuryErBp: bp)),
                ),
                const SizedBox(height: 10),
                _PercentField(
                  label: '公积金（单位）',
                  bp: config.housingFundErBp,
                  onChanged: (bp) =>
                      _emit(config.copyWith(housingFundErBp: bp)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        LifeEnergyGroupCard(
          title: '专项附加扣除 · 减的是计税基数',
          hint:
              '子女教育、租房、赡养老人… 这些减的是计税基数，不是税额。'
              '每月减 2,000，在 10% 档实际少交的是 200 元税。',
          children: [
            AppAmountField(
              controller: _special,
              labelText: '每月可减',
              currencyCode: widget.currencyCode,
              helperText: '几项加起来的月合计',
              onChanged: (value) {
                _emit(
                  config.copyWith(specialDeductionMinor: parseAmount(value)),
                );
              },
            ),
            const SizedBox(height: 10),
            _DerivedRow(label: '一年因此少交个税', valueText: _formatAnnualTaxSaving()),
          ],
        ),
      ],
    );
  }

  /// 「一年因此少交个税」：专项扣除 × 12 × 边际税率。
  ///
  /// 必须按**边际**税率算，不能说「少交 2,000 × 12 = 24,000」—— 扣除减的是
  /// 计税基数，税只减掉基数 × 税率那一部分。写成 24,000 会让人以为能退一大笔。
  String _formatAnnualTaxSaving() {
    final deduction = widget.config.specialDeductionMinor;
    if (deduction <= 0 || widget.grossMonthlyMinor <= 0) {
      return '—';
    }
    final plan = PayrollCalculator(config: widget.config).annual(
      year: 2000,
      inputs: List.generate(
        12,
        (_) => PayrollMonthInput.gross(widget.grossMonthlyMinor),
      ),
    );
    final taxable = plan.months.last.cumulativeTaxableMinor;
    final rateBp = bracketFor(taxable, cumulativeTaxBrackets).rateBp;
    final saved = (deduction * 12 * rateBp / 10000).round();
    return '≈ ${(saved / 100).toStringAsFixed(0)} 元';
  }
}

/// 万分比 → 百分比文案（800 → `8`、50 → `0.5`）。
String _formatRate(int bp) {
  final value = bp / 100;
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(
    value * 10 == (value * 10).roundToDouble() ? 1 : 2,
  );
}

/// 金额框里的文字 → 分。解析不了就当 0，不让整页崩。
int parseAmount(String raw) {
  final value = double.tryParse(raw.trim().replaceAll(',', '')) ?? 0;
  final minor = (value * 100).round();
  return minor < 0 ? 0 : minor;
}

/// 缴费基数：`auto` 跟随税前（夹上下限）/ `manual` 手填。
class _BaseRow extends StatelessWidget {
  const _BaseRow({
    required this.config,
    required this.grossMonthlyMinor,
    required this.controller,
    required this.currencyCode,
    required this.onModeChanged,
    required this.onBaseChanged,
  });

  final SocialInsuranceConfig config;
  final int grossMonthlyMinor;
  final TextEditingController controller;
  final String currencyCode;
  final ValueChanged<SocialBaseMode> onModeChanged;
  final ValueChanged<int> onBaseChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final effective = config.baseFor(grossMonthlyMinor);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '缴费基数',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
            ),
            SegmentedButton<SocialBaseMode>(
              segments: [
                for (final mode in SocialBaseMode.values)
                  ButtonSegment<SocialBaseMode>(
                    value: mode,
                    label: Text(mode.label),
                  ),
              ],
              selected: {config.baseMode},
              showSelectedIcon: false,
              onSelectionChanged: (selection) => onModeChanged(selection.first),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '夹在 ${_formatMoney(config.baseFloorMinor)} ~ '
          '${_formatMoney(config.baseCeilingMinor)} 之间',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            letterSpacing: 0,
            height: 1.35,
          ),
        ),
        if (config.baseMode == SocialBaseMode.manual) ...[
          const SizedBox(height: 10),
          AppAmountField(
            controller: controller,
            labelText: '手填基数',
            currencyCode: currencyCode,
            helperText: '社保 App 里查到的「缴费基数」',
            onChanged: (value) => onBaseChanged(parseAmount(value)),
          ),
        ] else if (effective > 0) ...[
          const SizedBox(height: 6),
          Text(
            '当前按 ${_formatMoney(effective)} 缴',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 0,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}

/// 「个人合计 22.5%」这类可展开的汇总行。
///
/// 收起时只看得到四个数，点开才有十几个比例 —— 多数人只关心总额和到手，不会逐项
/// 改比例，所以比例必须藏起来，否则第一屏就变成一张费率表。
class _ExpandableRates extends StatefulWidget {
  const _ExpandableRates({
    required this.title,
    required this.valueText,
    required this.subtitle,
    required this.children,
    required this.leading,
    this.muted = false,
  });

  final String title;
  final String valueText;
  final String subtitle;
  final List<Widget> children;
  final Widget leading;
  final bool muted;

  @override
  State<_ExpandableRates> createState() => _ExpandableRatesState();
}

class _ExpandableRatesState extends State<_ExpandableRates> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final ink = widget.muted
        ? colorScheme.onSurfaceVariant
        : colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(theme.radiusTokens.sm),
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                widget.leading,
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                          color: ink,
                        ),
                      ),
                      Text(
                        widget.subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          letterSpacing: 0,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  widget.valueText,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                    color: ink,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        if (_open) ...[const SizedBox(height: 10), ...widget.children],
      ],
    );
  }
}

/// 一个比例输入框。值以万分比整数进/出（800 = 8%）。
class _PercentField extends StatefulWidget {
  const _PercentField({
    required this.label,
    required this.bp,
    required this.onChanged,
  });

  final String label;
  final int bp;
  final ValueChanged<int> onChanged;

  @override
  State<_PercentField> createState() => _PercentFieldState();
}

class _PercentFieldState extends State<_PercentField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _formatRate(widget.bp));
  }

  @override
  void didUpdateWidget(_PercentField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 外面的值和框里的值不一样时回写。只在真的不一样时写，
    // 否则用户正在输入 `0.` 会被自己的 onChange 打断。
    if (widget.bp != oldWidget.bp) {
      final parsed = ((double.tryParse(_controller.text.trim()) ?? 0) * 100)
          .round();
      if (parsed != widget.bp) {
        _controller.text = _formatRate(widget.bp);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: _controller,
      labelText: widget.label,
      suffixText: '%',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (value) {
        final parsed = double.tryParse(value.trim()) ?? 0;
        widget.onChanged((parsed < 0 ? 0 : parsed * 100).round());
      },
    );
  }
}

/// 一行「派生值」：左边是口径说明，右边是算出来的数。
class _DerivedRow extends StatelessWidget {
  const _DerivedRow({required this.label, required this.valueText});

  final String label;
  final String valueText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(letterSpacing: 0),
          ),
        ),
        Text(
          valueText,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

String _formatMoney(int minor) {
  final value = minor / 100;
  final text = value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
  return '¥$text';
}
