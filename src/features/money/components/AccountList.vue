<script setup lang="ts">
import {
  Cloud,
  CreditCard,
  DollarSign,
  MoreHorizontal,
  PiggyBank,
  RotateCcw,
  TrendingUp,
  Wallet,
  Wallet2,
} from 'lucide-vue-next';
import SimplePagination from '@/components/common/SimplePagination.vue';
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
const moneyStore = useMoneyStore();

const mediaQueries = useMediaQueriesStore();
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
  moneyStore.toggleAccountAmountVisibility(accountSerialNum);
}

// 根据设备类型决定网格布局
const gridLayoutClass = computed(() => {
  if (mediaQueries.isMobile) {
    // 移动端布局：一行一个，100%宽度
    return 'grid-template-columns-mobile-single';
  } else {
    // 桌面端布局：一行两个
    return 'grid-template-columns-desktop-two';
  }
});
</script>

<template>
  <div class="money-tab-25">
    <!-- 过滤选项区域 -->
    <div class="screening-filtering">
      <div class="filter-main-group">
        <!-- 账户状态过滤 -->
        <div class="filter-flex-wrap">
          <div class="filter-status-buttons">
            <button
              class="account-select" :class="[
                filters.status === 'all'
                  ? 'account-select-all'
                  : 'account-select-gray',
              ]" @click="setActiveFilter('all')"
            >
              {{ t('common.actions.all') }}<span class="text-xs ml-1 opacity-75">[{{ pagination.totalItems.value }}]</span>
            </button>
            <button
              class="account-select" :class="[
                filters.status === 'active'
                  ? 'account-select-green'
                  : 'account-select-gray',
              ]" @click="setActiveFilter('active')"
            >
              {{ t('common.status.active') }}<span class="text-xs ml-1 opacity-75">({{ activeAccounts }})</span>
            </button>
            <button
              class="account-select" :class="[
                filters.status === 'inactive'
                  ? 'account-select-back'
                  : 'account-select-gray',
              ]" @click="setActiveFilter('inactive')"
            >
              {{ t('common.status.inactive') }}<span class="text-xs ml-1 opacity-75">({{ inactiveAccounts }})</span>
            </button>
          </div>
        </div>

        <!-- 移动端展开的额外过滤器 -->
        <template v-if="showMoreFilters">
          <!-- 账户类型过滤 -->
          <div class="filter-flex-wrap">
            <select
              v-model="filters.type"
              class="screening-filtering-select"
              @change="handleTypeFilter"
            >
              <option value="">
                {{ t('common.actions.all') }}{{ t('common.misc.types') }}
              </option>
              <option v-for="type in accountTypes" :key="type" :value="type">
                {{ getAccountTypeName(type) }}
              </option>
            </select>
          </div>

          <!-- 币种过滤 -->
          <div class="filter-flex-wrap">
            <select
              v-model="filters.currency"
              class="screening-filtering-select"
              @change="handleCurrencyFilter"
            >
              <option value="">
                {{ t('common.actions.all') }}{{ t('financial.currency') }}
              </option>
              <option v-for="currency in currencies" :key="currency" :value="currency">
                {{ currency }}
              </option>
            </select>
          </div>

          <!-- 排序选项 -->
          <div class="filter-flex-wrap">
            <select
              v-model="filters.sortBy"
              class="screening-filtering-select"
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
              class="screening-filtering-select"
              :title="filters.sortOrder === 'asc' ? t('common.sorting.asc') : t('common.sorting.desc')"
              @click="toggleSortOrder"
            >
              <LucideArrowUpDown class="btn-lucide" :class="filters.sortOrder === 'desc' && 'rotate-180'" />
            </button>
          </div>
        </template>

        <!-- 操作按钮组 -->
        <div class="filter-button-group">
          <button
            class="screening-filtering-select"
            @click="toggleFilters"
          >
            <MoreHorizontal class="wh-4 mr-1" />
          </button>
          <button
            class="screening-filtering-select"
            @click="resetFilters"
          >
            <RotateCcw class="wh-4 mr-1" />
          </button>
        </div>
      </div>
    </div>

    <!-- 账户列表区域 -->
    <div
      v-if="loading"
      class="loading-container"
    >
      {{ t('common.loading') }}
    </div>

    <div
      v-else-if="pagination.totalItems.value === 0"
      class="empty-state-container"
    >
      <div class="empty-state-icon">
        <LucideCreditCard class="empty-icon" />
      </div>
      <div class="empty-state-text">
        {{ pagination.totalItems.value === 0 ? t('financial.messages.noPatternAccount') : t('financial.noAccount') }}
      </div>
    </div>

    <div
      v-else
      class="accounts-grid"
      :class="gridLayoutClass"
    >
      <div
        v-for="account in pagination.paginatedItems.value"
        :key="account.serialNum"
        class="account-card"
        :class="{
          'account-card-inactive': !account.isActive,
        }" :style="{
          borderColor: account.color || 'var(--color-gray-200)',
        }"
      >
        <div class="account-header">
          <!-- 账户信息区域 -->
          <div class="account-info">
            <div class="account-info-top">
              <component :is="getAccountTypeIcon(account.type)" class="account-type-icon" />
              <span class="account-name">{{ account.name }}</span>
            </div>
            <span class="account-type-name">{{ getAccountTypeName(account.type) }}</span>
          </div>

          <!-- 操作按钮区域 -->
          <div class="account-actions">
            <button
              class="money-option-btn money-option-eye-hover"
              :title="moneyStore.isAccountAmountHidden(account.serialNum) ? '显示金额' : '隐藏金额'"
              @click="toggleAccountAmountVisibility(account.serialNum)"
            >
              <LucideEye v-if="!moneyStore.isAccountAmountHidden(account.serialNum)" class="wh-4" />
              <LucideEyeOff v-else class="wh-4" />
            </button>
            <!-- 虚拟账户不显示禁用、编辑、删除按钮 -->
            <template v-if="!account.isVirtual">
              <button
                class="money-option-btn money-option-ben-hover"
                :title="account.isActive ? t('common.status.stop') : t('common.status.enabled')"
                @click="emit('toggleActive', account.serialNum, !account.isActive)"
              >
                <LucideBan class="wh-4" />
              </button>
              <button
                class="money-option-btn money-option-edit-hover"
                :title="t('common.actions.edit')"
                @click="emit('edit', account)"
              >
                <LucideEdit class="wh-4" />
              </button>
              <button
                class="money-option-btn money-option-trash-hover"
                :title="t('common.actions.delete')"
                @click="emit('delete', account.serialNum)"
              >
                <LucideTrash class="wh-4" />
              </button>
            </template>
          </div>
        </div>

        <!-- 账户余额区域 -->
        <div class="account-balance">
          <span class="account-currency">{{ account.currency?.code }}</span>
          <span class="balance-amount">
            {{ moneyStore.isAccountAmountHidden(account.serialNum) ? '***' : formatCurrency(account.balance) }}
          </span>
        </div>
      </div>
    </div>

    <!-- 分页组件 -->
    <div v-if="pagination.totalPages.value > 1" class="pagination-container">
      <SimplePagination
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

