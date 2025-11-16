<script setup lang="ts">
import { invoke } from '@tauri-apps/api/core';
import {
  AlertCircle as LucideAlertCircle,
  AlertTriangle as LucideAlertTriangle,
  CheckCircle as LucideCheckCircle,
  ChevronDown as LucideChevronDown,
  ChevronUp as LucideChevronUp,
  Database as LucideDatabase,
  Info as LucideInfo,
  Loader2 as LucideLoader2,
  Play as LucidePlay,
  SkipForward as LucideSkipForward,
} from 'lucide-vue-next';
import { onMounted, ref } from 'vue';
import { toast } from '@/utils/toast';

interface MigrationResult {
  successCount: number;
  errorCount: number;
  skippedCount: number;
  errors: string[];
  durationMs: number;
}

interface SplitRecordsStats {
  totalSplitRecords: number;
  transactionsWithSplitMembers: number;
  migratedTransactions: number;
  pendingMigrations: number;
  migrationProgress: number;
}

const migrating = ref(false);
const migrationResult = ref<MigrationResult | null>(null);
const showErrors = ref(false);
const stats = ref<SplitRecordsStats | null>(null);
const loadingStats = ref(false);

async function loadStats() {
  try {
    loadingStats.value = true;
    const response = await invoke<{ data: SplitRecordsStats }>('get_split_records_stats');
    stats.value = response.data;
  } catch (error: any) {
    console.error('加载统计失败:', error);
  } finally {
    loadingStats.value = false;
  }
}

async function migrateSplitRecords() {
  if (migrating.value) return;

  // eslint-disable-next-line no-alert
  const confirmed = window.confirm(
    '确认要迁移历史分摊记录吗？\n\n' +
    '这将把所有历史交易的分摊成员（split_members JSON）数据迁移到 split_records 表。\n' +
    '此操作是安全的，不会删除任何数据。',
  );

  if (!confirmed) return;

  try {
    migrating.value = true;
    migrationResult.value = null;
    showErrors.value = false;

    const response = await invoke<{ data: MigrationResult }>('migrate_split_records');
    migrationResult.value = response.data;

    // 迁移后刷新统计
    await loadStats();

    if (response.data.errorCount === 0) {
      toast.success(
        `迁移完成！成功: ${response.data.successCount}, 跳过: ${response.data.skippedCount}, 耗时: ${response.data.durationMs}ms`,
      );
    } else {
      toast.warning(
        `迁移完成，有 ${response.data.errorCount} 条失败。成功: ${response.data.successCount}, 跳过: ${response.data.skippedCount}`,
      );
    }
  } catch (error: any) {
    console.error('迁移失败:', error);
    toast.error(`数据迁移失败: ${error.message || error}`);
  } finally {
    migrating.value = false;
  }
}

function toggleErrors() {
  showErrors.value = !showErrors.value;
}

function formatDuration(ms: number): string {
  if (ms < 1000) return `${ms}ms`;
  return `${(ms / 1000).toFixed(2)}s`;
}

// 组件挂载时加载统计
onMounted(() => {
  loadStats();
});
</script>

