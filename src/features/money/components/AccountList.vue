<template>
  <div class="min-h-50">
    <!-- 过滤选项区域 -->
    <div class="mb-6 p-4 bg-white rounded-lg shadow-sm border border-gray-200">
      <div class="flex flex-wrap items-center gap-3">
        <!-- 账户状态过滤 -->
        <div class="flex items-center gap-2">
          <div class="flex gap-1">
            <button
              :class="[
                'px-3 py-1.5 text-xs font-medium rounded-full border transition-all',
                activeFilter === 'all' 
                  ? 'bg-blue-500 text-white border-blue-500' 
                  : 'bg-white text-gray-600 border-gray-300 hover:border-blue-400'
              ]"
              @click="setActiveFilter('all')"
            >
              全部 <span class="ml-1 text-xs opacity-75">({{ totalAccounts }})</span>
            </button>
            <button
              :class="[
                'px-3 py-1.5 text-xs font-medium rounded-full border transition-all',
                activeFilter === 'active' 
                  ? 'bg-green-500 text-white border-green-500' 
                  : 'bg-white text-gray-600 border-gray-300 hover:border-green-400'
              ]"
              @click="setActiveFilter('active')"
            >
              <CheckCircle class="w-3 h-3 mr-1" />
              已启用 <span class="ml-1 text-xs opacity-75">({{ activeAccounts }})</span>
            </button>
            <button
              :class="[
                'px-3 py-1.5 text-xs font-medium rounded-full border transition-all',
                activeFilter === 'inactive' 
                  ? 'bg-gray-500 text-white border-gray-500' 
                  : 'bg-white text-gray-600 border-gray-300 hover:border-gray-400'
              ]"
              @click="setActiveFilter('inactive')"
            >
              <XCircle class="w-3 h-3 mr-1" />
              已停用 <span class="ml-1 text-xs opacity-75">({{ inactiveAccounts }})</span>
            </button>
          </div>
        </div>

        <!-- 分隔线 -->
        <div class="w-px h-6 bg-gray-300"></div>

        <!-- 账户类型过滤 -->
        <div class="flex items-center gap-2">
          <span class="text-sm font-medium text-gray-700">类型：</span>
          <select
            v-model="selectedType"
            @change="handleTypeFilter"
            class="px-3 py-1.5 text-xs border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
          >
            <option value="">全部类型</option>
            <option v-for="type in accountTypes" :key="type" :value="type">
              {{ getAccountTypeName(type) }}
            </option>
          </select>
        </div>

        <!-- 分隔线 -->
        <div class="w-px h-6 bg-gray-300"></div>

        <!-- 币种过滤 -->
        <div class="flex items-center gap-2">
          <span class="text-sm font-medium text-gray-700">币种：</span>
          <select
            v-model="selectedCurrency"
            @change="handleCurrencyFilter"
            class="px-3 py-1.5 text-xs border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
          >
            <option value="">全部币种</option>
            <option v-for="currency in currencies" :key="currency" :value="currency">
              {{ currency }}
            </option>
          </select>
        </div>

        <!-- 分隔线 -->
        <div class="w-px h-6 bg-gray-300"></div>

        <!-- 排序选项 -->
        <div class="flex items-center gap-2">
          <span class="text-sm font-medium text-gray-700">排序：</span>
          <select
            v-model="sortBy"
            @change="handleSortChange"
            class="px-3 py-1.5 text-xs border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
          >
            <option value="createdAt">创建时间</option>
            <option value="name">账户名称</option>
            <option value="balance">余额</option>
            <option value="type">账户类型</option>
          </select>
          <button
            @click="toggleSortOrder"
            class="p-1.5 text-gray-600 hover:text-blue-500 transition-colors"
            :title="sortOrder === 'asc' ? '升序' : '降序'"
          >
            <ArrowUpDown class="w-4 h-4" :class="sortOrder === 'desc' && 'rotate-180'" />
          </button>
        </div>

        <!-- 清空过滤器 -->
        <button
          @click="resetFilters"
          class="px-3 py-1.5 bg-gray-200 text-gray-700 rounded-md text-sm hover:bg-gray-300 transition-colors"
        >
          <RotateCcw class="wh-5 mr-1" />
        </button>
      </div>
    </div>

    <!-- 账户列表区域 -->
    <div v-if="loading" class="flex-justify-center h-50 text-gray-500">加载中...</div>

    <div v-else-if="paginatedAccounts.length === 0" class="flex-justify-center flex-col h-50 text-gray-400">
      <div class="text-6xl mb-4 opacity-50">
        <CreditCard class="wh-5" />
      </div>
      <div class="text-base">
        {{ filteredAccounts.length === 0 ? '暂无符合条件的账户' : '暂无账户' }}
      </div>
    </div>

    <div v-else class="grid gap-5 mb-6" style="grid-template-columns: repeat(auto-fill, minmax(320px, 1fr))">
      <div v-for="account in paginatedAccounts"
        :key="account.serialNum"
        :class="[
          'bg-white border rounded-lg p-5 transition-all hover:shadow-md',
          !account.isActive && 'opacity-60 bg-gray-100'
        ]"
        :style="{
          borderColor: account.color || '#E5E7EB'
        }"
      >
        <div class="flex flex-wrap justify-between items-center mb-4 gap-2">
          <!-- 类型图标 + 类型名称 + 账户名称 + 币种-->
          <div class="flex items-center gap-3 text-gray-800">
            <component :is="getAccountTypeIcon(account.type)" class="w-4 h-4 text-blue-500" />
            <span class="text-lg font-semibold text-gray-800">{{ account.name }}</span>
            <span class="text-sm text-gray-700">{{ getAccountTypeName(account.type) }}</span>
            <span class="text-xs text-gray-600">{{ account.currency?.code }}</span>
          </div>

          <!-- 操作按钮 -->
          <div class="flex items-center gap-1.5 self-end">
            <button
              class="money-option-btn hover:(border-green-500 text-green-500)"
              @click="emit('toggle-active', account.serialNum)" 
              :title="account.isActive ? '停用' : '启用'"
            >
              <Ban class="w-4 h-4" />
            </button>
            <button
              class="money-option-btn hover:(border-blue-500 text-blue-500)"
              @click="emit('edit', account)" 
              title="编辑"
            >
              <Edit class="w-4 h-4" />
            </button>
            <button
              class="money-option-btn hover:(border-red-500 text-red-500)"
              @click="emit('delete', account.serialNum)" 
              title="删除"
            >
              <Trash class="w-4 h-4" />
            </button>
          </div>
        </div>

        <div class="flex items-baseline gap-2 mb-4">
          <span class="text-2xl font-semibold text-gray-800">{{ formatCurrency(account.balance)}}</span>
        </div>

        <div class="border-t border-gray-200 pt-4">
          <div class="flex justify-between mb-2 text-sm">
            <span class="text-gray-600">创建时间：</span>
            <span class="text-gray-800">{{ formatDate(account.createdAt) }}</span>
          </div>
          <div v-if="account.description" class="flex justify-between mb-2 text-sm">
            <span class="text-gray-600">备注：</span>
            <span class="text-gray-800">{{ account.description }}</span>
          </div>
        </div>
      </div>
    </div>

    <!-- 分页组件 -->
    <div v-if="totalPages > 1" class="flex justify-center mt-6">
      <SimplePagination
        :current-page="currentPage"
        :total-pages="totalPages"
        :total-items="filteredAccounts.length"
        :page-size="pageSize"
        :show-total="true"
        :show-page-size="true"
        :page-size-options="[4, 8, 12, 20]"
        @page-change="handlePageChange"
        @page-size-change="handlePageSizeChange"
      />
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
  CheckCircle,
  XCircle,
  ArrowUpDown,
  RotateCcw,
} from 'lucide-vue-next';
import {Account, AccountType} from '@/schema/money';
import {formatDate} from '@/utils/date';
import {formatCurrency} from '../utils/money';
import SimplePagination from '@/components/common/SimplePagination.vue';

