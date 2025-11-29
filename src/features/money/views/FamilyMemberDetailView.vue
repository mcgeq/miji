<script setup lang="ts">
import {
  LucideActivity,
  LucideArrowLeft,
  LucideCoins,
  LucideTrendingUp,
  LucideWallet,
} from 'lucide-vue-next';
import { useFamilyLedgerStore, useFamilyMemberStore } from '@/stores/money';
import MemberDebtRelations from '../components/MemberDebtRelations.vue';
import MemberSplitRecordList from '../components/MemberSplitRecordList.vue';
import MemberTransactionList from '../components/MemberTransactionList.vue';

const route = useRoute();
const router = useRouter();
const memberStore = useFamilyMemberStore();
const familyLedgerStore = useFamilyLedgerStore();

const memberSerialNum = computed(() => {
  const params = route.params as { memberSerialNum?: string };
  return params.memberSerialNum || '';
});
const activeTab = ref<'transactions' | 'splits' | 'debts'>('transactions');

// 获取成员信息 - 从当前家庭账本的成员列表中查找
const member = computed(() => {
  const members = familyLedgerStore.currentLedger?.memberList ?? [];
  return members.find(m => m.serialNum === memberSerialNum.value);
});

// 获取成员统计
const memberStats = computed(() => memberStore.getMemberStats(memberSerialNum.value));

// 页面加载
const loading = ref(true);

onMounted(async () => {
  try {
    // 确保家庭账本数据已加载
    if (!familyLedgerStore.currentLedger) {
      const ledgerSerialNum = route.query.ledgerSerialNum as string | undefined;
      if (ledgerSerialNum) {
        await familyLedgerStore.switchLedger(ledgerSerialNum);
      }
    }
    // 加载成员统计数据
    if (member.value) {
      await memberStore.fetchMemberStats(memberSerialNum.value);
    }
  } catch (error) {
    console.error('Failed to load member details:', error);
  } finally {
    loading.value = false;
  }
});

function goBack() {
  router.back();
}

function formatCurrency(amount: number | undefined): string {
  if (amount === undefined || amount === null) return '¥0.00';
  return `¥${amount.toFixed(2)}`;
}

function getBalanceClass(balance: number | undefined): string {
  if (!balance) return 'neutral';
  return balance > 0 ? 'positive' : balance < 0 ? 'negative' : 'neutral';
}

function getRoleName(role: string): string {
  const roleMap: Record<string, string> = {
    Owner: '所有者',
    Admin: '管理员',
    Member: '成员',
    Viewer: '查看者',
  };
  return roleMap[role] || role;
}
</script>

