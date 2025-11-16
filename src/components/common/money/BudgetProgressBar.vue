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
  <div class="budget-progress-bar">
    <div class="progress-container">
      <div class="progress-track">
        <div
          class="progress-fill"
          :style="{
            width: `${Math.min(percentage, 100)}%`,
            backgroundColor: progressColor,
          }"
        >
          <span v-if="showPercentageInside && percentage > 20" class="percentage-inside">
            {{ percentage.toFixed(1) }}%
          </span>
        </div>

        <!-- 阈值线 -->
        <div
          v-if="threshold && threshold < 100"
          class="threshold-marker"
          :style="{ left: `${threshold}%` }"
          :title="`预警阈值: ${threshold}%`"
        >
          <div class="threshold-line" />
        </div>
      </div>
    </div>

    <div v-if="showLabels" class="progress-labels">
      <div class="label-left">
        <span class="amount used">¥{{ formatAmount(used) }}</span>
        <span v-if="!hidePercentage" class="percentage">{{ percentage.toFixed(1) }}%</span>
      </div>
      <div class="label-right">
        <span class="amount total">¥{{ formatAmount(total) }}</span>
      </div>
    </div>

    <!-- 超支指示 -->
    <div v-if="isExceeded" class="exceeded-indicator">
      <span class="icon">⚠️</span>
      <span class="text">已超支 ¥{{ formatAmount(Math.abs(remaining)) }}</span>
    </div>
  </div>
</template>

<style scoped>
.budget-progress-bar {
  width: 100%;
}

.progress-container {
  margin-bottom: 8px;
}

.progress-track {
  position: relative;
  width: 100%;
  height: 24px;
  background-color: var(--color-base-300);
  border-radius: 12px;
  overflow: hidden;
}

.progress-fill {
  position: relative;
  height: 100%;
  background-color: var(--color-success);
  border-radius: 12px;
  transition: all 0.3s ease;
  display: flex;
  align-items: center;
  justify-content: flex-end;
  padding-right: 8px;
}

.percentage-inside {
  color: white;
  font-size: 12px;
  font-weight: 600;
  text-shadow: 0 1px 2px rgba(0, 0, 0, 0.2);
}

.threshold-marker {
  position: absolute;
  top: 0;
  height: 100%;
  width: 2px;
  z-index: 10;
  transform: translateX(-1px);
}

.threshold-line {
  width: 2px;
  height: 100%;
  background-color: var(--color-neutral);
  opacity: 0.6;
}

.threshold-marker::before {
  content: '';
  position: absolute;
  top: -4px;
  left: 50%;
  transform: translateX(-50%);
  width: 0;
  height: 0;
  border-left: 4px solid transparent;
  border-right: 4px solid transparent;
  border-top: 4px solid var(--color-neutral);
}

.progress-labels {
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-size: 12px;
  color: var(--color-neutral);
}

.label-left {
  display: flex;
  align-items: center;
  gap: 8px;
}

.label-right {
  text-align: right;
}

.amount {
  font-weight: 500;
}

.amount.used {
  color: var(--color-base-content);
}

.amount.total {
  color: var(--color-neutral);
}

.percentage {
  color: var(--color-neutral);
  font-size: 11px;
}

.exceeded-indicator {
  display: flex;
  align-items: center;
  gap: 4px;
  margin-top: 4px;
  padding: 4px 8px;
  background-color: color-mix(in oklch, var(--color-error) 15%, var(--color-base-100));
  border-radius: 6px;
  font-size: 12px;
  color: var(--color-error);
}

.exceeded-indicator .icon {
  font-size: 14px;
}

.exceeded-indicator .text {
  font-weight: 500;
}

/* 深色模式通过主题变量自动适配 */
</style>
