<script setup lang="ts">
interface Props {
  /** 已使用金额 */
  used: number;
  /** 总金额 */
  total: number;
  /** 预警阈值百分比 (0-100) */
  threshold?: number;
  /** 是否显示标签 */
  showLabels?: boolean;
  /** 隐藏百分比 */
  hidePercentage?: boolean;
  /** 在进度条内部显示百分比 */
  showPercentageInside?: boolean;
  /** 自定义颜色阈值 */
  colorThresholds?: {
    safe: number; // 安全区 (默认50)
    warning: number; // 预警区 (默认80)
  };
}

const props = withDefaults(defineProps<Props>(), {
  threshold: undefined,
  showLabels: true,
  hidePercentage: false,
  showPercentageInside: false,
  colorThresholds: () => ({ safe: 50, warning: 80 }),
});

/**
 * 使用率百分比
 */
const percentage = computed(() => {
  if (props.total === 0) return 0;
  return (props.used / props.total) * 100;
});

/**
 * 剩余金额
 */
const remaining = computed(() => props.total - props.used);

/**
 * 是否超支
 */
const isExceeded = computed(() => remaining.value < 0);

/**
 * 进度条颜色
 */
const progressColor = computed(() => {
  const p = percentage.value;

  // 超支 - 错误色
  if (p > 100) return 'var(--color-error)';

  // 预警区 - 错误色
  if (p >= props.colorThresholds.warning) return 'var(--color-error)';

  // 警告区 - 警告色
  if (p >= props.colorThresholds.safe) return 'var(--color-warning)';

  // 安全区 - 成功色
  return 'var(--color-success)';
});

/**
 * 格式化金额
 */
function formatAmount(amount: number): string {
  return amount.toLocaleString('zh-CN', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
}
</script>

<template>
  <div class="w-full">
    <!-- 进度条容器 -->
    <div class="mb-2">
      <div class="relative w-full h-6 bg-[var(--color-base-300)] rounded-xl overflow-hidden">
        <!-- 进度填充 -->
        <div
          class="relative h-full rounded-xl transition-all duration-300 ease-in-out flex items-center justify-end pr-2"
          :style="{
            width: `${Math.min(percentage, 100)}%`,
            backgroundColor: progressColor,
          }"
        >
          <span
            v-if="showPercentageInside && percentage > 20"
            class="text-white text-xs font-semibold [text-shadow:0_1px_2px_rgba(0,0,0,0.2)]"
          >
            {{ percentage.toFixed(1) }}%
          </span>
        </div>

        <!-- 阈值标记线 -->
        <div
          v-if="threshold && threshold < 100"
          class="absolute top-0 h-full w-0.5 z-10 -translate-x-px before:content-[''] before:absolute before:-top-1 before:left-1/2 before:-translate-x-1/2 before:border-l-4 before:border-r-4 before:border-t-4 before:border-l-transparent before:border-r-transparent before:border-t-[var(--color-neutral)]"
          :style="{ left: `${threshold}%` }"
          :title="`预警阈值: ${threshold}%`"
        >
          <div class="w-0.5 h-full bg-[var(--color-neutral)] opacity-60" />
        </div>
      </div>
    </div>

    <!-- 标签 -->
    <div v-if="showLabels" class="flex justify-between items-center text-xs text-[var(--color-neutral)]">
      <div class="flex items-center gap-2">
        <span class="font-medium text-[var(--color-base-content)]">¥{{ formatAmount(used) }}</span>
        <span v-if="!hidePercentage" class="text-[11px]">{{ percentage.toFixed(1) }}%</span>
      </div>
      <div class="text-right">
        <span class="font-medium">¥{{ formatAmount(total) }}</span>
      </div>
    </div>

    <!-- 超支指示 -->
    <div
      v-if="isExceeded"
      class="flex items-center gap-1 mt-1 py-1 px-2 bg-[color-mix(in_oklch,var(--color-error)_15%,var(--color-base-100))] rounded-md text-xs text-[var(--color-error)]"
    >
      <span class="text-sm">⚠️</span>
      <span class="font-medium">已超支 ¥{{ formatAmount(Math.abs(remaining)) }}</span>
    </div>
  </div>
</template>
