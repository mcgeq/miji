import 'package:flutter/material.dart';
import 'package:miji/core/presentation/components/app_form_hint.dart';
import 'package:miji/core/presentation/components/app_responsive_dialog.dart';
import 'package:miji/core/presentation/components/app_surface.dart';
import 'package:miji/core/presentation/components/money_text.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/shared/widgets/app_amount_field.dart';

import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';

/// 打开「余额校正」面板，返回用户希望对齐到的目标余额（分）。
///
/// 只用于资产类账户：信用账户的「余额」是可用额度，改它等于改信用额度，
/// 应该走账单对账（补记差额流水 / 记录还款）。
Future<int?> showAccountBalanceAdjustmentSheet({
  required BuildContext context,
  required MoneyAccountEntity account,
}) {
  return showAppResponsiveDialog<int>(
    context: context,
    expandCompactSheet: true,
    builder: (dialogContext) =>
        _AccountBalanceAdjustmentSheet(account: account),
  );
}

class _AccountBalanceAdjustmentSheet extends StatefulWidget {
  const _AccountBalanceAdjustmentSheet({required this.account});

  final MoneyAccountEntity account;

  @override
  State<_AccountBalanceAdjustmentSheet> createState() =>
      _AccountBalanceAdjustmentSheetState();
}

class _AccountBalanceAdjustmentSheetState
    extends State<_AccountBalanceAdjustmentSheet> {
  late final TextEditingController _controller;
  int _targetMinor = 0;
  String? _errorText;

  MoneyAccountEntity get _account => widget.account;

  int get _differenceMinor => _targetMinor - _account.balanceMinor;

  @override
  void initState() {
    super.initState();
    _targetMinor = _account.balanceMinor;
    _controller = TextEditingController(
      text: (_account.balanceMinor / 100).toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final moneyColors = theme.moneyColors;
    final difference = _differenceMinor;
    final differenceColor = difference == 0
        ? colorScheme.onSurfaceVariant
        : difference > 0
        ? moneyColors.income
        : moneyColors.expense;

    return AppDialogScaffold(
      title: '余额校正',
      subtitle: _account.name,
      maxWidth: 400,
      titleTextAlign: TextAlign.center,
      actionsAlignment: WrapAlignment.center,
      errorText: _errorText,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSurface(
            tone: AppSurfaceTone.subtle,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: _Metric(
                    label: '账面余额',
                    child: MoneyText(
                      amountMinor: _account.balanceMinor,
                      currencyCode: _account.currencyCode,
                      textStyle: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Metric(
                    label: difference == 0
                        ? '差额'
                        : difference > 0
                        ? '需补记'
                        : '需扣减',
                    child: Text(
                      maskedMoneyOr(
                        '${difference > 0 ? '+' : '-'}'
                        '${formatMoneyMinor(difference.abs(), _account.currencyCode)}',
                        MoneyPrivacy.of(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: differenceColor,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppAmountField(
            controller: _controller,
            labelText: '实际余额',
            currencyCode: _account.currencyCode,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onChanged: (_) {
              // 输入过程中会出现「12.」或「12+」这类半成品，解析会抛错；
              // 这里保持上一次的有效值，等用户输完再判定。
              final parsed = _tryParse(_controller.text);
              setState(() {
                _targetMinor = parsed;
                _errorText = null;
              });
            },
          ),
          const SizedBox(height: 12),
          const AppFormHint(
            text: '差额通过初始余额补齐，不会产生流水，也不计入收支统计',
            icon: Icons.info_outline_rounded,
          ),
        ],
      ),
      actions: appDialogIconActions(
        onCancel: () => Navigator.of(context).pop(),
        onConfirm: _submit,
        confirmTooltip: '校正',
      ),
    );
  }

  int _tryParse(String input) {
    try {
      return parseMoneyAmountToMinor(input);
    } catch (_) {
      return _targetMinor;
    }
  }

  void _submit() {
    final int targetMinor;
    try {
      targetMinor = parseMoneyAmountToMinor(_controller.text);
    } catch (_) {
      setState(() => _errorText = '请输入有效金额');
      return;
    }
    if (targetMinor < 0) {
      setState(() => _errorText = '余额不能小于 0');
      return;
    }
    if (targetMinor == _account.balanceMinor) {
      setState(() => _errorText = '实际余额与账面余额相同，无需校正');
      return;
    }
    Navigator.of(context).pop(targetMinor);
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 3),
        child,
      ],
    );
  }
}
