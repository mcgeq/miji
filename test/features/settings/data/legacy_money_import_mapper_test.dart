import 'package:flutter_test/flutter_test.dart';
import 'package:miji/features/settings/data/legacy_money_import_mapper.dart';

void main() {
  test('converts decimal money string to minor units', () {
    expect(LegacyMoneyImportMapper.decimalToMinor('12.34'), 1234);
    expect(LegacyMoneyImportMapper.decimalToMinor('0'), 0);
    expect(LegacyMoneyImportMapper.decimalToMinor('-5.50'), -550);
  });

  test(
    'rounds decimal money string when more than two decimals are present',
    () {
      expect(LegacyMoneyImportMapper.decimalToMinor('12.345'), 1235);
      expect(LegacyMoneyImportMapper.decimalToMinor('12.344'), 1234);
      expect(LegacyMoneyImportMapper.decimalToMinor('-1.995'), -200);
    },
  );

  test('maps legacy account type to current storage value', () {
    expect(
      LegacyMoneyImportMapper.accountTypeStorage('CreditCard'),
      'credit_card',
    );
    expect(LegacyMoneyImportMapper.accountTypeStorage('Alipay'), 'alipay');
    expect(LegacyMoneyImportMapper.accountTypeStorage('WeChat'), 'wechat');
    expect(LegacyMoneyImportMapper.accountTypeStorage('Unknown'), 'cash');
  });

  test('maps legacy transaction enums to current storage values', () {
    expect(LegacyMoneyImportMapper.transactionTypeStorage('Income'), 'income');
    expect(
      LegacyMoneyImportMapper.transactionStatusStorage('Reversed'),
      'voided',
    );
    expect(
      LegacyMoneyImportMapper.paymentMethodStorage('BankTransfer'),
      'bank_transfer',
    );
  });

  test('maps legacy payment methods not covered by current enum parser', () {
    expect(
      LegacyMoneyImportMapper.paymentMethodStorage('WeChat'),
      'wechat_pay',
    );
    expect(
      LegacyMoneyImportMapper.paymentMethodStorage('CloudQuickPass'),
      'union_pay',
    );
    expect(LegacyMoneyImportMapper.paymentMethodStorage('JD'), 'third_party');
    expect(
      LegacyMoneyImportMapper.paymentMethodStorage('ApplePay'),
      'third_party',
    );
  });
}