<template>
  <div class="data-migration">
    <div class="migration-card">
      <div class="card-header">
        <div class="header-icon">
          <LucideDatabase class="icon" />
        </div>
        <div class="header-content">
          <h3>分摊记录数据迁移</h3>
          <p class="description">
            将历史交易的分摊成员数据从 JSON 字段迁移到 split_records 表，提升查询性能
          </p>
        </div>
      </div>

      <div class="card-body">
        <!-- 统计面板 -->
        <div v-if="stats" class="stats-panel">
          <h4 class="stats-title">
            当前状态
          </h4>
          <div class="stats-grid">
            <div class="stat-card">
              <div class="stat-label">
                split_records 总数
              </div>
              <div class="stat-value">
                {{ stats.totalSplitRecords }}
              </div>
            </div>
            <div class="stat-card">
              <div class="stat-label">
                已迁移交易
              </div>
              <div class="stat-value">
                {{ stats.migratedTransactions }}
              </div>
            </div>
            <div class="stat-card">
              <div class="stat-label">
                待迁移交易
              </div>
              <div class="stat-value" :class="{ warning: stats.pendingMigrations > 0 }">
                {{ stats.pendingMigrations }}
              </div>
            </div>
            <div class="stat-card">
              <div class="stat-label">
                迁移进度
              </div>
              <div class="stat-value">
                {{ stats.migrationProgress.toFixed(1) }}%
              </div>
              <div class="progress-bar">
                <div
                  class="progress-fill"
                  :style="{ width: `${stats.migrationProgress}%` }"
                />
              </div>
            </div>
          </div>

          <div v-if="stats.pendingMigrations > 0" class="alert-box">
            <LucideAlertCircle class="alert-icon" />
            <span>检测到 {{ stats.pendingMigrations }} 个交易待迁移，建议执行数据迁移</span>
          </div>
        </div>

        <div class="info-box">
          <LucideInfo class="info-icon" />
          <div class="info-content">
            <p><strong>迁移说明：</strong></p>
            <ul>
              <li>此操作会将所有历史交易的 split_members JSON 数据迁移到规范化的 split_records 表</li>
              <li>已有分摊记录的交易会自动跳过，不会重复创建</li>
              <li>迁移过程不会删除或修改原始数据，完全安全</li>
              <li>新创建的交易会自动生成 split_records，无需手动迁移</li>
            </ul>
          </div>
        </div>

        <button
          class="migrate-button"
          :class="{ loading: migrating }"
          :disabled="migrating"
          @click="migrateSplitRecords"
        >
          <LucideLoader2 v-if="migrating" class="spin-icon" />
          <LucidePlay v-else class="button-icon" />
          {{ migrating ? '迁移中...' : '开始迁移' }}
        </button>

        <div v-if="migrationResult" class="result-panel">
          <div class="result-header">
            <h4>迁移结果</h4>
            <span class="duration">耗时: {{ formatDuration(migrationResult.durationMs) }}</span>
          </div>

          <div class="result-stats">
            <div class="stat-item success">
              <LucideCheckCircle class="stat-icon" />
              <div class="stat-content">
                <span class="stat-label">成功</span>
                <span class="stat-value">{{ migrationResult.successCount }}</span>
              </div>
            </div>

            <div class="stat-item skipped">
              <LucideSkipForward class="stat-icon" />
              <div class="stat-content">
                <span class="stat-label">跳过</span>
                <span class="stat-value">{{ migrationResult.skippedCount }}</span>
              </div>
            </div>

            <div class="stat-item" :class="{ error: migrationResult.errorCount > 0 }">
              <LucideAlertCircle class="stat-icon" />
              <div class="stat-content">
                <span class="stat-label">失败</span>
                <span class="stat-value">{{ migrationResult.errorCount }}</span>
              </div>
            </div>
          </div>

          <div v-if="migrationResult.errors.length > 0" class="errors-section">
            <button class="toggle-errors-btn" @click="toggleErrors">
              <LucideChevronDown v-if="!showErrors" class="chevron-icon" />
              <LucideChevronUp v-else class="chevron-icon" />
              查看错误详情 ({{ migrationResult.errors.length }})
            </button>

            <div v-if="showErrors" class="errors-list">
              <div v-for="(error, index) in migrationResult.errors" :key="index" class="error-item">
                <LucideAlertTriangle class="error-icon" />
                <span class="error-text">{{ error }}</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.data-migration {
  padding: 24px;
  max-width: 800px;
}

.migration-card {
  background: var(--color-base-100);
  border-radius: 16px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  overflow: hidden;
}

.card-header {
  display: flex;
  align-items: flex-start;
  gap: 16px;
  padding: 24px;
  border-bottom: 1px solid var(--color-base-200);
}

.header-icon {
  width: 48px;
  height: 48px;
  border-radius: 12px;
  background: var(--color-primary-soft);
  display: flex;
  align-items: center;
  justify-content: center;
}

.header-icon .icon {
  width: 24px;
  height: 24px;
  color: var(--color-primary);
}

.header-content h3 {
  margin: 0 0 8px 0;
  font-size: 20px;
  color: var(--color-base-content);
}

.description {
  margin: 0;
  color: var(--color-gray-600);
  font-size: 14px;
}

.card-body {
  padding: 24px;
}

.info-box {
  display: flex;
  gap: 12px;
  padding: 16px;
  background: var(--color-info-soft);
  border-radius: 12px;
  margin-bottom: 24px;
}

.info-icon {
  width: 20px;
  height: 20px;
  color: var(--color-info);
  flex-shrink: 0;
}

.info-content {
  flex: 1;
}

.info-content p {
  margin: 0 0 8px 0;
  color: var(--color-info);
  font-weight: 500;
}

