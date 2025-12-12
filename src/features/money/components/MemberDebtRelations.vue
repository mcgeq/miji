<script setup lang="ts">
  import { LucideArrowRight, LucideTrendingDown, LucideTrendingUp } from 'lucide-vue-next';
  import { Card, Spinner } from '@/components/ui';
  import type { DebtRelation } from '@/schema/money';

  interface Props {
    memberSerialNum: string;
  }

  const props = defineProps<Props>();

  const debtRelations = ref<DebtRelation[]>([]);
  const loading = ref(true);

  // 加载债务关系
  onMounted(async () => {
    await loadDebtRelations();
  });

  async function loadDebtRelations() {
    loading.value = true;
    try {
      // TODO: 替换为实际API调用
      // const relations = await DebtApi.getDebtRelations({ memberSerialNum: props.memberSerialNum });
      // debtRelations.value = relations;

      // 临时模拟数据
      debtRelations.value = [];
    } catch (error) {
      console.error('Failed to load debt relations:', error);
    } finally {
      loading.value = false;
    }
  }

  // 我欠别人的债务
  const debts = computed(() =>
    debtRelations.value.filter(r => r.debtorMemberSerialNum === props.memberSerialNum),
  );

  // 别人欠我的债权
  const credits = computed(() =>
    debtRelations.value.filter(r => r.creditorMemberSerialNum === props.memberSerialNum),
  );

  // 净余额
  const netBalance = computed(() => {
    const totalCredit = credits.value.reduce((sum, r) => sum + r.amount, 0);
    const totalDebt = debts.value.reduce((sum, r) => sum + r.amount, 0);
    return totalCredit - totalDebt;
  });

  // 格式化金额
  function formatAmount(amount: number): string {
    return `¥${Math.abs(amount).toFixed(2)}`;
  }
</script>

