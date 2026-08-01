enum MoneySplitType {
  equal,
  fixedAmount,
  percentage;

  static MoneySplitType fromStorageValue(String value) {
    return switch (value) {
      'equal' || 'EQUAL' => MoneySplitType.equal,
      'fixed_amount' || 'FIXED_AMOUNT' => MoneySplitType.fixedAmount,
      'percentage' || 'PERCENTAGE' => MoneySplitType.percentage,
      _ => MoneySplitType.equal,
    };
  }

  String get storageValue {
    return switch (this) {
      MoneySplitType.equal => 'equal',
      MoneySplitType.fixedAmount => 'fixed_amount',
      MoneySplitType.percentage => 'percentage',
    };
  }

  String get label {
    return switch (this) {
      MoneySplitType.equal => '均摊',
      MoneySplitType.fixedAmount => '固定金额',
      MoneySplitType.percentage => '按比例',
    };
  }
}

enum MoneySplitRecordStatus {
  active,
  cancelled;

  static MoneySplitRecordStatus fromStorageValue(String value) {
    return switch (value) {
      'cancelled' => MoneySplitRecordStatus.cancelled,
      _ => MoneySplitRecordStatus.active,
    };
  }

  String get storageValue {
    return switch (this) {
      MoneySplitRecordStatus.active => 'active',
      MoneySplitRecordStatus.cancelled => 'cancelled',
    };
  }

  String get label {
    return switch (this) {
      MoneySplitRecordStatus.active => '已记录',
      MoneySplitRecordStatus.cancelled => '已取消',
    };
  }
}

enum MoneySplitRuleType {
  equal,
  percentage,
  fixedAmount,
  weighted,
  custom;

  static MoneySplitRuleType fromStorageValue(String value) {
    return switch (value) {
      'Equal' || 'equal' => MoneySplitRuleType.equal,
      'Percentage' || 'percentage' => MoneySplitRuleType.percentage,
      'FixedAmount' ||
      'fixed_amount' ||
      'fixedAmount' => MoneySplitRuleType.fixedAmount,
      'Weighted' || 'weighted' => MoneySplitRuleType.weighted,
      'Custom' || 'custom' => MoneySplitRuleType.custom,
      _ => MoneySplitRuleType.equal,
    };
  }

  String get storageValue {
    return switch (this) {
      MoneySplitRuleType.equal => 'Equal',
      MoneySplitRuleType.percentage => 'Percentage',
      MoneySplitRuleType.fixedAmount => 'FixedAmount',
      MoneySplitRuleType.weighted => 'Weighted',
      MoneySplitRuleType.custom => 'Custom',
    };
  }

  String get label {
    return switch (this) {
      MoneySplitRuleType.equal => '均摊',
      MoneySplitRuleType.percentage => '按比例',
      MoneySplitRuleType.fixedAmount => '固定金额',
      MoneySplitRuleType.weighted => '加权',
      MoneySplitRuleType.custom => '自定义',
    };
  }
}

