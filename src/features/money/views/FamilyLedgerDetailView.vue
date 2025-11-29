<script setup lang="ts">
import {
  LucideArrowLeft,
  LucideBarChart3,
  LucideCalculator,
  LucideCalendarClock,
  LucideCoins,
  LucideLoader2,
  LucideReceiptText,
  LucideTarget,
  LucideTrendingDown,
  LucideTrendingUp,
  LucideUserCheck,
  LucideUsers,
  LucideWallet,
} from 'lucide-vue-next';
import { storeToRefs } from 'pinia';
import Button from '@/components/ui/Button.vue';
import { useFamilyBudgetActions } from '@/composables/useFamilyBudgetActions';
import { MoneyDb } from '@/services/money/money';
import { useFamilyLedgerStore } from '@/stores/money';
import { toast } from '@/utils/toast';
import FamilyBudgetModal from '../components/FamilyBudgetModal.vue';
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

// 家庭预算相关
const {
  showModal: showBudgetModal,
  showCreateModal: showCreateBudgetModal,
  closeModal: closeBudgetModal,
  createFamilyBudget,
} = useFamilyBudgetActions();

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
  // 更新选中的成员，右侧显示该成员的交易
  selectedMemberSerial.value = serialNum;
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

// 处理家庭预算创建
async function handleCreateFamilyBudget(
  budgetData: any,
  allocations: any[],
) {
  const success = await createFamilyBudget(budgetData, allocations, async () => {
    toast.success('家庭预算创建成功！');
  });

  if (success) {
    closeBudgetModal();
  }
}

function getTabIcon(iconName: string) {
  const iconMap = {
    Calculator: LucideCalculator,
    BarChart3: LucideBarChart3,
  };
  return iconMap[iconName as keyof typeof iconMap] || LucideCalculator;
}
</script>

