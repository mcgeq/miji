import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/core/presentation/components/app_confirm_dialog.dart';
import 'package:miji/core/presentation/components/app_icon_action_button.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/life_energy/application/life_energy_format.dart';
import 'package:miji/features/life_energy/domain/bonus_payment.dart';
import 'package:miji/features/life_energy/presentation/life_energy_group_card.dart';
import 'package:miji/features/life_energy/providers/life_energy_providers.dart';
import 'package:miji/shared/widgets/app_amount_field.dart';
import 'package:miji/shared/widgets/app_text_field.dart';

/// 年终奖：一年一条，按纳税年度排。
///
/// 为什么不塞进档案表单：档案是「现在这个人」的一份尺子，年终奖是「某一年的
/// 一笔钱」。塞进表单就只有一份，换一年（或换一家公司）就把它覆盖了 —— 这正是
/// 这一块要解决的问题。所以它是独立的一组、自己读写。
class LifeEnergyBonusSection extends ConsumerWidget {
  const LifeEnergyBonusSection({super.key, required this.currencyCode});

  final String currencyCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final bonuses =
        ref.watch(bonusPaymentsProvider).asData?.value ??
        const <BonusPayment>[];
    final now = ref.watch(lifeEnergyClockProvider)();
    final hasCurrentYear = bonuses.any((bonus) => bonus.taxYear == now.year);

    return LifeEnergyGroupCard(
      title: '年终奖 · 按纳税年度',
      hint:
          '单独计税，不进 12 个月的累计预扣；一个纳税年度只能用一次这个办法，'
          '所以一年只记一条（同一年发了多笔，请加总后填一个数）。',
      children: [
        if (bonuses.isEmpty)
          Text(
            '还没记过。加一条，这一年的账才会把奖金算进全年到手。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
              letterSpacing: 0,
            ),
          )
        else
          for (final bonus in bonuses) ...[
            _BonusRow(
              bonus: bonus,
              currencyCode: currencyCode,
              onTap: () => showBonusSheet(context, bonus: bonus),
              onDelete: () => _confirmDelete(context, ref, bonus, currencyCode),
            ),
            const SizedBox(height: 8),
          ],
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => showBonusSheet(context),
            icon: const Icon(Icons.add_rounded, size: 18),
            // 今年已经有了一条就不再提「加」：点开只会覆盖，说「加一条」会骗人。
            label: Text(hasCurrentYear ? '记别的年份' : '记 ${now.year} 年的年终奖'),
          ),
        ),
      ],
    );
  }
}

Future<void> _confirmDelete(
  BuildContext context,
  WidgetRef ref,
  BonusPayment bonus,
  String currencyCode,
) async {
  final confirmed = await showAppConfirmDialog(
    context: context,
    title: '删掉这笔年终奖？',
    message:
        '${bonus.yearLabel}的 '
        '${formatLifeEnergyMoney(bonus.amountMinor, currencyCode)} '
        '会从那一年的账里去掉。',
    confirmLabel: '删掉',
    destructive: true,
  );
  if (!confirmed) {
    return;
  }
  await ref.read(lifeEnergyActionsProvider).deleteBonus(bonus);
}

class _BonusRow extends StatelessWidget {
  const _BonusRow({
    required this.bonus,
    required this.currencyCode,
    required this.onTap,
    required this.onDelete,
  });

  final BonusPayment bonus;
  final String currencyCode;
  final VoidCallback onTap;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(theme.radiusTokens.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(theme.radiusTokens.md),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          bonus.yearLabel,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0,
                          ),
                        ),
                        if (!bonus.hasYear) ...[
                          const SizedBox(width: 6),
                          Text(
                            '补一个年份，否则不进任何一年的账',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.error,
                              letterSpacing: 0,
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      bonus.sourceOrDefault,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                formatLifeEnergyMoney(bonus.amountMinor, currencyCode),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
              IconButton(
                tooltip: '删掉这一条',
                iconSize: 18,
                onPressed: () => onDelete(),
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 记/改一条年终奖。
///
/// [bonus] 为空 = 新增；有值 = 改那一条。年份已在年度里，所以新增时默认今年，
/// 也允许往前改 —— 补记去年的奖金是常事。
Future<void> showBonusSheet(BuildContext context, {BonusPayment? bonus}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
      ),
      child: _BonusForm(bonus: bonus),
    ),
  );
}

class _BonusForm extends ConsumerStatefulWidget {
  const _BonusForm({this.bonus});

  final BonusPayment? bonus;

  @override
  ConsumerState<_BonusForm> createState() => _BonusFormState();
}

class _BonusFormState extends ConsumerState<_BonusForm> {
  late final TextEditingController _amount;
  late final TextEditingController _source;
  late final TextEditingController _note;
  late int _year;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final now = ref.read(lifeEnergyClockProvider)();
    final bonus = widget.bonus;
    _year = bonus != null && bonus.hasYear ? bonus.taxYear : now.year;
    _amount = TextEditingController(
      text: bonus == null ? '' : (bonus.amountMinor / 100).toStringAsFixed(2),
    );
    _source = TextEditingController(text: bonus?.sourceLabel ?? '');
    _note = TextEditingController(text: bonus?.note ?? '');
  }

  @override
  void dispose() {
    _amount.dispose();
    _source.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = parseMoneyAmountToMinor(_amount.text);
    if (amount <= 0) {
      setState(() => _error = '填一下奖金金额（税前）');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    await ref
        .read(lifeEnergyActionsProvider)
        .saveBonus(
          taxYear: _year,
          amountMinor: amount,
          sourceLabel: _source.text,
          note: _note.text,
          bonus: widget.bonus,
        );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency =
        ref.watch(currentWorkProfileProvider).asData?.value?.currencyCode ??
        'CNY';
    final now = ref.watch(lifeEnergyClockProvider)();
    final years = [
      for (var y = now.year; y >= now.year - 12; y--) y,
      if (widget.bonus != null &&
          widget.bonus!.hasYear &&
          widget.bonus!.taxYear > now.year)
        widget.bonus!.taxYear,
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.bonus == null ? '记一笔年终奖' : '改这一笔年终奖',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '填发放年度：2026 年 1 月发的上一年奖金，算 2026 年度。'
              '税务上按发放年度走，所以年份选错，那一年的账就错。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<int>(
              initialValue: _year,
              decoration: const InputDecoration(labelText: '纳税年度'),
              items: [
                for (final year in years)
                  DropdownMenuItem(value: year, child: Text('$year 年度')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _year = value);
                }
              },
            ),
            const SizedBox(height: 12),
            AppAmountField(
              key: const ValueKey('bonusAmount'),
              controller: _amount,
              labelText: '奖金（税前）',
              currencyCode: currency,
              prominent: true,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _source,
              labelText: '发放方',
              hintText: '选填，例如「云图科技」',
            ),
            const SizedBox(height: 12),
            AppTextField(controller: _note, labelText: '备注', hintText: '选填'),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                  letterSpacing: 0,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppIconActionButton(
                  tooltip: '取消',
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  icon: Icons.close_rounded,
                  variant: AppIconActionVariant.outlined,
                ),
                const SizedBox(width: 8),
                AppIconActionButton(
                  tooltip: '保存',
                  onPressed: _saving ? null : _submit,
                  icon: Icons.check_rounded,
                  variant: AppIconActionVariant.filled,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