<style lang="postcss">
/* Loading and Empty States */
.loading-container {
  color: var(--color-gray-500);
  height: 12.5rem;
  display: flex;
  justify-content: center;
  align-items: center;
}

.empty-state-container {
  color: var(--color-gray-400);
  display: flex;
  flex-direction: column;
  height: 12.5rem;
  justify-content: center;
  align-items: center;
}

.empty-state-icon {
  font-size: 3.75rem;
  margin-bottom: 1rem;
  opacity: 0.5;
}

.empty-icon {
  width: 1.25rem;
  height: 1.25rem;
}

.empty-state-text {
  font-size: 1rem;
}

/* Accounts Grid - 优化网格布局 */
.accounts-grid {
  margin-bottom: 1rem;
  gap: 1rem;
  display: grid;
}

/* 网格布局类 - 响应式设计 */
.grid-template-columns-mobile-single {
  grid-template-columns: 1fr;
}

.grid-template-columns-desktop-two {
  grid-template-columns: repeat(2, 1fr);
  gap: 1rem;
}

/* 移动端优化 */
@media (max-width: 768px) {
  .accounts-grid {
    gap: 0.75rem;
    margin-bottom: 0.75rem;
  }

  .grid-template-columns-mobile-single {
    grid-template-columns: 1fr;
  }
}

/* 桌面端优化 */
@media (min-width: 769px) {
  .accounts-grid {
    gap: 1rem;
    margin-bottom: 1rem;
  }

  .grid-template-columns-desktop-two {
    grid-template-columns: repeat(2, 1fr);
    max-width: none;
  }
}

/* Account Card - 重新设计为更紧凑美观的卡片 */
.account-card {
  background: linear-gradient(135deg, var(--color-base-100) 0%, var(--color-base-200) 100%);
  padding: 1rem;
  border: 1px solid var(--color-primary-soft);
  border-radius: 0.75rem;
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
  position: relative;
  overflow: hidden;
  box-shadow: var(--shadow-sm);
}

.account-card::before {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  height: 3px;
  background: var(--color-primary-gradient);
  opacity: 0;
  transition: opacity 0.3s ease;
}

.account-card:hover {
  transform: translateY(-2px);
  box-shadow: var(--shadow-lg);
  border-color: var(--color-primary);
}

.account-card:hover::before {
  opacity: 1;
}

.account-card-inactive {
  opacity: 0.6;
  background: var(--color-gray-100);
  border-color: var(--color-gray-300);
}

