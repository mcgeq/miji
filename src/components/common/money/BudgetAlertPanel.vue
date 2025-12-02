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
 * 获取预警项样式类（Tailwind）
 */
function getAlertClasses(alert: BudgetAlertResponse) {
  const baseClasses = [
    'flex items-start gap-3 p-4 border-b border-[var(--color-base-200)] last:border-b-0',
    'cursor-pointer transition-colors duration-200',
    'hover:bg-[var(--color-base-200)]',
  ];

  if (alert.alertType === 'EXCEEDED') {
    return [
      ...baseClasses,
      'bg-[color-mix(in_oklch,var(--color-error)_10%,var(--color-base-100))]',
      'border-l-[3px] border-l-[var(--color-error)]',
    ].join(' ');
  }

  if (alert.alertType === 'WARNING') {
    return [
      ...baseClasses,
      'bg-[color-mix(in_oklch,var(--color-warning)_10%,var(--color-base-100))]',
      'border-l-[3px] border-l-[var(--color-warning)]',
    ].join(' ');
  }

  return baseClasses.join(' ');
}

/**
 * 获取使用率样式类（Tailwind）
 */
function getUsageRateClasses(rate: number) {
  if (rate >= 100) return 'text-[var(--color-error)] font-medium';
  if (rate >= 80) return 'text-[var(--color-warning)] font-medium';
  return 'text-[var(--color-base-content)] font-medium';
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
  <div
    v-if="hasAlerts"
    class="bg-[var(--color-base-100)] border border-[var(--color-base-300)] rounded-xl overflow-hidden"
  >
    <!-- 面板头部 -->
    <div class="flex justify-between items-center p-4 border-b border-[var(--color-base-300)] bg-[var(--color-base-200)]">
      <h3 class="flex items-center gap-2 m-0 text-base font-semibold text-[var(--color-base-content)]">
        <span class="text-lg">🔔</span>
        <span>预算预警</span>
        <span class="text-[var(--color-neutral)] text-sm font-normal">({{ alerts.length }})</span>
      </h3>

      <button
        v-if="showClearButton"
        class="py-1.5 px-3 bg-transparent border border-[var(--color-base-300)] rounded-md text-[13px] text-[var(--color-neutral)] cursor-pointer transition-all duration-200 hover:bg-[var(--color-base-200)] hover:border-[var(--color-neutral)] hover:text-[var(--color-base-content)]"
        @click="$emit('clear')"
      >
        清除全部
      </button>
    </div>

    <!-- 预警列表 -->
    <div class="flex flex-col">
      <div
        v-for="(alert, index) in sortedAlerts"
        :key="index"
        :class="getAlertClasses(alert)"
        @click="$emit('view', alert)"
      >
        <!-- 图标 -->
        <div class="shrink-0 text-xl leading-none">
          <span v-if="alert.alertType === 'EXCEEDED'">🚨</span>
          <span v-else>⚠️</span>
        </div>

        <!-- 内容 -->
        <div class="flex-1 flex flex-col gap-1.5">
          <div class="text-sm font-semibold text-[var(--color-base-content)]">
            {{ alert.budgetName }}
          </div>
          <div class="text-[13px] text-[var(--color-neutral)] leading-relaxed">
            {{ alert.message }}
          </div>
          <div class="flex items-center gap-2 text-xs">
            <span class="flex items-center gap-1">
              <span class="text-[var(--color-neutral)]">使用率:</span>
              <span :class="getUsageRateClasses(alert.usagePercentage)">
                {{ alert.usagePercentage.toFixed(1) }}%
              </span>
            </span>
            <span class="text-[var(--color-base-300)]">·</span>
            <span class="flex items-center gap-1">
              <span class="text-[var(--color-neutral)]">剩余:</span>
              <span
                class="font-medium" :class="[
                  alert.remainingAmount < 0 ? 'text-[var(--color-error)]' : 'text-[var(--color-base-content)]',
                ]"
              >
                ¥{{ formatAmount(alert.remainingAmount) }}
              </span>
            </span>
          </div>
        </div>

        <!-- 操作 -->
        <div class="shrink-0">
          <button
            class="py-1.5 px-3 bg-[var(--color-base-100)] border border-[var(--color-base-300)] rounded-md text-xs text-[var(--color-base-content)] cursor-pointer transition-all duration-200 hover:bg-[var(--color-base-200)] hover:border-[var(--color-neutral)]"
            title="查看详情"
            @click.stop="$emit('view', alert)"
          >
            查看
          </button>
        </div>
      </div>
    </div>

    <!-- 统计信息 -->
    <div
      v-if="showStats"
      class="flex gap-6 p-3 px-4 bg-[var(--color-base-200)] border-t border-[var(--color-base-300)]"
    >
      <div class="flex flex-col items-center gap-1">
        <span class="text-xl font-bold text-[var(--color-error)]">{{ exceededCount }}</span>
        <span class="text-[11px] text-[var(--color-neutral)] uppercase tracking-wider">已超支</span>
      </div>
      <div class="flex flex-col items-center gap-1">
        <span class="text-xl font-bold text-[var(--color-warning)]">{{ warningCount }}</span>
        <span class="text-[11px] text-[var(--color-neutral)] uppercase tracking-wider">预警中</span>
      </div>
    </div>
  </div>

  <!-- 无预警状态 -->
  <div
    v-else-if="showEmpty"
    class="flex flex-col items-center justify-center py-12 px-6 bg-[var(--color-base-100)] border border-[var(--color-base-300)] rounded-xl text-center"
  >
    <div class="text-5xl mb-4">
      ✅
    </div>
    <div class="text-base font-semibold text-[var(--color-base-content)] mb-2">
      暂无预警
    </div>
    <div class="text-sm text-[var(--color-neutral)]">
      所有预算使用正常
    </div>
  </div>
</template>
