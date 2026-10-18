import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/core/presentation/components/app_responsive_dialog.dart';
import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/life_energy/domain/payroll.dart';
import 'package:miji/features/life_energy/domain/salary_segment.dart';
import 'package:miji/features/life_energy/presentation/life_energy_payroll_fields.dart';
import 'package:miji/features/life_energy/providers/life_energy_providers.dart';
import 'package:miji/shared/widgets/app_amount_field.dart';
import 'package:miji/shared/widgets/app_text_field.dart';

/// 新增 / 编辑一段职业经历。
///
/// 表单只有四样东西是必填的：**从哪个月起、在哪家公司、拿多少钱**，以及
/// 条件（默认继承）。条件不是必填，因为大多数人涨薪时通勤没变 —— 让所有人都
/// 面对一个「通勤多少分钟」的输入框，会让一件简单的事看起来很难。
Future<void> showSalarySegmentSheet(
  BuildContext context, {
  SalarySegment? segment,
}) {
  return showAppResponsiveDialog<void>(
    context: context,
    expandCompactSheet: true,
    builder: (dialogContext) => _SalarySegmentDialog(segment: segment),
  );
}

class _SalarySegmentDialog extends ConsumerStatefulWidget {
  const _SalarySegmentDialog({this.segment});

  final SalarySegment? segment;

  @override
  ConsumerState<_SalarySegmentDialog> createState() =>
      _SalarySegmentDialogState();
}

class _SalarySegmentDialogState extends ConsumerState<_SalarySegmentDialog> {
  late final TextEditingController _employer;
  late final TextEditingController _amount;
  late final TextEditingController _commute;
  late final TextEditingController _overtimeHours;
  late final TextEditingController _workCost;
  late final TextEditingController _note;

