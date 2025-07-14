<template>
  <div class="modal-mask">
    <div class="modal-mask-window-money">
      <div class="flex justify-between items-center mb-4">
        <h3 class="text-lg font-semibold">{{ editingReminder ? '编辑提醒' : '添加提醒' }}</h3>
        <button @click="closeModal" class="text-gray-500 hover:text-gray-700">
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
          </svg>
        </button>
      </div>
      <form @submit.prevent="saveReminder">
        <div class="mb-2 flex items-center justify-between">
          <label class="text-sm font-medium text-gray-700 mb-2">提醒标题</label>
          <input
            v-model="form.title"
            type="text"
            required
            class="w-2/3 modal-input-select"
            placeholder="请输入提醒标题"
          />
        </div>
        <div class="mb-2 flex items-center justify-between">
          <label class="text-sm font-medium text-gray-700 mb-2">提醒类型</label>
          <select
            v-model="form.type"
            required
            class="w-2/3 modal-input-select"
          >
            <option value="">请选择类型</option>
            <option value="bill">账单提醒</option>
            <option value="income">收入提醒</option>
            <option value="budget">预算提醒</option>
            <option value="goal">目标提醒</option>
            <option value="investment">投资提醒</option>
            <option value="other">其他</option>
          </select>
        </div>
        <div class="mb-2 flex items-center justify-between">
          <label class="text-sm font-medium text-gray-700 mb-2">金额</label>
          <input
            v-model.number="form.amount"
            type="number"
            step="0.01"
            class="w-2/3 modal-input-select"
            placeholder="0.00（可选）"
          />
        </div>
        <div class="mb-2 flex items-center justify-between">
          <label class="text-sm font-medium text-gray-700 mb-2">提醒日期</label>
          <input
            v-model="form.date"
            type="date"
            required
            class="w-2/3 modal-input-select"
          />
        </div>
        <div class="mb-2 flex items-center justify-between">
          <label class="text-sm font-medium text-gray-700 mb-2">提醒时间</label>
          <input
            v-model="form.time"
            type="time"
            class="w-2/3 modal-input-select"
          />
        </div>
        <div class="mb-4 flex items-center justify-between">
          <label class="text-sm font-medium text-gray-700 mb-2">重复频率</label>
          <select
            v-model="form.repeat"
            class="w-2/3 modal-input-select"
          >
            <option value="none">不重复</option>
            <option value="daily">每日</option>
            <option value="weekly">每周</option>
            <option value="monthly">每月</option>
            <option value="yearly">每年</option>
          </select>
        </div>
        <div class="mb-2 flex items-center justify-between">
          <label class="text-sm font-medium text-gray-700 mb-2">优先级</label>
          <select
            v-model="form.priority"
            class="w-2/3 modal-input-select"
          >
            <option value="low">低</option>
            <option value="medium">中</option>
            <option value="high">高</option>
          </select>
        </div>
        <div class="mb-2 flex items-center justify-between">
          <label class="block text-sm font-medium text-gray-700 mb-2">提前提醒</label>
          <div class="flex items-center space-x-1 w-2/3">
            <input
              v-model.number="form.advanceValue"
              type="number"
              min="0"
              class="w-1/2 flex-1 modal-input-select"
              placeholder="0"
            />
            <select
              v-model="form.advanceUnit"
              class="modal-input-select"
            >
              <option value="minutes">分钟</option>
              <option value="hours">小时</option>
              <option value="days">天</option>
              <option value="weeks">周</option>
            </select>
          </div>
        </div>
        <div class="mb-2 flex items-center justify-between">
          <label class="text-sm font-medium text-gray-700 mb-2">颜色</label>
          <div class="flex gap-2">
            <div
              v-for="color in colors"
              :key="color"
              @click="form.color = color"
              :class="[
                'w-6 h-6 rounded-full cursor-pointer border-2',
                form.color === color ? 'border-gray-800' : 'border-gray-300'
              ]"
              :style="{ backgroundColor: color }"
            ></div>
          </div>
        </div>
        <div class="mb-2">
          <label class="flex items-center">
            <input
              v-model="form.enabled"
              type="checkbox"
              class="mr-2"
            />
            <span class="text-sm font-medium text-gray-700">启用提醒</span>
          </label>
        </div>
        <div class="mb-2">
          <textarea
            v-model="form.description"
            rows="3"
            class="w-full modal-input-select"
            placeholder="提醒描述（可选）"
          ></textarea>
        </div>
        <div class="flex justify-center space-x-3">
          <button
            type="button"
            @click="closeModal"
            class="modal-btn-x"
          >
            <X class="wh-5" />
          </button>
          <button
            type="submit"
            class="modal-btn-check"
          >
            <Check class="wh-5" />
          </button>
        </div>
      </form>
    </div>
  </div>
</template>

<script setup>
import { Check, X } from 'lucide-vue-next';
// 定义 props
const props = defineProps({
  isOpen: {
    type: Boolean,
    default: false,
  },
  editingReminder: {
    type: Object,
    default: null,
  },
});

// 定义 emits
const emit = defineEmits(['close', 'save']);

// 响应式数据
const form = reactive({
  title: '',
  type: '',
  amount: 0,
  date: '',
  time: '09:00',
  repeat: 'none',
  priority: 'medium',
  advanceValue: 0,
  advanceUnit: 'minutes',
  color: '#3B82F6',
  enabled: true,
  description: '',
});

const colors = ref([
  '#3B82F6',
  '#EF4444',
  '#10B981',
  '#F59E0B',
  '#8B5CF6',
  '#F97316',
  '#06B6D4',
  '#84CC16',
  '#EC4899',
  '#6B7280',
]);

// 方法
const resetForm = () => {
  if (props.editingReminder) {
    Object.assign(form, props.editingReminder);
  } else {
    const today = new Date();
    Object.assign(form, {
      title: '',
      type: '',
      amount: 0,
      date: today.toISOString().split('T')[0],
      time: '09:00',
      repeat: 'none',
      priority: 'medium',
      advanceValue: 0,
      advanceUnit: 'minutes',
      color: '#3B82F6',
      enabled: true,
      description: '',
    });
  }
};

const closeModal = () => {
  emit('close');
};

const saveReminder = () => {
  const reminderData = {
    ...form,
    id: props.editingReminder?.id || Date.now(),
    createdAt: props.editingReminder?.createdAt || new Date().toISOString(),
    status: props.editingReminder?.status || 'pending',
  };
  emit('save', reminderData);
  closeModal();
};

// 监听器
watch(
  () => props.isOpen,
  (newVal) => {
    if (newVal) {
      resetForm();
    }
  },
);

watch(
  () => props.editingReminder,
  (newVal) => {
    if (newVal) {
      Object.assign(form, newVal);
    }
  },
  { immediate: true },
);
</script>

<style scoped>
/* 自定义样式 */
</style>

