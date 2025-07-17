<template>
  <div class="min-h-25">
    <!-- 过滤器区域 -->
    <div class="flex flex-wrap justify-center items-center gap-3 mb-5 p-4 bg-gray-50 rounded-lg">
      <div class="filter-flex-wrap">
        <label class="show-on-desktop text-sm font-medium text-gray-700">交易类型</label>
        <select 
          v-model="filters.transactionType" 
          class="px-3 py-1.5 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
        >
          <option value="">全部</option>
          <option value="Income">收入</option>
          <option value="Expense">支出</option>
          <option value="Transfer">转账</option>
        </select>
      </div>

      <div class="filter-flex-wrap">
        <label class="show-on-desktop text-sm font-medium text-gray-700">账户</label>
        <select 
          v-model="filters.account" 
          class="px-3 py-1.5 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
        >
          <option value="">全部账户</option>
          <option v-for="account in props.accounts" :key="account.serialNum" :value="account.serialNum">
            {{ account.name }}
          </option>
        </select>
      </div>

      <div class="filter-flex-wrap">
        <label class="show-on-desktop text-sm font-medium text-gray-700">分类</label>
        <select 
          v-model="filters.category" 
          class="px-3 py-1.5 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
        >
          <option value="">全部分类</option>
          <option v-for="category in uniqueCategories" :key="category" :value="category">
            {{ category }}
          </option>
        </select>
      </div>

      <div class="filter-flex-wrap">
        <label class="show-on-desktop text-sm font-medium text-gray-700">开始日期</label>
        <input 
          type="date"
          v-model="filters.dateFrom"
          class="px-3 py-1.5 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
        />
      </div>

      <div class="filter-flex-wrap">
        <label class="show-on-desktop text-sm font-medium text-gray-700">结束日期</label>
        <input 
          type="date"
          v-model="filters.dateTo"
          class="px-3 py-1.5 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
        />
      </div>

      <button
        @click="resetFilters"
        class="px-3 py-1.5 bg-gray-200 text-gray-700 rounded-md text-sm hover:bg-gray-300 transition-colors"
      >
        <RotateCcw class="wh-5 mr-1" />
      </button>
    </div>

    <!-- 加载状态 -->
    <div v-if="loading" class="flex-justify-center h-25 text-gray-600">
      加载中...
    </div>

    <!-- 空状态 -->
    <div v-else-if="transactions.length === 0" class="flex-justify-center flex-col h-25 text-#999">
      <div class="text-6xl mb-4 opacity-50">
        <i class="icon-list"></i>
      </div>
      <div class="text-base">
        暂无交易记录
      </div>
    </div>

    <!-- 交易列表 -->
    <div v-else class="border border-gray-200 rounded-lg overflow-hidden mb-6">
      <!-- 表头 - 桌面版 -->
      <div class="hidden md:grid md:grid-cols-[120px_140px_180px_140px_140px_120px] bg-gray-100 border-b border-gray-200 font-semibold text-gray-800">
        <div class="p-4 text-sm grid place-items-end">类型</div>
        <div class="p-4 text-sm grid place-items-end">金额</div>
        <div class="p-4 text-sm grid place-items-end">账户</div>
        <div class="p-4 text-sm grid place-items-end">分类</div>
        <div class="p-4 text-sm grid place-items-end">时间</div>
        <div class="p-4 text-sm grid place-items-end">操作</div>
      </div>

      <!-- 交易行 -->
      <div
        v-for="transaction in transactions"
        :key="transaction.serialNum"
        class="grid grid-cols-1 md:grid-cols-[120px_140px_180px_140px_140px_120px] border-b border-gray-200 hover:bg-gray-50 transition-colors"
      >
        <!-- 类型列 -->
        <div class="p-4 text-sm flex justify-between md:justify-end md:items-center">
          <span class="md:hidden text-gray-600 font-semibold">类型</span>
          <div class="flex items-center gap-2">
            <component :is="getTransactionTypeIcon(transaction.transactionType)" class="w-4 h-4" />
            <span class="font-medium">{{ getTransactionTypeName(transaction.transactionType) }}</span>
          </div>
        </div>

        <!-- 金额列 -->
        <div class="p-4 text-sm flex justify-between md:justify-end md:items-center">
          <span class="md:hidden text-gray-600 font-semibold">金额</span>
          <div
            :class="[
              'font-semibold text-lg',
              transaction.transactionType === TransactionTypeSchema.enum.Income ? 'text-green-600' :
              transaction.transactionType === TransactionTypeSchema.enum.Expense ? 'text-red-500' :
              'text-blue-500'
            ]"
          >
            {{ transaction.transactionType === TransactionTypeSchema.enum.Expense ? '-' : '+' }}{{ formatCurrency(transaction.amount) }}
          </div>
        </div>

        <!-- 账户列 -->
        <div class="p-4 text-sm flex justify-between md:justify-end md:items-center">
          <span class="md:hidden text-gray-600 font-semibold">账户</span>
          <div class="md:text-right">
            <div class="font-medium text-gray-800">{{ transaction.account.name }}</div>
            <div v-if="transaction.description" class="text-xs text-gray-600 mt-1">{{ transaction.description }}</div>
          </div>
        </div>

        <!-- 分类列 -->
        <div class="p-4 text-sm flex justify-between md:justify-end md:items-center">
          <span class="md:hidden text-gray-600 font-semibold">分类</span>
          <div class="md:text-right">
            <span class="font-medium text-gray-800">{{ transaction.category }}</span>
            <div v-if="transaction.subCategory" class="text-xs text-gray-600">/ {{ transaction.subCategory }}</div>
          </div>
        </div>

        <!-- 时间列 -->
        <div class="p-4 text-sm flex justify-between md:justify-end md:items-center">
          <span class="md:hidden text-gray-600 font-semibold">时间</span>
          <div class="md:text-right">
            <div class="font-medium text-gray-800">{{ formatDate(transaction.date) }}</div>
            <div class="text-xs text-gray-600">{{ formatTime(transaction.createdAt) }}</div>
          </div>
        </div>

        <!-- 操作列 -->
        <div class="p-4 flex justify-between md:justify-end items-center">
          <span class="md:hidden text-gray-600 font-semibold">操作</span>
          <div class="flex gap-1">
            <button
              class="money-option-btn hover:(border-green-500 text-green-500)"
              @click="emit('view-details', transaction)"
              title="查看详情"
            >
              <Eye class="w-4 h-4" />
            </button>
            <button
              class="money-option-btn hover:(border-blue-500 text-blue-500)"
              @click="emit('edit', transaction)"
              title="编辑"
            >
              <Edit class="w-4 h-4" />
            </button>
            <button
              class="money-option-btn hover:(border-red-500 text-red-500)"
              @click="emit('delete', transaction.serialNum)"
              title="删除"
            >
              <Trash class="w-4 h-4" />
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- 分页组件 - 移动端优化版 -->
    <div v-if="pagination.totalItems > 0" class="flex justify-center mt-4">
      <!-- 移动端紧凑分页 -->
      <div class="flex md:hidden items-center justify-center gap-2 bg-white p-2 rounded-lg shadow-sm border">
        <!-- 上一页 -->
        <button
          @click="handlePageChange(pagination.currentPage - 1)"
          :disabled="pagination.currentPage <= 1"
          class="p-1.5 rounded-md border border-gray-300 text-gray-600 disabled:opacity-50 disabled:cursor-not-allowed hover:bg-gray-50"
        >
          <ChevronLeft class="w-4 h-4" />
        </button>
        
        <!-- 页码信息 -->
        <span class="text-sm text-gray-700 px-2">
          {{ pagination.currentPage }}/{{ pagination.totalPages }}
        </span>
        
        <!-- 下一页 -->
        <button
          @click="handlePageChange(pagination.currentPage + 1)"
          :disabled="pagination.currentPage >= pagination.totalPages"
          class="p-1.5 rounded-md border border-gray-300 text-gray-600 disabled:opacity-50 disabled:cursor-not-allowed hover:bg-gray-50"
        >
          <ChevronRight class="w-4 h-4" />
        </button>
        
        <!-- 每页大小选择 -->
        <select
          :value="pagination.pageSize"
          @change="handlePageSizeChange(Number(($event.target as HTMLSelectElement).value))"
          class="text-xs border border-gray-300 rounded px-1 py-0.5 bg-white"
        >
          <option value="10">10</option>
          <option value="20">20</option>
          <option value="50">50</option>
          <option value="100">100</option>
        </select>
      </div>

      <!-- 桌面端完整分页 -->
      <div class="hidden md:block">
        <SimplePagination 
          :current-page="pagination.currentPage"
          :total-pages="pagination.totalPages"
          :total-items="pagination.totalItems"
          :page-size="pagination.pageSize"
          :show-page-size="true"
          :page-size-options="[10, 20, 50, 100]"
          :compact="false"
          :responsive="false"
          :show-total="true"
          :show-jump="true"
          :show-first-last="true"
          @page-change="handlePageChange"
          @page-size-change="handlePageSizeChange"
        />
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import {
  Trash,
  Edit,
  Eye,
  TrendingUp,
  TrendingDown,
  Repeat,
  RotateCcw,
  ChevronLeft,
  ChevronRight,
} from 'lucide-vue-next';
import {TransactionType, TransactionTypeSchema} from '@/schema/common';
import {TransactionWithAccount, Account} from '@/schema/money';
import {formatDate} from '@/utils/date';
import {formatCurrency} from '../utils/money';
import {useMoneyStore} from '@/stores/moneyStore';
import SimplePagination from '@/components/common/SimplePagination.vue';

