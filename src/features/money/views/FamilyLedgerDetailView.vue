<script setup lang="ts">
import {
  LucideBarChart3,
  LucideCalculator,
  LucideCalendarClock,
  LucideCoins,
  LucideUsers,
  LucideWallet,
} from 'lucide-vue-next';
import { storeToRefs } from 'pinia';
import { MoneyDb } from '@/services/money/money';
import { useFamilyLedgerStore } from '@/stores/money';
import { toast } from '@/utils/toast';
import TransactionTable from '../components/TransactionTable.vue';
import FamilyStatsView from './FamilyStatsView.vue';
import SettlementView from './SettlementView.vue';
import type { FamilyMember, Transaction } from '@/schema/money';

interface LedgerDetailRouteParams {
  serialNum?: string;
}

const route = useRoute();
const router = useRouter();
const { t } = useI18n();
const familyLedgerStore = useFamilyLedgerStore();
const { currentLedger, currentLedgerStats } = storeToRefs(familyLedgerStore);

const pageLoading = ref(true);
const transactionsLoading = ref(false);
const allTransactions = ref<Transaction[]>([]);
const selectedMemberSerial = ref<string | null>(null);

// 详情页标签：结算中心 / 统计报表
const activeTab = ref<'settlement' | 'statistics'>('settlement');
const tabs = [
  { key: 'settlement', label: '结算中心', icon: 'Calculator' },
  { key: 'statistics', label: '统计报表', icon: 'BarChart3' },
];

const members = computed(() => currentLedger.value?.memberList ?? []);

const selectedMember = computed<FamilyMember | null>(() => {
  if (!members.value.length) return null;
  return (
    members.value.find(member => member.serialNum === selectedMemberSerial.value) ||
    members.value[0] ||
    null
  );
});

const memberTransactions = computed<Transaction[]>(() => {
  if (!selectedMember.value) return [];
  // 筛选与该成员相关的交易（包括作为分摊成员的交易和该成员账户的交易）
  return allTransactions.value.filter(transaction => {
    // 检查是否在分摊成员中
    const isInSplitMembers = transaction.splitMembers?.some(
      member => member.serialNum === selectedMember.value!.serialNum,
    );

    // 检查账户是否属于该成员（如果有账户-成员关联关系）
    // 暂时先只按分摊成员筛选，如果需要更复杂的逻辑可以后续扩展
    return isInSplitMembers || false;
  });
});

const routeSerialNum = computed(() => (route.params as LedgerDetailRouteParams).serialNum);

onMounted(() => {
  hydrateFromRoute();
});

watch(
  () => routeSerialNum.value,
  serialNum => {
    if (typeof serialNum === 'string' && serialNum.length) {
      hydrateFromRoute();
    }
  },
);

watch(
  () => currentLedger.value?.serialNum,
  serialNum => {
    if (!serialNum) return;
    const firstMember = members.value[0];
    selectedMemberSerial.value = firstMember?.serialNum || null;
    loadLedgerTransactions(serialNum);
  },
);

async function hydrateFromRoute() {
  const serialNum = routeSerialNum.value;
  if (!serialNum) {
    router.push('/family-ledger');
    return;
  }

  pageLoading.value = true;
  try {
    if (!familyLedgerStore.ledgers.length) {
      await familyLedgerStore.fetchLedgers();
    }

    const ledger = familyLedgerStore.getLedgerById(serialNum);
    if (!ledger) {
      toast.error('未找到指定的账本');
      router.push('/family-ledger');
      return;
    }

    await familyLedgerStore.switchLedger(serialNum);
    selectedMemberSerial.value = ledger.memberList?.[0]?.serialNum || null;
    await loadLedgerTransactions(serialNum);
  } catch (error) {
    console.error(error);
    toast.error('加载账本详情失败');
    router.push('/family-ledger');
  } finally {
    pageLoading.value = false;
  }
}

async function loadLedgerTransactions(serialNum: string) {
  transactionsLoading.value = true;
  try {
    const relations = await MoneyDb.listFamilyLedgerTransactions();
    const related = relations.filter(relation => relation.familyLedgerSerialNum === serialNum);

    const results = await Promise.all(
      related.map(async relation => {
        const transaction = await MoneyDb.getTransaction(relation.transactionSerialNum);
        return transaction || null;
      }),
    );

    allTransactions.value = results.filter((transaction): transaction is Transaction => Boolean(transaction));
  } catch (error) {
    console.error(error);
    toast.error('加载交易记录失败');
    allTransactions.value = [];
  } finally {
    transactionsLoading.value = false;
  }
}