.info-content ul {
  margin: 0;
  padding-left: 20px;
  color: var(--color-info);
  font-size: 14px;
}

.info-content li {
  margin-bottom: 4px;
}

.migrate-button {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  padding: 12px 24px;
  background: var(--color-primary);
  color: white;
  border: none;
  border-radius: 8px;
  font-size: 16px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
}

.migrate-button:hover:not(:disabled) {
  background: var(--color-primary-focus);
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(var(--color-primary-rgb), 0.3);
}

.migrate-button:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.button-icon,
.spin-icon {
  width: 20px;
  height: 20px;
}

.spin-icon {
  animation: spin 1s linear infinite;
}

.result-panel {
  margin-top: 24px;
  padding: 20px;
  background: var(--color-base-200);
  border-radius: 12px;
}

.result-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16px;
}

.result-header h4 {
  margin: 0;
  font-size: 16px;
  color: var(--color-base-content);
}

.duration {
  font-size: 14px;
  color: var(--color-gray-600);
}

.result-stats {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 16px;
}

.stat-item {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 16px;
  background: var(--color-base-100);
  border-radius: 8px;
  border-left: 4px solid var(--color-gray-300);
}

.stat-item.success {
  border-color: var(--color-success);
}

.stat-item.skipped {
  border-color: var(--color-warning);
}

.stat-item.error {
  border-color: var(--color-error);
}

.stat-icon {
  width: 24px;
  height: 24px;
}

.success .stat-icon {
  color: var(--color-success);
}

.skipped .stat-icon {
  color: var(--color-warning);
}

.error .stat-icon {
  color: var(--color-error);
}

.stat-content {
  display: flex;
  flex-direction: column;
}

.stat-label {
  font-size: 12px;
  color: var(--color-gray-600);
}

.stat-value {
  font-size: 24px;
  font-weight: 600;
  color: var(--color-base-content);
}

.errors-section {
  margin-top: 16px;
}

.toggle-errors-btn {
  display: flex;
  align-items: center;
  gap: 8px;
  width: 100%;
  padding: 12px;
  background: var(--color-base-100);
  border: 1px solid var(--color-base-300);
  border-radius: 8px;
  cursor: pointer;
  font-size: 14px;
  color: var(--color-base-content);
  transition: background 0.2s;
}

.toggle-errors-btn:hover {
  background: var(--color-base-200);
}

.chevron-icon {
  width: 16px;
  height: 16px;
}

.errors-list {
  margin-top: 12px;
  max-height: 300px;
  overflow-y: auto;
}

.error-item {
  display: flex;
  align-items: flex-start;
  gap: 8px;
  padding: 12px;
  background: var(--color-error-soft);
  border-radius: 8px;
  margin-bottom: 8px;
}

.error-icon {
  width: 16px;
  height: 16px;
  color: var(--color-error);
  flex-shrink: 0;
  margin-top: 2px;
}

.error-text {
  font-size: 13px;
  color: var(--color-error);
  line-height: 1.5;
}

.stats-panel {
  margin-bottom: 24px;
  padding: 20px;
  background: var(--color-base-100);
  border-radius: 12px;
  border: 1px solid var(--color-base-300);
}

.stats-title {
  margin: 0 0 16px 0;
  font-size: 16px;
  font-weight: 600;
  color: var(--color-base-content);
}

.stats-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
  gap: 16px;
  margin-bottom: 16px;
}

.stat-card {
  padding: 16px;
  background: var(--color-base-200);
  border-radius: 8px;
}

.stat-label {
  font-size: 13px;
  color: var(--color-gray-600);
  margin-bottom: 8px;
}

.stat-value {
  font-size: 28px;
  font-weight: 700;
  color: var(--color-base-content);
}

.stat-value.warning {
  color: var(--color-warning);
}

.progress-bar {
  margin-top: 8px;
  height: 6px;
  background: var(--color-base-300);
  border-radius: 3px;
  overflow: hidden;
}

.progress-fill {
  height: 100%;
  background: linear-gradient(90deg, var(--color-primary), var(--color-primary-focus));
  transition: width 0.3s ease;
}

.alert-box {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px 16px;
  background: var(--color-warning-soft);
  border-radius: 8px;
  border-left: 4px solid var(--color-warning);
}

.alert-icon {
  width: 20px;
  height: 20px;
  color: var(--color-warning);
  flex-shrink: 0;
}

.alert-box span {
  font-size: 14px;
  color: var(--color-warning);
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
