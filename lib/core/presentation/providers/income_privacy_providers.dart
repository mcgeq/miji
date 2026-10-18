import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 收入金额显隐（会话内存态，默认遮罩）。
///
/// 与全局「隐藏金额」（`moneyAmountsMaskedProvider`）**正交**：收入只看这里，
/// 全局开关只管支出/转账/中性金额。刻意不落库、不进同步通道 —— 隐私状态
/// 重启即复原为遮罩，是本功能的安全默认。
final incomeMaskedProvider = NotifierProvider<IncomeMaskedController, bool>(
  IncomeMaskedController.new,
);

class IncomeMaskedController extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;
}