function selectMember(serialNum: string) {
  // 跳转到成员详情页
  router.push({
    name: 'family-member-detail',
    params: { memberSerialNum: serialNum },
  });
}

function goBack() {
  router.push('/family-ledger');
}

function formatCurrency(value?: number | string | null) {
  if (value === undefined || value === null) return '￥0.00';
  const numValue = typeof value === 'string' ? Number.parseFloat(value) : value;
  if (Number.isNaN(numValue)) return '￥0.00';
  return `￥${numValue.toFixed(2)}`;
}

function getRoleName(role: FamilyMember['role']) {
  const mapper: Record<string, string> = {
    Owner: '所有者',
    Admin: '管理员',
    Member: '成员',
    Viewer: '观察者',
  };
  return mapper[role] || role;
}

function getSettlementCycleName(cycle: string) {
  if (!cycle) return '';
  const upperCycle = cycle.toUpperCase();
  const mapper: Record<string, string> = {
    WEEKLY: t('familyLedger.settlementCycle.weekly'),
    MONTHLY: t('familyLedger.settlementCycle.monthly'),
    QUARTERLY: t('familyLedger.settlementCycle.quarterly'),
    YEARLY: t('familyLedger.settlementCycle.yearly'),
    MANUAL: t('familyLedger.settlementCycle.manual'),
  };
  return mapper[upperCycle] || cycle;
}

// 基于实际交易数据计算统计信息
const calculatedStats = computed(() => {
  const transactions = allTransactions.value;
  const totalIncome = transactions
    .filter(t => t.transactionType === 'Income')
    .reduce((sum, t) => sum + (Number(t.amount) || 0), 0);
  const totalExpense = transactions
    .filter(t => t.transactionType === 'Expense')
    .reduce((sum, t) => sum + (Number(t.amount) || 0), 0);

  return {
    totalIncome,
    totalExpense,
    netBalance: totalIncome - totalExpense,
    activeTransactionCount: transactions.length,
  };
});

const currentStats = computed(() => ({
  ...currentLedgerStats.value,
  totalIncome: calculatedStats.value.totalIncome,
  totalExpense: calculatedStats.value.totalExpense,
}));

const memberCount = computed(() => currentLedger.value?.members || members.value.length || 0);
const accountCount = computed(() => currentLedger.value?.accounts);
const activeTransactions = computed(() => calculatedStats.value.activeTransactionCount);

function getTabIcon(iconName: string) {
  const iconMap = {
    Calculator: LucideCalculator,
    BarChart3: LucideBarChart3,
  };
  return iconMap[iconName as keyof typeof iconMap] || LucideCalculator;
}
</script>

