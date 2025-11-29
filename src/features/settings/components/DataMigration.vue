<script setup lang="ts">
import { invoke } from '@tauri-apps/api/core';
import {
  AlertCircle as LucideAlertCircle,
  AlertTriangle as LucideAlertTriangle,
  CheckCircle as LucideCheckCircle,
  ChevronDown as LucideChevronDown,
  ChevronUp as LucideChevronUp,
  Database as LucideDatabase,
  Play as LucidePlay,
  SkipForward as LucideSkipForward,
} from 'lucide-vue-next';
import { onMounted, ref } from 'vue';
import { Alert, Button, Card, Progress } from '@/components/ui';
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
  <div class="max-w-3xl mx-auto p-4 md:p-6">
    <Card shadow="md" padding="none">
      <template #header>
        <div class="flex items-start gap-4">
          <div class="w-12 h-12 rounded-xl bg-blue-100 dark:bg-blue-900/30 flex items-center justify-center shrink-0">
            <LucideDatabase class="w-6 h-6 text-blue-600 dark:text-blue-400" />
          </div>
          <div class="flex-1 min-w-0">
            <h3 class="text-lg md:text-xl font-semibold text-gray-900 dark:text-white mb-2">
              分摊记录数据迁移
            </h3>
            <p class="text-sm text-gray-600 dark:text-gray-400">
              将历史交易的分摊成员数据从 JSON 字段迁移到 split_records 表，提升查询性能
            </p>
          </div>
        </div>
      </template>

      <div class="p-4 md:p-6 space-y-6">
        <!-- 统计面板 -->
        <div v-if="stats" class="space-y-4">
          <h4 class="text-base font-semibold text-gray-900 dark:text-white">
            当前状态
          </h4>

          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3 md:gap-4">
            <div class="p-4 bg-gray-50 dark:bg-gray-700/50 rounded-xl">
              <div class="text-xs md:text-sm text-gray-600 dark:text-gray-400 mb-2">
                split_records 总数
              </div>
              <div class="text-2xl md:text-3xl font-bold text-gray-900 dark:text-white">
                {{ stats.totalSplitRecords }}
              </div>
            </div>

            <div class="p-4 bg-gray-50 dark:bg-gray-700/50 rounded-xl">
              <div class="text-xs md:text-sm text-gray-600 dark:text-gray-400 mb-2">
                已迁移交易
              </div>
              <div class="text-2xl md:text-3xl font-bold text-gray-900 dark:text-white">
                {{ stats.migratedTransactions }}
              </div>
            </div>

            <div class="p-4 bg-gray-50 dark:bg-gray-700/50 rounded-xl">
              <div class="text-xs md:text-sm text-gray-600 dark:text-gray-400 mb-2">
                待迁移交易
              </div>
              <div
                class="text-2xl md:text-3xl font-bold" :class="[
                  stats.pendingMigrations > 0
                    ? 'text-yellow-600 dark:text-yellow-400'
                    : 'text-gray-900 dark:text-white',
                ]"
              >
                {{ stats.pendingMigrations }}
              </div>
            </div>

            <div class="p-4 bg-gray-50 dark:bg-gray-700/50 rounded-xl">
              <div class="text-xs md:text-sm text-gray-600 dark:text-gray-400 mb-2">
                迁移进度
              </div>
              <div class="text-2xl md:text-3xl font-bold text-gray-900 dark:text-white mb-2">
                {{ stats.migrationProgress.toFixed(1) }}%
              </div>
              <Progress
                :value="stats.migrationProgress"
                :max="100"
                size="sm"
                color="primary"
              />
            </div>
          </div>

          <Alert
            v-if="stats.pendingMigrations > 0"
            type="warning"
            :show-icon="true"
          >
            检测到 {{ stats.pendingMigrations }} 个交易待迁移，建议执行数据迁移
          </Alert>
        </div>

        <Alert type="info" title="迁移说明">
          <ul class="space-y-1 text-sm list-disc list-inside">
            <li>此操作会将所有历史交易的 split_members JSON 数据迁移到规范化的 split_records 表</li>
            <li>已有分摊记录的交易会自动跳过，不会重复创建</li>
            <li>迁移过程不会删除或修改原始数据，完全安全</li>
            <li>新创建的交易会自动生成 split_records，无需手动迁移</li>
          </ul>
        </Alert>

        <Button
          variant="primary"
          size="lg"
          :loading="migrating"
          :disabled="migrating"
          :icon="LucidePlay"
          full-width
          @click="migrateSplitRecords"
        >
          {{ migrating ? '迁移中...' : '开始迁移' }}
        </Button>

        <div v-if="migrationResult" class="p-4 md:p-5 bg-gray-50 dark:bg-gray-700/50 rounded-xl space-y-4">
          <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2">
            <h4 class="text-base font-semibold text-gray-900 dark:text-white">
              迁移结果
            </h4>
            <span class="text-sm text-gray-600 dark:text-gray-400">
              耗时: {{ formatDuration(migrationResult.durationMs) }}
            </span>
          </div>

          <div class="grid grid-cols-1 sm:grid-cols-3 gap-3 md:gap-4">
            <div class="flex items-center gap-3 p-4 bg-white dark:bg-gray-800 rounded-lg border-l-4 border-green-500">
              <LucideCheckCircle class="w-6 h-6 text-green-600 dark:text-green-400 shrink-0" />
              <div class="flex flex-col min-w-0">
                <span class="text-xs text-gray-600 dark:text-gray-400">成功</span>
                <span class="text-xl md:text-2xl font-semibold text-gray-900 dark:text-white">
                  {{ migrationResult.successCount }}
                </span>
              </div>
            </div>

            <div class="flex items-center gap-3 p-4 bg-white dark:bg-gray-800 rounded-lg border-l-4 border-yellow-500">
              <LucideSkipForward class="w-6 h-6 text-yellow-600 dark:text-yellow-400 shrink-0" />
              <div class="flex flex-col min-w-0">
                <span class="text-xs text-gray-600 dark:text-gray-400">跳过</span>
                <span class="text-xl md:text-2xl font-semibold text-gray-900 dark:text-white">
                  {{ migrationResult.skippedCount }}
                </span>
              </div>
            </div>

            <div
              class="flex items-center gap-3 p-4 bg-white dark:bg-gray-800 rounded-lg border-l-4" :class="[
                migrationResult.errorCount > 0 ? 'border-red-500' : 'border-gray-300 dark:border-gray-600',
              ]"
            >
              <LucideAlertCircle
                class="w-6 h-6 shrink-0" :class="[
                  migrationResult.errorCount > 0
                    ? 'text-red-600 dark:text-red-400'
                    : 'text-gray-400 dark:text-gray-500',
                ]"
              />
              <div class="flex flex-col min-w-0">
                <span class="text-xs text-gray-600 dark:text-gray-400">失败</span>
                <span class="text-xl md:text-2xl font-semibold text-gray-900 dark:text-white">
                  {{ migrationResult.errorCount }}
                </span>
              </div>
            </div>
          </div>

          <div v-if="migrationResult.errors.length > 0" class="space-y-3">
            <button
              class="w-full flex items-center justify-center gap-2 px-4 py-3 bg-white dark:bg-gray-800 border border-gray-300 dark:border-gray-600 rounded-lg text-sm font-medium text-gray-900 dark:text-white hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors"
              @click="toggleErrors"
            >
              <component :is="showErrors ? LucideChevronUp : LucideChevronDown" class="w-4 h-4" />
              查看错误详情 ({{ migrationResult.errors.length }})
            </button>

            <div v-if="showErrors" class="space-y-2 max-h-72 overflow-y-auto">
              <div
                v-for="(error, index) in migrationResult.errors"
                :key="index"
                class="flex items-start gap-2 p-3 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg"
              >
                <LucideAlertTriangle class="w-4 h-4 text-red-600 dark:text-red-400 shrink-0 mt-0.5" />
                <span class="text-sm text-red-700 dark:text-red-300 break-words">{{ error }}</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Card>
  </div>
</template>
