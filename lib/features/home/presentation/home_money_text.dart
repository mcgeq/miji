import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/core/presentation/components/money_amount_text.dart';
import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/home/application/home_preference_providers.dart';

/// 首页专用金额文本：自动跟随「隐藏金额」开关。
///
/// 首页几乎每个区块都要展示金额，逐处传 `hidden` 会大量重复且容易漏，
/// 这里统一从偏好读取。
class HomeMoneyText extends ConsumerWidget {
  const HomeMoneyText({
    super.key,
    required this.amountMinor,
    this.currencyCode = 'CNY',
    this.tone = MoneyAmountTone.neutral,
    this.textStyle,
    this.color,
    this.showSign = false,
  });

  final int amountMinor;
  final String currencyCode;
  final MoneyAmountTone tone;
  final TextStyle? textStyle;
  final Color? color;
  final bool showSign;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final masked = ref.watch(homeMaskMoneyAmountsProvider);

    return MoneyAmountText(
      amountMinor: amountMinor,
      currencyCode: currencyCode,
      tone: tone,
      hidden: masked,
      textStyle: textStyle,
      color: color,
      showSign: showSign,
    );
  }
}

/// 把「已格式化的金额字符串」按隐藏开关处理。
///
/// 用于 Hero 这类需要自定义排版（整数 / 小数不同字号）的场景。
String resolveHomeMoneyText({required String formatted, required bool masked}) {
  return masked ? '••••' : formatted;
}

String formatHomeMoney(int amountMinor, String currencyCode) {
  return formatMoneyMinor(amountMinor, currencyCode);
}
