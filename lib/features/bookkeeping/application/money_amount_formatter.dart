import 'package:intl/intl.dart';

class MoneyAmountParseException implements Exception {
  const MoneyAmountParseException(this.input);

  final String input;

  @override
  String toString() {
    return 'MoneyAmountParseException(input: $input)';
  }
}

int parseMoneyAmountToMinor(String input) {
  final normalized = input.trim().replaceAll(',', '');
  if (normalized.isEmpty) {
    return 0;
  }

  final value = double.tryParse(normalized);
  if (value == null) {
    throw MoneyAmountParseException(input);
  }

  return (value * 100).round();
}

String formatMoneyMinor(int amountMinor, String currencyCode) {
  final formatter = NumberFormat.currency(
    locale: _localeForCurrency(currencyCode),
    name: currencyCode,
    symbol: _symbolForCurrency(currencyCode),
    decimalDigits: 2,
  );

  return formatter.format(amountMinor / 100);
}

String _localeForCurrency(String currencyCode) {
  return switch (currencyCode) {
    'CNY' => 'zh_CN',
    'USD' => 'en_US',
    'EUR' => 'de_DE',
    'JPY' => 'ja_JP',
    'HKD' => 'zh_HK',
    'GBP' => 'en_GB',
    'AUD' => 'en_AU',
    'CAD' => 'en_CA',
    'SGD' => 'en_SG',
    'KRW' => 'ko_KR',
    _ => 'zh_CN',
  };
}

String _symbolForCurrency(String currencyCode) {
  return switch (currencyCode) {
    'CNY' => '¥',
    'USD' => r'$',
    'EUR' => '€',
    'JPY' => '¥',
    'HKD' => r'HK$',
    'GBP' => '£',
    'AUD' => r'A$',
    'CAD' => r'C$',
    'SGD' => r'S$',
    'KRW' => '₩',
    _ => currencyCode,
  };
}