<template>
  <div class="flex flex-col gap-6">
    <!-- 加载状态 -->
    <div
      v-if="loading"
      class="flex flex-col items-center gap-2 py-12 text-gray-500 dark:text-gray-400"
    >
      <Spinner size="lg" />
      <span>加载中...</span>
    </div>

    <template v-else>
      <!-- 净余额卡片 -->
      <Card
        padding="lg"
        class="flex items-center justify-between"
        :class="[
          netBalance > 0 ? 'bg-gradient-to-br from-green-50 to-white dark:from-green-900/20 dark:to-gray-900 border-2 border-green-600 dark:border-green-500'
          : netBalance < 0 ? 'bg-gradient-to-br from-red-50 to-white dark:from-red-900/20 dark:to-gray-900 border-2 border-red-600 dark:border-red-500'
            : 'border-2 border-gray-300 dark:border-gray-600',
        ]"
      >
        <div>
          <label class="block text-sm text-gray-600 dark:text-gray-400 mb-2">净余额</label>
          <h2
            class="text-4xl md:text-5xl font-bold mb-2"
            :class="[
              netBalance > 0 ? 'text-green-600 dark:text-green-400'
              : netBalance < 0 ? 'text-red-600 dark:text-red-400'
                : 'text-gray-900 dark:text-white',
            ]"
          >
            {{ netBalance > 0 ? '+' : netBalance < 0 ? '-' : '' }}
            {{ formatAmount(netBalance) }}
          </h2>
          <p class="text-sm text-gray-600 dark:text-gray-400">
            {{ netBalance > 0 ? '您有应收款项' : netBalance < 0 ? '您有应付款项' : '已结清' }}
          </p>
        </div>
        <component
          :is="netBalance > 0 ? LucideTrendingUp : netBalance < 0 ? LucideTrendingDown : LucideArrowRight"
          :size="64"
          class="opacity-20"
          :class="[
            netBalance > 0 ? 'text-green-600 dark:text-green-500'
            : netBalance < 0 ? 'text-red-600 dark:text-red-500'
              : 'text-gray-400 dark:text-gray-600',
          ]"
        />
      </Card>

      <!-- 债务列表 -->
      <div class="flex flex-col gap-6">
        <!-- 应收款（别人欠我的） -->
        <Card v-if="credits.length > 0" padding="none" class="overflow-hidden">
          <h3
            class="flex items-center gap-2 px-5 py-4 text-base font-semibold bg-green-100 dark:bg-green-900/30 text-green-800 dark:text-green-300 border-b border-green-200 dark:border-green-800"
          >
            <LucideTrendingUp :size="20" />
            应收款
          </h3>
          <div class="flex flex-col">
            <div
              v-for="credit in credits"
              :key="credit.serialNum"
              class="px-5 py-4 border-b border-gray-200 dark:border-gray-700 last:border-b-0 transition-colors hover:bg-gray-50 dark:hover:bg-gray-800/50"
            >
              <div class="flex justify-between items-center mb-2">
                <span class="text-base font-medium text-gray-900 dark:text-white"
                  >成员 {{ credit.debtorMemberSerialNum.slice(0, 8) }}</span
                >
                <span class="text-lg font-semibold text-green-600 dark:text-green-400"
                  >{{ formatAmount(credit.amount) }}</span
                >
              </div>
              <div class="flex justify-between items-center text-sm">
                <span
                  class="px-3 py-1 rounded-xl font-medium"
                  :class="[
                    credit.isSettled
                      ? 'bg-green-100 dark:bg-green-900/30 text-green-800 dark:text-green-300'
                      : 'bg-yellow-100 dark:bg-yellow-900/30 text-yellow-800 dark:text-yellow-300',
                  ]"
                >
                  {{ credit.isSettled ? '已结算' : '待结算' }}
                </span>
                <span class="text-gray-500 dark:text-gray-400">
                  {{ new Date(credit.createdAt).toLocaleDateString('zh-CN') }}
                </span>
              </div>
            </div>
          </div>
          <div
            class="flex justify-between items-center px-5 py-4 bg-gray-50 dark:bg-gray-900/50 text-sm"
          >
            <span class="text-gray-600 dark:text-gray-400">小计</span>
            <strong class="text-lg font-semibold text-gray-900 dark:text-white"
              >{{ formatAmount(credits.reduce((sum, r) => sum + r.amount, 0)) }}</strong
            >
          </div>
        </Card>

        <!-- 应付款（我欠别人的） -->
        <Card v-if="debts.length > 0" padding="none" class="overflow-hidden">
          <h3
            class="flex items-center gap-2 px-5 py-4 text-base font-semibold bg-red-100 dark:bg-red-900/30 text-red-800 dark:text-red-300 border-b border-red-200 dark:border-red-800"
          >
            <LucideTrendingDown :size="20" />
            应付款
          </h3>
          <div class="flex flex-col">
            <div
              v-for="debt in debts"
              :key="debt.serialNum"
              class="px-5 py-4 border-b border-gray-200 dark:border-gray-700 last:border-b-0 transition-colors hover:bg-gray-50 dark:hover:bg-gray-800/50"
            >
              <div class="flex justify-between items-center mb-2">
                <span class="text-base font-medium text-gray-900 dark:text-white"
                  >成员 {{ debt.creditorMemberSerialNum.slice(0, 8) }}</span
                >
                <span class="text-lg font-semibold text-red-600 dark:text-red-400"
                  >{{ formatAmount(debt.amount) }}</span
                >
              </div>
              <div class="flex justify-between items-center text-sm">
                <span
                  class="px-3 py-1 rounded-xl font-medium"
                  :class="[
                    debt.isSettled
                      ? 'bg-green-100 dark:bg-green-900/30 text-green-800 dark:text-green-300'
                      : 'bg-yellow-100 dark:bg-yellow-900/30 text-yellow-800 dark:text-yellow-300',
                  ]"
                >
                  {{ debt.isSettled ? '已结算' : '待结算' }}
                </span>
                <span class="text-gray-500 dark:text-gray-400">
                  {{ new Date(debt.createdAt).toLocaleDateString('zh-CN') }}
                </span>
              </div>
            </div>
          </div>
          <div
            class="flex justify-between items-center px-5 py-4 bg-gray-50 dark:bg-gray-900/50 text-sm"
          >
            <span class="text-gray-600 dark:text-gray-400">小计</span>
            <strong class="text-lg font-semibold text-gray-900 dark:text-white"
              >{{ formatAmount(debts.reduce((sum, r) => sum + r.amount, 0)) }}</strong
            >
          </div>
        </Card>

        <!-- 空状态 -->
        <div
          v-if="credits.length === 0 && debts.length === 0"
          class="flex flex-col items-center gap-3 py-12 text-center"
        >
          <LucideArrowRight :size="48" class="text-gray-300 dark:text-gray-600" />
          <p class="text-base text-gray-600 dark:text-gray-400">暂无债务关系</p>
          <span class="text-sm text-gray-400 dark:text-gray-500"
            >参与分摆后，债务关系将显示在这里</span
          >
        </div>
      </div>
    </template>
  </div>
</template>
