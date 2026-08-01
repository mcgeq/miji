import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';

class TransactionEntryDefaults {
  const TransactionEntryDefaults({
    this.accountId,
    this.categoryId,
    this.subCategoryId,
    this.paymentMethod,
  });

  final String? accountId;
  final String? categoryId;
  final String? subCategoryId;
  final MoneyPaymentMethod? paymentMethod;

  Map<String, Object?> toJson() {
    return {
      'accountId': accountId,
      'categoryId': categoryId,
      'subCategoryId': subCategoryId,
      'paymentMethod': paymentMethod?.storageValue,
    };
  }

  static TransactionEntryDefaults fromJson(Map<String, dynamic> json) {
    final paymentMethodValue = json['paymentMethod'];
    return TransactionEntryDefaults(
      accountId: json['accountId'] as String?,
      categoryId: json['categoryId'] as String?,
      subCategoryId: json['subCategoryId'] as String?,
      paymentMethod: paymentMethodValue is String
          ? MoneyPaymentMethod.fromStorageValue(paymentMethodValue)
          : null,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TransactionEntryDefaults &&
        other.accountId == accountId &&
        other.categoryId == categoryId &&
        other.subCategoryId == subCategoryId &&
        other.paymentMethod == paymentMethod;
  }

  @override
  int get hashCode {
    return Object.hash(accountId, categoryId, subCategoryId, paymentMethod);
  }
}

class TransactionEntryDefaultsStore {
  const TransactionEntryDefaultsStore();

  Future<TransactionEntryDefaults?> readDefaults({
    required String userId,
    required String? ledgerId,
    required MoneyTransactionType type,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_defaultsKey(userId, ledgerId, type));
    if (raw == null || raw.isEmpty) {
      return null;
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return null;
    }

    return TransactionEntryDefaults.fromJson(
      Map<String, dynamic>.from(decoded),
    );
  }

  Future<void> saveDefaults({
    required String userId,
    required String? ledgerId,
    required MoneyTransactionType type,
    required TransactionEntryDefaults defaults,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _defaultsKey(userId, ledgerId, type),
      jsonEncode(defaults.toJson()),
    );

    final categoryId = defaults.categoryId;
    final subCategoryId = defaults.subCategoryId;
    if (categoryId != null && subCategoryId != null) {
      await saveSubCategoryForCategory(
        userId: userId,
        ledgerId: ledgerId,
        type: type,
        categoryId: categoryId,
        subCategoryId: subCategoryId,
      );
    }
  }

  Future<String?> readSubCategoryForCategory({
    required String userId,
    required String? ledgerId,
    required MoneyTransactionType type,
    required String categoryId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_subCategoryKey(userId, ledgerId, type, categoryId));
  }

  Future<void> saveSubCategoryForCategory({
    required String userId,
    required String? ledgerId,
    required MoneyTransactionType type,
    required String categoryId,
    required String subCategoryId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _subCategoryKey(userId, ledgerId, type, categoryId),
      subCategoryId,
    );
  }

  String _defaultsKey(
    String userId,
    String? ledgerId,
    MoneyTransactionType type,
  ) {
    return 'money.transactionEntryDefaults::$userId::${ledgerId ?? 'personal'}::${type.storageValue}';
  }

  String _subCategoryKey(
    String userId,
    String? ledgerId,
    MoneyTransactionType type,
    String categoryId,
  ) {
    return 'money.transactionEntrySubCategory::$userId::${ledgerId ?? 'personal'}::${type.storageValue}::$categoryId';
  }
}