<template>
  <div class="min-h-screen p-6 bg-gray-50 dark:bg-gray-900">
    <div v-if="pageLoading" class="flex items-center gap-3 text-gray-500 dark:text-gray-400">
      <LucideLoader2 class="w-6 h-6 animate-spin" />
      <span>正在加载账本详情...</span>
    </div>

    <template v-else>
      <div v-if="currentLedger" class="flex flex-col gap-6 max-w-7xl mx-auto">
        <header class="flex flex-col md:flex-row md:items-start md:justify-between gap-6">
          <button class="inline-flex items-center gap-2 px-3 py-2 border border-blue-200 dark:border-blue-800 rounded-lg bg-white dark:bg-gray-800 cursor-pointer text-gray-900 dark:text-gray-100 hover:bg-blue-50 dark:hover:bg-gray-700 transition-colors" @click="goBack">
            <LucideArrowLeft class="w-4 h-4" />
          </button>
          <div class="flex flex-col gap-2 flex-1">
            <div class="flex items-baseline gap-2">
              <h1 class="m-0 text-3xl font-bold text-gray-900 dark:text-gray-100">
                {{ currentLedger.name || currentLedger.description || '未命名账本' }}
              </h1>
              <p class="m-0 text-sm text-gray-500 dark:text-gray-400">
                {{ currentLedger.description || '暂未填写描述' }}
              </p>
            </div>
            <div class="flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-4">
              <div class="flex items-center gap-2">
                <button
                  v-for="tab in tabs"
                  :key="tab.key"
                  class="inline-flex items-center gap-1.5 px-2.5 py-1.5 rounded-full border transition-all text-xs" :class="[
                    activeTab === tab.key
                      ? 'bg-gray-200 dark:bg-gray-700 border-gray-400 dark:border-gray-600 text-blue-600 dark:text-blue-400'
                      : 'bg-transparent border-transparent text-gray-600 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-800 hover:border-gray-200 dark:hover:border-gray-700',
                  ]"
                  :title="tab.label"
                  @click="activeTab = tab.key as 'settlement' | 'statistics'"
                >
                  <component :is="getTabIcon(tab.icon)" class="w-4 h-4" />
                </button>
              </div>
              <div class="flex flex-wrap gap-4 mt-3 text-sm text-gray-600 dark:text-gray-400">
                <span class="flex items-center gap-2 px-3 py-1.5 bg-white dark:bg-gray-800 rounded-md font-medium transition-all hover:bg-gray-100 dark:hover:bg-gray-700 hover:text-gray-900 dark:hover:text-gray-100">
                  <LucideCoins class="w-4 h-4 flex-shrink-0 text-blue-600 dark:text-blue-400" />
                  {{ currentLedger.baseCurrency?.code || 'CNY' }}
                </span>
                <span class="flex items-center gap-2 px-3 py-1.5 bg-white dark:bg-gray-800 rounded-md font-medium transition-all hover:bg-gray-100 dark:hover:bg-gray-700 hover:text-gray-900 dark:hover:text-gray-100">
                  <LucideCalendarClock class="w-4 h-4 flex-shrink-0 text-blue-600 dark:text-blue-400" />
                  {{ getSettlementCycleName(currentLedger.settlementCycle) }}
                </span>
                <span class="flex items-center gap-2 px-3 py-1.5 bg-white dark:bg-gray-800 rounded-md font-medium transition-all hover:bg-gray-100 dark:hover:bg-gray-700 hover:text-gray-900 dark:hover:text-gray-100">
                  <LucideUsers class="w-4 h-4 flex-shrink-0 text-blue-600 dark:text-blue-400" />
                  {{ memberCount }}
                </span>
                <span class="flex items-center gap-2 px-3 py-1.5 bg-white dark:bg-gray-800 rounded-md font-medium transition-all hover:bg-gray-100 dark:hover:bg-gray-700 hover:text-gray-900 dark:hover:text-gray-100">
                  <LucideWallet class="w-4 h-4 flex-shrink-0 text-blue-600 dark:text-blue-400" />
                  {{ accountCount }}
                </span>
                <span class="flex items-center gap-2 px-3 py-1.5 bg-white dark:bg-gray-800 rounded-md font-medium transition-all hover:bg-gray-100 dark:hover:bg-gray-700 hover:text-gray-900 dark:hover:text-gray-100">
                  <LucideBarChart3 class="w-4 h-4 flex-shrink-0 text-blue-600 dark:text-blue-400" />
                  {{ activeTransactions }}
                </span>
              </div>
            </div>
          </div>
        </header>

        <section class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
          <article class="flex items-center gap-4 p-4 rounded-2xl bg-gray-100 dark:bg-gray-800 shadow-sm border-l-4 border-green-500">
            <LucideTrendingUp class="w-8 h-8 text-gray-600 dark:text-gray-400" />
            <div>
              <p class="m-0 text-gray-600 dark:text-gray-400">
                总收入
              </p>
              <h3 class="m-0 mt-1 text-2xl text-gray-900 dark:text-gray-100">
                {{ formatCurrency(currentStats?.totalIncome) }}
              </h3>
            </div>
          </article>
          <article class="flex items-center gap-4 p-4 rounded-2xl bg-gray-100 dark:bg-gray-800 shadow-sm border-l-4 border-red-500">
            <LucideTrendingDown class="w-8 h-8 text-gray-600 dark:text-gray-400" />
            <div>
              <p class="m-0 text-gray-600 dark:text-gray-400">
                总支出
              </p>
              <h3 class="m-0 mt-1 text-2xl text-gray-900 dark:text-gray-100">
                {{ formatCurrency(currentStats?.totalExpense) }}
              </h3>
            </div>
          </article>
          <article class="flex items-center gap-4 p-4 rounded-2xl bg-gray-100 dark:bg-gray-800 shadow-sm border-l-4 border-gray-500">
            <LucideWallet class="w-8 h-8 text-gray-600 dark:text-gray-400" />
            <div>
              <p class="m-0 text-gray-600 dark:text-gray-400">
                净余额
              </p>
              <h3 class="m-0 mt-1 text-2xl text-gray-900 dark:text-gray-100">
                {{ formatCurrency(calculatedStats.netBalance) }}
              </h3>
            </div>
          </article>
          <article class="flex items-center gap-4 p-4 rounded-2xl bg-gray-100 dark:bg-gray-800 shadow-sm border-l-4 border-yellow-500">
            <LucideReceiptText class="w-8 h-8 text-gray-600 dark:text-gray-400" />
            <div>
              <p class="m-0 text-gray-600 dark:text-gray-400">
                待结算
              </p>
              <h3 class="m-0 mt-1 text-2xl text-gray-900 dark:text-gray-100">
                {{ formatCurrency(currentStats?.pendingSettlement) }}
              </h3>
            </div>
          </article>
        </section>

        <!-- 成员概览 / 交易记录 -->
        <section class="grid grid-cols-1 lg:grid-cols-[minmax(280px,360px)_1fr] gap-6 mt-8">
          <div class="bg-white dark:bg-gray-800 rounded-2xl p-6 shadow-lg">
            <div class="flex justify-between items-center">
              <h2 class="m-0 text-xl text-gray-900 dark:text-gray-100">
                成员概览
              </h2>
              <Button variant="primary" @click="showCreateBudgetModal">
                <LucideTarget class="w-4 h-4" />
                创建家庭预算
              </Button>
            </div>
            <div v-if="members.length" class="grid grid-cols-1 gap-5 mt-5 max-h-[360px] overflow-y-auto [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden">
              <article
                v-for="member in members"
                :key="member.serialNum"
                class="relative border rounded-2xl p-5 cursor-pointer transition-all bg-white dark:bg-gray-900 flex flex-col h-full shadow-sm overflow-hidden before:content-[''] before:absolute before:top-0 before:left-0 before:right-0 before:h-1 before:bg-gradient-to-r before:from-blue-600 before:to-purple-600 before:opacity-0 before:transition-opacity" :class="[
                  member.serialNum === selectedMember?.serialNum
                    ? 'border-blue-600 shadow-lg shadow-blue-600/10 bg-gradient-to-br from-white to-blue-50/20 dark:from-gray-900 dark:to-blue-900/10 -translate-y-1 scale-[1.02] before:opacity-100'
                    : 'border-gray-200 dark:border-gray-700 hover:border-blue-300 dark:hover:border-blue-700 hover:shadow-md hover:-translate-y-0.5',
                ]"
                @click="selectMember(member.serialNum)"
              >
                <div class="flex items-center gap-3">
                  <div class="w-13 h-13 rounded-xl bg-gradient-to-br from-blue-600 to-purple-600 flex items-center justify-center font-bold text-xl text-white flex-shrink-0 shadow-sm">
                    {{ member.name.charAt(0).toUpperCase() }}
                  </div>
                  <div>
                    <p class="m-0 font-bold text-base text-gray-900 dark:text-gray-100 tracking-tight">
                      {{ member.name }}
                    </p>
                    <p class="m-0 mt-1.5 text-xs text-gray-600 dark:text-gray-400 font-medium px-2 py-0.5 bg-gray-100 dark:bg-gray-800 rounded inline-block w-fit">
                      {{ getRoleName(member.role) }}
                    </p>
                  </div>
                </div>
                <div class="grid grid-cols-3 gap-4 mt-5 pt-4 border-t border-gray-200 dark:border-gray-700">
                  <div class="flex flex-col items-center gap-1 px-2 py-2 bg-gray-50 dark:bg-gray-800 rounded-lg border border-gray-100 dark:border-gray-700 transition-all hover:bg-gray-100 dark:hover:bg-gray-700 hover:-translate-y-px min-w-0">
                    <span class="text-[9px] text-gray-600 dark:text-gray-400 font-semibold tracking-wider whitespace-nowrap text-center">交易笔数</span>
                    <strong class="text-xs font-bold text-gray-900 dark:text-gray-100 tracking-tight whitespace-nowrap overflow-hidden text-ellipsis max-w-full">{{ member.transactionCount ?? 0 }}</strong>
                  </div>
                  <div class="flex flex-col items-center gap-1 px-2 py-2 bg-gray-50 dark:bg-gray-800 rounded-lg border border-gray-100 dark:border-gray-700 transition-all hover:bg-gray-100 dark:hover:bg-gray-700 hover:-translate-y-px min-w-0">
                    <span class="text-[9px] text-gray-600 dark:text-gray-400 font-semibold tracking-wider whitespace-nowrap text-center">总支付</span>
                    <strong class="text-xs font-bold text-gray-900 dark:text-gray-100 tracking-tight whitespace-nowrap overflow-hidden text-ellipsis max-w-full">{{ formatCurrency(member.totalPaid) }}</strong>
                  </div>
                  <div class="flex flex-col items-center gap-1 px-2 py-2 bg-gray-50 dark:bg-gray-800 rounded-lg border border-gray-100 dark:border-gray-700 transition-all hover:bg-gray-100 dark:hover:bg-gray-700 hover:-translate-y-px min-w-0">
                    <span class="text-[9px] text-gray-600 dark:text-gray-400 font-semibold tracking-wider whitespace-nowrap text-center">应分摆</span>
                    <strong class="text-xs font-bold text-gray-900 dark:text-gray-100 tracking-tight whitespace-nowrap overflow-hidden text-ellipsis max-w-full">{{ formatCurrency(member.totalOwed) }}</strong>
                  </div>
                </div>
              </article>
            </div>
            <div v-else class="p-8 text-center text-gray-400 dark:text-gray-600">
              <LucideUserCheck class="w-9 h-9 mb-3 mx-auto" />
              <p class="m-0">
                尚未添加成员
              </p>
            </div>
          </div>

          <div class="bg-white dark:bg-gray-800 rounded-2xl p-6 shadow-lg">
            <div class="flex justify-between items-center">
              <div>
                <h2 class="m-0 text-xl text-gray-900 dark:text-gray-100">
                  {{ selectedMember ? `${selectedMember.name} 的交易` : '交易记录' }}
                </h2>
              </div>
            </div>

            <div class="max-h-[360px] overflow-y-auto overflow-x-hidden rounded-lg [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden">
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
        <section class="mt-8">
          <div class="bg-white dark:bg-gray-800 rounded-2xl p-4 shadow-lg">
            <div v-if="activeTab === 'settlement'" class="w-full">
              <SettlementView />
            </div>
            <div v-else-if="activeTab === 'statistics'" class="w-full">
              <FamilyStatsView />
            </div>
          </div>
        </section>
      </div>

      <div v-else class="p-8 text-center text-gray-400 dark:text-gray-600">
        <LucideUsers class="w-9 h-9 mb-3 mx-auto" />
        <p class="m-0">
          暂无账本数据
        </p>
      </div>
    </template>

    <!-- 家庭预算模态框 -->
    <FamilyBudgetModal
      v-if="showBudgetModal && currentLedger"
      :family-ledger-serial-num="currentLedger.serialNum"
      @close="closeBudgetModal"
      @save="handleCreateFamilyBudget"
    />
  </div>
</template>
