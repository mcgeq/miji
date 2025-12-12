/**
 * 交易验证逻辑 Composable
 *
 * 职责：
 * - 金额验证
 * - 账户余额验证
 * - 转账验证
 * - 表单字段验证
 */

import type { Account } from '@/schema/money';
import { AccountTypeSchema } from '@/schema/money';
import { isAmountInRange, parseAmount } from '../utils/numberUtils';

export function useTransactionValidation() {
  /**
   * 解析账户余额
   * @param account - 账户对象
   * @param useCredit - 是否使用授信额度（针对信用卡）
   * @returns 余额，解析失败返回null
   */
  function parseBalance(account: Account, useCredit = false): number | null {
    const value = useCredit ? account.initialBalance : account.balance;
    const num = parseAmount(value);
    return num;
  }

  /**
   * 验证是否可以从账户转出
   * @param amount - 转出金额
   * @param balance - 账户余额
   * @returns 是否可以转出
   */
  function canWithdraw(amount: number, balance: number): boolean {
    return isAmountInRange(amount, 0, balance);
  }

  /**
   * 验证是否可以向账户转入
   * @param account - 目标账户
   * @param amount - 转入金额
   * @returns 是否可以转入
   */
  function canDeposit(account: Account, amount: number): boolean {
    // 信用卡需要检查是否超过授信额度
    if (account.type === AccountTypeSchema.enum.CreditCard) {
      const currentBalance = parseBalance(account);
      const creditLimit = parseBalance(account, true);

      if (currentBalance === null || creditLimit === null) {
        return false;
      }

      // 转入后余额不能超过授信额度
      return currentBalance + amount <= creditLimit;
    }

    // 非信用卡账户不限制转入
    return true;
  }

  /**
   * 验证转账操作
   * @param fromAccount - 转出账户
   * @param toAccount - 转入账户
   * @param amount - 转账金额
   * @returns 验证结果
   */
  function validateTransfer(
    fromAccount: Account | undefined,
    toAccount: Account | undefined,
    amount: number,
  ): {
    valid: boolean;
    error?: string;
  } {
    // 检查账户是否存在
    if (!fromAccount) {
      return { valid: false, error: '未找到转出账户' };
    }

    if (!toAccount) {
      return { valid: false, error: '未找到转入账户' };
    }

    // 检查金额是否有效
    if (amount <= 0) {
      return { valid: false, error: '转账金额必须大于0' };
    }

    // 检查转出账户余额
    const fromBalance = parseBalance(fromAccount);
    if (fromBalance === null) {
      return { valid: false, error: '转出账户余额数据无效' };
    }

    if (!canWithdraw(amount, fromBalance)) {
      const errorMsg =
        fromAccount.type === AccountTypeSchema.enum.CreditCard
          ? '信用卡转出金额不能大于账户余额'
          : '转出金额超过账户余额';
      return { valid: false, error: errorMsg };
    }

    // 检查转入账户限制
    if (!canDeposit(toAccount, amount)) {
      return { valid: false, error: '转入金额将导致信用卡余额超过授信额度' };
    }

    return { valid: true };
  }

  /**
   * 验证支出操作
   * @param account - 账户
   * @param amount - 支出金额
   * @returns 验证结果
   */
  function validateExpense(
    account: Account | undefined,
    amount: number,
  ): {
    valid: boolean;
    error?: string;
  } {
    if (!account) {
      return { valid: false, error: '未找到账户' };
    }

    if (amount <= 0) {
      return { valid: false, error: '支出金额必须大于0' };
    }

    const balance = parseBalance(account);
    if (balance === null) {
      return { valid: false, error: '账户余额数据无效' };
    }

    if (!canWithdraw(amount, balance)) {
      const errorMsg =
        account.type === AccountTypeSchema.enum.CreditCard
          ? '信用卡支出金额不能大于账户余额'
          : '支出金额超过账户余额';
      return { valid: false, error: errorMsg };
    }

    return { valid: true };
  }

  /**
   * 验证收入操作
   * @param account - 账户
   * @param amount - 收入金额
   * @returns 验证结果
   */
  function validateIncome(
    account: Account | undefined,
    amount: number,
  ): {
    valid: boolean;
    error?: string;
  } {
    if (!account) {
      return { valid: false, error: '未找到账户' };
    }

    if (amount <= 0) {
      return { valid: false, error: '收入金额必须大于0' };
    }

    return { valid: true };
  }

  /**
   * 验证必填字段
   * @param fields - 字段对象
   * @returns 验证结果
   */
  function validateRequiredFields(fields: Record<string, unknown>): {
    valid: boolean;
    missingFields: string[];
  } {
    const missingFields: string[] = [];

    Object.entries(fields).forEach(([key, value]) => {
      if (
        value === null ||
        value === undefined ||
        value === '' ||
        (typeof value === 'number' && Number.isNaN(value))
      ) {
        missingFields.push(key);
      }
    });

    return {
      valid: missingFields.length === 0,
      missingFields,
    };
  }

  return {
    // 余额相关
    parseBalance,
    canWithdraw,
    canDeposit,

    // 交易验证
    validateTransfer,
    validateExpense,
    validateIncome,

    // 表单验证
    validateRequiredFields,
  };
}
