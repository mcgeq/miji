import type { Ref } from 'vue';
import type { TransactionType } from '@/schema/common';
import { TransactionTypeSchema } from '@/schema/common';
import type { Account, PaymentMethod } from '@/schema/money';
import { AccountTypeSchema, PaymentMethodSchema } from '@/schema/money';

/**
 * 根据账户类型和交易类型获取默认支付方式
 * @param account - 账户对象（可选）
 * @param transactionType - 交易类型
 * @returns 默认支付方式
 */
export function getDefaultPaymentMethod(
  account: Account | undefined | null,
  transactionType: TransactionType,
): PaymentMethod {
  // 收入交易默认使用 Other
  if (transactionType === TransactionTypeSchema.enum.Income) {
    return PaymentMethodSchema.enum.Other;
  }

  // 未选择账户时，默认现金
  if (!account) {
    return PaymentMethodSchema.enum.Cash;
  }

  // 根据账户类型设置对应的支付方式
  const typeToPaymentMap: Record<string, PaymentMethod> = {
    [AccountTypeSchema.enum.Alipay]: PaymentMethodSchema.enum.Alipay,
    [AccountTypeSchema.enum.WeChat]: PaymentMethodSchema.enum.WeChat,
    [AccountTypeSchema.enum.CreditCard]: PaymentMethodSchema.enum.CreditCard,
    [AccountTypeSchema.enum.Bank]: PaymentMethodSchema.enum.BankTransfer,
    [AccountTypeSchema.enum.Savings]: PaymentMethodSchema.enum.Savings,
    [AccountTypeSchema.enum.CloudQuickPass]: PaymentMethodSchema.enum.CloudQuickPass,
  };

  return typeToPaymentMap[account.type] || PaymentMethodSchema.enum.Cash;
}

/**
 * 支付方式管理 Composable
 * 根据账户类型和交易类型计算可用的支付方式
 */
export function usePaymentMethods(
  accounts: Ref<Account[]>,
  selectedAccountSerialNum: Ref<string | undefined>,
  transactionType: Ref<TransactionType>,
) {
  /**
   * 可用的支付方式列表
   * 根据选中账户类型和交易类型动态计算
   */
  const availablePaymentMethods = computed(() => {
    const selectedAccount = accounts.value.find(
      acc => acc.serialNum === selectedAccountSerialNum.value,
    );

    // 非收入交易时，根据账户类型限制支付方式
    if (transactionType.value !== TransactionTypeSchema.enum.Income) {
      // 支付宝账户只能使用支付宝支付
      if (selectedAccount?.type === AccountTypeSchema.enum.Alipay) {
        return [PaymentMethodSchema.enum.Alipay];
      }
      if (selectedAccount?.type === AccountTypeSchema.enum.WeChat) {
        // 微信账户只能使用微信支付
        return [PaymentMethodSchema.enum.WeChat];
      }
      if (selectedAccount?.type === AccountTypeSchema.enum.CreditCard) {
        // 信用卡账户支持多种支付方式
        return [
          PaymentMethodSchema.enum.CreditCard,
          PaymentMethodSchema.enum.Alipay,
          PaymentMethodSchema.enum.WeChat,
          PaymentMethodSchema.enum.CloudQuickPass,
          PaymentMethodSchema.enum.JD,
          PaymentMethodSchema.enum.UnionPay,
          PaymentMethodSchema.enum.PayPal,
          PaymentMethodSchema.enum.ApplePay,
          PaymentMethodSchema.enum.GooglePay,
          PaymentMethodSchema.enum.SamsungPay,
          PaymentMethodSchema.enum.HuaweiPay,
          PaymentMethodSchema.enum.MiPay,
        ];
      }
    }

    // 默认返回所有支付方式选项
    return PaymentMethodSchema.options;
  });

  /**
   * 判断支付方式是否可编辑
   * 收入交易不可编辑，只有一个支付方式时也不可编辑
   */
  const isPaymentMethodEditable = computed(() => {
    // 收入交易不可编辑支付方式
    if (transactionType.value === TransactionTypeSchema.enum.Income) {
      return false;
    }
    // 只有一个支付方式时不可编辑
    return availablePaymentMethods.value.length > 1;
  });

  return {
    availablePaymentMethods,
    isPaymentMethodEditable,
  };
}
