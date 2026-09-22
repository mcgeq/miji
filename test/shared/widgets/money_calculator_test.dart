import 'package:flutter_test/flutter_test.dart';
import 'package:miji/shared/widgets/money_calculator.dart';

void main() {
  group('MoneyCalculator', () {
    test('starts empty', () {
      const calculator = MoneyCalculator.empty;

      expect(calculator.isEmpty, isTrue);
      expect(calculator.display, '');
      expect(calculator.amountMinor, isNull);
      expect(calculator.pendingLabel, isNull);
    });

    test('accepts digits and a single decimal point', () {
      var calculator = MoneyCalculator.empty;
      for (final key in ['3', '8', '.', '5']) {
        calculator = calculator.press(key);
      }

      expect(calculator.display, '38.5');
      expect(calculator.amountMinor, 3850);
    });

    test('ignores a second decimal point and more than two decimals', () {
      var calculator = MoneyCalculator.empty;
      for (final key in ['1', '.', '2', '.', '3', '4', '5']) {
        calculator = calculator.press(key);
      }

      expect(calculator.display, '1.23');
    });

    test('does not keep a leading zero', () {
      var calculator = MoneyCalculator.empty;
      calculator = calculator.press('0').press('5');

      expect(calculator.display, '5');
    });

    test('supports 0 and 00 keys', () {
      var calculator = MoneyCalculator.empty;
      calculator = calculator.press('1').press('00');

      expect(calculator.display, '100');
      expect(calculator.amountMinor, 10000);
    });

    test('adds two amounts (38 + 12 = 50)', () {
      var calculator = MoneyCalculator.empty;
      for (final key in ['3', '8']) {
        calculator = calculator.press(key);
      }
      calculator = calculator.press(MoneyKeypadKeys.add);

      // 等待结算时给出提示，金额仍然是 38。
      expect(calculator.pendingLabel, '38.00 ＋');
      expect(calculator.amountMinor, 3800);

      for (final key in ['1', '2']) {
        calculator = calculator.press(key);
      }
      expect(calculator.amountMinor, 5000);

      calculator = calculator.press(MoneyKeypadKeys.equals);
      expect(calculator.pendingLabel, isNull);
      expect(calculator.amountMinor, 5000);
      expect(calculator.display, '50.00');
    });

    test('chains multiple operations left to right', () {
      var calculator = MoneyCalculator.empty;
      for (final key in [
        '1',
        '0',
        MoneyKeypadKeys.add,
        '5',
        MoneyKeypadKeys.subtract,
        '3',
      ]) {
        calculator = calculator.press(key);
      }

      expect(calculator.amountMinor, 1200);
    });

    test('replaces a pending operator instead of stacking them', () {
      var calculator = MoneyCalculator.empty;
      calculator = calculator
          .press('1')
          .press('0')
          .press(MoneyKeypadKeys.add)
          .press(MoneyKeypadKeys.subtract)
          .press('5');

      expect(calculator.amountMinor, 500);
      expect(calculator.pendingLabel, '10.00 −');
    });

    test('backspace steps back: operator, then the accumulated value', () {
      var calculator = MoneyCalculator.empty
          .press('1')
          .press('2')
          .press(MoneyKeypadKeys.add);

      // 先撤销待应用的运算符，累计值保留。
      calculator = calculator.press(MoneyKeypadKeys.backspace);
      expect(calculator.pendingLabel, isNull);
      expect(calculator.display, '12.00');
      expect(calculator.amountMinor, 1200);

      // 再按一次清掉累计值。
      calculator = calculator.press(MoneyKeypadKeys.backspace);
      expect(calculator.isEmpty, isTrue);
      expect(calculator.display, '');
    });

    test('backspace edits the digits being typed', () {
      final calculator = MoneyCalculator.empty
          .press('1')
          .press('2')
          .press('3')
          .press(MoneyKeypadKeys.backspace);

      expect(calculator.display, '12');
    });

    test('backspace on an empty calculator is a no-op', () {
      final calculator = MoneyCalculator.empty.press(MoneyKeypadKeys.backspace);

      expect(calculator.isEmpty, isTrue);
    });

    test('an operator without any amount is ignored', () {
      final calculator = MoneyCalculator.empty.press(MoneyKeypadKeys.add);

      expect(calculator.isEmpty, isTrue);
    });

    test(
      'subtraction can produce a negative amount for validation to catch',
      () {
        var calculator = MoneyCalculator.empty;
        calculator = calculator
            .press('5')
            .press(MoneyKeypadKeys.subtract)
            .press('8');

        expect(calculator.amountMinor, -300);
      },
    );
  });
}
