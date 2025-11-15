<script setup lang="ts">
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
  <div class="family-stats-view">
    <div class="view-header">
      <div class="header-info">
        <h2 class="view-title">
          统计报表
        </h2>
        <div v-if="currentLedger" class="ledger-info">
          <span class="ledger-name">{{ currentLedger.name }}</span>
        </div>
      </div>

      <!-- 导出按钮 -->
      <div v-if="currentLedger" class="export-actions">
        <div class="export-dropdown">
          <button class="export-btn">
            <LucideDownload class="w-4 h-4" />
            导出数据
            <LucideChevronDown class="w-4 h-4" />
          </button>
          <div class="dropdown-menu">
            <button class="dropdown-item" @click="exportData('csv')">
              <LucideFileText class="w-4 h-4" />
              CSV 格式
            </button>
            <button class="dropdown-item" @click="exportData('excel')">
              <LucideFileSpreadsheet class="w-4 h-4" />
              Excel 格式
            </button>
            <button class="dropdown-item" @click="exportData('pdf')">
              <LucideFile class="w-4 h-4" />
              PDF 报告
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- 统计内容 -->
    <div class="stats-content">
      <FamilyFinancialStats
        v-if="currentLedger"
        :family-ledger-serial-num="currentLedger.serialNum"
      />

      <!-- 无账本状态 -->
      <div v-else class="no-ledger-state">
        <LucideAlertCircle class="warning-icon" />
        <h3 class="warning-title">
          请先选择账本
        </h3>
        <p class="warning-description">
          需要选择一个家庭账本才能查看统计报表
        </p>
        <router-link to="/family-ledger" class="select-ledger-btn">
          <LucideBook class="w-4 h-4" />
          选择账本
        </router-link>
      </div>
    </div>
  </div>
</template>

<style scoped>
.family-stats-view {
  padding: 1rem;
  max-width: 1200px;
  margin: 0 auto;
}

.view-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 2rem;
}

.header-info {
  display: flex;
  align-items: center;
  gap: 1rem;
}

.view-title {
  font-size: 1.5rem;
  font-weight: 600;
  color: var(--color-base-content);
}

.ledger-info {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.5rem 1rem;
  background-color: var(--color-gray-100);
  border-radius: 0.375rem;
}

.ledger-name {
  font-size: 0.875rem;
  font-weight: 500;
  color: var(--color-gray-700);
}

.export-actions {
  position: relative;
}

.export-dropdown {
  position: relative;
}

.export-btn {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.5rem 1rem;
  background-color: var(--color-primary);
  color: var(--color-primary-content);
  border-radius: 0.375rem;
  font-size: 0.875rem;
  transition: background-color 0.2s;
}

.export-btn:hover {
  background-color: var(--color-primary-hover);
}

.dropdown-menu {
  position: absolute;
  top: 100%;
  right: 0;
  margin-top: 0.25rem;
  background: var(--color-base-100);
  border: 1px solid var(--color-gray-200);
  border-radius: 0.375rem;
  box-shadow: var(--shadow-md);
  z-index: 10;
  min-width: 150px;
  opacity: 0;
  visibility: hidden;
  transform: translateY(-10px);
  transition: all 0.2s;
}

.export-dropdown:hover .dropdown-menu {
  opacity: 1;
  visibility: visible;
  transform: translateY(0);
}

.dropdown-item {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  width: 100%;
  padding: 0.75rem 1rem;
  font-size: 0.875rem;
  color: var(--color-gray-700);
  text-align: left;
  transition: background-color 0.2s;
}

.dropdown-item:hover {
  background-color: var(--color-base-200);
}

.dropdown-item:first-child {
  border-radius: 0.375rem 0.375rem 0 0;
}

.dropdown-item:last-child {
  border-radius: 0 0 0.375rem 0.375rem;
}

.stats-content {
  min-height: 400px;
}

.no-ledger-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 3rem;
  text-align: center;
}

.warning-icon {
  width: 3rem;
  height: 3rem;
  color: var(--color-warning);
  margin-bottom: 1rem;
}

.warning-title {
  font-size: 1.125rem;
  font-weight: 600;
  color: var(--color-base-content);
  margin-bottom: 0.5rem;
}

.warning-description {
  color: var(--color-gray-500);
  margin-bottom: 1.5rem;
}

.select-ledger-btn {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.75rem 1.5rem;
  background-color: var(--color-primary);
  color: var(--color-primary-content);
  border-radius: 0.375rem;
  font-size: 0.875rem;
  font-weight: 500;
  text-decoration: none;
  transition: background-color 0.2s;
}

.select-ledger-btn:hover {
  background-color: var(--color-primary-hover);
}
</style>
