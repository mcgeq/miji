import type { Transaction } from '@/schema/money';

/**
 * 检测是否为分期交易（基于notes字段的正则表达式）
 *
 * @param transaction 交易对象
 * @returns 是否为分期交易
 */
export function isInstallmentTransaction(transaction: Transaction): boolean {
  // 检查基本条件：交易类型为支出，且有relatedTransactionSerialNum
  if (transaction.transactionType !== 'Expense' || !transaction.relatedTransactionSerialNum) {
    return false;
  }

  // 检查notes字段是否包含分期计划模式
  if (!transaction.notes) {
    return false;
  }

  // 正则表达式匹配：分期计划:序列号,第X/Y期
  const installmentPattern = /分期计划:\s*\d+,\s*第\d+\/\d+期/;
  return installmentPattern.test(transaction.notes);
}
