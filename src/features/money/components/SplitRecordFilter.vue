<script setup lang="ts">
import { LucideCalendar, LucideFilter, LucideX } from 'lucide-vue-next';
import Button from '@/components/ui/Button.vue';
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
  <div class="flex flex-col bg-white dark:bg-gray-800 rounded-xl border border-gray-200 dark:border-gray-700 shadow-sm overflow-hidden">
    <div class="px-6 py-4 border-b border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-700">
      <div class="flex items-center gap-3">
        <LucideFilter class="w-5 h-5 text-blue-600 dark:text-blue-400" />
        <h3 class="m-0 text-lg font-semibold text-gray-900 dark:text-white">
          高级筛选
        </h3>
        <span v-if="activeFiltersCount > 0" class="inline-flex items-center justify-center min-w-[24px] h-6 px-2 bg-blue-600 dark:bg-blue-500 text-white rounded-xl text-xs font-semibold">
          {{ activeFiltersCount }}
        </span>
      </div>
    </div>

    <div class="px-6 py-4 flex flex-col gap-6 max-h-[500px] overflow-y-auto">
      <!-- 状态筛选 -->
      <div class="flex flex-col gap-3">
        <label class="flex items-center gap-2 text-sm font-medium text-gray-700 dark:text-gray-300">状态</label>
        <div class="flex gap-4">
          <label class="flex items-center gap-2 cursor-pointer">
            <input
              v-model="localConfig.status"
              type="radio"
              value="all"
              class="w-4 h-4 text-blue-600 border-gray-300 focus:ring-blue-500 dark:border-gray-600 dark:bg-gray-700 cursor-pointer"
            >
            <span class="text-sm text-gray-900 dark:text-white">全部</span>
          </label>
          <label class="flex items-center gap-2 cursor-pointer">
            <input
              v-model="localConfig.status"
              type="radio"
              value="pending"
              class="w-4 h-4 text-blue-600 border-gray-300 focus:ring-blue-500 dark:border-gray-600 dark:bg-gray-700 cursor-pointer"
            >
            <span class="text-sm text-gray-900 dark:text-white">进行中</span>
          </label>
          <label class="flex items-center gap-2 cursor-pointer">
            <input
              v-model="localConfig.status"
              type="radio"
              value="completed"
              class="w-4 h-4 text-blue-600 border-gray-300 focus:ring-blue-500 dark:border-gray-600 dark:bg-gray-700 cursor-pointer"
            >
            <span class="text-sm text-gray-900 dark:text-white">已完成</span>
          </label>
        </div>
      </div>

      <!-- 分摊类型 -->
      <div class="flex flex-col gap-3">
        <label class="flex items-center gap-2 text-sm font-medium text-gray-700 dark:text-gray-300">分摊类型</label>
        <select
          v-model="localConfig.splitType"
          class="px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg text-sm bg-white dark:bg-gray-700 text-gray-900 dark:text-white cursor-pointer focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
        >
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
      <div class="flex flex-col gap-3">
        <label class="flex items-center gap-2 text-sm font-medium text-gray-700 dark:text-gray-300">参与成员</label>
        <select
          v-model="localConfig.memberSerialNum"
          class="px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg text-sm bg-white dark:bg-gray-700 text-gray-900 dark:text-white cursor-pointer focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
        >
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
      <div class="flex flex-col gap-3">
        <label class="flex items-center gap-2 text-sm font-medium text-gray-700 dark:text-gray-300">
          <LucideCalendar class="w-4 h-4 text-gray-500 dark:text-gray-400" />
          日期范围
        </label>

        <!-- 快速选择 -->
        <div class="flex flex-col sm:flex-row gap-2">
          <button
            class="flex-1 px-3 py-2 bg-gray-50 dark:bg-gray-700 border border-gray-300 dark:border-gray-600 rounded-md text-xs text-gray-900 dark:text-white cursor-pointer transition-all hover:bg-gray-100 dark:hover:bg-gray-600 hover:border-blue-500 dark:hover:border-blue-400"
            @click="setQuickDate(7)"
          >
            最近7天
          </button>
          <button
            class="flex-1 px-3 py-2 bg-gray-50 dark:bg-gray-700 border border-gray-300 dark:border-gray-600 rounded-md text-xs text-gray-900 dark:text-white cursor-pointer transition-all hover:bg-gray-100 dark:hover:bg-gray-600 hover:border-blue-500 dark:hover:border-blue-400"
            @click="setQuickDate(30)"
          >
            最近30天
          </button>
          <button
            class="flex-1 px-3 py-2 bg-gray-50 dark:bg-gray-700 border border-gray-300 dark:border-gray-600 rounded-md text-xs text-gray-900 dark:text-white cursor-pointer transition-all hover:bg-gray-100 dark:hover:bg-gray-600 hover:border-blue-500 dark:hover:border-blue-400"
            @click="setQuickDate(90)"
          >
            最近90天
          </button>
        </div>

        <!-- 自定义日期 -->
        <div class="flex flex-col sm:flex-row items-stretch sm:items-center gap-3">
          <input
            v-model="localConfig.dateRange.start"
            type="date"
            class="flex-1 px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg text-sm bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            placeholder="开始日期"
          >
          <span class="text-sm text-gray-500 dark:text-gray-400 text-center sm:text-left">至</span>
          <input
            v-model="localConfig.dateRange.end"
            type="date"
            class="flex-1 px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg text-sm bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            placeholder="结束日期"
          >
        </div>
      </div>

      <!-- 金额范围 -->
      <div class="flex flex-col gap-3">
        <label class="flex items-center gap-2 text-sm font-medium text-gray-700 dark:text-gray-300">金额范围</label>
        <div class="flex flex-col sm:flex-row items-stretch sm:items-center gap-3">
          <input
            v-model.number="localConfig.amountRange.min"
            type="number"
            class="flex-1 px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg text-sm bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            placeholder="最小金额"
            min="0"
            step="0.01"
          >
          <span class="text-sm text-gray-500 dark:text-gray-400 text-center sm:text-left">至</span>
          <input
            v-model.number="localConfig.amountRange.max"
            type="number"
            class="flex-1 px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg text-sm bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            placeholder="最大金额"
            min="0"
            step="0.01"
          >
        </div>
      </div>
    </div>

    <!-- 操作按钮 -->
    <div class="flex gap-4 px-6 py-4 border-t border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-700">
      <Button
        variant="secondary"
        class="flex-1"
        @click="resetFilter"
      >
        <LucideX class="w-4 h-4" />
        重置
      </Button>
      <Button
        variant="primary"
        class="flex-1"
        @click="applyFilter"
      >
        <LucideFilter class="w-4 h-4" />
        应用筛选
      </Button>
    </div>
  </div>
</template>
