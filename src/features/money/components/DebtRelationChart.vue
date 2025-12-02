<script setup lang="ts">
import { Button, Card } from '@/components/ui';
import { useFamilyMemberStore, useFamilySplitStore } from '@/stores/money';
// 移除未使用的类型导入

interface Props {
  familyLedgerSerialNum: string;
}

const props = defineProps<Props>();

const splitStore = useFamilySplitStore();
const memberStore = useFamilyMemberStore();

// 使用store状态
const { debtRelations, settlementSuggestions } = storeToRefs(splitStore);
const { members } = storeToRefs(memberStore);

// 本地状态
const showSettlementSuggestions = ref(true);
const selectedMember = ref<string | null>(null);

// 获取成员信息
function getMemberInfo(serialNum: string) {
  const member = members.value.find(m => m.serialNum === serialNum);
  return {
    name: member?.name || 'Unknown',
    avatar: member?.avatar,
    colorTag: member?.colorTag || '#e5e7eb',
  };
}

// 计算成员净余额
const memberBalances = computed(() => {
  const balances = new Map<string, number>();

  // 初始化所有成员余额为0
  members.value.forEach(member => {
    balances.set(member.serialNum, 0);
  });

  // 计算债务关系
  debtRelations.value.forEach(debt => {
    if (!debt.isSettled) {
      // 债权人增加余额
      const creditorBalance = balances.get(debt.creditorMemberSerialNum) || 0;
      balances.set(debt.creditorMemberSerialNum, creditorBalance + debt.amount);

      // 债务人减少余额
      const debtorBalance = balances.get(debt.debtorMemberSerialNum) || 0;
      balances.set(debt.debtorMemberSerialNum, debtorBalance - debt.amount);
    }
  });

  return Array.from(balances.entries()).map(([serialNum, balance]) => ({
    serialNum,
    balance,
    ...getMemberInfo(serialNum),
  }));
});

// 债权人列表
const creditors = computed(() =>
  memberBalances.value.filter(m => m.balance > 0).sort((a, b) => b.balance - a.balance),
);

// 债务人列表
const debtors = computed(() =>
  memberBalances.value.filter(m => m.balance < 0).sort((a, b) => a.balance - b.balance),
);

// 平衡成员列表
const balanced = computed(() =>
  memberBalances.value.filter(m => Math.abs(m.balance) < 0.01),
);

// 获取成员相关的债务关系
function getMemberDebts(memberSerialNum: string) {
  return debtRelations.value.filter(debt =>
    !debt.isSettled && (
      debt.creditorMemberSerialNum === memberSerialNum ||
      debt.debtorMemberSerialNum === memberSerialNum
    ),
  );
}

// 格式化金额
function formatAmount(amount: number): string {
  return Math.abs(amount).toFixed(2);
}

// 移除未使用的函数

// 获取余额状态文本
function getBalanceText(balance: number): string {
  if (balance > 0) {
    return '债权';
  } else if (balance < 0) {
    return '债务';
  } else {
    return '平衡';
  }
}

// 选择成员查看详情
function selectMember(serialNum: string) {
  selectedMember.value = selectedMember.value === serialNum ? null : serialNum;
}

// 获取结算建议
async function fetchSettlementSuggestions() {
  try {
    await splitStore.fetchSettlementSuggestions(props.familyLedgerSerialNum);
  } catch (error) {
    console.error('获取结算建议失败:', error);
  }
}

// 初始化数据
onMounted(() => {
  splitStore.setCurrentLedger(props.familyLedgerSerialNum);
  memberStore.setCurrentLedger(props.familyLedgerSerialNum);

  // 加载数据
  memberStore.fetchMembers(props.familyLedgerSerialNum);
  fetchSettlementSuggestions();
});
</script>

