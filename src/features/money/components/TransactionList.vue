<script setup lang="ts">
import {
  ChevronLeft,
  ChevronRight,
  Edit,
  Eye,
  Repeat,
  RotateCcw,
  Trash,
  TrendingDown,
  TrendingUp,
} from 'lucide-vue-next';
import SimplePagination from '@/components/common/SimplePagination.vue';
import { TransactionTypeSchema } from '@/schema/common';
import { useMoneyStore } from '@/stores/moneyStore';
import { DateUtils } from '@/utils/date';
import { Lg } from '@/utils/debugLog';
import { formatCurrency } from '../utils/money';
import type { TransactionType } from '@/schema/common';
import type { Account, TransactionWithAccount } from '@/schema/money';

interface Props {
  accounts: Account[];
}

const props = defineProps<Props>();

const emit = defineEmits<{
  edit: [transaction: TransactionWithAccount];
  delete: [serialNum: string];
  viewDetails: [transaction: TransactionWithAccount];
}>();

const { t } = useI18n();
const moneyStore = useMoneyStore();

// 数据状态
const loading = ref(false);
const transactions = ref<TransactionWithAccount[]>([]);

// 过滤器状态
const filters = ref({
  transactionType: '',
  account: '',
  category: '',
  dateFrom: '',
  dateTo: '',
});

// 分页状态
const pagination = ref({
  currentPage: 1,
  totalPages: 1,
  totalItems: 0,
  pageSize: 20,
});

// 重置过滤器
function resetFilters() {
  filters.value = {
    transactionType: '',
    account: '',
    category: '',
    dateFrom: '',
    dateTo: '',
  };
  pagination.value.currentPage = 1;
  loadTransactions();
}

// 获取唯一分类
const uniqueCategories = computed(() => {
  const categories = transactions.value.map(
    transaction => transaction.category,
  );
  return [...new Set(categories)].filter(Boolean);
});

// 加载交易数据
async function loadTransactions() {
  loading.value = true;
  try {
    const params: any = {
      page: pagination.value.currentPage,
      pageSize: pagination.value.pageSize,
    };

    // 添加过滤条件
    if (filters.value.transactionType) {
      params.type = filters.value.transactionType;
    }
    if (filters.value.account) {
      params.accountSerialNum = filters.value.account;
    }
    if (filters.value.category) {
      params.category = filters.value.category;
    }
    if (filters.value.dateFrom) {
      params.dateFrom = filters.value.dateFrom;
    }
    if (filters.value.dateTo) {
      params.dateTo = filters.value.dateTo;
    }

    const result = await moneyStore.getTransactions(params);
    transactions.value = result.items;
    pagination.value.totalItems = result.total;
    pagination.value.totalPages = Math.ceil(
      result.total / pagination.value.pageSize,
    );
  }
  catch (error) {
    transactions.value = [];
    pagination.value.totalItems = 0;
    pagination.value.totalPages = 0;
    Lg.e('Transaction', error);
  }
  finally {
    loading.value = false;
  }
}

// 处理页码变化
function handlePageChange(page: number) {
  pagination.value.currentPage = page;
  loadTransactions();
}

// 处理页面大小变化
function handlePageSizeChange(pageSize: number) {
  pagination.value.pageSize = pageSize;
  pagination.value.currentPage = 1; // 重置到第一页
  loadTransactions();
}

// 监听过滤器变化，重置到第一页并重新加载数据
watch(
  filters,
  () => {
    pagination.value.currentPage = 1;
    loadTransactions();
  },
  { deep: true },
);

// 原有的方法
function getTransactionTypeIcon(type: TransactionType) {
  const icons = {
    Income: TrendingUp,
    Expense: TrendingDown,
    Transfer: Repeat,
  };
  return icons[type] || 'icon-list';
}

function getTransactionTypeName(type: TransactionType) {
  const names = {
    Income: t('financial.transaction.income'),
    Expense: t('financial.transaction.expense'),
    Transfer: t('financial.transaction.transfer'),
  };
  return names[type] || t('financial.transaction.unknown');
}

function formatTime(dateStr: string) {
  return new Date(dateStr).toLocaleTimeString('zh-CN', {
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  });
}

// 组件挂载时加载数据
onMounted(() => {
  loadTransactions();
});

// 暴露刷新方法给父组件
defineExpose({
  refresh: loadTransactions,
});
</script>

