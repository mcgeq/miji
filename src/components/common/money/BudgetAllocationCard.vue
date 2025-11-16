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
 * 卡片样式类
 */
const cardClasses = computed(() => ({
  exceeded: props.allocation.isExceeded,
  warning: props.allocation.isWarning && !props.allocation.isExceeded,
  normal: !props.allocation.isWarning && !props.allocation.isExceeded,
  mandatory: props.allocation.isMandatory,
  paused: props.allocation.status === 'PAUSED',
}));

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
  <div class="budget-allocation-card" :class="cardClasses">
    <!-- 卡片头部 -->
    <div class="card-header">
      <div class="title-section">
        <div class="title">
          <span v-if="allocation.memberName" class="member-name">
            {{ allocation.memberName }}
          </span>
          <span v-else class="member-name all-members">所有成员</span>

          <span class="separator">·</span>

          <span v-if="allocation.categoryName" class="category-name">
            {{ allocation.categoryName }}
          </span>
          <span v-else class="category-name all-categories">所有分类</span>
        </div>

        <!-- 标签 -->
        <div class="tags">
          <span v-if="allocation.isMandatory" class="tag mandatory" title="强制保障">
            🛡️ 强制
          </span>
          <span class="tag priority" :title="`优先级: ${allocation.priority}`">
            P{{ allocation.priority }}
          </span>
          <span v-if="allocation.status !== 'ACTIVE'" class="tag status">
            {{ statusText }}
          </span>
        </div>
      </div>

      <!-- 操作按钮 -->
      <div v-if="showActions" class="actions">
        <button class="btn-icon" title="编辑" @click="$emit('edit', allocation)">
          ✏️
        </button>
        <button class="btn-icon" title="删除" @click="handleDelete">
          🗑️
        </button>
      </div>
    </div>

    <!-- 卡片主体 -->
    <div class="card-body">
      <!-- 金额信息 -->
      <div class="amount-section">
        <div class="amount-row">
          <span class="label">预算:</span>
          <span class="value allocated">¥{{ formatAmount(allocation.allocatedAmount) }}</span>
        </div>
        <div class="amount-row">
          <span class="label">已用:</span>
          <span class="value used">¥{{ formatAmount(allocation.usedAmount) }}</span>
        </div>
        <div class="amount-row">
          <span class="label">剩余:</span>
          <span class="value remaining" :class="{ negative: allocation.isExceeded }">
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
      <div class="status-section">
        <!-- 超支状态 -->
        <div v-if="allocation.isExceeded" class="status-badge exceeded">
          <span class="icon">🚨</span>
          <span class="text">已超支</span>
          <span v-if="!allocation.canOverspendMore" class="warning">无法继续</span>
        </div>

        <!-- 预警状态 -->
        <div v-else-if="allocation.isWarning" class="status-badge warning">
          <span class="icon">⚠️</span>
          <span class="text">预警中</span>
          <span class="threshold">({{ allocation.alertThreshold }}%)</span>
        </div>

        <!-- 正常状态 -->
        <div v-else class="status-badge normal">
          <span class="icon">✅</span>
          <span class="text">正常</span>
        </div>

        <!-- 超支设置 -->
        <div v-if="allocation.allowOverspend" class="overspend-info">
          <span class="icon">🔓</span>
          <span class="text">
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
        <div v-else class="overspend-info locked">
          <span class="icon">🔒</span>
          <span class="text">禁止超支</span>
        </div>
      </div>

      <!-- 备注 -->
      <div v-if="allocation.notes" class="notes">
        <span class="icon">📝</span>
        <span class="text">{{ allocation.notes }}</span>
      </div>
    </div>
  </div>
</template>

<style scoped>
.budget-allocation-card {
  background: var(--color-base-100);
  border: 1px solid var(--color-base-300);
  border-radius: 12px;
  padding: 16px;
  transition: all 0.2s ease;
}

.budget-allocation-card:hover {
  box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
}

/* 状态边框颜色 */
.budget-allocation-card.exceeded {
  border-left: 4px solid var(--color-error);
}

.budget-allocation-card.warning {
  border-left: 4px solid var(--color-warning);
}

.budget-allocation-card.mandatory {
  border-top: 2px solid var(--color-primary);
}

.budget-allocation-card.paused {
  opacity: 0.6;
}

/* 头部 */
.card-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 12px;
}

.title-section {
  flex: 1;
}

.title {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 16px;
  font-weight: 600;
  color: var(--color-base-content);
  margin-bottom: 8px;
}

.member-name {
  color: var(--color-base-content);
}

.member-name.all-members {
  color: var(--color-neutral);
  font-style: italic;
}

.separator {
  color: var(--color-base-300);
}

.category-name {
  color: var(--color-neutral);
}

.category-name.all-categories {
  font-style: italic;
}

.tags {
  display: flex;
  gap: 6px;
  flex-wrap: wrap;
}

.tag {
  display: inline-flex;
  align-items: center;
  padding: 2px 8px;
  border-radius: 12px;
  font-size: 11px;
  font-weight: 500;
}

.tag.mandatory {
  background-color: color-mix(in oklch, var(--color-primary) 15%, var(--color-base-100));
  color: var(--color-primary);
}

.tag.priority {
  background-color: var(--color-base-200);
  color: var(--color-neutral);
}

.tag.status {
  background-color: color-mix(in oklch, var(--color-warning) 15%, var(--color-base-100));
  color: var(--color-warning);
}

.actions {
  display: flex;
  gap: 4px;
}

.btn-icon {
  padding: 4px 8px;
  background: transparent;
  border: 1px solid var(--color-base-300);
  border-radius: 6px;
  cursor: pointer;
  font-size: 14px;
  transition: all 0.2s;
}

.btn-icon:hover {
  background-color: var(--color-base-200);
  border-color: var(--color-neutral);
}

/* 主体 */
.card-body {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.amount-section {
  display: flex;
  justify-content: space-between;
  gap: 12px;
}

.amount-row {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.amount-row .label {
  font-size: 11px;
  color: var(--color-neutral);
}

.amount-row .value {
  font-size: 14px;
  font-weight: 600;
}

.amount-row .value.allocated {
  color: var(--color-neutral);
}

.amount-row .value.used {
  color: var(--color-base-content);
}

.amount-row .value.remaining {
  color: var(--color-success);
}

.amount-row .value.remaining.negative {
  color: var(--color-error);
}

.status-section {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.status-badge {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 6px 10px;
  border-radius: 8px;
  font-size: 13px;
  font-weight: 500;
}

.status-badge.exceeded {
  background-color: color-mix(in oklch, var(--color-error) 15%, var(--color-base-100));
  color: var(--color-error);
}

.status-badge.warning {
  background-color: color-mix(in oklch, var(--color-warning) 15%, var(--color-base-100));
  color: var(--color-warning);
}

.status-badge.normal {
  background-color: color-mix(in oklch, var(--color-success) 15%, var(--color-base-100));
  color: var(--color-success);
}

.status-badge .icon {
  font-size: 14px;
}

.status-badge .warning,
.status-badge .threshold {
  font-size: 11px;
  opacity: 0.8;
  margin-left: 4px;
}

.overspend-info {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 12px;
  color: var(--color-neutral);
}

.overspend-info.locked {
  color: var(--color-error);
}

.overspend-info .icon {
  font-size: 12px;
}

.notes {
  display: flex;
  gap: 6px;
  padding: 8px;
  background-color: var(--color-base-200);
  border-radius: 6px;
  font-size: 12px;
  color: var(--color-neutral);
}

.notes .icon {
  flex-shrink: 0;
}

/* 深色模式通过主题变量自动适配 */
</style>