interface Props {
  accounts: Account[];
  loading: boolean;
}

const props = defineProps<Props>();

const emit = defineEmits<{
  edit: [account: Account];
  delete: [serialNum: string];
  'toggle-active': [serialNum: string];
}>();

// 过滤和分页状态
const activeFilter = ref<'all' | 'active' | 'inactive'>('all');
const selectedType = ref<string>('');
const selectedCurrency = ref<string>('');
const sortBy = ref<'createdAt' | 'name' | 'balance' | 'type'>('createdAt');
const sortOrder = ref<'asc' | 'desc'>('desc');
const currentPage = ref(1);
const pageSize = ref(4);

// 计算统计数据
const totalAccounts = computed(() => props.accounts.length);
const activeAccounts = computed(
  () => props.accounts.filter((account) => account.isActive).length,
);
const inactiveAccounts = computed(
  () => props.accounts.filter((account) => !account.isActive).length,
);

// 获取所有账户类型
const accountTypes = computed(() => {
  const types = new Set(props.accounts.map((account) => account.type));
  return Array.from(types);
});

// 获取所有币种
const currencies = computed(() => {
  const currencies = new Set(
    props.accounts.map((account) => account.currency?.code).filter(Boolean),
  );
  return Array.from(currencies);
});

// 过滤后的账户
const filteredAccounts = computed(() => {
  let filtered = props.accounts;

  // 状态过滤
  if (activeFilter.value === 'active') {
    filtered = filtered.filter((account) => account.isActive);
  } else if (activeFilter.value === 'inactive') {
    filtered = filtered.filter((account) => !account.isActive);
  }

  // 类型过滤
  if (selectedType.value) {
    filtered = filtered.filter(
      (account) => account.type === selectedType.value,
    );
  }

  // 币种过滤
  if (selectedCurrency.value) {
    filtered = filtered.filter(
      (account) => account.currency?.code === selectedCurrency.value,
    );
  }

  // 排序
  filtered.sort((a, b) => {
    let aValue, bValue;

    switch (sortBy.value) {
      case 'name':
        aValue = a.name.toLowerCase();
        bValue = b.name.toLowerCase();
        break;
      case 'balance':
        aValue = a.balance;
        bValue = b.balance;
        break;
      case 'type':
        aValue = a.type;
        bValue = b.type;
        break;
      case 'createdAt':
      default:
        aValue = new Date(a.createdAt).getTime();
        bValue = new Date(b.createdAt).getTime();
        break;
    }

    if (aValue < bValue) return sortOrder.value === 'asc' ? -1 : 1;
    if (aValue > bValue) return sortOrder.value === 'asc' ? 1 : -1;
    return 0;
  });

  return filtered;
});