<template>
  <div class="ledger-detail-view">
    <div v-if="pageLoading" class="page-loader">
      <LucideLoader2 class="spinner" />
      <span>正在加载账本详情...</span>
    </div>

    <template v-else>
      <div v-if="currentLedger" class="detail-content">
        <header class="detail-header">
          <button class="ghost-button" @click="goBack">
            <LucideArrowLeft class="icon" />
          </button>
          <div class="title-block">
            <div class="title-main">
              <h1 class="title-name">
                {{ currentLedger.name || currentLedger.description || '未命名账本' }}
              </h1>
              <p class="title-description text-sm text-muted">
                {{ currentLedger.description || '暂未填写描述' }}
              </p>
            </div>
            <div class="title-footer">
              <div class="tabs-nav">
                <button
                  v-for="tab in tabs"
                  :key="tab.key"
                  class="tab-btn"
                  :class="{ active: activeTab === tab.key }"
                  :title="tab.label"
                  @click="activeTab = tab.key as 'settlement' | 'statistics'"
                >
                  <component :is="getTabIcon(tab.icon)" class="tab-icon" />
                </button>
              </div>
              <div class="meta">
                <span class="meta-item">
                  <LucideCoins class="meta-icon" />
                  {{ currentLedger.baseCurrency?.code || 'CNY' }}
                </span>
                <span class="meta-item">
                  <LucideCalendarClock class="meta-icon" />
                  {{ getSettlementCycleName(currentLedger.settlementCycle) }}
                </span>
                <span class="meta-item">
                  <LucideUsers class="meta-icon" />
                  {{ memberCount }}
                </span>
                <span class="meta-item">
                  <LucideWallet class="meta-icon" />
                  {{ accountCount }}
                </span>
                <span class="meta-item">
                  <LucideBarChart3 class="meta-icon" />
                  {{ activeTransactions }}
                </span>
              </div>
            </div>
          </div>
        </header>

        <section class="summary-grid">
          <article class="summary-card income">
            <LucideTrendingUp class="card-icon" />
            <div>
              <p>总收入</p>
              <h3>{{ formatCurrency(currentStats?.totalIncome) }}</h3>
            </div>
          </article>
          <article class="summary-card expense">
            <LucideTrendingDown class="card-icon" />
            <div>
              <p>总支出</p>
              <h3>{{ formatCurrency(currentStats?.totalExpense) }}</h3>
            </div>
          </article>
          <article class="summary-card neutral">
            <LucideWallet class="card-icon" />
            <div>
              <p>净余额</p>
              <h3>{{ formatCurrency(calculatedStats.netBalance) }}</h3>
            </div>
          </article>
          <article class="summary-card warning">
            <LucideReceiptText class="card-icon" />
            <div>
              <p>待结算</p>
              <h3>{{ formatCurrency(currentStats?.pendingSettlement) }}</h3>
            </div>
          </article>
        </section>

        <!-- 成员概览 / 交易记录 -->
        <section class="detail-body">
          <div class="members-panel">
            <div class="panel-header">
              <h2>成员概览</h2>
            </div>
            <div v-if="members.length" class="members-grid">
              <article
                v-for="member in members"
                :key="member.serialNum"
                class="member-card"
                :class="{ active: member.serialNum === selectedMember?.serialNum }"
                @click="selectMember(member.serialNum)"
              >
                <div class="member-header">
                  <div class="avatar">
                    {{ member.name.charAt(0).toUpperCase() }}
                  </div>
                  <div>
                    <p class="member-name">
                      {{ member.name }}
                    </p>
                    <p class="member-role">
                      {{ getRoleName(member.role) }}
                    </p>
                  </div>
                </div>
                <div class="member-metrics">
                  <div>
                    <span>交易笔数</span>
                    <strong>{{ member.transactionCount ?? 0 }}</strong>
                  </div>
                  <div>
                    <span>总支付</span>
                    <strong>{{ formatCurrency(member.totalPaid) }}</strong>
                  </div>
                  <div>
                    <span>应分摊</span>
                    <strong>{{ formatCurrency(member.totalOwed) }}</strong>
                  </div>
                </div>
              </article>
            </div>
            <div v-else class="empty-state">
              <LucideUserCheck class="empty-icon" />
              <p>尚未添加成员</p>
            </div>
          </div>

          <div class="transactions-panel">
            <div class="panel-header">
              <div>
                <h2>
                  {{ selectedMember ? `${selectedMember.name} 的交易` : '交易记录' }}
                </h2>
              </div>
            </div>

            <div class="transactions-scroll-container">
              <TransactionTable
                :transactions="memberTransactions"
                :loading="transactionsLoading"
                :show-actions="false"
                :columns="['date', 'type', 'category', 'amount', 'account', 'description']"
                empty-text="暂无相关交易记录"
              />
            </div>
          </div>
        </section>

        <!-- 结算中心 / 统计报表 -->
        <section class="detail-tabs">
          <div class="tab-content">
            <div v-if="activeTab === 'settlement'" class="tab-panel">
              <SettlementView />
            </div>
            <div v-else-if="activeTab === 'statistics'" class="tab-panel">
              <FamilyStatsView />
            </div>
          </div>
        </section>
      </div>

      <div v-else class="empty-state">
        <LucideUsers class="empty-icon" />
        <p>暂无账本数据</p>
      </div>
    </template>
  </div>
</template>

<style scoped>
.ledger-detail-view {
  min-height: 100vh;
  padding: 24px;
  background: var(--color-base-100);
}

.page-loader,
.panel-loading {
  display: flex;
  align-items: center;
  gap: 12px;
  color: var(--color-gray-500);
}

.spinner {
  width: 24px;
  height: 24px;
  animation: spin 1s linear infinite;
}

.detail-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 24px;
  margin-bottom: 24px;
}

.ghost-button {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  padding: 8px 12px;
  border: 1px solid var(--color-primary-soft);
  border-radius: 8px;
  background: var(--color-base-100);
  cursor: pointer;
  color: var(--color-base-content);
}

.icon {
  width: 16px;
  height: 16px;
}

.title-block {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.title-main {
  display: flex;
  align-items: baseline;
  gap: 8px;
}

.title-name {
  margin: 0;
  font-size: 28px;
  color: var(--color-base-content);
}

.title-description {
  margin: 0;
}

.title-footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
}

