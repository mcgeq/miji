import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/core/presentation/components/app_responsive_dialog.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/life_energy/application/life_energy_format.dart';
import 'package:miji/features/life_energy/domain/life_energy_enums.dart';
import 'package:miji/features/life_energy/domain/overtime_record.dart';
import 'package:miji/features/life_energy/providers/life_energy_providers.dart';
import 'package:miji/shared/widgets/app_amount_field.dart';
import 'package:miji/shared/widgets/app_text_field.dart';
import 'package:miji/shared/widgets/date_picker.dart';

/// 记录一次加班 / 一周加班里的一天。
///
/// 只有三个字段：哪天 / 多久 / 怎么补。**不问起止时刻**：一问就变成考勤，
/// 而且用户填不出一周前的准确时刻，只会填个大概 —— 那还不如直接问时长。
///
/// 这个弹层约 500px，带键盘也放得下，所以它就该是真正的随手记：点「记录加班」
/// → 键盘直接在时长上弹起 → 点记录，全程不滚动、不导航。
Future<void> showOvertimeEntrySheet(BuildContext context) {
  return showAppResponsiveDialog<void>(
    context: context,
    expandCompactSheet: true,
    builder: (dialogContext) => const _OvertimeEntryDialog(),
  );
}

class _OvertimeEntryDialog extends ConsumerStatefulWidget {
  const _OvertimeEntryDialog();

  @override
  ConsumerState<_OvertimeEntryDialog> createState() =>
      _OvertimeEntryDialogState();
}

