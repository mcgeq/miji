<script setup lang="ts">
import { Card, Spinner } from '@/components/ui';
import { DateUtils } from '@/utils/date';
import type { FamilyLedger } from '@/schema/money';

interface Props {
  ledgers: FamilyLedger[];
  loading: boolean;
}

const props = defineProps<Props>();
const emit = defineEmits<{
  enter: [ledger: FamilyLedger];
  edit: [ledger: FamilyLedger];
  delete: [serialNum: string];
}>();
const { ledgers, loading } = toRefs(props);

// 注意：accounts, transactions, budgets 现在是整数类型，不再是 JSON 字符串
</script>

<template>
  <div class="w-full min-h-[300px] h-full">
    <!-- 加载状态 -->
    <div v-if="loading" class="flex justify-center items-center h-full min-h-[200px] text-gray-500 dark:text-gray-400 gap-2">
      <Spinner size="md" />
      <span>加载中...</span>
    </div>

    <!-- 空状态 -->
    <div v-else-if="ledgers.length === 0" class="flex flex-col justify-center items-center h-full min-h-[200px] text-gray-400 dark:text-gray-600">
      <div class="text-6xl mb-4 opacity-50">
        <LucideUsers :size="60" />
      </div>
      <div class="text-base">
        暂无家庭账本
      </div>
    </div>

    <!-- 账本网格 -->
    <div v-else class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-5 w-full">
      <Card v-for="ledger in ledgers" :key="ledger.serialNum" padding="lg" hoverable class="transition-all duration-200">
        <!-- 账本头部信息 -->
        <div class="flex flex-col sm:flex-row items-start justify-between mb-4 gap-3">
          <div class="flex-1">
            <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-1">
              {{ ledger.name || ledger.description || '未命名账本' }}
            </h3>
            <div class="text-sm text-gray-600 dark:text-gray-400 flex gap-2 items-center">
              <span>币种: {{ ledger.baseCurrency }}</span>
            </div>
          </div>
          <!-- 操作按钮 -->
          <div class="flex gap-1.5 items-center self-end sm:self-auto">
            <button
              class="p-2 rounded-md border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-300 transition-all hover:bg-gray-100 dark:hover:bg-gray-700 hover:border-gray-400 dark:hover:border-gray-500"
              title="进入账本"
              @click="emit('enter', ledger)"
            >
              <LucideLogIn :size="16" />
            </button>
            <button
              class="p-2 rounded-md border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-300 transition-all hover:bg-gray-100 dark:hover:bg-gray-700 hover:border-gray-400 dark:hover:border-gray-500"
              title="编辑"
              @click="emit('edit', ledger)"
            >
              <LucideEdit :size="16" />
            </button>
            <button
              class="p-2 rounded-md border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800 text-red-600 dark:text-red-400 transition-all hover:bg-red-50 dark:hover:bg-red-900/20 hover:border-red-400 dark:hover:border-red-500"
              title="删除"
              @click="emit('delete', ledger.serialNum)"
            >
              <LucideTrash :size="16" />
            </button>
          </div>
        </div>

        <!-- 成员列表 -->
        <div class="mb-4">
          <div class="flex flex-wrap gap-2">
            <div class="text-xs px-2 py-1 rounded-full bg-gray-100 dark:bg-gray-800 flex gap-1 items-center">
              <LucideUser :size="12" class="text-gray-500 dark:text-gray-400" />
              <span>{{ ledger.members || 0 }} 位成员</span>
            </div>
          </div>
        </div>

        <!-- 统计信息 -->
        <div class="pt-3 border-t border-gray-200 dark:border-gray-700 grid grid-cols-3 gap-3">
          <div class="text-center">
            <div class="text-xs text-gray-500 dark:text-gray-400">
              账户
            </div>
            <div class="text-sm font-medium text-gray-900 dark:text-white">
              {{ ledger.accounts || 0 }}
            </div>
          </div>
          <div class="text-center">
            <div class="text-xs text-gray-500 dark:text-gray-400">
              交易
            </div>
            <div class="text-sm font-medium text-gray-900 dark:text-white">
              {{ ledger.transactions || 0 }}
            </div>
          </div>
          <div class="text-center">
            <div class="text-xs text-gray-500 dark:text-gray-400">
              预算
            </div>
            <div class="text-sm font-medium text-gray-900 dark:text-white">
              {{ ledger.budgets || 0 }}
            </div>
          </div>
        </div>

        <!-- 创建时间 -->
        <div class="mt-3 pt-3 border-t border-gray-200 dark:border-gray-700">
          <div class="text-xs text-gray-500 dark:text-gray-400">
            创建于 {{ DateUtils.formatDate(ledger.createdAt) }}
          </div>
        </div>
      </Card>
    </div>
  </div>
</template>