.tabs-nav {
  display: flex;
  align-items: center;
  gap: 8px;
}

.tab-btn {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 6px 10px;
  border-radius: 999px;
  border: 1px solid transparent;
  background: transparent;
  color: var(--color-gray-600);
  cursor: pointer;
  font-size: 13px;
  transition: background 0.15s ease, color 0.15s ease, border-color 0.15s ease;
}

.tab-btn:hover {
  background: var(--color-base-200);
  border-color: var(--color-gray-200);
}

.tab-btn.active {
  background: var(--color-base-300);
  border-color: var(--color-neutral);
  color: var(--color-accent);
}

.tab-icon {
  width: 1rem;
  height: 1rem;
}

.meta {
  display: flex;
  gap: 16px;
  margin-top: 12px;
  font-size: 0.875rem;
  color: var(--color-gray-600);
}

.meta-item {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 6px 12px;
  background: var(--color-base-100);
  border-radius: 6px;
  font-weight: 500;
  transition: all 0.2s ease;
}

.meta-item:hover {
  background: var(--color-base-200);
  color: var(--color-base-content);
}

.meta-icon {
  width: 16px;
  height: 16px;
  flex-shrink: 0;
  color: var(--color-primary);
}

.summary-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
  gap: 16px;
}

.summary-card {
  display: flex;
  align-items: center;
  gap: 16px;
  padding: 16px;
  border-radius: 16px;
  background: var(--color-base-200);
  box-shadow: 0 1px 3px rgb(15 23 42 / 0.08);
}

.summary-card p {
  margin: 0;
  color: var(--color-gray-600);
}

.summary-card h3 {
  margin: 4px 0 0;
  font-size: 24px;
  color: var(--color-base-content);
}

.summary-card.neutral { border-left: 4px solid var(--color-neutral); }
.summary-card.income { border-left: 4px solid var(--color-success); }
.summary-card.expense { border-left: 4px solid var(--color-error); }
.summary-card.warning { border-left: 4px solid var(--color-warning); }
.summary-card.info { border-left: 4px solid var(--color-info); }

.card-icon {
  width: 32px;
  height: 32px;
  color: var(--color-gray-600);
}

.detail-body {
  display: grid;
  grid-template-columns: minmax(280px, 360px) 1fr;
  gap: 24px;
  margin-top: 32px;
}

.detail-tabs {
  margin-top: 1em;
  margin-left: auto;
  margin-right: auto;
}

.tab-content {
  background: var(--color-base-100);
  border-radius: 1rem;
  padding: 1rem;
  box-shadow: 0 10px 30px rgb(15 23 42 / 0.08);
}

.tab-panel {
  width: 100%;
}

.members-panel,
.transactions-panel {
  background: var(--color-base-100);
  border-radius: 16px;
  padding: 24px;
  box-shadow: 0 10px 30px rgb(15 23 42 / 0.08);
}

.panel-header h2 {
  margin: 0;
  font-size: 20px;
  color: var(--color-base-content);
}

.panel-header p {
  margin: 4px 0 0;
  color: var(--color-gray-500);
}

.members-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: 20px;
  margin-top: 20px;
}

.member-card {
  position: relative;
  border: 1px solid var(--color-base-300);
  border-radius: 16px;
  padding: 20px;
  cursor: pointer;
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
  background: white;
  display: flex;
  flex-direction: column;
  height: 100%;
  box-shadow: var(--shadow-sm);
  overflow: hidden;
}

.member-card::before {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  height: 4px;
  background: var(--color-primary-gradient);
  opacity: 0;
  transition: opacity 0.3s ease;
}

.member-card.active {
  border-color: var(--color-primary);
  box-shadow: var(--shadow-lg), 0 0 0 3px oklch(from var(--color-primary) l c h / 0.1);
  background: linear-gradient(135deg, white 0%, oklch(from var(--color-primary) l c h / 0.02) 100%);
  transform: translateY(-4px) scale(1.02);
}

.member-card.active::before {
  opacity: 1;
}

.member-card:hover {
  border-color: var(--color-primary-soft);
  box-shadow: var(--shadow-md);
  transform: translateY(-2px);
}

.member-header {
  display: flex;
  align-items: center;
  gap: 12px;
}

.avatar {
  width: 52px;
  height: 52px;
  border-radius: 14px;
  background: var(--color-primary-gradient);
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 700;
  font-size: 1.35rem;
  color: var(--color-primary-content);
  flex-shrink: 0;
  box-shadow: var(--shadow-sm), inset 0 1px 0 oklch(from var(--color-primary) l c h / 0.2);
  position: relative;
  overflow: hidden;
}