// 分页后的账户
const paginatedAccounts = computed(() => {
  const start = (currentPage.value - 1) * pageSize.value;
  const end = start + pageSize.value;
  return filteredAccounts.value.slice(start, end);
});

// 总页数
const totalPages = computed(() => {
  return Math.ceil(filteredAccounts.value.length / pageSize.value);
});

// 过滤器方法
const setActiveFilter = (filter: 'all' | 'active' | 'inactive') => {
  activeFilter.value = filter;
  currentPage.value = 1;
};

const handleTypeFilter = () => {
  currentPage.value = 1;
};

const handleCurrencyFilter = () => {
  currentPage.value = 1;
};

const handleSortChange = () => {
  currentPage.value = 1;
};

const toggleSortOrder = () => {
  sortOrder.value = sortOrder.value === 'asc' ? 'desc' : 'asc';
  currentPage.value = 1;
};

const resetFilters = () => {
  activeFilter.value = 'all';
  selectedType.value = '';
  selectedCurrency.value = '';
  sortBy.value = 'createdAt';
  sortOrder.value = 'desc';
  currentPage.value = 1;
};

// 分页方法
const handlePageChange = (page: number) => {
  currentPage.value = page;
};

const handlePageSizeChange = (size: number) => {
  pageSize.value = size;
  currentPage.value = 1;
};

// 监听过滤条件变化，重置页码
watch([activeFilter, selectedType, selectedCurrency], () => {
  currentPage.value = 1;
});

// 图标和名称映射函数
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
</script>

<style lang="postcss">
.money-option-btn {
  @apply inline-flex items-center justify-center w-8 h-8 rounded-lg border border-gray-300 text-gray-600 
         hover:shadow-md transition-all duration-200 bg-white;
}
</style>
