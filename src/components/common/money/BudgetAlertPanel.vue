<script setup lang="ts">
import type { BudgetAlertResponse } from '@/types/budget-allocation';

interface Props {
  /** 预警列表 */
  alerts: BudgetAlertResponse[];
  /** 是否显示清除按钮 */
  showClearButton?: boolean;
  /** 是否显示统计 */
  showStats?: boolean;
  /** 是否显示空状态 */
  showEmpty?: boolean;
}

interface Emits {
  (e: 'view', alert: BudgetAlertResponse): void;
  (e: 'clear'): void;
}

const props = withDefaults(defineProps<Props>(), {
  showClearButton: false,
  showStats: true,
  showEmpty: true,
});

defineEmits<Emits>();

/**
 * 是否有预警
 */
const hasAlerts = computed(() => props.alerts.length > 0);

/**
 * 排序后的预警（超支优先）
 */
const sortedAlerts = computed(() => {
  return [...props.alerts].sort((a, b) => {
    // 超支的排在前面
    if (a.alertType === 'EXCEEDED' && b.alertType !== 'EXCEEDED') return -1;
    if (a.alertType !== 'EXCEEDED' && b.alertType === 'EXCEEDED') return 1;

    // 使用率高的排在前面
    return b.usagePercentage - a.usagePercentage;
  });
});

/**
 * 已超支数量
 */
const exceededCount = computed(() => {
  return props.alerts.filter(a => a.alertType === 'EXCEEDED').length;
});

/**
 * 预警中数量
 */
const warningCount = computed(() => {
  return props.alerts.filter(a => a.alertType === 'WARNING').length;
});

/**
 * 预警项样式类
 */
function alertClasses(alert: BudgetAlertResponse) {
  return {
    exceeded: alert.alertType === 'EXCEEDED',
    warning: alert.alertType === 'WARNING',
  };
}

/**
 * 使用率样式类
 */
function usageRateClass(rate: number) {
  if (rate >= 100) return 'exceeded';
  if (rate >= 80) return 'warning';
  return 'normal';
}

/**
 * 格式化金额
 */
function formatAmount(amount: number): string {
  return Math.abs(amount).toLocaleString('zh-CN', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
}
</script>

<template>
  <div v-if="hasAlerts" class="budget-alert-panel">
    <div class="panel-header">
      <h3 class="title">
        <span class="icon">🔔</span>
        <span class="text">预算预警</span>
        <span class="count">({{ alerts.length }})</span>
      </h3>

      <button v-if="showClearButton" class="btn-clear" @click="$emit('clear')">
        清除全部
      </button>
    </div>

    <div class="alert-list">
      <div
        v-for="(alert, index) in sortedAlerts"
        :key="index"
        class="alert-item"
        :class="alertClasses(alert)"
        @click="$emit('view', alert)"
      >
        <!-- 图标 -->
        <div class="alert-icon">
          <span v-if="alert.alertType === 'EXCEEDED'">🚨</span>
          <span v-else>⚠️</span>
        </div>

        <!-- 内容 -->
        <div class="alert-content">
          <div class="alert-title">
            {{ alert.budgetName }}
          </div>
          <div class="alert-message">
            {{ alert.message }}
          </div>
          <div class="alert-details">
            <span class="detail-item">
              <span class="label">使用率:</span>
              <span class="value" :class="usageRateClass(alert.usagePercentage)">
                {{ alert.usagePercentage.toFixed(1) }}%
              </span>
            </span>
            <span class="separator">·</span>
            <span class="detail-item">
              <span class="label">剩余:</span>
              <span
                class="value"
                :class="{ negative: alert.remainingAmount < 0 }"
              >
                ¥{{ formatAmount(alert.remainingAmount) }}
              </span>
            </span>
          </div>
        </div>

        <!-- 操作 -->
        <div class="alert-actions">
          <button
            class="btn-action"
            title="查看详情"
            @click.stop="$emit('view', alert)"
          >
            查看
          </button>
        </div>
      </div>
    </div>

    <!-- 统计信息 -->
    <div v-if="showStats" class="panel-footer">
      <div class="stat-item">
        <span class="stat-value exceeded">{{ exceededCount }}</span>
        <span class="stat-label">已超支</span>
      </div>
      <div class="stat-item">
        <span class="stat-value warning">{{ warningCount }}</span>
        <span class="stat-label">预警中</span>
      </div>
    </div>
  </div>

  <!-- 无预警状态 -->
  <div v-else-if="showEmpty" class="budget-alert-empty">
    <div class="empty-icon">
      ✅
    </div>
    <div class="empty-text">
      暂无预警
    </div>
    <div class="empty-subtitle">
      所有预算使用正常
    </div>
  </div>
</template>

<style scoped>
.budget-alert-panel {
  background: var(--color-base-100);
  border: 1px solid var(--color-base-300);
  border-radius: 12px;
  overflow: hidden;
}

.panel-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 16px;
  border-bottom: 1px solid var(--color-base-300);
  background-color: var(--color-base-200);
}

