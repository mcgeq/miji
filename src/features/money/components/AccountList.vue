<script setup lang="ts">
import {
  ArrowUpDown,
  Ban,
  Cloud,
  CreditCard,
  DollarSign,
  Edit,
  Eye,
  EyeOff,
  MoreHorizontal,
  PiggyBank,
  RotateCcw,
  Trash,
  TrendingUp,
  Wallet,
  Wallet2,
} from 'lucide-vue-next';
import { Button, Card, Pagination } from '@/components/ui';
import { useAccountStore, useMoneyConfigStore } from '@/stores/money';
import { useAccountFilters } from '../composables/useAccountFilters';
import { formatCurrency } from '../utils/money';
import type { Account, AccountType } from '@/schema/money';
import type {
  LucideIcon,
} from 'lucide-vue-next';

interface Props {
  accounts: Account[];
  loading: boolean;
}

const props = defineProps<Props>();

const emit = defineEmits<{
  edit: [account: Account];
  delete: [serialNum: string];
  toggleActive: [serialNum: string, isActive: boolean];
}>();

const { t } = useI18n();
const accountStore = useAccountStore();
const moneyConfigStore = useMoneyConfigStore();

const mediaQueries = useMediaQueriesStore();

// 检查账户金额是否隐藏（全局 + 单个）
function isAccountAmountHidden(serialNum: string) {
  return moneyConfigStore.globalAmountHidden || accountStore.isAccountAmountHidden(serialNum);
}
// 移动端过滤展开状态
const showMoreFilters = ref(!mediaQueries.isMobile);

// 过滤和分页状态
const {
  filters,
  accountTypes,
  currencies,
  pagination,
  activeAccounts,
  inactiveAccounts,
  resetFilters,
  setActiveFilter,
  toggleSortOrder,
} = useAccountFilters(() => props.accounts, 4);

// 切换过滤器显示状态
function toggleFilters() {
  showMoreFilters.value = !showMoreFilters.value;
}

function handleTypeFilter() {
  pagination.currentPage.value = 1;
}

function handleCurrencyFilter() {
  pagination.currentPage.value = 1;
}

function handleSortChange() {
  pagination.currentPage.value = 1;
}

// 分页方法
function handlePageChange(page: number) {
  pagination.currentPage.value = page;
}

function handlePageSizeChange(size: number) {
  pagination.pageSize.value = size;
  pagination.currentPage.value = 1;
}

// 图标和名称映射函数
function getAccountTypeIcon(type: AccountType): LucideIcon {
  const icons: Record<AccountType, LucideIcon> = {
    Savings: PiggyBank,
    Cash: DollarSign,
    Bank: PiggyBank,
    CreditCard,
    Investment: TrendingUp,
    Alipay: Wallet,
    WeChat: Wallet2,
    CloudQuickPass: Cloud,
    Other: Wallet,
  };
  return icons[type] || Wallet;
}

function getAccountTypeName(type: AccountType): string {
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
}

// 切换账户金额可见性
function toggleAccountAmountVisibility(accountSerialNum: string) {
  accountStore.toggleAccountAmountHidden(accountSerialNum);
}
</script>

