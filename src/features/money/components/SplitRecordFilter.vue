<script setup lang="ts">
import { LucideCalendar, LucideFilter, LucideX } from 'lucide-vue-next';
import { useFamilyMemberStore } from '@/stores/money';
import type { SplitRuleType } from '@/schema/money';

interface FilterConfig {
  status: 'all' | 'pending' | 'completed';
  splitType: SplitRuleType | 'all';
  memberSerialNum: string;
  dateRange: {
    start: string;
    end: string;
  };
  amountRange: {
    min: number | null;
    max: number | null;
  };
}

interface Props {
  modelValue: FilterConfig;
}

const props = defineProps<Props>();
const emit = defineEmits<{
  'update:modelValue': [config: FilterConfig];
  'apply': [];
  'reset': [];
}>();

const memberStore = useFamilyMemberStore();

// 本地筛选配置
const localConfig = ref<FilterConfig>({ ...props.modelValue });

// 可用成员列表
const availableMembers = computed(() => memberStore.members);

// 分摊类型选项
const splitTypeOptions = [
  { value: 'all', label: '全部类型' },
  { value: 'EQUAL', label: '均摊' },
  { value: 'PERCENTAGE', label: '按比例' },
  { value: 'FIXED_AMOUNT', label: '固定金额' },
  { value: 'WEIGHTED', label: '按权重' },
];

// 监听 props 变化
watch(() => props.modelValue, newValue => {
  localConfig.value = { ...newValue };
}, { deep: true });

// 应用筛选
function applyFilter() {
  emit('update:modelValue', { ...localConfig.value });
  emit('apply');
}

// 重置筛选
function resetFilter() {
  localConfig.value = {
    status: 'all',
    splitType: 'all',
    memberSerialNum: '',
    dateRange: { start: '', end: '' },
    amountRange: { min: null, max: null },
  };
  emit('update:modelValue', { ...localConfig.value });
  emit('reset');
}

// 快速日期选择
function setQuickDate(days: number) {
  const end = new Date();
  const start = new Date();
  start.setDate(start.getDate() - days);

  localConfig.value.dateRange = {
    start: start.toISOString().split('T')[0],
    end: end.toISOString().split('T')[0],
  };
}

// 统计已应用的筛选数量
const activeFiltersCount = computed(() => {
  let count = 0;
  if (localConfig.value.status !== 'all') count++;
  if (localConfig.value.splitType !== 'all') count++;
  if (localConfig.value.memberSerialNum) count++;
  if (localConfig.value.dateRange.start && localConfig.value.dateRange.end) count++;
  if (localConfig.value.amountRange.min !== null || localConfig.value.amountRange.max !== null) count++;
  return count;
});
</script>

<template>
  <div class="split-record-filter">
    <div class="filter-header">
      <div class="header-title">
        <LucideFilter class="icon" />
        <h3>高级筛选</h3>
        <span v-if="activeFiltersCount > 0" class="filter-count">
          {{ activeFiltersCount }}
        </span>
      </div>
    </div>

    <div class="filter-content">
      <!-- 状态筛选 -->
      <div class="filter-group">
        <label class="filter-label">状态</label>
        <div class="radio-group">
          <label class="radio-option">
            <input
              v-model="localConfig.status"
              type="radio"
              value="all"
            >
            <span>全部</span>
          </label>
          <label class="radio-option">
            <input
              v-model="localConfig.status"
              type="radio"
              value="pending"
            >
            <span>进行中</span>
          </label>
          <label class="radio-option">
            <input
              v-model="localConfig.status"
              type="radio"
              value="completed"
            >
            <span>已完成</span>
          </label>
        </div>
      </div>

      <!-- 分摊类型 -->
      <div class="filter-group">
        <label class="filter-label">分摊类型</label>
        <select v-model="localConfig.splitType" class="filter-select">
          <option
            v-for="option in splitTypeOptions"
            :key="option.value"
            :value="option.value"
          >
            {{ option.label }}
          </option>
        </select>
      </div>

      <!-- 成员筛选 -->
      <div class="filter-group">
        <label class="filter-label">参与成员</label>
        <select v-model="localConfig.memberSerialNum" class="filter-select">
          <option value="">
            全部成员
          </option>
          <option
            v-for="member in availableMembers"
            :key="member.serialNum"
            :value="member.serialNum"
          >
            {{ member.name }}
          </option>
        </select>
      </div>

      <!-- 日期范围 -->
      <div class="filter-group">
        <label class="filter-label">
          <LucideCalendar class="label-icon" />
          日期范围
        </label>

        <!-- 快速选择 -->
        <div class="quick-dates">
          <button class="quick-date-btn" @click="setQuickDate(7)">
            最近7天
          </button>
          <button class="quick-date-btn" @click="setQuickDate(30)">
            最近30天
          </button>
          <button class="quick-date-btn" @click="setQuickDate(90)">
            最近90天
          </button>
        </div>

        <!-- 自定义日期 -->
        <div class="date-range">
          <input
            v-model="localConfig.dateRange.start"
            type="date"
            class="date-input"
            placeholder="开始日期"
          >
          <span class="date-separator">至</span>
          <input
            v-model="localConfig.dateRange.end"
            type="date"
            class="date-input"
            placeholder="结束日期"
          >
        </div>
      </div>

      <!-- 金额范围 -->
      <div class="filter-group">
        <label class="filter-label">金额范围</label>
        <div class="amount-range">
          <input
            v-model.number="localConfig.amountRange.min"
            type="number"
            class="amount-input"
            placeholder="最小金额"
            min="0"
            step="0.01"
          >
          <span class="amount-separator">至</span>
          <input
            v-model.number="localConfig.amountRange.max"
            type="number"
            class="amount-input"
            placeholder="最大金额"
            min="0"
            step="0.01"
          >
        </div>
      </div>
    </div>

    <!-- 操作按钮 -->
    <div class="filter-footer">
      <button class="btn-reset" @click="resetFilter">
        <LucideX class="icon" />
        重置
      </button>
      <button class="btn-apply" @click="applyFilter">
        <LucideFilter class="icon" />
        应用筛选
      </button>
    </div>
  </div>
