import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/core/preferences/providers/preferences_providers.dart';
import 'package:miji/core/presentation/components/money_amount_text.dart';
import 'package:miji/core/presentation/providers/income_privacy_providers.dart';

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

/// 收入金额显隐作用域。
///
/// 与全局 [MoneyPrivacy] 并列的第二套遮罩：收入默认遮罩（`****`）、
/// 点按任意一处收入金额即全部切换、与全局开关互不影响。
///
/// 挂在 `main.dart` 的 `ProviderScope` 内（不是 Shell 里）：收入状态必须
/// 在对话框 / 根导航器路由里也能读、也能点。
class IncomePrivacy extends InheritedWidget {
  const IncomePrivacy({
    super.key,
    required this.masked,
    required this.toggle,
    required super.child,
  });

  final bool masked;

  /// 切换全部收入金额显隐（后代在不接 Riverpod 的情况下也能用）。
  final VoidCallback toggle;

  /// 兜底 `true`：读不到作用域的上下文显示 `****`，失败安全。
  ///
  /// 与 [MoneyPrivacy.of] 的 `?? false` 刻意相反 —— 收入的默认态是遮罩。
  static bool of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<IncomePrivacy>()
            ?.masked ??
        true;
  }

  static VoidCallback? toggleOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<IncomePrivacy>()?.toggle;
  }

  @override
  bool updateShouldNotify(IncomePrivacy oldWidget) {
    return oldWidget.masked != masked || oldWidget.toggle != toggle;
  }
}

/// 读取会话态收入显隐并提供给子树（挂在 `main.dart` 的 ProviderScope 内一次）。
class IncomePrivacyScope extends ConsumerWidget {
  const IncomePrivacyScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IncomePrivacy(
      masked: ref.watch(incomeMaskedProvider),
      toggle: () => ref.read(incomeMaskedProvider.notifier).toggle(),
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
    if (tone == MoneyAmountTone.income) {
      // 收入：只看收入显隐（忽略全局 MoneyPrivacy），并自带点击切换。
      final masked = IncomePrivacy.of(context);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: IncomePrivacy.toggleOf(context),
        child: Semantics(
          button: true,
          label: masked ? '显示金额' : '隐藏金额',
          child: MoneyAmountText(
            amountMinor: amountMinor,
            currencyCode: currencyCode,
            tone: tone,
            hidden: masked,
            maskedPlaceholder: '****',
            textStyle: textStyle,
            color: color,
            showSign: showSign,
            textAlign: textAlign,
          ),
        ),
      );
    }
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
String maskedMoneyOr(
  String formatted,
  bool masked, {
  String placeholder = '••••',
}) {
  return masked ? placeholder : formatted;
}

/// 拼接**收入**文案时的遮罩（例如「收入 ¥800」「本月收入 ¥1.2w」）。
///
/// 读 [IncomePrivacy]：默认 `****`，点任意一处收入金额后同步刷新。
String maskedIncomeOr(String formatted, BuildContext context) {
  return IncomePrivacy.of(context) ? '****' : formatted;
}

/// 同一处可能展示收入也可能展示支出时的二选一
/// （统计焦点、分类 kind、预算是否收入目标、交易类型）。
///
/// 收入看 [IncomePrivacy]（`****`），其余看全局 [MoneyPrivacy]（`••••`）。
String maskedMoneyValue(
  String formatted, {
  required bool isIncome,
  required BuildContext context,
}) {
  return isIncome
      ? maskedIncomeOr(formatted, context)
      : maskedMoneyOr(formatted, MoneyPrivacy.of(context));
}

/// 让**非 MoneyText** 的收入金额展示也能点按切换（汇总栏、日头、hero 明细行等）。
///
/// 语义上标成按钮，读屏可识别；与 [MoneyText] 收入分支同一套手势。
class IncomeAmountTap extends StatelessWidget {
  const IncomeAmountTap({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final masked = IncomePrivacy.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: IncomePrivacy.toggleOf(context),
      child: Semantics(
        button: true,
        label: masked ? '显示金额' : '隐藏金额',
        child: child,
      ),
    );
  }
}
