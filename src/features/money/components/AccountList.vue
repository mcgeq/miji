<template>
  <div class="min-h-50">
    <div v-if="loading" class="flex justify-center items-center h-50 text-gray-500">加载中...</div>

    <div v-else-if="accounts.length === 0" class="flex flex-col items-center justify-center h-50 text-gray-400">
      <div class="text-6xl mb-4 opacity-50">
        <i class="icon-credit-card"></i>
      </div>
      <div class="text-base">暂无账户</div>
    </div>

    <div v-else class="grid gap-5" style="grid-template-columns: repeat(auto-fill, minmax(320px, 1fr))">
      <div v-for="account in accounts" :key="account.serialNum" :class="[
        'bg-white border border-gray-200 rounded-lg p-5 transition-all hover:shadow-md',
        !account.isActive && 'opacity-60 bg-gray-100'
      ]">

        <div class="flex flex-wrap justify-between items-center mb-4 gap-2">
          <!-- 类型图标 + 类型名称 + 账户名称 + 币种-->
          <div class="flex items-center gap-3 text-gray-800">
            <component :is="getAccountTypeIcon(account.type)" class="w-4 h-4 text-blue-500" />
            <span class="text-lg font-semibold text-gray-800">{{ account.name }}</span>
            <span class="text-sm text-gray-700">{{ getAccountTypeName(account.type) }}</span>
            <span class="text-xs text-gray-600">{{ account.currency.code }}</span>
          </div>

          <!-- 操作按钮 -->
          <div class="flex items-center gap-1.5 self-end">
            <button
              class="w-6 h-6 bg-white cursor-pointer flex items-center justify-center transition-all hover:(border-blue-500 text-blue-500)"
              @click="emit('edit', account)" title="编辑">
              <Edit class="w-4 h-4" />
            </button>
            <button
              class="w-6 h-6 bg-white cursor-pointer flex items-center justify-center transition-all hover:(border-blue-500 text-blue-500)"
              @click="emit('toggle-active', account.serialNum)" :title="account.isActive ? '停用' : '启用'">
              <Ban class="w-4 h-4" />
            </button>
            <button
              class="w-6 h-6 bg-white cursor-pointer flex items-center justify-center transition-all hover:(border-red-500 text-red-500)"
              @click="emit('delete', account.serialNum)" title="删除">
              <Trash class="w-4 h-4" />
            </button>
          </div>
        </div>

        <div class="flex items-baseline gap-2 mb-4">
          <span class="text-2xl font-semibold text-gray-800">{{ formatCurrency(account.balance) }}</span>
        </div>

        <div class="border-t border-gray-200 pt-4">
          <div class="flex justify-between mb-2 text-sm">
            <span class="text-gray-500">创建时间：</span>
            <span class="text-gray-800">{{ formatDate(account.createdAt) }}</span>
          </div>
          <div v-if="account.description" class="flex justify-between mb-2 text-sm">
            <span class="text-gray-500">备注：</span>
            <span class="text-gray-800">{{ account.description }}</span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import {
  Trash,
  Edit,
  Ban,
  PiggyBank,
  DollarSign,
  LucideIcon,
  CreditCard,
  TrendingUp,
  Wallet,
  Wallet2,
  Cloud,
} from 'lucide-vue-next';
import { Account, AccountType } from '@/schema/money';
import { formatDate } from '@/utils/date';

interface Props {
  accounts: Account[];
  loading: boolean;
}

defineProps<Props>();

const emit = defineEmits<{
  edit: [account: Account];
  delete: [serialNum: string];
  'toggle-active': [serialNum: string];
}>();

const getAccountTypeIcon = (type: AccountType): LucideIcon => {
  const icons: Record<AccountType, LucideIcon> = {
    Savings: PiggyBank,
    Cash: DollarSign,
    Bank: PiggyBank,
    CreditCard: CreditCard,
    Investment: TrendingUp,
    Alipay: Wallet,
    WeChat: Wallet2,
    CloudQuickPass: Cloud,
    Other: Wallet,
  };
  return icons[type] || Wallet;
};

const getAccountTypeName = (type: AccountType): string => {
  const names: Record<AccountType, string> = {
    Savings: '储蓄账户',
    Cash: '现金',
    Bank: '银行账户',
    CreditCard: '信用卡',
    Investment: '投资账户',
    Alipay: '支付宝',
    WeChat: '微信',
    CloudQuickPass: '云闪付',
    Other: '其他',
  };
  return names[type] || '未知类型';
};

const formatCurrency = (amount: string) => {
  const num = parseFloat(amount);
  return num.toLocaleString('zh-CN', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
};
</script>

<style lang="postcss"></style>
