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
}