.account-card-inactive::before {
  background: var(--color-gray-400);
}

/* Account Header - 更紧凑的布局 */
.account-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  margin-bottom: 0.75rem;
  gap: 0.5rem;
}

.account-info {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
  flex: 1;
  min-width: 0;
}

.account-info-top {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.account-type-icon {
  color: var(--color-primary);
  height: 1.25rem;
  width: 1.25rem;
  flex-shrink: 0;
}

.account-name {
  font-size: 1rem;
  color: var(--color-base-content);
  font-weight: 600;
  line-height: 1.2;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.account-type-name {
  font-size: 0.75rem;
  color: var(--color-gray-500);
  font-weight: 500;
  margin-left: 1.75rem;
}

/* Account Actions - 更优雅的操作按钮 */
.account-actions {
  display: flex;
  gap: 0.25rem;
  flex-shrink: 0;
}

.money-option-btn {
  width: 2rem;
  height: 2rem;
  border-radius: 0.5rem;
  border: 1px solid var(--color-gray-200);
  background: var(--color-base-100);
  color: var(--color-gray-600);
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.2s ease;
  cursor: pointer;
  position: relative;
  overflow: hidden;
}

.money-option-btn::before {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: var(--color-primary);
  opacity: 0;
  transition: opacity 0.2s ease;
}

.money-option-btn:hover {
  border-color: var(--color-primary);
  color: var(--color-primary);
  transform: scale(1.05);
}

.money-option-btn:hover::before {
  opacity: 0.1;
}

.money-option-btn:active {
  transform: scale(0.95);
}

.money-option-eye-hover:hover {
  background-color: var(--color-info);
  color: var(--color-info-content);
  border-color: var(--color-info);
}

.money-option-ben-hover:hover {
  background-color: var(--color-warning);
  color: var(--color-warning-content);
  border-color: var(--color-warning);
}

.money-option-edit-hover:hover {
  background-color: var(--color-primary);
  color: var(--color-primary-content);
  border-color: var(--color-primary);
}

.money-option-trash-hover:hover {
  background-color: var(--color-error);
  color: var(--color-error-content);
  border-color: var(--color-error);
}

/* Account Balance - 更突出的余额显示 */
.account-balance {
  display: flex;
  align-items: baseline;
  gap: 0.5rem;
  margin-top: 0.5rem;
}

.account-currency {
  font-size: 0.75rem;
  color: var(--color-gray-500);
  font-weight: 500;
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.balance-amount {
  font-size: 1.5rem;
  color: var(--color-base-content);
  font-weight: 700;
  line-height: 1;
  letter-spacing: -0.025em;
}

/* 移动端优化 */
@media (max-width: 768px) {
  .account-card {
    padding: 0.875rem;
  }

  .account-header {
    margin-bottom: 0.625rem;
  }

  .account-name {
    font-size: 0.9375rem;
  }

  .account-type-name {
    font-size: 0.6875rem;
    margin-left: 1.5rem;
  }

  .balance-amount {
    font-size: 1.375rem;
  }

  .money-option-btn {
    width: 1.75rem;
    height: 1.75rem;
  }

  .account-type-icon {
    height: 1.125rem;
    width: 1.125rem;
  }
}

/* Account Select Buttons */
.account-select {
  font-size: 0.75rem;
  font-weight: 500;
  padding: 0.375rem 0.75rem;
  border: 1px solid var(--color-gray-300);
  border-radius: 9999px;
  transition: all 0.2s;
}

.account-select-all {
  background-color: var(--color-info);
  color: var(--color-info-content);
  border: 1px solid var(--color-info);
}

.account-select-green {
  background-color: var(--color-success);
  border-color: var(--color-success);
}

.account-select-gray {
  background-color: var(--color-neutral-content);
  border-color: var(--color-neutral);
}
.account-select-back {
  background-color: var(--color-gray-600);
  border-color: var(--color-gray-600);
}

.account-select-blue {
  background-color: var(--color-info);
  border-color: var(--color-info);
}

.account-select-green:hover {
  border-color: var(--color-success);
}

.account-select-blue:hover {
  border-color: var(--color-info);
}

.account-select-gray:hover {
  border-color: var(--color-gray-400);
}

/* Additional utility styles */
.filter-main-group {
  display: flex;
  flex-wrap: wrap;
  gap: 0.75rem;
  align-items: center;
}

.filter-status-buttons {
  display: flex;
  gap: 0.25rem;
}

.filter-button-group {
  display: flex;
  gap: 0.25rem;
}

.pagination-container {
  margin-top: 1rem;
  display: flex;
  justify-content: center;
}

/* 移动端分页组件底部安全间距 */
@media (max-width: 768px) {
  .pagination-container {
    margin-bottom: 4rem; /* 为底部导航栏预留空间 */
    padding-bottom: 1rem; /* 额外的底部内边距 */
  }
}
</style>
