import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';

enum MoneyAutoPostingFrequency {
  daily,
  weekly,
  monthly;

  static MoneyAutoPostingFrequency fromStorageValue(String value) {
    return switch (value) {
      'daily' => MoneyAutoPostingFrequency.daily,
      'weekly' => MoneyAutoPostingFrequency.weekly,
      'monthly' => MoneyAutoPostingFrequency.monthly,
      _ => MoneyAutoPostingFrequency.monthly,
    };
  }

  String get storageValue {
    return switch (this) {
      MoneyAutoPostingFrequency.daily => 'daily',
      MoneyAutoPostingFrequency.weekly => 'weekly',
      MoneyAutoPostingFrequency.monthly => 'monthly',
    };
  }
}

enum MoneyAutoPostingRunStatus {
  pending,
  posted,
  duplicateIgnored,
  blocked,
  retryableFailed,
  userDeleted;

  static MoneyAutoPostingRunStatus fromStorageValue(String value) {
    return switch (value) {
      'pending' => MoneyAutoPostingRunStatus.pending,
      'posted' => MoneyAutoPostingRunStatus.posted,
      'duplicate_ignored' => MoneyAutoPostingRunStatus.duplicateIgnored,
      'blocked' => MoneyAutoPostingRunStatus.blocked,
      'retryable_failed' => MoneyAutoPostingRunStatus.retryableFailed,
      'user_deleted' => MoneyAutoPostingRunStatus.userDeleted,
      _ => MoneyAutoPostingRunStatus.pending,
    };
  }

  String get storageValue {
    return switch (this) {
      MoneyAutoPostingRunStatus.pending => 'pending',
      MoneyAutoPostingRunStatus.posted => 'posted',
      MoneyAutoPostingRunStatus.duplicateIgnored => 'duplicate_ignored',
      MoneyAutoPostingRunStatus.blocked => 'blocked',
      MoneyAutoPostingRunStatus.retryableFailed => 'retryable_failed',
      MoneyAutoPostingRunStatus.userDeleted => 'user_deleted',
    };
  }
}

class MoneyAutoPostingTemplateEntity {
  const MoneyAutoPostingTemplateEntity({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.amountMinor,
    required this.currencyCode,
    required this.description,
    required this.notes,
    required this.merchant,
    required this.accountId,
    required this.categoryId,
    required this.subCategoryId,
    required this.paymentMethod,
    required this.customPaymentMethodName,
    required this.actualPayerAccount,
    required this.ledgerId,
    required this.frequency,
    required this.dayOfMonth,
    required this.weekday,
    required this.timeOfDayMinutes,
    required this.startsOn,
    required this.endsOn,
    required this.isActive,
    required this.version,
    required this.isDeleted,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String name;
  final MoneyTransactionType type;
  final int amountMinor;
  final String currencyCode;
  final String description;
  final String? notes;
  final String? merchant;
  final String accountId;
  final String categoryId;
  final String? subCategoryId;
  final MoneyPaymentMethod paymentMethod;
  final String? customPaymentMethodName;
  final String actualPayerAccount;
  final String? ledgerId;
  final MoneyAutoPostingFrequency frequency;
  final int? dayOfMonth;
  final int? weekday;
  final int timeOfDayMinutes;
  final DateTime startsOn;
  final DateTime? endsOn;
  final bool isActive;
  final int version;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class MoneyAutoPostingTemplateDraft {
  const MoneyAutoPostingTemplateDraft({
    required this.name,
    required this.type,
    required this.amountMinor,
    required this.currencyCode,
    required this.description,
    this.notes,
    this.merchant,
    required this.accountId,
    required this.categoryId,
    this.subCategoryId,
    required this.paymentMethod,
    this.customPaymentMethodName,
    this.actualPayerAccount = 'default',
    this.ledgerId,
    required this.frequency,
    this.dayOfMonth,
    this.weekday,
    this.timeOfDayMinutes = 0,
    required this.startsOn,
    this.endsOn,
    this.isActive = true,
  });

  final String name;
  final MoneyTransactionType type;
  final int amountMinor;
  final String currencyCode;
  final String description;
  final String? notes;
  final String? merchant;
  final String accountId;
  final String categoryId;
  final String? subCategoryId;
  final MoneyPaymentMethod paymentMethod;
  final String? customPaymentMethodName;
  final String actualPayerAccount;
  final String? ledgerId;
  final MoneyAutoPostingFrequency frequency;
  final int? dayOfMonth;
  final int? weekday;
  final int timeOfDayMinutes;
  final DateTime startsOn;
  final DateTime? endsOn;
  final bool isActive;
}

class MoneyAutoPostingTemplateUpdate {
  const MoneyAutoPostingTemplateUpdate({
    required this.id,
    required this.name,
    required this.type,
    required this.amountMinor,
    required this.currencyCode,
    required this.description,
    this.notes,
    this.merchant,
    required this.accountId,
    required this.categoryId,
    this.subCategoryId,
    required this.paymentMethod,
    this.customPaymentMethodName,
    this.actualPayerAccount = 'default',
    this.ledgerId,
    required this.frequency,
    this.dayOfMonth,
    this.weekday,
    this.timeOfDayMinutes = 0,
    required this.startsOn,
    this.endsOn,
    required this.isActive,
  });

  final String id;
  final String name;
  final MoneyTransactionType type;
  final int amountMinor;
  final String currencyCode;
  final String description;
  final String? notes;
  final String? merchant;
  final String accountId;
  final String categoryId;
  final String? subCategoryId;
  final MoneyPaymentMethod paymentMethod;
  final String? customPaymentMethodName;
  final String actualPayerAccount;
  final String? ledgerId;
  final MoneyAutoPostingFrequency frequency;
  final int? dayOfMonth;
  final int? weekday;
  final int timeOfDayMinutes;
  final DateTime startsOn;
  final DateTime? endsOn;
  final bool isActive;
}

class MoneyAutoPostingRunEntity {
  const MoneyAutoPostingRunEntity({
    required this.id,
    required this.userId,
    required this.templateId,
    required this.occurrenceKey,
    required this.status,
    required this.transactionId,
    required this.scheduledFor,
    required this.postedAt,
    required this.templateVersion,
    required this.errorCode,
    required this.errorMessage,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String templateId;
  final String occurrenceKey;
  final MoneyAutoPostingRunStatus status;
  final String? transactionId;
  final DateTime scheduledFor;
  final DateTime? postedAt;
  final int templateVersion;
  final String? errorCode;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class MoneyAutoPostingExecutionSummary {
  const MoneyAutoPostingExecutionSummary({
    required this.postedCount,
    required this.skippedCount,
    required this.blockedCount,
    required this.failedCount,
  });

  final int postedCount;
  final int skippedCount;
  final int blockedCount;
  final int failedCount;

  static const empty = MoneyAutoPostingExecutionSummary(
    postedCount: 0,
    skippedCount: 0,
    blockedCount: 0,
    failedCount: 0,
  );

  MoneyAutoPostingExecutionSummary add({
    int posted = 0,
    int skipped = 0,
    int blocked = 0,
    int failed = 0,
  }) {
    return MoneyAutoPostingExecutionSummary(
      postedCount: postedCount + posted,
      skippedCount: skippedCount + skipped,
      blockedCount: blockedCount + blocked,
      failedCount: failedCount + failed,
    );
  }
}
