import 'package:miji/core/sync/delta_sync/delta_conflict_models.dart';
import 'package:miji/core/sync/delta_sync/delta_conflict_resolver.dart';
import 'package:miji/core/sync/delta_sync/delta_conflict_store.dart';
import 'package:miji/features/bookkeeping/domain/money_repository.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';

class MoneyDeltaConflictApplyService {
  const MoneyDeltaConflictApplyService({
    required this.repository,
    required this.conflictStore,
    this.resolver = const DeltaConflictResolver(),
  });

  final MoneyRepository repository;
  final DeltaConflictStore conflictStore;
  final DeltaConflictResolver resolver;

  Future<void> applyTransactionConflict({
    required StoredDeltaConflict conflict,
    required String deviceId,
    required List<DeltaConflictFieldChoice> choices,
  }) async {
    if (conflict.tableName != 'money_transactions') {
      throw const MoneyDeltaConflictApplyException(
        MoneyDeltaConflictApplyErrorCode.unsupportedTable,
      );
    }
    _assertSupportedRemoteChoices(choices);

    final detected = DeltaDetectedConflict(
      table: conflict.tableName,
      recordId: conflict.recordId,
      localRecord: DeltaLocalRecord(
        table: conflict.tableName,
        recordId: conflict.recordId,
        version: null,
        snapshot: conflict.localSnapshot,
      ),
      remoteChange: conflict.remoteChange,
      fieldGroups: conflict.fieldGroups,
    );
    final merged = resolver.mergeTransactionFields(
      DeltaConflictResolutionDraft(conflict: detected, choices: choices),
    );

    await repository.updateTransaction(
      conflict.userId,
      _updateFromSnapshot(conflict.recordId, merged),
    );
    await conflictStore.markResolved(
      id: conflict.id,
      resolution: DeltaConflictResolution.merged,
      deviceId: deviceId,
    );
  }

  Future<void> applyRecordConflict({
    required StoredDeltaConflict conflict,
    required String deviceId,
    required DeltaConflictSide side,
  }) async {
    if (conflict.tableName == 'money_transactions') {
      throw const MoneyDeltaConflictApplyException(
        MoneyDeltaConflictApplyErrorCode.unsupportedTable,
      );
    }

    if (side == DeltaConflictSide.remote) {
      await repository.applyRemoteMoneyChange(
        conflict.remoteChange,
        DeltaLocalRecord(
          table: conflict.tableName,
          recordId: conflict.recordId,
          version: null,
          snapshot: conflict.localSnapshot,
        ),
      );
    }

    await conflictStore.markResolved(
      id: conflict.id,
      resolution: side == DeltaConflictSide.remote
          ? DeltaConflictResolution.remote
          : DeltaConflictResolution.local,
      deviceId: deviceId,
    );
  }

  void _assertSupportedRemoteChoices(List<DeltaConflictFieldChoice> choices) {
    for (final choice in choices) {
      if (choice.side != DeltaConflictSide.remote) {
        continue;
      }
      if (_supportsRemoteChoice(choice.group)) {
        continue;
      }
      throw MoneyDeltaConflictApplyException(
        MoneyDeltaConflictApplyErrorCode.unsupportedRemoteFieldGroup,
        choice.group.name,
      );
    }
  }

  bool _supportsRemoteChoice(TransactionConflictFieldGroup group) {
    return switch (group) {
      TransactionConflictFieldGroup.record ||
      TransactionConflictFieldGroup.basic ||
      TransactionConflictFieldGroup.account ||
      TransactionConflictFieldGroup.category ||
      TransactionConflictFieldGroup.text => true,
      TransactionConflictFieldGroup.ledger ||
      TransactionConflictFieldGroup.split ||
      TransactionConflictFieldGroup.installment ||
      TransactionConflictFieldGroup.deleteState => false,
    };
  }

  MoneyTransactionUpdate _updateFromSnapshot(
    String transactionId,
    Map<String, Object?> snapshot,
  ) {
    final type = MoneyTransactionType.fromStorageValue(
      _string(snapshot, 'type'),
    );
    if (type == MoneyTransactionType.transfer) {
      throw const MoneyDeltaConflictApplyException(
        MoneyDeltaConflictApplyErrorCode.unsupportedTransfer,
      );
    }

    return MoneyTransactionUpdate(
      id: transactionId,
      type: type,
      transactionAt: _dateTime(snapshot, 'transaction_at'),
      amountMinor: _int(snapshot, 'amount_minor'),
      currencyCode: _string(snapshot, 'currency_code'),
      notes: _nullableString(snapshot, 'notes'),
      merchant: _nullableString(snapshot, 'merchant'),
      location: _nullableString(snapshot, 'location'),
      accountId: _string(snapshot, 'account_id'),
      categoryId: _string(snapshot, 'category_id'),
      subCategoryId: _nullableString(snapshot, 'sub_category_id'),
      paymentMethod: MoneyPaymentMethod.fromStorageValue(
        _string(snapshot, 'payment_method'),
      ),
      customPaymentMethodName: _nullableString(
        snapshot,
        'custom_payment_method_name',
      ),
      tags: _stringList(snapshot, 'tags'),
    );
  }

  String _string(Map<String, Object?> snapshot, String key) {
    final value = snapshot[key];
    if (value is String && value.isNotEmpty) {
      return value;
    }
    throw MoneyDeltaConflictApplyException(
      MoneyDeltaConflictApplyErrorCode.missingRequiredField,
      key,
    );
  }

  String? _nullableString(Map<String, Object?> snapshot, String key) {
    final value = snapshot[key];
    if (value == null) {
      return null;
    }
    return value.toString();
  }

  int _int(Map<String, Object?> snapshot, String key) {
    final value = snapshot[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    throw MoneyDeltaConflictApplyException(
      MoneyDeltaConflictApplyErrorCode.missingRequiredField,
      key,
    );
  }

  DateTime _dateTime(Map<String, Object?> snapshot, String key) {
    final value = snapshot[key];
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) {
        return parsed;
      }
    }
    throw MoneyDeltaConflictApplyException(
      MoneyDeltaConflictApplyErrorCode.missingRequiredField,
      key,
    );
  }

  List<String> _stringList(Map<String, Object?> snapshot, String key) {
    final value = snapshot[key];
    if (value is List) {
      return value.map((item) => item.toString()).toList(growable: false);
    }
    return const <String>[];
  }
}

enum MoneyDeltaConflictApplyErrorCode {
  unsupportedTable,
  unsupportedTransfer,
  unsupportedRemoteFieldGroup,
  missingRequiredField,
}

class MoneyDeltaConflictApplyException implements Exception {
  const MoneyDeltaConflictApplyException(this.code, [this.detail]);

  final MoneyDeltaConflictApplyErrorCode code;
  final Object? detail;

  @override
  String toString() {
    return 'MoneyDeltaConflictApplyException($code, detail: $detail)';
  }
}
