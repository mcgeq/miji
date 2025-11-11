// src/stores/money/money-errors.ts
import { AppError, AppErrorCode, AppErrorSeverity } from '@/errors/appError';
import { MoneyDbError } from '@/services/money/baseManager';

/**
 * Money Store 错误代码
 */
export enum MoneyStoreErrorCode {
  ACCOUNT_NOT_FOUND = 'ACCOUNT_NOT_FOUND',
  TRANSACTION_NOT_FOUND = 'TRANSACTION_NOT_FOUND',
  RELATED_TRANSACTION_NOT_FOUND = 'RELATED_TRANSACTION_NOT_FOUND',
  INVALID_TRANSACTION_TYPE = 'INVALID_TRANSACTION_TYPE',
  CREDIT_CARD_BALANCE_INVALID = 'CREDIT_CARD_BALANCE_INVALID',
  DATABASE_OPERATION_FAILED = 'DATABASE_OPERATION_FAILED',
  NOT_FOUND = 'NOT_FOUND',
  BUDGET_NOT_FOUND = 'BUDGET_NOT_FOUND',
  REMINDER_NOT_FOUND = 'REMINDER_NOT_FOUND',
  CATEGORY_NOT_FOUND = 'CATEGORY_NOT_FOUND',
}

/**
 * Money Store 错误类
 */
export class MoneyStoreError extends AppError {
  constructor(code: MoneyStoreErrorCode | AppErrorCode, message: string, details?: any) {
    let severity: AppErrorSeverity;
    switch (code) {
      case MoneyStoreErrorCode.DATABASE_OPERATION_FAILED:
      case AppErrorCode.DATABASE_FAILURE:
        severity = AppErrorSeverity.HIGH;
        break;
      case MoneyStoreErrorCode.ACCOUNT_NOT_FOUND:
      case MoneyStoreErrorCode.TRANSACTION_NOT_FOUND:
      case MoneyStoreErrorCode.RELATED_TRANSACTION_NOT_FOUND:
      case MoneyStoreErrorCode.BUDGET_NOT_FOUND:
      case MoneyStoreErrorCode.REMINDER_NOT_FOUND:
      case MoneyStoreErrorCode.CATEGORY_NOT_FOUND:
        severity = AppErrorSeverity.MEDIUM;
        break;
      case MoneyStoreErrorCode.INVALID_TRANSACTION_TYPE:
      case MoneyStoreErrorCode.CREDIT_CARD_BALANCE_INVALID:
        severity = AppErrorSeverity.LOW;
        break;
      default:
        severity = AppErrorSeverity.MEDIUM;
    }

    super('money', code, message, severity, details);
    this.name = 'MoneyStoreError';
    this.message = message;
  }

  public getUserMessage(): string {
    const messages: Record<string, string> = {
      [MoneyStoreErrorCode.ACCOUNT_NOT_FOUND]: 'Account does not exist.',
      [MoneyStoreErrorCode.TRANSACTION_NOT_FOUND]: 'Transaction not found.',
      [MoneyStoreErrorCode.RELATED_TRANSACTION_NOT_FOUND]: 'Related transaction not found.',
      [MoneyStoreErrorCode.INVALID_TRANSACTION_TYPE]: 'Invalid transaction type.',
      [MoneyStoreErrorCode.CREDIT_CARD_BALANCE_INVALID]: 'Credit card balance is invalid.',
      [MoneyStoreErrorCode.DATABASE_OPERATION_FAILED]:
        'Database operation failed. Please try again.',
      [MoneyStoreErrorCode.BUDGET_NOT_FOUND]: 'Budget not found.',
      [MoneyStoreErrorCode.REMINDER_NOT_FOUND]: 'Reminder not found.',
      [MoneyStoreErrorCode.CATEGORY_NOT_FOUND]: 'Category not found.',
    };
    return messages[this.code] || this.message;
  }
}

/**
 * 错误处理辅助函数
 * 用于统一处理各种错误并转换为 AppError
 */
export function handleMoneyStoreError(
  err: unknown,
  defaultMessage: string,
  operation?: string,
  entity?: string,
): AppError {
  let appError: AppError;

  if (err instanceof MoneyDbError) {
    appError = new MoneyStoreError(
      MoneyStoreErrorCode.DATABASE_OPERATION_FAILED,
      `${defaultMessage}: ${err.message}`,
      {
        operation: operation || err.operation,
        entity: entity || err.entity,
        originalError: err.originalError,
      },
    );
  } else if (err instanceof MoneyStoreError) {
    appError = err;
  } else {
    appError = AppError.wrap(
      'money',
      err,
      MoneyStoreErrorCode.DATABASE_OPERATION_FAILED,
      defaultMessage,
    );
  }

  appError.log();
  return appError;
}