</template>

<style scoped>
.split-record-filter {
  display: flex;
  flex-direction: column;
  background: white;
  border-radius: 12px;
  border: 1px solid var(--color-base-300);
  box-shadow: var(--shadow-sm);
  overflow: hidden;
}

/* Header */
.filter-header {
  padding: 1.5rem;
  border-bottom: 1px solid var(--color-base-200);
  background: var(--color-base-100);
}

.header-title {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.header-title .icon {
  width: 20px;
  height: 20px;
  color: var(--color-primary);
}

.header-title h3 {
  margin: 0;
  font-size: 1.125rem;
  font-weight: 600;
}

.filter-count {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 24px;
  height: 24px;
  padding: 0 0.5rem;
  background: var(--color-primary);
  color: white;
  border-radius: 12px;
  font-size: 0.75rem;
  font-weight: 600;
}

/* Content */
.filter-content {
  padding: 1.5rem;
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
  max-height: 500px;
  overflow-y: auto;
}

.filter-group {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.filter-label {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.875rem;
  font-weight: 500;
  color: var(--color-gray-700);
}

.label-icon {
  width: 16px;
  height: 16px;
  color: var(--color-gray-500);
}

/* Radio Group */
.radio-group {
  display: flex;
  gap: 1rem;
}

.radio-option {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  cursor: pointer;
}

.radio-option input[type="radio"] {
  cursor: pointer;
}

.radio-option span {
  font-size: 0.875rem;
}

/* Select */
.filter-select {
  padding: 0.75rem;
  border: 1px solid var(--color-base-300);
  border-radius: 8px;
  font-size: 0.875rem;
  background: white;
  cursor: pointer;
}

.filter-select:focus {
  outline: none;
  border-color: var(--color-primary);
}

/* Quick Dates */
.quick-dates {
  display: flex;
  gap: 0.5rem;
}

.quick-date-btn {
  flex: 1;
  padding: 0.5rem;
  background: var(--color-base-100);
  border: 1px solid var(--color-base-300);
  border-radius: 6px;
  font-size: 0.75rem;
  cursor: pointer;
  transition: all 0.2s;
}

.quick-date-btn:hover {
  background: var(--color-base-200);
  border-color: var(--color-primary);
}

/* Date Range */
.date-range {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.date-input {
  flex: 1;
  padding: 0.75rem;
  border: 1px solid var(--color-base-300);
  border-radius: 8px;
  font-size: 0.875rem;
}

.date-input:focus {
  outline: none;
  border-color: var(--color-primary);
}

.date-separator {
  font-size: 0.875rem;
  color: var(--color-gray-500);
}

/* Amount Range */
.amount-range {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.amount-input {
  flex: 1;
  padding: 0.75rem;
  border: 1px solid var(--color-base-300);
  border-radius: 8px;
  font-size: 0.875rem;
}

.amount-input:focus {
  outline: none;
  border-color: var(--color-primary);
}

.amount-separator {
  font-size: 0.875rem;
  color: var(--color-gray-500);
}

/* Footer */
.filter-footer {
  display: flex;
  gap: 1rem;
  padding: 1.5rem;
  border-top: 1px solid var(--color-base-200);
  background: var(--color-base-100);
}

.btn-reset,
.btn-apply {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  padding: 0.75rem;
  border: none;
  border-radius: 8px;
  font-size: 0.875rem;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
}

.btn-reset {
  background: white;
  border: 1px solid var(--color-base-300);
  color: var(--color-gray-700);
}

.btn-reset:hover {
  background: var(--color-base-200);
}

.btn-apply {
  background: var(--color-primary);
  color: white;
}

.btn-apply:hover {
  background: var(--color-primary-dark);
  transform: translateY(-1px);
  box-shadow: var(--shadow-md);
}

.btn-reset .icon,
.btn-apply .icon {
  width: 16px;
  height: 16px;
}

/* Responsive */
@media (max-width: 768px) {
  .quick-dates {
    flex-direction: column;
  }

  .date-range,
  .amount-range {
    flex-direction: column;
    align-items: stretch;
  }

  .date-separator,
  .amount-separator {
    text-align: center;
  }
}
</style>
