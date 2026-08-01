import 'package:flutter/material.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';

enum MoneyAmountTone { neutral, income, expense, transfer, credit, warning }

class MoneyAmountText extends StatelessWidget {
  const MoneyAmountText({
    super.key,
    required this.amountMinor,
    this.currencyCode = 'CNY',
    this.tone = MoneyAmountTone.neutral,
    this.hidden = false,
    this.textStyle,
    this.color,
    this.showSign = false,
  });

  final int amountMinor;
  final String currencyCode;
  final MoneyAmountTone tone;
  final bool hidden;
  final TextStyle? textStyle;
  final Color? color;
  final bool showSign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedColor = color ?? _colorFor(theme);
    final sign = showSign && amountMinor > 0 ? '+' : '';
    final text = hidden
        ? '••••'
        : '$sign${formatMoneyMinor(amountMinor, currencyCode)}';

    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: (textStyle ?? theme.textTheme.titleMedium)?.copyWith(
        color: resolvedColor,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
    );
  }

  Color _colorFor(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final moneyColors = theme.moneyColors;
    return switch (tone) {
      MoneyAmountTone.neutral => colorScheme.onSurface,
      MoneyAmountTone.income => moneyColors.income,
      MoneyAmountTone.expense => moneyColors.expense,
      MoneyAmountTone.transfer => moneyColors.transfer,
      MoneyAmountTone.credit => moneyColors.credit,
      MoneyAmountTone.warning => moneyColors.warning,
    };
  }
}
