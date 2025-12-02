<script setup lang="ts">
import {
  LucideAlertCircle,
  LucideBook,
  LucideChevronDown,
  LucideDownload,
  LucideFile,
  LucideFileSpreadsheet,
  LucideFileText,
} from 'lucide-vue-next';
import { useFamilyLedgerStore } from '@/stores/money';
import FamilyFinancialStats from '../components/FamilyFinancialStats.vue';

const familyLedgerStore = useFamilyLedgerStore();
const { currentLedger } = storeToRefs(familyLedgerStore);

// 导出功能
async function exportData(format: 'csv' | 'excel' | 'pdf') {
  if (!currentLedger.value) {
    console.warn('请先选择账本');
    return;
  }

  try {
    const { FamilyApi } = await import('@/services/family/familyApi');

    // 调用导出API
    const blob = await FamilyApi.export.exportStats(
      currentLedger.value.serialNum,
      format,
      {
        includeMembers: true,
        includeTransactions: true,
      },
    );

    // 创建下载链接
    const url = URL.createObjectURL(blob);
    const fileName = `family-stats-${currentLedger.value.name}-${new Date().toISOString().split('T')[0]}.${format}`;

    const a = document.createElement('a');
    a.href = url;
    a.download = fileName;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);

    // console.log(`Successfully exported ${format} file: ${fileName}`);
  } catch (error) {
    console.error('导出失败:', error);

    // 开发环境下的fallback
    if (import.meta.env.DEV) {
      const fileName = `family-stats-${currentLedger.value.name}-${new Date().toISOString().split('T')[0]}.${format}`;
      console.warn(`导出功能开发中，将导出为: ${fileName}`);
    } else {
      console.error('导出失败，请稍后重试');
    }
  }
}
</script>

<template>
  <div class="p-0">
    <div class="flex flex-col md:flex-row items-start md:items-center justify-between mb-8 gap-4">
      <div class="flex items-center gap-4">
        <h2 class="text-2xl font-semibold text-gray-900 dark:text-gray-100">
          统计报表
        </h2>
        <div v-if="currentLedger" class="flex items-center gap-2 px-4 py-2 bg-gray-100 dark:bg-gray-800 rounded-md">
          <span class="text-sm font-medium text-gray-700 dark:text-gray-300">{{ currentLedger.name }}</span>
        </div>
      </div>

      <!-- 导出按钮 -->
      <div v-if="currentLedger" class="relative">
        <div class="relative group">
          <button class="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-md text-sm transition-colors hover:bg-blue-700">
            <LucideDownload class="w-4 h-4" />
            导出数据
            <LucideChevronDown class="w-4 h-4" />
          </button>
          <div class="absolute top-full right-0 mt-1 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-md shadow-lg z-10 min-w-[150px] opacity-0 invisible -translate-y-2 transition-all duration-200 group-hover:opacity-100 group-hover:visible group-hover:translate-y-0">
            <button class="flex items-center gap-2 w-full px-4 py-3 text-sm text-gray-700 dark:text-gray-300 text-left transition-colors hover:bg-gray-100 dark:hover:bg-gray-700 first:rounded-t-md last:rounded-b-md" @click="exportData('csv')">
              <LucideFileText class="w-4 h-4" />
              CSV 格式
            </button>
            <button class="flex items-center gap-2 w-full px-4 py-3 text-sm text-gray-700 dark:text-gray-300 text-left transition-colors hover:bg-gray-100 dark:hover:bg-gray-700 first:rounded-t-md last:rounded-b-md" @click="exportData('excel')">
              <LucideFileSpreadsheet class="w-4 h-4" />
              Excel 格式
            </button>
            <button class="flex items-center gap-2 w-full px-4 py-3 text-sm text-gray-700 dark:text-gray-300 text-left transition-colors hover:bg-gray-100 dark:hover:bg-gray-700 first:rounded-t-md last:rounded-b-md" @click="exportData('pdf')">
              <LucideFile class="w-4 h-4" />
              PDF 报告
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- 统计内容 -->
    <div class="min-h-[400px]">
      <FamilyFinancialStats
        v-if="currentLedger"
        :family-ledger-serial-num="currentLedger.serialNum"
      />

      <!-- 无账本状态 -->
      <div v-else class="flex flex-col items-center justify-center p-12 text-center">
        <LucideAlertCircle class="w-12 h-12 text-yellow-500 dark:text-yellow-400 mb-4" />
        <h3 class="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-2">
          请先选择账本
        </h3>
        <p class="text-gray-500 dark:text-gray-400 mb-6">
          需要选择一个家庭账本才能查看统计报表
        </p>
        <router-link to="/family-ledger" class="flex items-center gap-2 px-6 py-3 bg-blue-600 text-white rounded-md text-sm font-medium no-underline transition-colors hover:bg-blue-700">
          <LucideBook class="w-4 h-4" />
          选择账本
        </router-link>
      </div>
    </div>
  </div>
</template>
