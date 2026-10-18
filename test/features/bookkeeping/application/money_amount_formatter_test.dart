import 'package:flutter_test/flutter_test.dart';

import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';

void main() {
  group('parseMoneyAmountToMinor', () {
    test('parses plain decimal strings', () {
      expect(parseMoneyAmountToMinor('1234.56'), 123456);
      expect(parseMoneyAmountToMinor('42'), 4200);
      expect(parseMoneyAmountToMinor('0.07'), 7);
    });

    test('strips commas and surrounding whitespace', () {
      expect(parseMoneyAmountToMinor('1,234.56'), 123456);
      expect(parseMoneyAmountToMinor('  42  '), 4200);
    });

    test('rounds to nearest cent', () {
      expect(parseMoneyAmountToMinor('0.075'), 8);
      expect(parseMoneyAmountToMinor('0.074'), 7);
    });

    test('returns 0 for empty input', () {
      expect(parseMoneyAmountToMinor(''), 0);
      expect(parseMoneyAmountToMinor('   '), 0);
    });

    test('throws MoneyAmountParseException for invalid input', () {
      expect(
        () => parseMoneyAmountToMinor('abc'),
        throwsA(isA<MoneyAmountParseException>()),
      );
      expect(
        () => parseMoneyAmountToMinor('12.34.56'),
        throwsA(isA<MoneyAmountParseException>()),
      );
    });
  });

  group('formatMoneyMinor', () {
    test('formats CNY with ¥ symbol and two decimals', () {
      expect(formatMoneyMinor(123456, 'CNY'), '¥1,234.56');
      expect(formatMoneyMinor(0, 'CNY'), '¥0.00');
    });

    test(r'formats USD with $ symbol', () {
      expect(formatMoneyMinor(123456, 'USD'), r'$1,234.56');
    });

    test('falls back to currency code for unknown currencies', () {
      expect(formatMoneyMinor(123456, 'XYZ'), 'XYZ1,234.56');
    });
  });

  group('formatMoneyMinorCompact', () {
    test('keeps full precision below one thousand', () {
      expect(formatMoneyMinorCompact(0, 'CNY'), '¥0.00');
      expect(formatMoneyMinorCompact(12345, 'CNY'), '¥123.45');
      expect(formatMoneyMinorCompact(99900, 'CNY'), '¥999.00');
    });

    test('abbreviates thousands with k', () {
      expect(formatMoneyMinorCompact(100000, 'CNY'), '¥1k');
      expect(formatMoneyMinorCompact(230000, 'CNY'), '¥2.3k');
      expect(formatMoneyMinorCompact(990000, 'CNY'), '¥9.9k');
    });

    test('abbreviates ten thousands with w', () {
      expect(formatMoneyMinorCompact(1000000, 'CNY'), '¥1w');
      expect(formatMoneyMinorCompact(3200000, 'CNY'), '¥3.2w');
      expect(formatMoneyMinorCompact(123500000, 'CNY'), '¥123.5w');
    });

    test('rounds to one decimal and trims trailing zero', () {
      expect(formatMoneyMinorCompact(995100, 'CNY'), '¥10k');
      expect(formatMoneyMinorCompact(9999999, 'CNY'), '¥10w');
    });

    test('keeps the sign before the symbol', () {
      expect(formatMoneyMinorCompact(-230000, 'CNY'), '-¥2.3k');
      expect(formatMoneyMinorCompact(-12345, 'CNY'), '-¥123.45');
    });

    test('uses the currency symbol of the currency code', () {
      expect(formatMoneyMinorCompact(230000, 'USD'), r'$2.3k');
      expect(formatMoneyMinorCompact(230000, 'XYZ'), 'XYZ2.3k');
    });
  });
}
