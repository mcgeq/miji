<template>
  <div v-if="isOpen" class="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50">
    <div class="bg-white rounded-lg p-6 w-full max-w-md mx-4">
      <div class="flex justify-between items-center mb-4">
        <h3 class="text-lg font-semibold">{{ editingReminder ? '编辑提醒' : '添加提醒' }}</h3>
        <button @click="closeModal" class="text-gray-500 hover:text-gray-700">
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
          </svg>
        </button>
      </div>
      <form @submit.prevent="saveReminder">
        <div class="mb-4">
          <label class="block text-sm font-medium text-gray-700 mb-2">提醒标题</label>
          <input
            v-model="form.title"
            type="text"
            required
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            placeholder="请输入提醒标题"
          />
        </div>
        <div class="mb-4">
          <label class="block text-sm font-medium text-gray-700 mb-2">提醒类型</label>
          <select
            v-model="form.type"
            required
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
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
        <div class="mb-4">
          <label class="block text-sm font-medium text-gray-700 mb-2">金额</label>
          <input
            v-model.number="form.amount"
            type="number"
            step="0.01"
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            placeholder="0.00（可选）"
          />
        </div>
        <div class="mb-4">
          <label class="block text-sm font-medium text-gray-700 mb-2">提醒日期</label>
          <input
            v-model="form.date"
            type="date"
            required
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>
        <div class="mb-4">
          <label class="block text-sm font-medium text-gray-700 mb-2">提醒时间</label>
          <input
            v-model="form.time"
            type="time"
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>
        <div class="mb-4">
          <label class="block text-sm font-medium text-gray-700 mb-2">重复频率</label>
          <select
            v-model="form.repeat"
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          >
            <option value="none">不重复</option>
            <option value="daily">每日</option>
            <option value="weekly">每周</option>
            <option value="monthly">每月</option>
            <option value="yearly">每年</option>
          </select>
        </div>
        <div class="mb-4">
          <label class="block text-sm font-medium text-gray-700 mb-2">优先级</label>
          <select
            v-model="form.priority"
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          >
            <option value="low">低</option>
            <option value="medium">中</option>
            <option value="high">高</option>
          </select>
        </div>
        <div class="mb-4">
          <label class="block text-sm font-medium text-gray-700 mb-2">提前提醒</label>
          <div class="flex items-center space-x-2">
            <input
              v-model.number="form.advanceValue"
              type="number"
              min="0"
              class="flex-1 px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              placeholder="0"
            />
            <select
              v-model="form.advanceUnit"
              class="px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
              <option value="minutes">分钟</option>
              <option value="hours">小时</option>
              <option value="days">天</option>
              <option value="weeks">周</option>
            </select>
          </div>
        </div>
        <div class="mb-4">
          <label class="block text-sm font-medium text-gray-700 mb-2">颜色</label>
          <div class="flex gap-2">
            <div
              v-for="color in colors"
              :key="color"
              @click="form.color = color"
              :class="[
                'w-8 h-8 rounded-full cursor-pointer border-2',
                form.color === color ? 'border-gray-800' : 'border-gray-300'
              ]"
              :style="{ backgroundColor: color }"
            ></div>
          </div>
        </div>
        <div class="mb-4">
          <label class="flex items-center">
            <input
              v-model="form.enabled"
              type="checkbox"
              class="mr-2"
            />
            <span class="text-sm font-medium text-gray-700">启用提醒</span>
          </label>
        </div>
        <div class="mb-6">
          <label class="block text-sm font-medium text-gray-700 mb-2">描述</label>
          <textarea
            v-model="form.description"
            rows="3"
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            placeholder="提醒描述（可选）"
          ></textarea>
        </div>
        <div class="flex justify-end space-x-3">
          <button
            type="button"
            @click="closeModal"
            class="px-4 py-2 text-gray-600 border border-gray-300 rounded-md hover:bg-gray-50"
          >
            取消
          </button>
          <button
            type="submit"
            class="px-4 py-2 bg-blue-500 text-white rounded-md hover:bg-blue-600"
          >
            {{ editingReminder ? '更新' : '添加' }}
          </button>
        </div>
      </form>
    </div>
  </div>
</template>

<script setup>
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