.title {
  display: flex;
  align-items: center;
  gap: 8px;
  margin: 0;
  font-size: 16px;
  font-weight: 600;
  color: var(--color-base-content);
}

.title .icon {
  font-size: 18px;
}

.title .count {
  color: var(--color-neutral);
  font-size: 14px;
  font-weight: 400;
}

.btn-clear {
  padding: 6px 12px;
  background: transparent;
  border: 1px solid var(--color-base-300);
  border-radius: 6px;
  font-size: 13px;
  color: var(--color-neutral);
  cursor: pointer;
  transition: all 0.2s;
}

.btn-clear:hover {
  background-color: var(--color-base-200);
  border-color: var(--color-neutral);
  color: var(--color-base-content);
}

.alert-list {
  display: flex;
  flex-direction: column;
}

.alert-item {
  display: flex;
  align-items: flex-start;
  gap: 12px;
  padding: 16px;
  border-bottom: 1px solid var(--color-base-200);
  cursor: pointer;
  transition: background-color 0.2s;
}

.alert-item:last-child {
  border-bottom: none;
}

.alert-item:hover {
  background-color: var(--color-base-200);
}

.alert-item.exceeded {
  background-color: color-mix(in oklch, var(--color-error) 10%, var(--color-base-100));
  border-left: 3px solid var(--color-error);
}

.alert-item.warning {
  background-color: color-mix(in oklch, var(--color-warning) 10%, var(--color-base-100));
  border-left: 3px solid var(--color-warning);
}

.alert-icon {
  flex-shrink: 0;
  font-size: 20px;
  line-height: 1;
}

.alert-content {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.alert-title {
  font-size: 14px;
  font-weight: 600;
  color: var(--color-base-content);
}

.alert-message {
  font-size: 13px;
  color: var(--color-neutral);
  line-height: 1.5;
}

.alert-details {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 12px;
}

.detail-item {
  display: flex;
  align-items: center;
  gap: 4px;
}

.detail-item .label {
  color: var(--color-neutral);
}

.detail-item .value {
  font-weight: 500;
  color: var(--color-base-content);
}

.detail-item .value.exceeded {
  color: var(--color-error);
}

.detail-item .value.warning {
  color: var(--color-warning);
}

.detail-item .value.negative {
  color: var(--color-error);
}

.separator {
  color: var(--color-base-300);
}

.alert-actions {
  flex-shrink: 0;
}

.btn-action {
  padding: 6px 12px;
  background-color: var(--color-base-100);
  border: 1px solid var(--color-base-300);
  border-radius: 6px;
  font-size: 12px;
  color: var(--color-base-content);
  cursor: pointer;
  transition: all 0.2s;
}

.btn-action:hover {
  background-color: var(--color-base-200);
  border-color: var(--color-neutral);
}

.panel-footer {
  display: flex;
  gap: 24px;
  padding: 12px 16px;
  background-color: var(--color-base-200);
  border-top: 1px solid var(--color-base-300);
}

.stat-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4px;
}

.stat-value {
  font-size: 20px;
  font-weight: 700;
}

.stat-value.exceeded {
  color: var(--color-error);
}

.stat-value.warning {
  color: var(--color-warning);
}

.stat-label {
  font-size: 11px;
  color: var(--color-neutral);
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

/* 空状态 */
.budget-alert-empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 48px 24px;
  background: var(--color-base-100);
  border: 1px solid var(--color-base-300);
  border-radius: 12px;
  text-align: center;
}

.empty-icon {
  font-size: 48px;
  margin-bottom: 16px;
}

.empty-text {
  font-size: 16px;
  font-weight: 600;
  color: var(--color-base-content);
  margin-bottom: 8px;
}

.empty-subtitle {
  font-size: 14px;
  color: var(--color-neutral);
}

/* 深色模式通过主题变量自动适配 */
</style>
