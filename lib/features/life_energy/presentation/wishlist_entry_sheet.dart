import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/core/presentation/components/app_responsive_dialog.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/life_energy/application/life_energy_format.dart';
import 'package:miji/features/life_energy/domain/life_energy_enums.dart';
import 'package:miji/features/life_energy/domain/wishlist_entry.dart';
import 'package:miji/features/life_energy/providers/life_energy_providers.dart';
import 'package:miji/shared/widgets/app_amount_field.dart';
import 'package:miji/shared/widgets/app_text_field.dart';

/// 新建 / 编辑一件想买的东西。
///
/// 核心交互是「金额下面紧跟一条换算」：代价必须在**还没买**的时候出现，
/// 而不是买完之后在统计里出现。
Future<void> showWishlistEntrySheet(
  BuildContext context, {
  WishlistEntry? entry,
}) {
  return showAppResponsiveDialog<void>(
    context: context,
    expandCompactSheet: true,
    builder: (dialogContext) => _WishlistEntryDialog(entry: entry),
  );
}

class _WishlistEntryDialog extends ConsumerStatefulWidget {
  const _WishlistEntryDialog({this.entry});

  final WishlistEntry? entry;

  @override
  ConsumerState<_WishlistEntryDialog> createState() =>
      _WishlistEntryDialogState();
}

