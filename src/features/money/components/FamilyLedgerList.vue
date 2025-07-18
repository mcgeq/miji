<template>
  <div class="min-h-50">
    <div v-if="loading" class="flex-justify-center h-50 text-gray-500">加载中...</div>

    <div v-else-if="ledgers.length === 0" class="flex-justify-center flex-col h-50 text-gray-400">
      <div class="text-6xl mb-4 opacity-50">
        <Users class="wh-5" />
      </div>
      <div class="text-base">暂无家庭账本</div>
    </div>

    <div v-else class="grid gap-5" style="grid-template-columns: repeat(auto-fill, minmax(380px, 1fr))">
      <div v-for="ledger in ledgers" :key="ledger.serialNum" class="card-hover p-5 transition-all duration-200">
        <!-- 账本头部信息 -->
        <div class="flex justify-between items-start mb-4">
          <div class="flex-1">
            <h3 class="text-lg font-semibold text-gray-800 mb-1">{{ ledger.description }}</h3>
            <div class="flex items-center gap-2 text-sm text-gray-600">
              <span>基础币种: {{ ledger.baseCurrency.nameZh }}</span>
              <span class="text-gray-400">|</span>
              <span>{{ ledger.members.length }} 位成员</span>
            </div>
          </div>
          <!-- 操作按钮 -->
          <div class="flex items-center gap-1.5">
            <button class="action-btn" @click="emit('enter', ledger)" title="进入账本">
              <LogIn class="w-4 h-4" />
            </button>
            <button class="action-btn" @click="emit('edit', ledger)" title="编辑">
              <Edit class="w-4 h-4" />
            </button>
            <button class="action-btn-danger" @click="emit('delete', ledger.serialNum)" title="删除">
              <Trash class="w-4 h-4" />
            </button>
          </div>
        </div>

        <!-- 成员列表 -->
        <div class="mb-4">
          <div class="text-sm font-medium text-gray-700 mb-2">成员</div>
          <div class="flex flex-wrap gap-2">
            <div v-for="member in ledger.members.slice(0, 4)" :key="member.serialNum"
              class="flex items-center gap-1 px-2 py-1 bg-gray-100 rounded-full text-xs">
              <Crown v-if="member.isPrimary" class="w-3 h-3 text-yellow-500" />
              <User v-else class="w-3 h-3 text-gray-500" />
              <span>{{ member.name }}</span>
              <span class="text-gray-500">({{ getRoleName(member.role) }})</span>
            </div>
            <div v-if="ledger.members.length > 4"
              class="flex items-center px-2 py-1 bg-gray-100 rounded-full text-xs text-gray-500">
              +{{ ledger.members.length - 4 }}
            </div>
          </div>
        </div>

        <!-- 统计信息 -->
        <div class="grid grid-cols-3 gap-3 pt-3 border-t border-gray-200">
          <div class="text-center">
            <div class="text-xs text-gray-500">账户</div>
            <div class="text-sm font-medium">{{ getAccountCount(ledger.accounts) }}</div>
          </div>
          <div class="text-center">
            <div class="text-xs text-gray-500">交易</div>
            <div class="text-sm font-medium">{{ getTransactionCount(ledger.transactions) }}</div>
          </div>
          <div class="text-center">
            <div class="text-xs text-gray-500">预算</div>
            <div class="text-sm font-medium">{{ getBudgetCount(ledger.budgets) }}</div>
          </div>
        </div>

        <!-- 创建时间 -->
        <div class="mt-3 pt-3 border-t border-gray-200">
          <div class="text-xs text-gray-500">
            创建于 {{ formatDate(ledger.createdAt) }}
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { Crown, Edit, LogIn, Trash, User, Users } from 'lucide-vue-next';
import { FamilyLedger } from '@/schema/money';
import type { UserRole } from '@/schema/userRole';
import { formatDate } from '@/utils/date';

interface Props {
  ledgers: FamilyLedger[];
  loading: boolean;
}

defineProps<Props>();

const emit = defineEmits<{
  enter: [ledger: FamilyLedger];
  edit: [ledger: FamilyLedger];
  delete: [serialNum: string];
}>();

const getRoleName = (role: UserRole): string => {
  const roleNames: Record<UserRole, string> = {
    Owner: '所有者',
    Admin: '管理员',
    User: '用户',
    Moderator: '协调员',
    Editor: '编辑者',
    Guest: '访客',
    Developer: '开发者',
  };
  return roleNames[role] || '未知';
};

// 这些函数需要根据实际的数据结构来解析
const getAccountCount = (accounts: string): number => {
  try {
    return JSON.parse(accounts || '[]').length;
  } catch {
    return 0;
  }
};

const getTransactionCount = (transactions: string): number => {
  try {
    return JSON.parse(transactions || '[]').length;
  } catch {
    return 0;
  }
};

const getBudgetCount = (budgets: string): number => {
  try {
    return JSON.parse(budgets || '[]').length;
  } catch {
    return 0;
  }
};
</script>