class _OvertimeEntryDialogState extends ConsumerState<_OvertimeEntryDialog> {
  late DateTime _workDate;
  late final TextEditingController _hoursController;
  OvertimeCompensation _compensation = OvertimeCompensation.none;
  bool _restDay = false;
  bool _hasExtraCost = false;
  final _extraCostController = TextEditingController();
  final _payController = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final now = ref.read(lifeEnergyClockProvider)();
    _workDate = DateTime(now.year, now.month, now.day);
    _restDay = _isWeekend(_workDate);
    _hoursController = TextEditingController(text: '2');
  }

  @override
  void dispose() {
    _hoursController.dispose();
    _extraCostController.dispose();
    _payController.dispose();
    super.dispose();
  }

  static bool _isWeekend(DateTime date) =>
      date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;

  int get _minutes {
    final hours = double.tryParse(_hoursController.text.trim()) ?? 0;
    return (hours * 60).round();
  }

  int get _extraCostMinor {
    if (!_hasExtraCost) {
      return 0;
    }
    try {
      return parseMoneyAmountToMinor(_extraCostController.text);
    } on MoneyAmountParseException {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final radius = theme.radiusTokens;
    final profile = ref.watch(currentWorkProfileProvider).asData?.value;
    final existing =
        ref.watch(currentMonthOvertimeProvider).asData?.value ??
        const <OvertimeRecord>[];

    // 预览：把这条「还没保存」的记录并进本月，当场看见时薪怎么动。
    final preview = profile == null
        ? null
        : LifeEnergyPeriod(
            profile: profile,
            records: [
              ...existing,
              OvertimeRecord(
                id: '__preview__',
                userId: profile.userId,
                workDate: _workDate,
                minutes: _minutes,
                compensation: _compensation,
                extraCostMinor: _extraCostMinor,
                isRestDay: _restDay,
                createdAt: _workDate,
                updatedAt: _workDate,
              ),
            ],
          );

    return AppDialogScaffold(
      title: '记录加班',
      subtitle: '只记时长，不记几点到几点。',
      maxWidth: 520,
      errorText: _error,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(radius.md),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(radius.md),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.event_rounded,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${_workDate.year}-${_workDate.month.toString().padLeft(2, '0')}-'
                    '${_workDate.day.toString().padLeft(2, '0')}',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                  const Spacer(),
                  if (_restDay)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.moneyColors.warningContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '休息日',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.moneyColors.warningStrong,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _hoursController,
            labelText: '加了多久（小时）',
            hintText: '例如 2 或 1.5',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final hours in const [1, 2, 3, 4])
                ChoiceChip(
                  label: Text('$hours 小时'),
                  selected: _minutes == hours * 60,
                  onSelected: (_) {
                    _hoursController.text = '$hours';
                    setState(() {});
                  },
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '怎么补的',
            style: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 6),
          SegmentedButton<OvertimeCompensation>(
            segments: [
              for (final value in OvertimeCompensation.values)
                ButtonSegment<OvertimeCompensation>(
                  value: value,
                  label: Text(value.label),
                ),
            ],
            selected: {_compensation},
            showSelectedIcon: false,
            onSelectionChanged: (selection) {
              setState(() => _compensation = selection.first);
            },
          ),
          const SizedBox(height: 6),
          Text(
            switch (_compensation) {
              OvertimeCompensation.paid => '拿到钱的加班会抬高本期时薪 —— 那一小时的边际收益比平时高。',
              OvertimeCompensation.timeOff => '调休净额为零：多上多少小时，之后也少上多少，不计入本期。',
              OvertimeCompensation.none => '白干只会让分母变大：同样一份工资，摊到更多小时上。',
            },
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.45,
              letterSpacing: 0,
            ),
          ),
          if (_compensation == OvertimeCompensation.paid) ...[
            const SizedBox(height: 10),
            AppAmountField(
              controller: _payController,
              labelText: '实际拿到的加班费',
              currencyCode: profile?.currencyCode ?? 'CNY',
              helperText: '不按倍率替你推算「应得」，只填实际到账的金额。',
              onChanged: (_) => setState(() {}),
            ),
          ],
          const SizedBox(height: 10),
          SwitchListTile(
            value: _restDay,
            onChanged: (value) => setState(() => _restDay = value),
            contentPadding: EdgeInsets.zero,
            title: const Text('休息日加班'),
            subtitle: Text(
              _restDay && (profile?.commuteMinutesPerDay ?? 0) > 0
                  ? '会多算一趟往返通勤 ${profile!.commuteMinutesPerDay} 分钟'
                  : '工作日加班不用补通勤（往返本来就在每天那 ${profile?.commuteMinutesPerDay ?? 0} 分钟里）',
            ),
          ),
          SwitchListTile(
            value: _hasExtraCost,
            onChanged: (value) => setState(() => _hasExtraCost = value),
            contentPadding: EdgeInsets.zero,
            title: const Text('因为加班多花了钱'),
            subtitle: const Text('打车回家、宵夜这类；公司报销的不要填'),
          ),
          if (_hasExtraCost) ...[
            const SizedBox(height: 8),
            AppAmountField(
              controller: _extraCostController,
              labelText: '多花了多少',
              currencyCode: profile?.currencyCode ?? 'CNY',
              onChanged: (_) => setState(() {}),
            ),
          ],
          const SizedBox(height: 12),
          if (preview != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(radius.md),
              ),
              child: Text(
                '本月时薪 ${formatLifeEnergyWage(preview.baselineHourlyWageMinor, profile!.currencyCode)}'
                ' → ${formatLifeEnergyWage(preview.hourlyWageMinor, profile.currencyCode)}'
                '（${formatLifeEnergyDelta(preview.wageDeltaRatio)}）',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ),
        ],
      ),
      // 图标按钮：跟记账那批弹层一致（取消 = ×，确认 = ✓）。
      actions: appDialogIconActions(
        onCancel: _saving ? null : () => Navigator.of(context).pop(),
        onConfirm: _saving ? null : _submit,
        cancelTooltip: '取消',
        confirmTooltip: _minutes > 0
            ? '记录 ${formatLifeEnergyMinutes(_minutes)}'
            : '记录',
      ),
    );
  }

  int get _payMinor {
    try {
      return parseMoneyAmountToMinor(_payController.text);
    } on MoneyAmountParseException {
      return 0;
    }
  }

  Future<void> _pickDate() async {
    final now = ref.read(lifeEnergyClockProvider)();
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _workDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year, now.month + 1, 0),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _workDate = DateTime(picked.year, picked.month, picked.day);
      // 日期自动判断休息日；用户仍可手动改回来（调休上班的周六）。
      _restDay = _isWeekend(_workDate);
    });
  }

  Future<void> _submit() async {
    if (_minutes <= 0) {
      setState(() => _error = '先填加了多久');
      return;
    }
    if (_minutes > 24 * 60) {
      setState(() => _error = '单条记录不能超过 24 小时');
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      await ref
          .read(lifeEnergyActionsProvider)
          .addOvertimeEntry(
            workDate: _workDate,
            minutes: _minutes,
            compensation: _compensation,
            payAmountMinor: _compensation == OvertimeCompensation.paid
                ? _payMinor
                : 0,
            extraCostMinor: _extraCostMinor,
            isRestDay: _restDay,
          );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '记录失败，请重试';
        });
      }
    }
  }
}