.avatar::after {
  content: '';
  position: absolute;
  top: -50%;
  left: -50%;
  width: 200%;
  height: 200%;
  background: linear-gradient(45deg, transparent, oklch(from var(--color-primary) l c h / 0.15), transparent);
  transform: rotate(45deg);
}

.member-name {
  margin: 0;
  font-weight: 700;
  font-size: 1.05rem;
  color: var(--color-base-content);
  letter-spacing: -0.01em;
}

.member-role {
  margin: 6px 0 0;
  font-size: 0.8rem;
  color: var(--color-neutral);
  font-weight: 500;
  padding: 2px 8px;
  background: var(--color-base-200);
  border-radius: 6px;
  display: inline-block;
  width: fit-content;
}

.member-metrics {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 16px;
  margin-top: 20px;
  padding-top: 16px;
  border-top: 1px solid var(--color-base-300);
}

.member-metrics > div {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4px;
  padding: 8px 8px;
  background: var(--color-base-100);
  border-radius: 10px;
  border: 1px solid var(--color-base-200);
  transition: all 0.2s ease;
  min-width: 0;
}

.member-metrics > div:hover {
  background: var(--color-base-200);
  transform: translateY(-1px);
}

.member-metrics span {
  font-size: 9px;
  color: var(--color-neutral);
  font-weight: 600;
  letter-spacing: 0.3px;
  white-space: nowrap;
  text-align: center;
}

.member-metrics strong {
  font-size: 13px;
  font-weight: 700;
  color: var(--color-base-content);
  letter-spacing: -0.02em;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  max-width: 100%;
}

/* 交易列表滚动容器 */
.transactions-scroll-container {
  max-height: 480px; /* 约6条记录的高度 (每条约80px) */
  overflow-y: auto;
  overflow-x: hidden;
  border-radius: 8px;
}

/* 自定义滚动条样式 */
.transactions-scroll-container::-webkit-scrollbar {
  width: 8px;
}

.transactions-scroll-container::-webkit-scrollbar-track {
  background: var(--color-base-100);
  border-radius: 4px;
}

.transactions-scroll-container::-webkit-scrollbar-thumb {
  background: var(--color-base-300);
  border-radius: 4px;
}

.transactions-scroll-container::-webkit-scrollbar-thumb:hover {
  background: var(--color-primary-soft);
}

.empty-state {
  padding: 32px;
  text-align: center;
  color: var(--color-gray-400);
}

.empty-icon {
  width: 36px;
  height: 36px;
  margin-bottom: 12px;
}

@media (max-width: 1024px) {
  .detail-body {
    grid-template-columns: 1fr;
  }

  .members-grid {
    grid-template-columns: repeat(auto-fill, minmax(240px, 1fr));
    gap: 14px;
  }
}

@media (max-width: 768px) {
  .title-footer {
    flex-direction: column;
    align-items: flex-start;
    gap: 8px;
  }

  .meta {
    margin-top: 4px;
    flex-wrap: wrap;
    gap: 8px;
  }

  .meta-item {
    padding: 3px 8px;
    font-size: 0.8rem;
  }

  .meta-icon {
    width: 14px;
    height: 14px;
  }

  .members-grid {
    grid-template-columns: 1fr;
    gap: 12px;
    /* 限制高度，约显示2个成员卡片 */
    max-height: 350px;
    overflow-y: auto;
    /* 隐藏滚动条 */
    scrollbar-width: none; /* Firefox */
    -ms-overflow-style: none; /* IE and Edge */
  }

  .members-grid::-webkit-scrollbar {
    display: none; /* Chrome, Safari, Opera */
  }

  .member-card {
    padding: 16px;
  }

  .avatar {
    width: 44px;
    height: 44px;
    font-size: 1.15rem;
  }

  .member-metrics {
    gap: 8px;
    margin-top: 14px;
    padding-top: 14px;
  }

  .member-metrics > div {
    padding: 6px 6px;
  }

  .member-metrics span {
    font-size: 8px;
  }

  .member-metrics strong {
    font-size: 12px;
  }

  /* 移动端交易列表高度调整 */
  .transactions-scroll-container {
    max-height: 400px; /* 移动端显示约5条记录 */
  }
}

@keyframes spin {
  from {
    transform: rotate(0deg);
  }
  to {
    transform: rotate(360deg);
  }
}
</style>