<template>
  <div class="min-h-screen bg-gray-50 dark:bg-gray-900 p-6">
    <div v-if="loading" class="flex flex-col items-center justify-center min-h-[60vh] gap-4">
      <div class="w-10 h-10 border-3 border-gray-300 dark:border-gray-700 border-t-blue-600 rounded-full animate-spin" />
      <span class="text-gray-600 dark:text-gray-400">加载中...</span>
    </div>

    <template v-else-if="member">
      <!-- 头部 -->
      <header class="flex gap-4 mb-8">
        <button class="p-2 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg cursor-pointer transition-all hover:bg-gray-100 dark:hover:bg-gray-700" @click="goBack">
          <LucideArrowLeft class="w-5 h-5" />
        </button>
        <div class="flex items-center gap-6 flex-1 bg-white dark:bg-gray-800 p-6 rounded-xl shadow-sm">
          <div
            class="w-20 h-20 rounded-full flex items-center justify-center text-white text-3xl font-semibold flex-shrink-0"
            :style="{ backgroundColor: member.colorTag || '#3b82f6' }"
          >
            {{ member.name.charAt(0).toUpperCase() }}
          </div>
          <div>
            <h1 class="text-2xl font-semibold m-0 mb-2 text-gray-900 dark:text-gray-100">
              {{ member.name }}
            </h1>
            <span
              class="inline-block px-3 py-1 rounded-xl text-sm font-medium" :class="[
                member.role === 'Owner' ? 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900/30 dark:text-yellow-300'
                : member.role === 'Admin' ? 'bg-blue-100 text-blue-800 dark:bg-blue-900/30 dark:text-blue-300'
                  : 'bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-300',
              ]"
            >
              {{ getRoleName(member.role) }}
            </span>
            <p v-if="member.userSerialNum" class="mt-2 mb-0 text-gray-500 dark:text-gray-400 text-sm">
              ID: {{ member.userSerialNum }}
            </p>
          </div>
        </div>
      </header>

      <!-- 财务统计卡片 -->
      <section class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
        <div class="bg-white dark:bg-gray-800 p-6 rounded-xl shadow-sm flex items-center gap-4">
          <LucideWallet class="w-10 h-10 p-2 rounded-lg bg-gray-100 dark:bg-gray-700 text-blue-600 dark:text-blue-400" />
          <div>
            <label class="block text-sm text-gray-500 dark:text-gray-400 mb-1">总支付</label>
            <h3 class="m-0 text-2xl font-semibold text-gray-900 dark:text-gray-100">
              {{ formatCurrency(memberStats?.totalPaid) }}
            </h3>
          </div>
        </div>
        <div class="bg-white dark:bg-gray-800 p-6 rounded-xl shadow-sm flex items-center gap-4">
          <LucideCoins class="w-10 h-10 p-2 rounded-lg bg-gray-100 dark:bg-gray-700 text-blue-600 dark:text-blue-400" />
          <div>
            <label class="block text-sm text-gray-500 dark:text-gray-400 mb-1">应分摆</label>
            <h3 class="m-0 text-2xl font-semibold text-gray-900 dark:text-gray-100">
              {{ formatCurrency(memberStats?.totalOwed) }}
            </h3>
          </div>
        </div>
        <div
          class="bg-white dark:bg-gray-800 p-6 rounded-xl shadow-sm flex items-center gap-4"
        >
          <LucideTrendingUp
            class="w-10 h-10 p-2 rounded-lg" :class="[
              getBalanceClass(memberStats?.netBalance) === 'positive' ? 'bg-green-100 dark:bg-green-900/30 text-green-600 dark:text-green-400'
              : getBalanceClass(memberStats?.netBalance) === 'negative' ? 'bg-red-100 dark:bg-red-900/30 text-red-600 dark:text-red-400'
                : 'bg-gray-100 dark:bg-gray-700 text-blue-600 dark:text-blue-400',
            ]"
          />
          <div>
            <label class="block text-sm text-gray-500 dark:text-gray-400 mb-1">净余额</label>
            <h3
              class="m-0 text-2xl font-semibold" :class="[
                getBalanceClass(memberStats?.netBalance) === 'positive' ? 'text-green-600 dark:text-green-400'
                : getBalanceClass(memberStats?.netBalance) === 'negative' ? 'text-red-600 dark:text-red-400'
                  : 'text-gray-900 dark:text-gray-100',
              ]"
            >
              {{ formatCurrency(memberStats?.netBalance) }}
            </h3>
          </div>
        </div>
        <div class="bg-white dark:bg-gray-800 p-6 rounded-xl shadow-sm flex items-center gap-4">
          <LucideActivity class="w-10 h-10 p-2 rounded-lg bg-gray-100 dark:bg-gray-700 text-blue-600 dark:text-blue-400" />
          <div>
            <label class="block text-sm text-gray-500 dark:text-gray-400 mb-1">交易笔数</label>
            <h3 class="m-0 text-2xl font-semibold text-gray-900 dark:text-gray-100">
              {{ memberStats?.transactionCount || 0 }}
            </h3>
          </div>
        </div>
      </section>

      <!-- 标签页 -->
      <section class="bg-white dark:bg-gray-800 rounded-xl shadow-sm overflow-hidden">
        <div class="flex border-b border-gray-200 dark:border-gray-700">
          <button
            class="flex-1 px-4 py-4 bg-transparent border-none cursor-pointer text-base font-medium transition-all border-b-2" :class="[
              activeTab === 'transactions'
                ? 'text-blue-600 dark:text-blue-400 border-blue-600 dark:border-blue-400'
                : 'text-gray-500 dark:text-gray-400 border-transparent hover:bg-gray-50 dark:hover:bg-gray-700',
            ]"
            @click="activeTab = 'transactions'"
          >
            交易记录
          </button>
          <button
            class="flex-1 px-4 py-4 bg-transparent border-none cursor-pointer text-base font-medium transition-all border-b-2" :class="[
              activeTab === 'splits'
                ? 'text-blue-600 dark:text-blue-400 border-blue-600 dark:border-blue-400'
                : 'text-gray-500 dark:text-gray-400 border-transparent hover:bg-gray-50 dark:hover:bg-gray-700',
            ]"
            @click="activeTab = 'splits'"
          >
            分摆记录
          </button>
          <button
            class="flex-1 px-4 py-4 bg-transparent border-none cursor-pointer text-base font-medium transition-all border-b-2" :class="[
              activeTab === 'debts'
                ? 'text-blue-600 dark:text-blue-400 border-blue-600 dark:border-blue-400'
                : 'text-gray-500 dark:text-gray-400 border-transparent hover:bg-gray-50 dark:hover:bg-gray-700',
            ]"
            @click="activeTab = 'debts'"
          >
            债务关系
          </button>
        </div>

        <div class="p-8">
          <div v-if="activeTab === 'transactions'" class="min-h-[400px]">
            <MemberTransactionList :member-serial-num="memberSerialNum" />
          </div>
          <div v-if="activeTab === 'splits'" class="min-h-[400px]">
            <MemberSplitRecordList :member-serial-num="memberSerialNum" />
          </div>
          <div v-if="activeTab === 'debts'" class="min-h-[400px]">
            <MemberDebtRelations :member-serial-num="memberSerialNum" />
          </div>
        </div>
      </section>
    </template>

    <div v-else class="flex flex-col items-center justify-center min-h-[60vh] gap-4">
      <p class="text-gray-600 dark:text-gray-400">
        未找到成员信息
      </p>
      <button class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors" @click="goBack">
        返回
      </button>
    </div>
  </div>
</template>