  late int _year;
  late int _month;
  late bool _conditionsOn;
  late bool _payrollOn;
  late SocialInsuranceConfig _payroll;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final segment = widget.segment;
    final now = ref.read(lifeEnergyClockProvider)();
    _year = segment?.effectiveYear ?? now.year;
    _month = segment?.effectiveMonth ?? now.month;
    _employer = TextEditingController(text: segment?.employer ?? '');
    // 税前口径下这一栏填的是税前：段上存了税前就显示税前，没存（net 时代
    // 记的旧段）才显示到手 —— 显示到手而拿它当税前算，是最坏的一种错。
    _amount = TextEditingController(
      text: segment == null
          ? ''
          : ((segment.grossAmountMinor ?? segment.amountMinor) / 100)
                .toStringAsFixed(2),
    );
    _commute = TextEditingController(
      text: segment?.commuteMinutesPerDay?.toString() ?? '',
    );
    _overtimeHours = TextEditingController(
      text: segment?.overtimeMinutesPerMonth == null
          ? ''
          : (segment!.overtimeMinutesPerMonth! / 60).toStringAsFixed(1),
    );
    _workCost = TextEditingController(
      text: segment?.workCostMonthlyMinor == null
          ? ''
          : (segment!.workCostMonthlyMinor! / 100).toStringAsFixed(2),
    );
    _note = TextEditingController(text: segment?.note ?? '');
    // 已经带条件的段，打开编辑时直接展开 —— 否则用户会以为条件丢了。
    _conditionsOn = segment?.hasConditionOverride ?? false;
    // 参数同理：段上冻着快照就展开，没有就从档案那一份开始改。
    _payrollOn = segment?.hasPayroll ?? false;
    final current = ref.read(currentWorkProfileProvider).asData?.value;
    _payroll =
        segment?.payroll ?? current?.payroll ?? SocialInsuranceConfig.defaults;
  }

  @override
  void dispose() {
    for (final controller in [
      _employer,
      _amount,
      _commute,
      _overtimeHours,
      _workCost,
      _note,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  int get _amountMinor {
    try {
      return parseMoneyAmountToMinor(_amount.text);
    } on MoneyAmountParseException {
      return 0;
    }
  }

  int? _optionalInt(TextEditingController controller) {
    final text = controller.text.trim();
    if (text.isEmpty) {
      return null;
    }
    final value = int.tryParse(text);
    return value == null || value < 0 ? null : value;
  }

  int? _optionalMinutes(TextEditingController controller) {
    final text = controller.text.trim();
    if (text.isEmpty) {
      return null;
    }
    final value = double.tryParse(text);
    if (value == null || value < 0) {
      return null;
    }
    return (value * 60).round();
  }

  int? _optionalMoney(TextEditingController controller) {
    final text = controller.text.trim();
    if (text.isEmpty) {
      return null;
    }
    try {
      final value = parseMoneyAmountToMinor(text);
      return value < 0 ? null : value;
    } on MoneyAmountParseException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = ref.watch(currentWorkProfileProvider).asData?.value;
    final editing = widget.segment != null;
    final grossMode = profile?.isGrossMode ?? false;
    final now = ref.watch(lifeEnergyClockProvider)();
    final years = [for (var y = now.year - 15; y <= now.year + 1; y++) y];

    return AppDialogScaffold(
      title: editing ? '编辑这一段' : '加一段薪资',
      subtitle: '涨薪、跳槽、转正都算「一段」。段之前的记录不会跟着变。',
      maxWidth: 520,
      errorText: _error,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: _employer,
            labelText: '工作单位',
            hintText: '选填，例如「云图科技」',
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<int>(
                  initialValue: _year,
                  decoration: const InputDecoration(labelText: '生效年份'),
                  items: [
                    for (final year in years)
                      DropdownMenuItem(value: year, child: Text('$year 年')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _year = value);
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<int>(
                  initialValue: _month,
                  decoration: const InputDecoration(labelText: '月份'),
                  items: [
                    for (var m = 1; m <= 12; m++)
                      DropdownMenuItem(value: m, child: Text('$m 月')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _month = value);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppAmountField(
            key: const ValueKey('salarySegmentAmount'),
            controller: _amount,
            labelText: grossMode
                ? '税前月薪'
                : (profile?.payCycle.amountLabel ?? '金额'),
            currencyCode: profile?.currencyCode ?? 'CNY',
            prominent: true,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 6),
          Text(
            grossMode
                ? '填税前。到手会按这一段的月份重新推算，不用自己算。'
                : '口径跟档案一致（${profile?.payCycle.label ?? '按月'}），不用换单位。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  '这段时间的工作条件也变了',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
              ),
              Switch(
                value: _conditionsOn,
                onChanged: (value) => setState(() => _conditionsOn = value),
              ),
            ],
          ),
          if (_conditionsOn) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _commute,
                    labelText: '每天往返通勤',
                    hintText: '${profile?.commuteMinutesPerDay ?? 0}',
                    suffixText: '分钟',
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppTextField(
                    controller: _overtimeHours,
                    labelText: '常规加班',
                    hintText: '每月小时',
                    suffixText: '小时',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            AppAmountField(
              controller: _workCost,
              labelText: '工作开销（月合计）',
              currencyCode: profile?.currencyCode ?? 'CNY',
              helperText: '只填为了上班才多花的部分，合计即可，不用拆六项。',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Text(
              '留空就沿用档案里的值。填了之后这一段会固定下来，'
              '以后改档案不会动到它。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
                letterSpacing: 0,
              ),
            ),
          ],
          if (grossMode) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '这一段的五险一金参数不同',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                Switch(
                  value: _payrollOn,
                  onChanged: (value) => setState(() => _payrollOn = value),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (_payrollOn) ...[
              Text(
                '换城市（基数上下限、公积金比例全不同）、换公司（公积金比例由'
                '单位定）、7 月社保基数调整，都打开这里改一遍。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 12),
              PayrollFieldsSection(
                config: _payroll,
                grossMonthlyMinor: _amountMinor,
                currencyCode: profile?.currencyCode ?? 'CNY',
                onConfigChanged: (config) => setState(() => _payroll = config),
              ),
            ] else
              Text(
                '沿用档案里的参数。打开开关才会给这一段单独存一份 —— '
                '关着的时候它跟着档案变，打开了就固定在当次填的数上。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                  letterSpacing: 0,
                ),
              ),
          ],
          const SizedBox(height: 14),
          AppTextField(
            controller: _note,
            labelText: '备注',
            hintText: '选填，例如「转正」「调岗」',
          ),
        ],
      ),
      actions: appDialogIconActions(
        onCancel: _saving ? null : () => Navigator.of(context).pop(),
        onConfirm: _saving ? null : _submit,
        cancelTooltip: '取消',
        confirmTooltip: editing ? '保存' : '加进来',
      ),
    );
  }

  Future<void> _submit() async {
    var amount = _amountMinor;
    if (amount <= 0) {
      setState(() => _error = '填一下这段时间的金额');
      return;
    }
    final start = DateTime(_year, _month);
    final now = ref.read(lifeEnergyClockProvider)();
    if (start.isAfter(DateTime(now.year, now.month))) {
      setState(() => _error = '生效月份不能晚于这个月');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final actions = ref.read(lifeEnergyActionsProvider);
    final currentProfile = ref.read(currentWorkProfileProvider).asData?.value;
    final grossMode = currentProfile?.isGrossMode ?? false;

    // 税前口径：这一栏填的是税前，到手由算式推出再存进 amountMinor。
    // 存的是「整年都按这个税前」时生效月的到手 —— 段上的到手只是回退值，
    // 真正展示用的到手由 SalaryHistory 按整年累计重算。
    // 这一段自己带了参数就用它 —— 换城市后的到手必须按新城市的比例算，
    // 拿档案那份算出来的数字会跟工资条差一大截。
    final config = _payrollOn && grossMode
        ? _payroll
        : (currentProfile?.payroll ?? SocialInsuranceConfig.defaults);

    int? grossAmountMinor;
    if (grossMode) {
      grossAmountMinor = amount;
      final plan =
          PayrollCalculator(
            config: config,
            // 年终奖单独计税，不进这 12 个月，算这一段到手时不用它。
            bonusMinor: 0,
          ).annual(
            year: 2000,
            inputs: List.generate(12, (_) => PayrollMonthInput.gross(amount)),
          );
      amount = plan.month(_month)?.netMinor ?? amount;
    }

    final employer = _employer.text.trim();
    final note = _note.text.trim();
    final commute = _conditionsOn ? _optionalInt(_commute) : null;
    final overtime = _conditionsOn ? _optionalMinutes(_overtimeHours) : null;
    final workCost = _conditionsOn ? _optionalMoney(_workCost) : null;

    final existing = widget.segment;
    if (existing == null) {
      await actions.addSalarySegment(
        effectiveYear: _year,
        effectiveMonth: _month,
        amountMinor: amount,
        grossAmountMinor: grossAmountMinor,
        employer: employer.isEmpty ? null : employer,
        commuteMinutesPerDay: commute,
        overtimeMinutesPerMonth: overtime,
        workCostMonthlyMinor: workCost,
        payroll: grossMode && _payrollOn ? _payroll : null,
        note: note.isEmpty ? null : note,
      );
    } else {
      await actions.updateSalarySegment(
        SalarySegment(
          id: existing.id,
          userId: existing.userId,
          employer: employer.isEmpty ? null : employer,
          effectiveYear: _year,
          effectiveMonth: _month,
          amountMinor: amount,
          grossAmountMinor: grossAmountMinor,
          payCycle: existing.payCycle,
          workDaysPerMonth: existing.workDaysPerMonth,
          workMinutesPerDay: existing.workMinutesPerDay,
          commuteMinutesPerDay: commute,
          overtimeMinutesPerMonth: overtime,
          workCostMonthlyMinor: workCost,
          // 关掉开关就是清空快照（回到跟随档案）。这里造的是新对象，
          // 不传就等于 null，不需要额外的 clear 开关。
          payroll: grossMode && _payrollOn ? _payroll : null,
          note: note.isEmpty ? null : note,
          createdAt: existing.createdAt,
          updatedAt: existing.updatedAt,
        ),
      );
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}
