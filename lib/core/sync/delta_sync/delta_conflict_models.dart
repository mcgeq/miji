import 'package:miji/core/sync/delta_sync/delta_package_models.dart';

enum TransactionConflictFieldGroup {
  record,
  basic,
  account,
  category,
  ledger,
  split,
  installment,
  text,
  deleteState,
}

class DeltaLocalRecord {
  const DeltaLocalRecord({
    required this.table,
    required this.recordId,
    required this.version,
    required this.snapshot,
  });

  final String table;
  final String recordId;
  final int? version;
  final Map<String, Object?> snapshot;
}

class DeltaDetectedConflict {
  const DeltaDetectedConflict({
    required this.table,
    required this.recordId,
    required this.localRecord,
    required this.remoteChange,
    required this.fieldGroups,
  });

  final String table;
  final String recordId;
  final DeltaLocalRecord? localRecord;
  final DeltaChangeRecord remoteChange;
  final Set<TransactionConflictFieldGroup> fieldGroups;
}

class DeltaApplyResult {
  const DeltaApplyResult({
    required this.appliedCount,
    required this.conflictCount,
    required this.skippedCount,
  });

  final int appliedCount;
  final int conflictCount;
  final int skippedCount;
}

class TransactionConflictFieldClassifier {
  const TransactionConflictFieldClassifier();

  Set<TransactionConflictFieldGroup> classify(Iterable<String> fields) {
    final groups = <TransactionConflictFieldGroup>{};
    for (final field in fields) {
      final group = _groupForField(field);
      if (group != null) {
        groups.add(group);
      }
    }
    return groups;
  }

  TransactionConflictFieldGroup? _groupForField(String field) {
    return switch (field) {
      'type' ||
      'status' ||
      'transaction_at' ||
      'amount_minor' ||
      'currency_code' => TransactionConflictFieldGroup.basic,
      'account_id' ||
      'to_account_id' ||
      'payment_method' ||
      'custom_payment_method_name' ||
      'actual_payer_account' => TransactionConflictFieldGroup.account,
      'category_id' ||
      'sub_category_id' ||
      'tags' => TransactionConflictFieldGroup.category,
      'ledger_id' ||
      'ledger_ids' ||
      'ledger_memberships' => TransactionConflictFieldGroup.ledger,
      'split_record_id' ||
      'split_details' ||
      'split_type' => TransactionConflictFieldGroup.split,
      'installment_plan_id' ||
      'interest_rate_basis_points' ||
      'total_interest_minor' ||
      'calc_method' => TransactionConflictFieldGroup.installment,
      'description' ||
      'notes' ||
      'merchant' ||
      'location' => TransactionConflictFieldGroup.text,
      'is_deleted' || 'deleted_at' => TransactionConflictFieldGroup.deleteState,
      _ => null,
    };
  }
}