class _WishlistEntryDialogState extends ConsumerState<_WishlistEntryDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;
  late WishDesireLevel _desire;
  late int _cooldownDays;
  bool? _q1;
  bool? _q2;
  bool? _q3;
  String? _error;
  bool _saving = false;

  static const _cooldownOptions = <int>[3, 7, 14, 30];

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _titleController = TextEditingController(text: entry?.title ?? '');
    _notesController = TextEditingController(text: entry?.notes ?? '');
    _amountController = TextEditingController(
      text: entry == null
          ? ''
          : (entry.targetAmountMinor / 100).toStringAsFixed(0),
    );
    _desire = entry?.desire ?? WishDesireLevel.want;
    _q1 = entry?.q1Satisfaction;
    _q2 = entry?.q2Aligned;
    _q3 = entry?.q3NoJob;
    _cooldownDays = _resolveInitialCooldown(entry);
  }

  /// 编辑一条已经在冷却中的记录时，尽量落在同一档上，不要一打开就偷偷改期限。
  int _resolveInitialCooldown(WishlistEntry? entry) {
    final until = entry?.cooldownUntil;
    if (until == null) {
      return 7;
    }
    final now = ref.read(lifeEnergyClockProvider)();
    final days = (until.difference(now).inMinutes / (60 * 24)).ceil();
    for (final option in _cooldownOptions) {
      if ((days - option).abs() <= 1) {
        return option;
      }
    }
    return 7;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  /// 备注：空白当「没写」，清空要能真的存成 null，所以两边分开传。
  String? get _notes {
    final text = _notesController.text.trim();
    return text.isEmpty ? null : text;
  }

  int get _amountMinor {
    try {
      return parseMoneyAmountToMinor(_amountController.text);
    } on MoneyAmountParseException {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = ref.watch(currentWorkProfileProvider).asData?.value;
    final hours = profile?.hoursFor(_amountMinor);
    final days = profile?.daysFor(_amountMinor);
    final editing = widget.entry != null;
    final insight = ref.watch(currentWishlistInsightProvider);

    return AppDialogScaffold(
      title: editing ? '编辑想买的东西' : '记一件想买的东西',
      subtitle: '先记下来，过几天再决定。冷却期内它不会出现在任何账上。',
      maxWidth: 520,
      errorText: _error,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: _titleController,
            labelText: '想买什么',
            hintText: '例如：降噪耳机',
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          AppAmountField(
            controller: _amountController,
            labelText: '价格',
            currencyCode: profile?.currencyCode ?? 'CNY',
            prominent: true,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(theme.radiusTokens.md),
            ),
            child: Text(
              hours == null || days == null
                  ? '填完收入与工时后，这里会显示它值多少个工作日。'
                  : '= ${formatLifeEnergyHours(hours)} 小时 · '
                        '${formatLifeEnergyWorkdays(days)} 个工作日'
                        '（时薪 ${formatLifeEnergyWage(profile!.hourlyWageMinor, profile.currencyCode)}）',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.4,
                letterSpacing: 0,
              ),
            ),
          ),
          // 单件的代价只是背景，真正能改变决定的是「清单加起来要干多久」。
          // 编辑时不显示：那会变成「改了这一件，清单变成多少」，容易读成
          // 「我又多欠了这么多天」。
          // 金额还是空的（`daysFor(0)` 会给 0 天）就不显示：那时「加进去之后」
          // 跟「现在是多少」一模一样，说了等于没说。
          if (!editing &&
              _amountMinor > 0 &&
              days != null &&
              insight != null &&
              insight.activeCount > 0) ...[
            const SizedBox(height: 6),
            Text(
              '加进去之后 · ${insight.activeCount + 1} 件 · '
              '全买下来 '
              '${formatLifeEnergyWorkdays(insight.totalWorkdays + days)} 个工作日',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
                letterSpacing: 0,
              ),
            ),
          ],
          const SizedBox(height: 16),
          _Label('有多想要'),
          const SizedBox(height: 6),
          SegmentedButton<WishDesireLevel>(
            segments: [
              for (final level in WishDesireLevel.values)
                ButtonSegment<WishDesireLevel>(
                  value: level,
                  label: Text(level.label),
                ),
            ],
            selected: {_desire},
            showSelectedIcon: false,
            onSelectionChanged: (selection) {
              setState(() => _desire = selection.first);
            },
          ),
          const SizedBox(height: 16),
          _Label('买之前问自己三个问题'),
          // 问题文案来自 domain 的常量：详情页要照着复述同样三句。
          _QuestionRow(
            text: wishlistQuestions[0],
            value: _q1,
            onChanged: (value) => setState(() => _q1 = value),
          ),
          _QuestionRow(
            text: wishlistQuestions[1],
            value: _q2,
            onChanged: (value) => setState(() => _q2 = value),
          ),
          _QuestionRow(
            text: wishlistQuestions[2],
            value: _q3,
            onChanged: (value) => setState(() => _q3 = value),
          ),
          const SizedBox(height: 12),
          // 备注：模型和仓储一直有 notes，界面上却无处可填 —— 详情页那句话
          // 只能是空的。填一句「为什么想买」，一周后回来看才有意义。
          AppTextField(
            controller: _notesController,
            labelText: '为什么想买',
            hintText: '选填，一句话；一周后回来看这句',
          ),
          const SizedBox(height: 12),
          _Label('冷却期（到期才提醒你决定）'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in _cooldownOptions)
                ChoiceChip(
                  label: Text('$option 天'),
                  selected: _cooldownDays == option,
                  onSelected: (_) => setState(() => _cooldownDays = option),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '书里主张等一个月，但一个月在手机上会被彻底忘记；7 天是「还记得这件事」的上限。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
      actions: appDialogIconActions(
        onCancel: _saving ? null : () => Navigator.of(context).pop(),
        onConfirm: _saving ? null : _submit,
        cancelTooltip: '取消',
        confirmTooltip: editing ? '保存' : '放进清单，$_cooldownDays 天后再决定',
      ),
    );
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _error = '先写清楚想买什么');
      return;
    }
    if (_amountMinor <= 0) {
      setState(() => _error = '价格要大于 0');
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });

    final actions = ref.read(lifeEnergyActionsProvider);
    final existing = widget.entry;
    try {
      if (existing == null) {
        await actions.addWishlistItem(
          title: title,
          targetAmountMinor: _amountMinor,
          notes: _notes,
          desire: _desire,
          cooldownUntil: ref
              .read(lifeEnergyClockProvider)()
              .add(Duration(days: _cooldownDays)),
          q1Satisfaction: _q1,
          q2Aligned: _q2,
          q3NoJob: _q3,
        );
      } else {
        await actions.updateWishlistItem(
          existing.copyWith(
            title: title,
            targetAmountMinor: _amountMinor,
            notes: _notes,
            clearNotes: _notes == null,
            desire: _desire,
            q1Satisfaction: _q1,
            q2Aligned: _q2,
            q3NoJob: _q3,
            replaceAnswers: true,
          ),
        );
      }
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '保存失败，请重试';
        });
      }
    }
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.labelLarge?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
    );
  }
}

class _QuestionRow extends StatelessWidget {
  const _QuestionRow({
    required this.text,
    required this.value,
    required this.onChanged,
  });

  final String text;
  final bool? value;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // 三态循环：未答 → 是 → 否 → 未答。用点按而不是开关：开关只有两态，
    // 没法表达「还没答」，而那恰恰是这个功能想要的默认值。
    final nextValue = value == null ? true : (value! ? false : null);
    final label = value == null ? '未答' : (value! ? '是' : '否');
    final color = value == null
        ? colorScheme.onSurfaceVariant
        : (value! ? colorScheme.primary : colorScheme.onSurfaceVariant);

    return InkWell(
      onTap: () => onChanged(nextValue),
      borderRadius: BorderRadius.circular(theme.radiusTokens.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(letterSpacing: 0),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