interface Props {
  accounts: Account[];
}

const props = defineProps<Props>();

const emit = defineEmits<{
  edit: [transaction: TransactionWithAccount];
  delete: [serialNum: string];
  'view-details': [transaction: TransactionWithAccount];
}>();

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
const resetFilters = () => {
  filters.value = {
    transactionType: '',
    account: '',
    category: '',
    dateFrom: '',
    dateTo: '',
  };
  pagination.value.currentPage = 1;
  loadTransactions();
};

// 获取唯一分类
const uniqueCategories = computed(() => {
  const categories = transactions.value.map(
    (transaction) => transaction.category,
  );
  return [...new Set(categories)].filter(Boolean);
});

// 加载交易数据
const loadTransactions = async () => {
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
  } catch (error) {
    console.error('加载交易数据失败:', error);
    transactions.value = [];
    pagination.value.totalItems = 0;
    pagination.value.totalPages = 0;
  } finally {
    loading.value = false;
  }
};

// 处理页码变化
const handlePageChange = (page: number) => {
  pagination.value.currentPage = page;
  loadTransactions();
};

// 处理页面大小变化
const handlePageSizeChange = (pageSize: number) => {
  pagination.value.pageSize = pageSize;
  pagination.value.currentPage = 1; // 重置到第一页
  loadTransactions();
};

// 监听过滤器变化，重置到第一页并重新加载数据
watch(
  filters,
  () => {
    pagination.value.currentPage = 1;
    loadTransactions();
  },
  {deep: true},
);

// 原有的方法
const getTransactionTypeIcon = (type: TransactionType) => {
  const icons = {
    Income: TrendingUp,
    Expense: TrendingDown,
    Transfer: Repeat,
  };
  return icons[type] || 'icon-list';
};

const getTransactionTypeName = (type: TransactionType) => {
  const names = {
    Income: '收入',
    Expense: '支出',
    Transfer: '转账',
  };
  return names[type] || '未知';
};

const formatTime = (dateStr: string) => {
  return new Date(dateStr).toLocaleTimeString('zh-CN', {
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  });
};

// 组件挂载时加载数据
onMounted(() => {
  loadTransactions();
});

// 暴露刷新方法给父组件
defineExpose({
  refresh: loadTransactions,
});
</script>

<style scoped lang="postcss">
.money-option-btn {
  @apply p-1.5 border border-gray-300 rounded-md text-gray-600 hover:bg-gray-50 transition-colors;
}
</style>
