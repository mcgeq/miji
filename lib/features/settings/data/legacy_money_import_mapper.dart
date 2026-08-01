import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';

class LegacyMoneyImportMapper {
  const LegacyMoneyImportMapper._();

  static int decimalToMinor(Object? value) {
    final source = value?.toString().trim() ?? '0';
    if (source.isEmpty) {
      return 0;
    }

    final negative = source.startsWith('-');
    final unsigned = negative ? source.substring(1) : source;
    final parts = unsigned.split('.');
    final whole = int.tryParse(parts.first.isEmpty ? '0' : parts.first) ?? 0;
    final fraction = parts.length > 1 ? parts[1] : '';
    final cents = _fractionToCents(fraction);
    final minor = whole * 100 + cents;
    return negative ? -minor : minor;
  }

  static int? nullableDecimalToMinor(Object? value) {
    if (value == null || value.toString().trim().isEmpty) {
      return null;
    }
    return decimalToMinor(value);
  }

  static int? interestRateToBasisPoints(Object? value) {
    if (value == null || value.toString().trim().isEmpty) {
      return null;
    }
    final rate = double.tryParse(value.toString().trim());
    if (rate == null) {
      return null;
    }
    return (rate * 100).round();
  }

  static MoneyAccountType accountType(Object? value) {
    return MoneyAccountType.fromStorageValue(value?.toString() ?? '');
  }

  static String accountTypeStorage(Object? value) {
    return accountType(value).storageValue;
  }

  static String transactionTypeStorage(Object? value) {
    return MoneyTransactionType.fromStorageValue(
      value?.toString() ?? '',
    ).storageValue;
  }

  static String transactionStatusStorage(Object? value) {
    return MoneyTransactionStatus.fromStorageValue(
      value?.toString() ?? '',
    ).storageValue;
  }

  static String paymentMethodStorage(Object? value) {
    final source = value?.toString().trim() ?? '';
    return switch (source) {
      'Savings' || 'BankCard' => MoneyPaymentMethod.bankCard.storageValue,
      'Cash' => MoneyPaymentMethod.cash.storageValue,
      'BankTransfer' => MoneyPaymentMethod.bankTransfer.storageValue,
      'CreditCard' => MoneyPaymentMethod.creditCard.storageValue,
      'WeChat' || 'WeChatPay' => MoneyPaymentMethod.wechatPay.storageValue,
      'Alipay' => MoneyPaymentMethod.alipay.storageValue,
      'CloudQuickPass' ||
      'UnionPay' => MoneyPaymentMethod.unionPay.storageValue,
      'JD' ||
      'PayPal' ||
      'ApplePay' ||
      'GooglePay' ||
      'SamsungPay' ||
      'HuaweiPay' ||
      'MiPay' => MoneyPaymentMethod.thirdParty.storageValue,
      'Other' => MoneyPaymentMethod.other.storageValue,
      _ => MoneyPaymentMethod.fromStorageValue(source).storageValue,
    };
  }

  static DateTime dateTime(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) {
      return DateTime.now();
    }
    return DateTime.parse(text).toLocal();
  }

  static DateTime? nullableDateTime(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) {
      return null;
    }
    return DateTime.parse(text).toLocal();
  }

  static int dateOnlyInt(Object? value) {
    final date = dateTime(value);
    return date.year * 10000 + date.month * 100 + date.day;
  }

  static int? nullableDateOnlyInt(Object? value) {
    final date = nullableDateTime(value);
    if (date == null) {
      return null;
    }
    return date.year * 10000 + date.month * 100 + date.day;
  }

  static int _fractionToCents(String fraction) {
    if (fraction.isEmpty) {
      return 0;
    }

    final normalized = fraction.padRight(3, '0');
    final cents = int.tryParse(normalized.substring(0, 2)) ?? 0;
    final roundingDigit = int.tryParse(normalized.substring(2, 3)) ?? 0;
    return roundingDigit >= 5 ? cents + 1 : cents;
  }
}