<template>
  <div class="space-y-4">
    <!-- 过滤选项区域 -->
    <div class="bg-white dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-700 p-4">
      <div class="flex flex-wrap gap-3 items-center">
        <!-- 账户状态过滤 -->
        <div class="flex gap-2">
          <button
            class="px-3 py-1.5 text-xs font-medium rounded-full border transition-all"
            :class="filters.status === 'all'
              ? 'bg-blue-600 text-white border-blue-600'
              : 'bg-gray-100 dark:bg-gray-700 text-gray-600 dark:text-gray-400 border-gray-300 dark:border-gray-600 hover:border-gray-400 dark:hover:border-gray-500'"
            @click="setActiveFilter('all')"
          >
            {{ t('common.actions.all') }}<span class="ml-1 opacity-75">[{{ pagination.totalItems.value }}]</span>
          </button>
          <button
            class="px-3 py-1.5 text-xs font-medium rounded-full border transition-all"
            :class="filters.status === 'active'
              ? 'bg-green-600 text-white border-green-600'
              : 'bg-gray-100 dark:bg-gray-700 text-gray-600 dark:text-gray-400 border-gray-300 dark:border-gray-600 hover:border-gray-400 dark:hover:border-gray-500'"
            @click="setActiveFilter('active')"
          >
            {{ t('common.status.active') }}<span class="ml-1 opacity-75">({{ activeAccounts }})</span>
          </button>
          <button
            class="px-3 py-1.5 text-xs font-medium rounded-full border transition-all"
            :class="filters.status === 'inactive'
              ? 'bg-gray-600 text-white border-gray-600'
              : 'bg-gray-100 dark:bg-gray-700 text-gray-600 dark:text-gray-400 border-gray-300 dark:border-gray-600 hover:border-gray-400 dark:hover:border-gray-500'"
            @click="setActiveFilter('inactive')"
          >
            {{ t('common.status.inactive') }}<span class="ml-1 opacity-75">({{ inactiveAccounts }})</span>
          </button>
        </div>

        <!-- 移动端展开的额外过滤器 -->
        <template v-if="showMoreFilters">
          <!-- 账户类型过滤 -->
          <select
            v-model="filters.type"
            class="px-3 py-1.5 text-sm rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
            @change="handleTypeFilter"
          >
            <option value="">
              {{ t('common.actions.all') }}{{ t('common.misc.types') }}
            </option>
            <option v-for="type in accountTypes" :key="type" :value="type">
              {{ getAccountTypeName(type) }}
            </option>
          </select>

          <!-- 币种过滤 -->
          <select
            v-model="filters.currency"
            class="px-3 py-1.5 text-sm rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
            @change="handleCurrencyFilter"
          >
            <option value="">
              {{ t('common.actions.all') }}{{ t('financial.currency') }}
            </option>
            <option v-for="currency in currencies" :key="currency" :value="currency">
              {{ currency }}
            </option>
          </select>

          <!-- 排序选项 -->
          <div class="flex gap-2">
            <select
              v-model="filters.sortBy"
              class="px-3 py-1.5 text-sm rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
              @change="handleSortChange"
            >
              <option value="updatedAt">
                {{ t('date.updatedDate') }}
              </option>
              <option value="createdAt">
                {{ t('date.createDate') }}
              </option>
              <option value="name">
                {{ t('financial.account.name') }}
              </option>
              <option value="balance">
                {{ t('financial.balance') }}
              </option>
              <option value="type">
                {{ t('financial.account.type') }}
              </option>
            </select>
            <button
              class="px-3 py-1.5 rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 hover:bg-gray-50 dark:hover:bg-gray-600 transition-colors"
              :title="filters.sortOrder === 'asc' ? t('common.sorting.asc') : t('common.sorting.desc')"
              @click="toggleSortOrder"
            >
              <ArrowUpDown :size="16" :class="filters.sortOrder === 'desc' && 'rotate-180'" class="text-gray-600 dark:text-gray-300 transition-transform" />
            </button>
          </div>
        </template>

        <!-- 操作按钮组 -->
        <div class="flex gap-2 ml-auto">
          <Button
            variant="secondary"
            size="sm"
            :icon="MoreHorizontal"
            @click="toggleFilters"
          />
          <Button
            variant="secondary"
            size="sm"
            :icon="RotateCcw"
            @click="resetFilters"
          />
        </div>
      </div>
    </div>

    <!-- 账户列表区域 -->
    <div
      v-if="loading"
      class="flex items-center justify-center h-48 text-gray-500 dark:text-gray-400"
    >
      {{ t('common.loading') }}
    </div>

    <div
      v-else-if="pagination.totalItems.value === 0"
      class="flex flex-col items-center justify-center h-48 text-gray-400 dark:text-gray-500"
    >
      <CreditCard :size="60" class="mb-4 opacity-50" />
      <div class="text-base">
        {{ pagination.totalItems.value === 0 ? t('financial.messages.noPatternAccount') : t('financial.noAccount') }}
      </div>
    </div>

    <div
      v-else
      class="grid gap-4 mb-4"
      :class="mediaQueries.isMobile ? 'grid-cols-1' : 'grid-cols-2'"
    >
      <Card
        v-for="account in pagination.paginatedItems.value"
        :key="account.serialNum"
        padding="md"
        hoverable
        class="relative overflow-hidden transition-all duration-300"
        :class="{
          'opacity-60': !account.isActive,
        }"
        :style="{
          borderLeftColor: account.color || '#e5e7eb',
          borderLeftWidth: '4px',
        }"
      >
        <!-- 顶部渐变条 -->
        <div
          class="absolute top-0 left-0 right-0 h-1 opacity-0 hover:opacity-100 transition-opacity duration-300"
          :style="{ background: `linear-gradient(90deg, ${account.color || '#3b82f6'}, transparent)` }"
        />

        <div class="flex items-start justify-between mb-3 gap-2">
          <!-- 账户信息区域 -->
          <div class="flex flex-col gap-1 flex-1 min-w-0">
            <div class="flex items-center gap-2">
              <component :is="getAccountTypeIcon(account.type)" :size="20" class="text-blue-600 dark:text-blue-400 shrink-0" />
              <span class="font-semibold text-gray-900 dark:text-white truncate">{{ account.name }}</span>
            </div>
            <span class="text-xs text-gray-500 dark:text-gray-400 ml-7">{{ getAccountTypeName(account.type) }}</span>
          </div>

          <!-- 操作按钮区域 -->
          <div class="flex gap-1 shrink-0">
            <button
              class="w-8 h-8 flex items-center justify-center rounded-lg border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-600 dark:text-gray-400 hover:border-blue-500 hover:text-blue-600 dark:hover:text-blue-400 hover:bg-blue-50 dark:hover:bg-blue-900/20 transition-all active:scale-95"
              :title="isAccountAmountHidden(account.serialNum) ? '显示金额' : '隐藏金额'"
              @click="toggleAccountAmountVisibility(account.serialNum)"
            >
              <Eye v-if="!isAccountAmountHidden(account.serialNum)" :size="16" />
              <EyeOff v-else :size="16" />
            </button>
            <!-- 虚拟账户不显示禁用、编辑、删除按钮 -->
            <template v-if="!account.isVirtual">
              <button
                class="w-8 h-8 flex items-center justify-center rounded-lg border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-600 dark:text-gray-400 hover:border-yellow-500 hover:text-yellow-600 dark:hover:text-yellow-400 hover:bg-yellow-50 dark:hover:bg-yellow-900/20 transition-all active:scale-95"
                :title="account.isActive ? t('common.status.stop') : t('common.status.enabled')"
                @click="emit('toggleActive', account.serialNum, !account.isActive)"
              >
                <Ban :size="16" />
              </button>
              <!-- 禁用状态的账户不显示编辑、删除按钮 -->
              <template v-if="account.isActive">
                <button
                  class="w-8 h-8 flex items-center justify-center rounded-lg border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-600 dark:text-gray-400 hover:border-blue-500 hover:text-blue-600 dark:hover:text-blue-400 hover:bg-blue-50 dark:hover:bg-blue-900/20 transition-all active:scale-95"
                  :title="t('common.actions.edit')"
                  @click="emit('edit', account)"
                >
                  <Edit :size="16" />
                </button>
                <button
                  class="w-8 h-8 flex items-center justify-center rounded-lg border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-600 dark:text-gray-400 hover:border-red-500 hover:text-red-600 dark:hover:text-red-400 hover:bg-red-50 dark:hover:bg-red-900/20 transition-all active:scale-95"
                  :title="t('common.actions.delete')"
                  @click="emit('delete', account.serialNum)"
                >
                  <Trash :size="16" />
                </button>
              </template>
            </template>
          </div>
        </div>

        <!-- 账户余额区域 -->
        <div class="flex items-baseline gap-2 mt-2">
          <span class="text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">{{ account.currency?.code }}</span>
          <span class="text-2xl font-bold text-gray-900 dark:text-white tracking-tight">
            {{ isAccountAmountHidden(account.serialNum) ? '***' : formatCurrency(account.balance) }}
          </span>
        </div>
      </Card>
    </div>

    <!-- 分页组件 -->
    <div v-if="pagination.totalPages.value > 1" class="flex justify-center" :class="mediaQueries.isMobile && 'mb-16 pb-4'">
      <Pagination
        :current-page="pagination.currentPage.value"
        :total-pages="pagination.totalPages.value"
        :total-items="pagination.totalItems.value"
        :page-size="pagination.pageSize.value"
        :show-total="false"
        :show-page-size="true"
        :page-size-options="[4, 8, 12, 20]"
        @page-change="handlePageChange"
        @page-size-change="handlePageSizeChange"
      />
    </div>
  </div>
</template>
