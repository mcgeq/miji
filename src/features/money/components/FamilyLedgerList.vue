<script setup lang="ts">
import { Crown, Edit, LogIn, Trash, User, Users } from 'lucide-vue-next';
import { DateUtils } from '@/utils/date';
import { getRoleName } from '../utils/family';
import type { FamilyLedger } from '@/schema/money';

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

const { t } = useI18n();

// 这些函数需要根据实际的数据结构来解析
function getAccountCount(accounts: string): number {
  try {
    return JSON.parse(accounts || '[]').length;
  } catch {
    return 0;
  }
}

function getTransactionCount(transactions: string): number {
  try {
    return JSON.parse(transactions || '[]').length;
  } catch {
    return 0;
  }
}

function getBudgetCount(budgets: string): number {
  try {
    return JSON.parse(budgets || '[]').length;
  } catch {
    return 0;
  }
}
</script>

<template>
  <div class="min-h-50">
    <div v-if="loading" class="text-gray-500 flex-justify-center h-50">
      加载中...
    </div>

    <div v-else-if="ledgers.length === 0" class="text-gray-400 flex-justify-center flex-col h-50">
      <div class="text-6xl mb-4 opacity-50">
        <Users class="wh-5" />
      </div>
      <div class="text-base">
        暂无家庭账本
      </div>
    </div>

    <div v-else class="gap-5 grid" style="grid-template-columns: repeat(auto-fill, minmax(380px, 1fr))">
      <div v-for="ledger in ledgers" :key="ledger.serialNum" class="p-5 card-hover transition-all duration-200">
        <!-- 账本头部信息 -->
        <div class="mb-4 flex items-start justify-between">
          <div class="flex-1">
            <h3 class="text-lg text-gray-800 font-semibold mb-1">
              {{ ledger.description }}
            </h3>
            <div class="text-sm text-gray-600 flex gap-2 items-center">
              <span>基础币种: {{ t(ledger.baseCurrency.code) }}</span>
              <span class="text-gray-400">|</span>
              <span>{{ ledger.members.length }} 位成员</span>
            </div>
          </div>
          <!-- 操作按钮 -->
          <div class="flex gap-1.5 items-center">
            <button class="action-btn" title="进入账本" @click="emit('enter', ledger)">
              <LogIn class="h-4 w-4" />
            </button>
            <button class="action-btn" title="编辑" @click="emit('edit', ledger)">
              <Edit class="h-4 w-4" />
            </button>
            <button class="action-btn-danger" title="删除" @click="emit('delete', ledger.serialNum)">
              <Trash class="h-4 w-4" />
            </button>
          </div>
        </div>

        <!-- 成员列表 -->
        <div class="mb-4">
          <div class="text-sm text-gray-700 font-medium mb-2">
            成员
          </div>
          <div class="flex flex-wrap gap-2">
            <div
              v-for="member in ledger.members.slice(0, 4)" :key="member.serialNum"
              class="text-xs px-2 py-1 rounded-full bg-gray-100 flex gap-1 items-center"
            >
              <Crown v-if="member.isPrimary" class="text-yellow-500 h-3 w-3" />
              <User v-else class="text-gray-500 h-3 w-3" />
              <span>{{ member.name }}</span>
              <span class="text-gray-500">({{ getRoleName(member.role) }})</span>
            </div>
            <div
              v-if="ledger.members.length > 4"
              class="text-xs text-gray-500 px-2 py-1 rounded-full bg-gray-100 flex items-center"
            >
              +{{ ledger.members.length - 4 }}
            </div>
          </div>
        </div>

        <!-- 统计信息 -->
        <div class="pt-3 border-t border-gray-200 gap-3 grid grid-cols-3">
          <div class="text-center">
            <div class="text-xs text-gray-500">
              账户
            </div>
            <div class="text-sm font-medium">
              {{ getAccountCount(ledger.accounts) }}
            </div>
          </div>
          <div class="text-center">
            <div class="text-xs text-gray-500">
              交易
            </div>
            <div class="text-sm font-medium">
              {{ getTransactionCount(ledger.transactions) }}
            </div>
          </div>
          <div class="text-center">
            <div class="text-xs text-gray-500">
              预算
            </div>
            <div class="text-sm font-medium">
              {{ getBudgetCount(ledger.budgets) }}
            </div>
          </div>
        </div>

        <!-- 创建时间 -->
        <div class="mt-3 pt-3 border-t border-gray-200">
          <div class="text-xs text-gray-500">
            创建于 {{ DateUtils.formatDate(ledger.createdAt) }}
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
