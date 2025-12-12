/**
 * 交易表单工具函数
 */

import { CURRENCY_CNY } from '@/constants/moneyConst';
import type { TransactionType } from '@/schema/common';
import { TransactionStatusSchema, TransactionTypeSchema } from '@/schema/common';
import type { Account, Transaction } from '@/schema/money';
import { PaymentMethodSchema } from '@/schema/money';
import { DateUtils } from '@/utils/date';
import { parseAmount } from './numberUtils';

/**
 * 创建默认交易对象
 * @param type - 交易类型
 * @param _accounts - 账户列表（保留参数以保持向后兼容，不再使用）
 */
export function createDefaultTransaction(type: TransactionType, _accounts: Account[]): Transaction {
  return {
    serialNum: '',
    transactionType: type,
    category: type === TransactionTypeSchema.enum.Transfer ? 'Transfer' : 'other',
    subCategory: 'other',
    amount: 0,
    refundAmount: 0,
    currency: CURRENCY_CNY,
    account: {} as Account,
    accountSerialNum: '', // 默认为空，要求用户主动选择
    toAccountSerialNum: '',
    paymentMethod: PaymentMethodSchema.enum.Cash, // 将在选择账户后自动更新
    actualPayerAccount: PaymentMethodSchema.enum.Cash,
    date: DateUtils.getLocalISODateTimeWithOffset(),
    description: '',
    transactionStatus: TransactionStatusSchema.enum.Completed,
    tags: [],
    isDeleted: false,
    isInstallment: false,
    firstDueDate: undefined,
    totalPeriods: 0,
    remainingPeriods: 0,
    installmentAmount: 0,
    remainingPeriodsAmount: 0,
    installmentPlanSerialNum: undefined,
    relatedTransactionSerialNum: undefined,
    familyLedgerSerialNums: [],
    createdAt: '',
    updatedAt: '',
  };
}

/**
 * 初始化表单数据
 * 将字符串类型的数字字段转换为数字类型
 */
export function initializeFormData(
  transaction: Transaction | null,
  type: TransactionType,
  accounts: Account[],
): Transaction {
  const base = transaction || createDefaultTransaction(type, accounts);

  return {
    ...base,
    // 确保金额字段是数字类型
    amount: parseAmount(base.amount),
    refundAmount: parseAmount(base.refundAmount),
    // 确保分期相关字段是数字类型
    totalPeriods: parseAmount(base.totalPeriods),
    remainingPeriods: parseAmount(base.remainingPeriods),
    installmentAmount: parseAmount(base.installmentAmount),
    remainingPeriodsAmount: parseAmount(base.remainingPeriodsAmount),
    // 确保币种对象存在
    currency: base.currency || CURRENCY_CNY,
    // 确保日期字段存在
    date: base.date || DateUtils.getLocalISODateTimeWithOffset(),
    // 如果是转账类型，确保 category 是 Transfer
    category: type === TransactionTypeSchema.enum.Transfer ? 'Transfer' : base.category,
  };
}

/**
 * 判断是否为转账交易
 */
export function isTransferTransaction(transaction: Transaction): boolean {
  return transaction.category === 'Transfer';
}

/**
 * 判断是否为分期交易
 */
export function isInstallmentTransactionForm(transaction: Transaction): boolean {
  return transaction.isInstallment;
}