<template>
  <div class="p-4 space-y-6">
    <!-- 头部控制 -->
    <div class="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 mb-6">
      <h3 class="text-xl font-semibold text-gray-900 dark:text-white">
        债务关系图
      </h3>
      <div class="flex items-center gap-4">
        <label class="flex items-center gap-2 text-sm cursor-pointer">
          <input
            v-model="showSettlementSuggestions"
            type="checkbox"
            class="w-4 h-4 text-blue-600 bg-gray-100 border-gray-300 rounded focus:ring-blue-500 dark:focus:ring-blue-600 dark:ring-offset-gray-800 focus:ring-2 dark:bg-gray-700 dark:border-gray-600"
          >
          <span class="text-gray-700 dark:text-gray-300">显示结算建议</span>
        </label>
        <Button variant="secondary" size="sm" @click="fetchSettlementSuggestions">
          <LucideRefreshCw :size="16" />
          <span class="ml-2">刷新</span>
        </Button>
      </div>
    </div>

    <!-- 总览统计 -->
    <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
      <Card padding="md" hoverable>
        <div class="flex items-center gap-3">
          <div class="p-2 rounded-md bg-green-100 dark:bg-green-900/30 text-green-600 dark:text-green-400">
            <LucideTrendingUp :size="20" />
          </div>
          <div class="flex-1">
            <div class="text-2xl font-semibold text-gray-900 dark:text-white">
              {{ creditors.length }}
            </div>
            <div class="text-sm text-gray-500 dark:text-gray-400">
              债权人
            </div>
          </div>
        </div>
      </Card>

      <Card padding="md" hoverable>
        <div class="flex items-center gap-3">
          <div class="p-2 rounded-md bg-red-100 dark:bg-red-900/30 text-red-600 dark:text-red-400">
            <LucideTrendingDown :size="20" />
          </div>
          <div class="flex-1">
            <div class="text-2xl font-semibold text-gray-900 dark:text-white">
              {{ debtors.length }}
            </div>
            <div class="text-sm text-gray-500 dark:text-gray-400">
              债务人
            </div>
          </div>
        </div>
      </Card>

      <Card padding="md" hoverable>
        <div class="flex items-center gap-3">
          <div class="p-2 rounded-md bg-gray-100 dark:bg-gray-700 text-gray-600 dark:text-gray-400">
            <LucideEqual :size="20" />
          </div>
          <div class="flex-1">
            <div class="text-2xl font-semibold text-gray-900 dark:text-white">
              {{ balanced.length }}
            </div>
            <div class="text-sm text-gray-500 dark:text-gray-400">
              已平衡
            </div>
          </div>
        </div>
      </Card>

      <Card padding="md" hoverable>
        <div class="flex items-center gap-3">
          <div class="p-2 rounded-md bg-blue-100 dark:bg-blue-900/30 text-blue-600 dark:text-blue-400">
            <LucideUsers :size="20" />
          </div>
          <div class="flex-1">
            <div class="text-2xl font-semibold text-gray-900 dark:text-white">
              {{ members.length }}
            </div>
            <div class="text-sm text-gray-500 dark:text-gray-400">
              总成员
            </div>
          </div>
        </div>
      </Card>
    </div>

    <!-- 成员余额列表 -->
    <div class="mb-8">
      <h4 class="text-lg font-semibold text-gray-900 dark:text-white mb-4">
        成员余额
      </h4>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <!-- 债权人 -->
        <Card v-if="creditors.length > 0" padding="none">
          <h5 class="text-base font-semibold px-4 py-3 bg-gray-50 dark:bg-gray-900/50 border-b border-gray-200 dark:border-gray-700 text-green-600 dark:text-green-400 m-0">
            债权人
          </h5>
          <div class="p-2">
            <div
              v-for="member in creditors"
              :key="member.serialNum"
              class="flex items-center gap-3 p-3 rounded-md cursor-pointer transition-all hover:bg-gray-50 dark:hover:bg-gray-800"
              :class="selectedMember === member.serialNum && 'bg-blue-50 dark:bg-blue-900/20 border border-blue-500'"
              @click="selectMember(member.serialNum)"
            >
              <div class="shrink-0">
                <img
                  v-if="member.avatar"
                  :src="member.avatar"
                  :alt="member.name"
                  class="w-8 h-8 rounded-full object-cover"
                >
                <div
                  v-else
                  class="w-8 h-8 rounded-full flex items-center justify-center text-white font-semibold text-sm"
                  :style="{ backgroundColor: member.colorTag }"
                >
                  {{ member.name.charAt(0).toUpperCase() }}
                </div>
              </div>

              <div class="flex-1">
                <div class="font-medium text-gray-900 dark:text-white mb-0.5">
                  {{ member.name }}
                </div>
                <div class="text-sm font-semibold text-green-600 dark:text-green-400">
                  +￥{{ formatAmount(member.balance) }}
                </div>
              </div>

              <div class="px-2 py-1 rounded-full text-xs font-medium bg-green-100 dark:bg-green-900/30 text-green-600 dark:text-green-400">
                {{ getBalanceText(member.balance) }}
              </div>
            </div>
          </div>
        </Card>

        <!-- 债务人 -->
        <Card v-if="debtors.length > 0" padding="none">
          <h5 class="text-base font-semibold px-4 py-3 bg-gray-50 dark:bg-gray-900/50 border-b border-gray-200 dark:border-gray-700 text-red-600 dark:text-red-400 m-0">
            债务人
          </h5>
          <div class="p-2">
            <div
              v-for="member in debtors"
              :key="member.serialNum"
              class="flex items-center gap-3 p-3 rounded-md cursor-pointer transition-all hover:bg-gray-50 dark:hover:bg-gray-800"
              :class="selectedMember === member.serialNum && 'bg-blue-50 dark:bg-blue-900/20 border border-blue-500'"
              @click="selectMember(member.serialNum)"
            >
              <div class="shrink-0">
                <img
                  v-if="member.avatar"
                  :src="member.avatar"
                  :alt="member.name"
                  class="w-8 h-8 rounded-full object-cover"
                >
                <div
                  v-else
                  class="w-8 h-8 rounded-full flex items-center justify-center text-white font-semibold text-sm"
                  :style="{ backgroundColor: member.colorTag }"
                >
                  {{ member.name.charAt(0).toUpperCase() }}
                </div>
              </div>

              <div class="flex-1">
                <div class="font-medium text-gray-900 dark:text-white mb-0.5">
                  {{ member.name }}
                </div>
                <div class="text-sm font-semibold text-red-600 dark:text-red-400">
                  -¥{{ formatAmount(member.balance) }}
                </div>
              </div>

              <div class="px-2 py-1 rounded-full text-xs font-medium bg-red-100 dark:bg-red-900/30 text-red-600 dark:text-red-400">
                {{ getBalanceText(member.balance) }}
              </div>
            </div>
          </div>
        </Card>

        <!-- 平衡成员 -->
        <Card v-if="balanced.length > 0" padding="none">
          <h5 class="text-base font-semibold px-4 py-3 bg-gray-50 dark:bg-gray-900/50 border-b border-gray-200 dark:border-gray-700 text-gray-600 dark:text-gray-400 m-0">
            已平衡
          </h5>
          <div class="p-2">
            <div
              v-for="member in balanced"
              :key="member.serialNum"
              class="flex items-center gap-3 p-3 rounded-md"
            >
              <div class="shrink-0">
                <img
                  v-if="member.avatar"
                  :src="member.avatar"
                  :alt="member.name"
                  class="w-8 h-8 rounded-full object-cover"
                >
                <div
                  v-else
                  class="w-8 h-8 rounded-full flex items-center justify-center text-white font-semibold text-sm"
                  :style="{ backgroundColor: member.colorTag }"
                >
                  {{ member.name.charAt(0).toUpperCase() }}
                </div>
              </div>

              <div class="flex-1">
                <div class="font-medium text-gray-900 dark:text-white mb-0.5">
                  {{ member.name }}
                </div>
                <div class="text-sm font-semibold text-gray-500 dark:text-gray-400">
                  ¥0.00
                </div>
              </div>

              <div class="px-2 py-1 rounded-full text-xs font-medium bg-gray-100 dark:bg-gray-700 text-gray-600 dark:text-gray-400">
                {{ getBalanceText(member.balance) }}
              </div>
            </div>
          </div>
        </Card>
      </div>
    </div>

    <!-- 成员详情 -->
    <Card v-if="selectedMember" padding="md" class="mb-8">
      <h4 class="text-lg font-semibold text-gray-900 dark:text-white mb-4">
        {{ getMemberInfo(selectedMember).name }} 的债务详情
      </h4>

      <div class="flex flex-col gap-3">
        <div
          v-for="debt in getMemberDebts(selectedMember)"
          :key="debt.serialNum"
          class="p-3 bg-gray-50 dark:bg-gray-900/50 rounded-md border border-gray-200 dark:border-gray-700"
        >
          <div class="flex items-center justify-between mb-2">
            <div class="flex items-center gap-2">
              <span class="font-medium text-green-600 dark:text-green-400">{{ getMemberInfo(debt.creditorMemberSerialNum).name }}</span>
              <LucideArrowRight :size="16" class="text-gray-400 dark:text-gray-600" />
              <span class="font-medium text-red-600 dark:text-red-400">{{ getMemberInfo(debt.debtorMemberSerialNum).name }}</span>
            </div>
            <div class="font-semibold text-gray-900 dark:text-white">
              ¥{{ debt.amount.toFixed(2) }}
            </div>
          </div>

          <div v-if="debt.description" class="text-sm text-gray-600 dark:text-gray-400 mb-2">
            {{ debt.description }}
          </div>

          <div class="text-xs text-gray-400 dark:text-gray-500">
            {{ new Date(debt.createdAt).toLocaleDateString() }}
          </div>
        </div>
      </div>
    </Card>

    <!-- 结算建议 -->
    <Card v-if="showSettlementSuggestions && settlementSuggestions.length > 0" padding="md" class="mb-8">
      <h4 class="text-lg font-semibold text-gray-900 dark:text-white mb-4">
        结算建议
      </h4>

      <div class="flex flex-col gap-4">
        <div
          v-for="(suggestion, index) in settlementSuggestions"
          :key="index"
          class="p-4 bg-blue-50 dark:bg-blue-900/20 rounded-lg border border-blue-200 dark:border-blue-800"
        >
          <div class="flex items-center gap-4 mb-2">
            <div class="flex items-center gap-2 flex-1">
              <div class="shrink-0">
                <div
                  class="w-6 h-6 rounded-full flex items-center justify-center text-white font-semibold text-xs"
                  :style="{ backgroundColor: getMemberInfo(suggestion.fromMemberSerialNum).colorTag }"
                >
                  {{ suggestion.fromMemberName.charAt(0).toUpperCase() }}
                </div>
              </div>
              <span class="font-medium text-gray-900 dark:text-white">{{ suggestion.fromMemberName }}</span>
            </div>

            <div class="flex flex-col items-center gap-1">
              <LucideArrowRight :size="20" class="text-blue-500" />
              <div class="text-sm font-semibold text-blue-600 dark:text-blue-400">
                ¥{{ suggestion.amount.toFixed(2) }}
              </div>
            </div>

            <div class="flex items-center gap-2 flex-1">
              <div class="shrink-0">
                <div
                  class="w-6 h-6 rounded-full flex items-center justify-center text-white font-semibold text-xs"
                  :style="{ backgroundColor: getMemberInfo(suggestion.toMemberSerialNum).colorTag }"
                >
                  {{ suggestion.toMemberName.charAt(0).toUpperCase() }}
                </div>
              </div>
              <span class="font-medium text-gray-900 dark:text-white">{{ suggestion.toMemberName }}</span>
            </div>
          </div>

          <div v-if="suggestion.relatedDebts.length > 0" class="text-xs text-gray-600 dark:text-gray-400">
            <span>涉及债务:</span>
            <span class="font-medium ml-1">{{ suggestion.relatedDebts.length }} 笔</span>
          </div>
        </div>
      </div>
    </Card>

    <!-- 空状态 -->
    <div v-if="memberBalances.every(m => Math.abs(m.balance) < 0.01)" class="flex flex-col items-center justify-center py-12 text-center">
      <LucideCheckCircle :size="64" class="text-green-500 dark:text-green-400 mb-4" />
      <h3 class="text-xl font-semibold text-gray-900 dark:text-white mb-2">
        所有账务已平衡
      </h3>
      <p class="text-gray-500 dark:text-gray-400">
        当前没有未结算的债务关系
      </p>
    </div>
  </div>
</template>
