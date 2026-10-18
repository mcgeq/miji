/// 时薪面板的展示格式。
///
/// 统一放在这里，是因为同一串数字会在三个页面（面板 / 清单 / 档案吸底条）
/// 反复出现；分开写必然出现「面板 174.7 小时、清单 175 小时」这种不一致。
library;

import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';

/// 小时数：一位小数。`174.7`。
///
/// 不做四舍五入到整数：174.7 和 175 的差别看着小，但用户会拿它跟「一个月
/// 工作 176 小时」对照 —— 保留一位才能自己发现「这个月几乎整月白干」。
String formatLifeEnergyHours(double hours) {
  if (hours.isNaN || hours.isInfinite) {
    return '0.0';
  }
  return hours.toStringAsFixed(1);
}

/// 「1 个工作日 = 9.71 小时」这类口径说明用两位小数。
///
/// 一位小数会把 9.71 抹成 9.7，而 9.71 正是「含通勤」的证据：用户拿它跟
/// 合同上的 8 小时一比，才能看出自己每天多卖了 1.7 小时。
String formatLifeEnergyDayHours(double hours) {
  if (hours.isNaN || hours.isInfinite) {
    return '0.00';
  }
  return hours.toStringAsFixed(2);
}

/// 工作日数：一位小数。`18.0`。
///
/// 刻意保留 `.0`：它和金额并排出现时，「4.1 个工作日」比「4 天」更像一个
/// 量出来的结果，而不是拍脑袋的估计。
String formatLifeEnergyWorkdays(double days) {
  if (days.isNaN || days.isInfinite) {
    return '0.0';
  }
  final text = days.toStringAsFixed(1);
  return text;
}

/// 真实时薪 / 日单价：一位小数，走货币符号。`¥48.2`。
String formatLifeEnergyWage(double amountMinor, String currencyCode) {
  if (amountMinor.isNaN || amountMinor.isInfinite) {
    return '—';
  }
  return formatMoneyMinorWithDigits(amountMinor.round(), currencyCode, 1);
}

/// 年度账里的整数金额。`¥178,320`。
///
/// 年度账不出现小数：这些数本身就是「参数估算」出来的，写 `¥178,320.00`
/// 会假装精确到分 —— 而实际上差 5% 以内都算正常。
String formatLifeEnergyMoney(int amountMinor, String currencyCode) {
  return formatMoneyMinorWithDigits(amountMinor, currencyCode, 0);
}

/// 比例：一位百分数（不带符号）。`74.3%`。
String formatLifeEnergyPercent(double ratio) {
  if (ratio.isNaN || ratio.isInfinite) {
    return '—';
  }
  return '${(ratio * 100).toStringAsFixed(1)}%';
}

/// 涨跌幅：带符号的一位百分数。`+6.5%` / `-9.8%`。
String formatLifeEnergyDelta(double ratio) {
  if (ratio.isNaN || ratio.isInfinite) {
    return '0.0%';
  }
  final sign = ratio > 0 ? '+' : (ratio < 0 ? '-' : '');
  return '$sign${(ratio * 100).abs().toStringAsFixed(1)}%';
}

/// 分钟转成「X 小时」文案（用于加班记录行）。`16 小时`、`1.5 小时`。
String formatLifeEnergyMinutes(int minutes) {
  final hours = minutes / 60;
  final text = hours == hours.roundToDouble()
      ? hours.toStringAsFixed(0)
      : hours.toStringAsFixed(1);
  return '$text 小时';
}
