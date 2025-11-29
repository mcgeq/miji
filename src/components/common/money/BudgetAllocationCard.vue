<script setup lang="ts">
import BudgetProgressBar from './BudgetProgressBar.vue';
import type { BudgetAllocationResponse } from '@/types/budget-allocation';

interface Props {
  /** 预算分配数据 */
  allocation: BudgetAllocationResponse;
  /** 是否显示操作按钮 */
  showActions?: boolean;
}

interface Emits {
  (e: 'edit', allocation: BudgetAllocationResponse): void;
  (e: 'delete', allocation: BudgetAllocationResponse): void;
}

const props = withDefaults(defineProps<Props>(), {
  showActions: true,
});

const emit = defineEmits<Emits>();

/**
 * 卡片样式类（Tailwind）
 */
const cardClasses = computed(() => {
  const classes = [
    'bg-[var(--color-base-100)] border border-[var(--color-base-300)] rounded-xl p-4',
    'transition-all duration-200 ease-in-out',
    'hover:shadow-[0_4px_6px_-1px_rgba(0,0,0,0.1)]',
  ];

  // 状态边框
  if (props.allocation.isExceeded) {
    classes.push('border-l-[4px] border-l-[var(--color-error)]');
  } else if (props.allocation.isWarning) {
    classes.push('border-l-[4px] border-l-[var(--color-warning)]');
  }

  // 强制保障
  if (props.allocation.isMandatory) {
    classes.push('border-t-2 border-t-[var(--color-primary)]');
  }

  // 暂停状态
  if (props.allocation.status === 'PAUSED') {
    classes.push('opacity-60');
  }

  return classes.join(' ');
});

/**
 * 状态文本
 */
