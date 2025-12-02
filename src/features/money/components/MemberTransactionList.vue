<script setup lang="ts">
import { LucideArrowDown, LucideArrowUp, LucideFilter, LucideSearch } from 'lucide-vue-next';
import { Card, Spinner } from '@/components/ui';
import { MoneyDb } from '@/services/money/money';
import type { Transaction } from '@/schema/money';

interface Props {
  memberSerialNum: string;
}

const props = defineProps<Props>();

const transactions = ref<Transaction[]>([]);
const loading = ref(true);
const searchKeyword = ref('');
const filterType = ref<'all' | 'Income' | 'Expense'>('all');

// 加载交易记录
onMounted(async () => {
  await loadTransactions();
});

async function loadTransactions() {
  loading.value = true;
  try {
    // 获取所有交易，然后筛选包含该成员的交易
    const allTransactions = await MoneyDb.listTransactions();
    transactions.value = allTransactions.filter(transaction => {
      // 检查是否是该成员创建的或参与分摊的
      return transaction.splitMembers?.some(member => member.serialNum === props.memberSerialNum);
    });
  } catch (error) {
    console.error('Failed to load member transactions:', error);
  } finally {
    loading.value = false;
  }
}

// 筛选后的交易列表
const filteredTransactions = computed(() => {
  let result = transactions.value;

  // 按类型筛选
  if (filterType.value !== 'all') {
    result = result.filter(t => t.transactionType === filterType.value);
  }

  // 按关键词搜索
  if (searchKeyword.value) {
    const keyword = searchKeyword.value.toLowerCase();
    result = result.filter(t =>
      t.description?.toLowerCase().includes(keyword) ||
      t.category?.toLowerCase().includes(keyword),
    );
  }

  // 按日期倒序排序
  return result.sort((a, b) =>
    new Date(b.date).getTime() - new Date(a.date).getTime(),
  );
});

// 格式化日期
function formatDate(dateStr: string): string {
  const date = new Date(dateStr);
  return date.toLocaleDateString('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  });
}

// 格式化金额
function formatAmount(amount: number): string {
  return `¥${amount.toFixed(2)}`;
}

// 获取交易类型图标
function getTypeIcon(type: string) {
  return type === 'Income' ? LucideArrowDown : LucideArrowUp;
}
</script>

<template>
  <div class="flex flex-col gap-4">
    <!-- 工具栏 -->
    <div class="flex gap-4 flex-wrap">
      <div class="flex-1 min-w-[200px] relative flex items-center">
        <LucideSearch :size="18" class="absolute left-3 text-gray-400 dark:text-gray-500 pointer-events-none" />
        <input
          v-model="searchKeyword"
          type="text"
          placeholder="搜索交易..."
          class="w-full py-2 pl-10 pr-3 border border-gray-300 dark:border-gray-600 rounded-lg text-sm transition-all bg-white dark:bg-gray-800 text-gray-900 dark:text-white placeholder-gray-400 dark:placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-blue-500 dark:focus:ring-blue-600 focus:border-blue-500 dark:focus:border-blue-600"
        >
      </div>

      <div class="flex items-center gap-2">
        <LucideFilter :size="18" class="text-gray-500 dark:text-gray-400" />
        <select
          v-model="filterType"
          class="px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg text-sm cursor-pointer transition-all bg-white dark:bg-gray-800 text-gray-900 dark:text-white hover:border-blue-500 dark:hover:border-blue-600 focus:outline-none focus:ring-2 focus:ring-blue-500 dark:focus:ring-blue-600"
        >
          <option value="all">
            全部类型
          </option>
          <option value="Income">
            收入
          </option>
          <option value="Expense">
            支出
          </option>
        </select>
      </div>
    </div>

    <!-- 加载状态 -->
    <div v-if="loading" class="flex flex-col items-center gap-2 py-12 text-gray-500 dark:text-gray-400">
      <Spinner size="lg" />
      <span>加载中...</span>
    </div>

    <!-- 交易列表 -->
    <div v-else-if="filteredTransactions.length > 0" class="flex flex-col gap-3">
      <div
        v-for="transaction in filteredTransactions"
        :key="transaction.serialNum"
        class="flex items-center gap-4 p-4 bg-gray-50 dark:bg-gray-900/50 border border-gray-300 dark:border-gray-700 rounded-lg transition-all hover:bg-white dark:hover:bg-gray-800 hover:shadow-sm hover:-translate-y-0.5"
      >
        <div
          class="w-10 h-10 rounded-lg flex items-center justify-center shrink-0" :class="[
            transaction.transactionType === 'Income'
              ? 'bg-green-100 dark:bg-green-900/30 text-green-600 dark:text-green-400'
              : 'bg-red-100 dark:bg-red-900/30 text-red-600 dark:text-red-400',
          ]"
        >
          <component :is="getTypeIcon(transaction.transactionType)" :size="20" />
        </div>

        <div class="flex-1 min-w-0">
          <div class="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-2 sm:gap-4 mb-2">
            <h4 class="text-base font-medium text-gray-900 dark:text-white truncate">
              {{ transaction.description }}
            </h4>
            <span
              class="text-lg font-semibold whitespace-nowrap" :class="[
                transaction.transactionType === 'Income'
                  ? 'text-green-600 dark:text-green-400'
                  : 'text-red-600 dark:text-red-400',
              ]"
            >
              {{ transaction.transactionType === 'Income' ? '+' : '-' }}
              {{ formatAmount(transaction.amount) }}
            </span>
          </div>

          <div class="flex gap-2 sm:gap-4 flex-wrap text-sm text-gray-500 dark:text-gray-400">
            <span>{{ formatDate(transaction.date) }}</span>
            <span class="px-2 py-0.5 bg-gray-200 dark:bg-gray-700 rounded text-gray-700 dark:text-gray-300">{{ transaction.category }}</span>
            <span v-if="transaction.splitMembers && transaction.splitMembers.length > 0" class="px-2 py-0.5 bg-blue-100 dark:bg-blue-900/30 text-blue-800 dark:text-blue-300 rounded font-medium">
              分摊 {{ transaction.splitMembers.length }} 人
            </span>
          </div>
        </div>
      </div>
    </div>

    <!-- 空状态 -->
    <div v-else class="text-center py-12 text-gray-500 dark:text-gray-400">
      <p>暂无交易记录</p>
    </div>

    <!-- 统计信息 -->
    <Card v-if="!loading && filteredTransactions.length > 0" padding="md" class="bg-gray-50 dark:bg-gray-900/50 text-center">
      <span class="text-sm text-gray-600 dark:text-gray-400">共 {{ filteredTransactions.length }} 笔交易</span>
    </Card>
  </div>
</template>
