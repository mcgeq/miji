<script setup lang="ts">
import { LucideAlertCircle, LucideBarChart3, LucideFileText } from 'lucide-vue-next';
import { useFamilyLedgerStore } from '@/stores/money';
import SettlementRecords from '../components/SettlementRecords.vue';

// 懒加载图表组件 (Task 27: 按需加载重型组件)
const DebtRelationChart = defineAsyncComponent({
  loader: () => import('../components/DebtRelationChart.vue'),
  loadingComponent: { template: '<div class="animate-pulse bg-gray-200 dark:bg-gray-700 rounded-lg h-64" />' },
  delay: 200,
});

const familyLedgerStore = useFamilyLedgerStore();
const { currentLedger } = storeToRefs(familyLedgerStore);

// 当前选中的标签页
const activeTab = ref<'overview' | 'records'>('overview');

// 切换标签页
function switchTab(tab: 'overview' | 'records') {
  activeTab.value = tab;
}
</script>

<template>
  <div class="p-0">
    <div class="flex flex-col sm:flex-row items-start sm:items-center justify-between mb-8 gap-4">
      <h2 class="text-2xl font-semibold text-gray-900 dark:text-gray-100">
        结算中心
      </h2>
      <div v-if="currentLedger" class="flex items-center gap-2 px-4 py-2 bg-gray-100 dark:bg-gray-800 rounded-md">
        <span class="text-sm font-medium text-gray-700 dark:text-gray-300">{{ currentLedger.name }}</span>
      </div>
    </div>

    <!-- 标签页导航 -->
    <div class="flex gap-1 mb-6 border-b border-gray-200 dark:border-gray-700">
      <button
        class="flex items-center gap-2 px-4 py-3 text-sm font-medium transition-all border-b-2" :class="[
          activeTab === 'overview'
            ? 'text-blue-600 dark:text-blue-400 border-blue-600 dark:border-blue-400 bg-blue-50 dark:bg-blue-900/20'
            : 'text-gray-600 dark:text-gray-400 border-transparent hover:text-gray-900 dark:hover:text-gray-100 hover:bg-gray-50 dark:hover:bg-gray-800',
        ]"
        @click="switchTab('overview')"
      >
        <LucideBarChart3 class="w-4 h-4" />
        债务总览
      </button>
      <button
        class="flex items-center gap-2 px-4 py-3 text-sm font-medium transition-all border-b-2" :class="[
          activeTab === 'records'
            ? 'text-blue-600 dark:text-blue-400 border-blue-600 dark:border-blue-400 bg-blue-50 dark:bg-blue-900/20'
            : 'text-gray-600 dark:text-gray-400 border-transparent hover:text-gray-900 dark:hover:text-gray-100 hover:bg-gray-50 dark:hover:bg-gray-800',
        ]"
        @click="switchTab('records')"
      >
        <LucideFileText class="w-4 h-4" />
        结算记录
      </button>
    </div>

    <!-- 内容区域 -->
    <div class="min-h-[400px]">
      <div v-if="activeTab === 'overview'" class="animate-fade-in">
        <DebtRelationChart
          v-if="currentLedger"
          :family-ledger-serial-num="currentLedger.serialNum"
        />
        <div v-else class="flex flex-col items-center justify-center p-12 text-center">
          <LucideAlertCircle class="w-12 h-12 text-yellow-500 dark:text-yellow-400 mb-4" />
          <h3 class="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-2">
            请先选择账本
          </h3>
          <p class="text-gray-600 dark:text-gray-400">
            需要选择一个家庭账本才能查看结算信息
          </p>
        </div>
      </div>

      <div v-if="activeTab === 'records'" class="animate-fade-in">
        <SettlementRecords
          v-if="currentLedger"
          :family-ledger-serial-num="currentLedger.serialNum"
        />
        <div v-else class="flex flex-col items-center justify-center p-12 text-center">
          <LucideAlertCircle class="w-12 h-12 text-yellow-500 dark:text-yellow-400 mb-4" />
          <h3 class="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-2">
            请先选择账本
          </h3>
          <p class="text-gray-600 dark:text-gray-400">
            需要选择一个家庭账本才能查看结算记录
          </p>
        </div>
      </div>
    </div>
  </div>
</template>