const statusText = computed(() => {
  switch (props.allocation.status) {
    case 'PAUSED':
      return '已暂停';
    case 'COMPLETED':
      return '已完成';
    default:
      return '';
  }
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

/**
 * 处理删除
 */
function handleDelete() {
  // eslint-disable-next-line no-alert
  if (window.confirm(`确定要删除这个预算分配吗？\n${props.allocation.memberName || '所有成员'} - ${props.allocation.categoryName || '所有分类'}`)) {
    emit('delete', props.allocation);
  }
}
</script>

<template>
  <div :class="cardClasses">
    <!-- 卡片头部 -->
    <div class="flex justify-between items-start mb-3">
      <div class="flex-1">
        <!-- 标题 -->
        <div class="flex items-center gap-1.5 text-base font-semibold text-[var(--color-base-content)] mb-2">
          <span v-if="allocation.memberName">
            {{ allocation.memberName }}
          </span>
          <span v-else class="text-[var(--color-neutral)] italic">所有成员</span>

          <span class="text-[var(--color-base-300)]">·</span>

          <span v-if="allocation.categoryName" class="text-[var(--color-neutral)]">
            {{ allocation.categoryName }}
          </span>
          <span v-else class="text-[var(--color-neutral)] italic">所有分类</span>
        </div>

        <!-- 标签 -->
        <div class="flex gap-1.5 flex-wrap">
          <span
            v-if="allocation.isMandatory"
            class="inline-flex items-center py-0.5 px-2 rounded-xl text-[11px] font-medium bg-[color-mix(in_oklch,var(--color-primary)_15%,var(--color-base-100))] text-[var(--color-primary)]"
            title="强制保障"
          >
            🛡️ 强制
          </span>
          <span
            class="inline-flex items-center py-0.5 px-2 rounded-xl text-[11px] font-medium bg-[var(--color-base-200)] text-[var(--color-neutral)]"
            :title="`优先级: ${allocation.priority}`"
          >
            P{{ allocation.priority }}
          </span>
          <span
            v-if="allocation.status !== 'ACTIVE'"
            class="inline-flex items-center py-0.5 px-2 rounded-xl text-[11px] font-medium bg-[color-mix(in_oklch,var(--color-warning)_15%,var(--color-base-100))] text-[var(--color-warning)]"
          >
            {{ statusText }}
          </span>
        </div>
      </div>

      <!-- 操作按钮 -->
      <div v-if="showActions" class="flex gap-1">
        <button
          class="py-1 px-2 bg-transparent border border-[var(--color-base-300)] rounded-md cursor-pointer text-sm transition-all duration-200 hover:bg-[var(--color-base-200)] hover:border-[var(--color-neutral)]"
          title="编辑"
          @click="$emit('edit', allocation)"
        >
          ✏️
        </button>
        <button
          class="py-1 px-2 bg-transparent border border-[var(--color-base-300)] rounded-md cursor-pointer text-sm transition-all duration-200 hover:bg-[var(--color-base-200)] hover:border-[var(--color-neutral)]"
          title="删除"
          @click="handleDelete"
        >
          🗑️
        </button>
      </div>
    </div>

    <!-- 卡片主体 -->
    <div class="flex flex-col gap-3">
      <!-- 金额信息 -->
      <div class="flex justify-between gap-3">
        <div class="flex flex-col gap-0.5">
          <span class="text-[11px] text-[var(--color-neutral)]">预算:</span>
          <span class="text-sm font-semibold text-[var(--color-neutral)]">¥{{ formatAmount(allocation.allocatedAmount) }}</span>
        </div>
        <div class="flex flex-col gap-0.5">
          <span class="text-[11px] text-[var(--color-neutral)]">已用:</span>
          <span class="text-sm font-semibold text-[var(--color-base-content)]">¥{{ formatAmount(allocation.usedAmount) }}</span>
        </div>
        <div class="flex flex-col gap-0.5">
          <span class="text-[11px] text-[var(--color-neutral)]">剩余:</span>
          <span
            class="text-sm font-semibold" :class="[
              allocation.isExceeded ? 'text-[var(--color-error)]' : 'text-[var(--color-success)]',
            ]"
          >
            ¥{{ formatAmount(allocation.remainingAmount) }}
          </span>
        </div>
      </div>

      <!-- 进度条 -->
      <BudgetProgressBar
        :used="allocation.usedAmount"
        :total="allocation.allocatedAmount"
        :threshold="allocation.alertEnabled ? allocation.alertThreshold : undefined"
        :show-labels="false"
        :show-percentage-inside="true"
      />

      <!-- 状态信息 -->
      <div class="flex flex-col gap-2">
        <!-- 超支状态 -->
        <div
          v-if="allocation.isExceeded"
          class="flex items-center gap-1.5 py-1.5 px-2.5 rounded-lg text-[13px] font-medium bg-[color-mix(in_oklch,var(--color-error)_15%,var(--color-base-100))] text-[var(--color-error)]"
        >
          <span class="text-sm">🚨</span>
          <span>已超支</span>
          <span v-if="!allocation.canOverspendMore" class="text-[11px] opacity-80 ml-1">无法继续</span>
        </div>

        <!-- 预警状态 -->
        <div
          v-else-if="allocation.isWarning"
          class="flex items-center gap-1.5 py-1.5 px-2.5 rounded-lg text-[13px] font-medium bg-[color-mix(in_oklch,var(--color-warning)_15%,var(--color-base-100))] text-[var(--color-warning)]"
        >
          <span class="text-sm">⚠️</span>
          <span>预警中</span>
          <span class="text-[11px] opacity-80 ml-1">({{ allocation.alertThreshold }}%)</span>
        </div>

        <!-- 正常状态 -->
        <div
          v-else
          class="flex items-center gap-1.5 py-1.5 px-2.5 rounded-lg text-[13px] font-medium bg-[color-mix(in_oklch,var(--color-success)_15%,var(--color-base-100))] text-[var(--color-success)]"
        >
          <span class="text-sm">✅</span>
          <span>正常</span>
        </div>

        <!-- 超支设置 -->
        <div
          v-if="allocation.allowOverspend"
          class="flex items-center gap-1.5 text-xs text-[var(--color-neutral)]"
        >
          <span class="text-xs">🔓</span>
          <span>
            允许超支
            <template v-if="allocation.overspendLimitType !== 'NONE'">
              (最多
              <template v-if="allocation.overspendLimitType === 'PERCENTAGE'">
                {{ allocation.overspendLimitValue }}%
              </template>
              <template v-else>
                ¥{{ formatAmount(allocation.overspendLimitValue!) }}
              </template>
              )
            </template>
          </span>
        </div>
        <div
          v-else
          class="flex items-center gap-1.5 text-xs text-[var(--color-error)]"
        >
          <span class="text-xs">🔒</span>
          <span>禁止超支</span>
        </div>
      </div>

      <!-- 备注 -->
      <div
        v-if="allocation.notes"
        class="flex gap-1.5 p-2 bg-[var(--color-base-200)] rounded-md text-xs text-[var(--color-neutral)]"
      >
        <span class="shrink-0">📝</span>
        <span>{{ allocation.notes }}</span>
      </div>
    </div>
  </div>
</template>