class MoneySplitRuleEntity {
  const MoneySplitRuleEntity({
    required this.id,
    required this.userId,
    required this.ledgerId,
    required this.name,
    required this.ruleType,
    required this.ruleConfigJson,
    required this.isActive,
    required this.priority,
    required this.version,
    required this.isDeleted,
    required this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String ledgerId;
  final String name;
  final MoneySplitRuleType ruleType;
  final String ruleConfigJson;
  final bool isActive;
  final int priority;
  final int version;
  final bool isDeleted;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class MoneySplitRuleDraft {
  const MoneySplitRuleDraft({
    required this.ledgerId,
    required this.name,
    required this.ruleType,
    required this.ruleConfigJson,
    this.isActive = true,
    this.priority = 0,
  });

  final String ledgerId;
  final String name;
  final MoneySplitRuleType ruleType;
  final String ruleConfigJson;
  final bool isActive;
  final int priority;
}

class MoneySplitRuleUpdate {
  const MoneySplitRuleUpdate({
    required this.id,
    required this.name,
    required this.ruleType,
    required this.ruleConfigJson,
    required this.isActive,
    required this.priority,
  });

  final String id;
  final String name;
  final MoneySplitRuleType ruleType;
  final String ruleConfigJson;
  final bool isActive;
  final int priority;
}

class MoneyMemberEntity {
  const MoneyMemberEntity({
    required this.id,
    required this.userId,
    required this.name,
    required this.role,
    required this.status,
    required this.color,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String name;
  final String role;
  final String status;
  final String? color;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class MoneyMemberDraft {
  const MoneyMemberDraft({
    required this.name,
    this.role = 'participant',
    this.color,
  });

  final String name;
  final String role;
  final String? color;
}

class MoneyMemberUpdate {
  const MoneyMemberUpdate({
    required this.id,
    required this.name,
    this.role = 'participant',
    this.color,
  });

  final String id;
  final String name;
  final String role;
  final String? color;
}

class MoneyLedgerEntity {
  const MoneyLedgerEntity({
    required this.id,
    required this.userId,
    required this.name,
    required this.ledgerType,
    required this.status,
    required this.baseCurrencyCode,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String name;
  final String ledgerType;
  final String status;
  final String baseCurrencyCode;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isPersonal => ledgerType == 'personal';

  bool get isFamily => ledgerType == 'family';

  bool get isActive => status == 'active';
}

class MoneyLedgerDraft {
  const MoneyLedgerDraft({
    required this.name,
    this.ledgerType = 'family',
    this.description,
    this.baseCurrencyCode = 'CNY',
    this.color,
    this.icon,
  });

  final String name;
  final String ledgerType;
  final String? description;
  final String baseCurrencyCode;
  final String? color;
  final String? icon;
}

class MoneyLedgerUpdate {
  const MoneyLedgerUpdate({
    required this.id,
    required this.name,
    this.description,
    this.color,
    this.icon,
  });

  final String id;
  final String name;
  final String? description;
  final String? color;
  final String? icon;
}

class MoneySplitContextEntity {
  const MoneySplitContextEntity({required this.ledger, required this.members});

  final MoneyLedgerEntity ledger;
  final List<MoneyMemberEntity> members;
}

class MoneySplitRecordDetailEntity {
  const MoneySplitRecordDetailEntity({
    required this.id,
    required this.userId,
    required this.splitRecordId,
    required this.memberId,
    required this.memberName,
    required this.amountMinor,
    required this.percentageBasisPoints,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String splitRecordId;
  final String memberId;
  final String memberName;
  final int amountMinor;
  final int? percentageBasisPoints;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class MoneySplitRecordEntity {
  const MoneySplitRecordEntity({
    required this.id,
    required this.userId,
    required this.ledgerId,
    required this.transactionId,
    required this.status,
    required this.splitType,
    required this.totalAmountMinor,
    required this.currencyCode,
    required this.payerMemberId,
    required this.payerMemberName,
    required this.notes,
    required this.details,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String ledgerId;
  final String? transactionId;
  final MoneySplitRecordStatus status;
  final MoneySplitType splitType;
  final int totalAmountMinor;
  final String currencyCode;
  final String payerMemberId;
  final String payerMemberName;
  final String? notes;
  final List<MoneySplitRecordDetailEntity> details;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class MoneySplitParticipantDraft {
  const MoneySplitParticipantDraft({
    required this.memberId,
    this.amountMinor,
    this.percentageBasisPoints,
  });

  final String memberId;
  final int? amountMinor;
  final int? percentageBasisPoints;
}

class MoneySplitDraft {
  const MoneySplitDraft({
    required this.ledgerId,
    required this.transactionId,
    required this.splitType,
    required this.payerMemberId,
    required this.participants,
    this.notes,
  });

  final String ledgerId;
  final String transactionId;
  final MoneySplitType splitType;
  final String payerMemberId;
  final List<MoneySplitParticipantDraft> participants;
  final String? notes;
}

class MoneySplitConfigDraft {
  const MoneySplitConfigDraft({
    required this.ledgerId,
    required this.splitType,
    required this.payerMemberId,
    required this.participants,
    this.notes,
  });

  final String ledgerId;
  final MoneySplitType splitType;
  final String payerMemberId;
  final List<MoneySplitParticipantDraft> participants;
  final String? notes;

  MoneySplitDraft forTransaction(String transactionId) {
    return MoneySplitDraft(
      ledgerId: ledgerId,
      transactionId: transactionId,
      splitType: splitType,
      payerMemberId: payerMemberId,
      participants: participants,
      notes: notes,
    );
  }
}