<template>
  <div class="min-h-25">
    <!-- 过滤器区域 -->
    <div class="mb-5 flex flex-wrap items-center justify-center gap-3 rounded-lg bg-gray-50 p-4">
      <div class="filter-flex-wrap">
        <label class="show-on-desktop text-sm text-gray-700 font-medium">{{ t('financial.transaction.transType')
        }}</label>
        <select
          v-model="filters.transactionType"
          class="border border-gray-300 rounded-md px-3 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
        >
          <option value="">
            {{ t('common.actions.all') }}
          </option>
          <option value="Income">
            {{ t('financial.transaction.income') }}
          </option>
          <option value="Expense">
            {{ t('financial.transaction.expense') }}
          </option>
          <option value="Transfer">
            {{ t('financial.transaction.transfer') }}
          </option>
        </select>
      </div>

      <div class="filter-flex-wrap">
        <label class="show-on-desktop text-sm text-gray-700 font-medium">{{ t('financial.account.account') }}</label>
        <select
          v-model="filters.account"
          class="border border-gray-300 rounded-md px-3 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
        >
          <option value="">
            {{ t('common.actions.all') }}{{ t('financial.account.account') }}
          </option>
          <option v-for="account in props.accounts" :key="account.serialNum" :value="account.serialNum">
            {{ account.name }}
          </option>
        </select>
      </div>

      <div class="filter-flex-wrap">
        <label class="show-on-desktop text-sm text-gray-700 font-medium">{{ t('categories.category') }}</label>
        <select
          v-model="filters.category"
          class="border border-gray-300 rounded-md px-3 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
        >
          <option value="">
            {{ t('categories.allCategory') }}
          </option>
          <option v-for="category in uniqueCategories" :key="category" :value="category">
            {{ category }}
          </option>
        </select>
      </div>

      <div class="filter-flex-wrap">
        <label class="show-on-desktop text-sm text-gray-700 font-medium">{{ t('date.startDate') }}</label>
        <input
          v-model="filters.dateFrom" type="date"
          class="border border-gray-300 rounded-md px-3 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
        >
      </div>

      <div class="filter-flex-wrap">
        <label class="show-on-desktop text-sm text-gray-700 font-medium">{{ t('date.endDate') }}</label>
        <input
          v-model="filters.dateTo" type="date"
          class="border border-gray-300 rounded-md px-3 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
        >
      </div>

      <button
        class="rounded-md bg-gray-200 px-3 py-1.5 text-sm text-gray-700 transition-colors hover:bg-gray-300"
        @click="resetFilters"
      >
        <RotateCcw class="mr-1 wh-5" />
      </button>
    </div>

    <!-- 加载状态 -->
    <div v-if="loading" class="h-25 flex-justify-center text-gray-600">
      {{ t('common.loading') }}
    </div>

    <!-- 空状态 -->
    <div v-else-if="transactions.length === 0" class="h-25 flex-justify-center flex-col text-#999">
      <div class="mb-4 text-6xl opacity-50">
        <i class="icon-list" />
      </div>
      <div class="text-base">
        暂无交易记录
      </div>
    </div>

    <!-- 交易列表 -->
    <div v-else class="mb-6 overflow-hidden border border-gray-200 rounded-lg">
      <!-- 表头 - 桌面版 -->
      <div
        class="hidden border-b border-gray-200 bg-gray-100 text-gray-800 font-semibold md:grid md:grid-cols-[120px_140px_180px_140px_140px_120px]"
      >
        <div class="grid place-items-end p-4 text-sm">
          {{ t('common.misc.types') }}
        </div>
        <div class="grid place-items-end p-4 text-sm">
          {{ t('financial.money') }}
        </div>
        <div class="grid place-items-end p-4 text-sm">
          {{ t('financial.account.account') }}
        </div>
        <div class="grid place-items-end p-4 text-sm">
          {{ t('categories.category') }}
        </div>
        <div class="grid place-items-end p-4 text-sm">
          {{ t('date.date') }}
        </div>
        <div class="grid place-items-end p-4 text-sm">
          {{ t('common.misc.options') }}
        </div>
      </div>

      <!-- 交易行 -->
      <div
        v-for="transaction in transactions" :key="transaction.serialNum"
        class="grid grid-cols-1 border-b border-gray-200 transition-colors md:grid-cols-[120px_140px_180px_140px_140px_120px] hover:bg-gray-50"
      >
        <!-- 类型列 -->
        <div class="flex justify-between p-4 text-sm md:items-center md:justify-end">
          <span class="text-gray-600 font-semibold md:hidden">{{ t('categories.category') }}</span>
          <div class="flex items-center gap-2">
            <component :is="getTransactionTypeIcon(transaction.transactionType)" class="h-4 w-4" />
            <span class="font-medium">{{ getTransactionTypeName(transaction.transactionType) }}</span>
          </div>
        </div>

        <!-- 金额列 -->
        <div class="flex justify-between p-4 text-sm md:items-center md:justify-end">
          <span class="text-gray-600 font-semibold md:hidden">{{ t('financial.money') }}</span>
          <div
            class="text-lg font-semibold" :class="[
              transaction.transactionType === TransactionTypeSchema.enum.Income ? 'text-green-600'
              : transaction.transactionType === TransactionTypeSchema.enum.Expense ? 'text-red-500'
                : 'text-blue-500',
            ]"
          >
            {{ transaction.transactionType === TransactionTypeSchema.enum.Expense ? '-' : '+' }}{{
              formatCurrency(transaction.amount) }}
          </div>
        </div>

        <!-- 账户列 -->
        <div class="flex justify-between p-4 text-sm md:items-center md:justify-end">
          <span class="text-gray-600 font-semibold md:hidden">{{ t('financial.account.account') }}</span>
          <div class="md:text-right">
            <div class="text-gray-800 font-medium">
              {{ transaction.account.name }}
            </div>
            <div v-if="transaction.description" class="mt-1 text-xs text-gray-600">
              {{ transaction.description }}
            </div>
          </div>
        </div>

        <!-- 分类列 -->
        <div class="flex justify-between p-4 text-sm md:items-center md:justify-end">
          <span class="text-gray-600 font-semibold md:hidden">{{ t('categories.category') }}</span>
          <div class="md:text-right">
            <span class="text-gray-800 font-medium">{{ transaction.category }}</span>
            <div v-if="transaction.subCategory" class="text-xs text-gray-600">
              / {{ transaction.subCategory }}
            </div>
          </div>
        </div>

        <!-- 时间列 -->
        <div class="flex justify-between p-4 text-sm md:items-center md:justify-end">
          <span class="text-gray-600 font-semibold md:hidden">{{ t('date.date') }}</span>
          <div class="md:text-right">
            <div class="text-gray-800 font-medium">
              {{ DateUtils.formatDate(transaction.date) }}
            </div>
            <div class="text-xs text-gray-600">
              {{ formatTime(transaction.createdAt) }}
            </div>
          </div>
        </div>

        <!-- 操作列 -->
        <div class="flex items-center justify-between p-4 md:justify-end">
          <span class="text-gray-600 font-semibold md:hidden">{{ t('common.misc.options') }}</span>
          <div class="flex gap-1">
            <button
              class="money-option-btn hover:(border-green-500 text-green-500)"
              :title="t('common.actions.view')" @click="emit('viewDetails', transaction)"
            >
              <Eye class="h-4 w-4" />
            </button>
            <button
              class="money-option-btn hover:(border-blue-500 text-blue-500)" :title="t('common.actions.edit')"
              @click="emit('edit', transaction)"
            >
              <Edit class="h-4 w-4" />
            </button>
            <button
              class="money-option-btn hover:(border-red-500 text-red-500)"
              :title="t('common.actions.delete')" @click="emit('delete', transaction.serialNum)"
            >
              <Trash class="h-4 w-4" />
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- 分页组件 - 移动端优化版 -->
    <div v-if="pagination.totalItems > 0" class="mt-4 flex justify-center">
      <!-- 移动端紧凑分页 -->
      <div class="flex items-center justify-center gap-2 border rounded-lg bg-white p-2 shadow-sm md:hidden">
        <!-- 上一页 -->
        <button
          :disabled="pagination.currentPage <= 1" class="border border-gray-300 rounded-md p-1.5 text-gray-600 disabled:cursor-not-allowed hover:bg-gray-50 disabled:opacity-50"
          @click="handlePageChange(pagination.currentPage - 1)"
        >
          <ChevronLeft class="h-4 w-4" />
        </button>

        <!-- 页码信息 -->
        <span class="px-2 text-sm text-gray-700">
          {{ pagination.currentPage }}/{{ pagination.totalPages }}
        </span>

        <!-- 下一页 -->
        <button
          :disabled="pagination.currentPage >= pagination.totalPages"
          class="border border-gray-300 rounded-md p-1.5 text-gray-600 disabled:cursor-not-allowed hover:bg-gray-50 disabled:opacity-50"
          @click="handlePageChange(pagination.currentPage + 1)"
        >
          <ChevronRight class="h-4 w-4" />
        </button>

        <!-- 每页大小选择 -->
        <select
          :value="pagination.pageSize"
          class="border border-gray-300 rounded bg-white px-1 py-0.5 text-xs"
          @change="handlePageSizeChange(Number(($event.target as HTMLSelectElement).value))"
        >
          <option value="10">
            10
          </option>
          <option value="20">
            20
          </option>
          <option value="50">
            50
          </option>
          <option value="100">
            100
          </option>
        </select>
      </div>

      <!-- 桌面端完整分页 -->
      <div class="hidden md:block">
        <SimplePagination
          :current-page="pagination.currentPage" :total-pages="pagination.totalPages"
          :total-items="pagination.totalItems" :page-size="pagination.pageSize" :show-page-size="true"
          :page-size-options="[10, 20, 50, 100]" :compact="false" :responsive="false" :show-total="false"
          :show-jump="true" :show-first-last="true" @page-change="handlePageChange"
          @page-size-change="handlePageSizeChange"
        />
      </div>
    </div>
  </div>
</template>

<style scoped lang="postcss">
.money-option-btn {
  @apply p-1.5 border border-gray-300 rounded-md text-gray-600 hover:bg-gray-50 transition-colors;
}
</style>
