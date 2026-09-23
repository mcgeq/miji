import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/core/preferences/providers/preferences_providers.dart';
import 'package:miji/core/presentation/components/money_amount_text.dart';

// 调用方通常只需要 import 这一个文件。
export 'package:miji/core/presentation/components/money_amount_text.dart'
    show MoneyAmountText, MoneyAmountTone;

/// 金额隐私作用域。
///
/// 「隐藏金额」是**全局**设置，但金额散落在 100+ 个组件里，逐处传 `hidden`
/// 一定会漏（上一轮的问题就是：开关只覆盖了首页与账户页）。这里把它放进
/// InheritedWidget：任何读取 [MoneyPrivacy.of] 的组件都会在开关变化时精确重建，
/// 既不用全局可变状态，也不用把 provider 传下去。
///
/// 只需要在外壳里包一层：[MoneyPrivacyScope]。
class MoneyPrivacy extends InheritedWidget {
  const MoneyPrivacy({super.key, required this.masked, required super.child});

  final bool masked;

  static bool of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<MoneyPrivacy>()?.masked ??
        false;
  }

  @override
  bool updateShouldNotify(MoneyPrivacy oldWidget) {
    return oldWidget.masked != masked;
  }
}

/// 读取全局偏好并提供给子树（装在外壳/页面顶端一次即可）。
class MoneyPrivacyScope extends ConsumerWidget {
  const MoneyPrivacyScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MoneyPrivacy(
      masked: ref.watch(moneyAmountsMaskedProvider),
      child: child,
    );
  }
}

/// 自动跟随「隐藏金额」开关的金额文本。
///
/// 记账模块到处都在展示金额，全部走这个组件（或 [maskedMoneyOr]）即可保证
/// 一处开关全局生效；它是 StatelessWidget，不需要 widget 自己接 Riverpod。
class MoneyText extends StatelessWidget {
  const MoneyText({
    super.key,
    required this.amountMinor,
    this.currencyCode = 'CNY',
    this.tone = MoneyAmountTone.neutral,
    this.textStyle,
    this.color,
    this.showSign = false,
    this.textAlign,
  });

  final int amountMinor;
  final String currencyCode;
  final MoneyAmountTone tone;
  final TextStyle? textStyle;
  final Color? color;
  final bool showSign;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return MoneyAmountText(
      amountMinor: amountMinor,
      currencyCode: currencyCode,
      tone: tone,
      hidden: MoneyPrivacy.of(context),
      textStyle: textStyle,
      color: color,
      showSign: showSign,
      textAlign: textAlign,
    );
  }
}

/// 需要自己拼字符串时的遮罩（例如「支出 ¥1,240」「日均 ¥138」）。
///
/// 组件形式覆盖不了这类拼接文案，用这个保证同一处开关也生效。
String maskedMoneyOr(String formatted, bool masked) {
  return masked ? '••••' : formatted;
}
