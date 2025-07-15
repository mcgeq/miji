<template>
  <div class="modal-mask">
    <div class="modal-mask-window-money">
      <div class="flex justify-between items-center mb-4">
        <h3 class="text-lg font-semibold">{{ editingBudget ? '编辑预算' : '添加预算' }}</h3>
        <button @click="closeModal" class="text-gray-500 hover:text-gray-700">
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
          </svg>
        </button>
      </div>
      <form @submit.prevent="saveBudget">
        <div class="mb-2 flex items-center justify-between">
          <label class="text-sm font-medium text-gray-700 mb-2">预算名称</label>
          <input
            v-model="form.name"
            type="text"
            required
            class="w-2/3 modal-input-select"
            placeholder="请输入预算名称"
          />
        </div>
        <div class="mb-2 flex items-center justify-between">
          <label class="text-sm font-medium text-gray-700 mb-2">预算类别</label>
          <select
            v-model="form.category"
            required
            class="w-2/3 modal-input-select"
          >
            <option value="">请选择类别</option>
            <option value="food">餐饮</option>
            <option value="transport">交通</option>
            <option value="shopping">购物</option>
            <option value="entertainment">娱乐</option>
            <option value="health">医疗</option>
            <option value="education">教育</option>
            <option value="housing">住房</option>
            <option value="utilities">水电费</option>
            <option value="insurance">保险</option>
            <option value="investment">投资</option>
            <option value="other">其他</option>
          </select>
        </div>

        <div class="mb-2 flex items-center justify-between">
          <label class="text-sm font-medium text-gray-700 mb-2">预算金额</label>
          <input
            v-model.number="form.amount"
            type="number"
            step="0.01"
            required
            class="w-2/3 modal-input-select"
            placeholder="0.00"
          />
        </div>
 
        <div class="mb-2 flex items-center justify-between">
          <label class="text-sm font-medium text-gray-700 mb-2">预算周期</label>
          <select
            v-model="form.period"
            required
            class="w-2/3 modal-input-select"
          >
            <option value="monthly">月度</option>
            <option value="weekly">周度</option>
            <option value="daily">日度</option>
            <option value="yearly">年度</option>
          </select>
        </div>
 
        <div class="mb-2 flex items-center justify-between">
          <label class="text-sm font-medium text-gray-700 mb-2">开始日期</label>
          <input
            v-model="form.startDate"
            type="date"
            required
            class="w-2/3 modal-input-select"
          />
        </div>
 
        <div class="mb-2 flex items-center justify-between">
          <label class="text-sm font-medium text-gray-700 mb-2">结束日期</label>
          <input
            v-model="form.endDate"
            type="date"
            class="w-2/3 modal-input-select"
          />
        </div>
        
        <div class="mb-2 flex items-center justify-between">
          <label class="text-sm font-medium text-gray-700 mb-2">颜色</label>
          <ColorSelector
            v-model="form.color"
            :color-names="colorNameMap"
          />
        </div>

        <div class="mb-4 h-8 flex items-center justify-between">
          <div class="w-1/3">
            <label class="flex items-center">
              <input
                v-model="form.alertEnabled"
                type="checkbox"
                class="mr-2 modal-input-select"
              />
              <span class="text-sm font-medium text-gray-700">启用超支提醒</span>
            </label>
          </div>
 
          <div v-if="form.alertEnabled" class="w-2/3">
            <input
              v-model.number="form.alertThreshold"
              type="number"
              min="1"
              max="100"
              class="w-full modal-input-select"
              placeholder="80"
            />
          </div>
        </div>
        <div class="mb-2">
          <textarea
            v-model="form.description"
            rows="3"
            class="w-full modal-input-select"
            placeholder="预算描述（可选）"
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

<script setup lang="ts">
import { Check, X } from 'lucide-vue-next';
import { COLORS_MAP } from '@/constants/moneyConst';
import ColorSelector from '@/components/common/ColorSelector.vue';

const colorNameMap = ref(COLORS_MAP);

// 定义 props
const props = defineProps({
  isOpen: {
    type: Boolean,
    default: false,
  },
  editingBudget: {
    type: Object,
    default: null,
  },
});

// 定义 emits
const emit = defineEmits(['close', 'save']);

// 响应式数据
const form = reactive({
  name: '',
  category: '',
  amount: 0,
  period: 'monthly',
  startDate: '',
  endDate: '',
  color: '#3B82F6',
  alertEnabled: false,
  alertThreshold: 80,
  description: '',
});

// 方法
const resetForm = () => {
  if (props.editingBudget) {
    Object.assign(form, props.editingBudget);
  } else {
    const today = new Date();
    Object.assign(form, {
      name: '',
      category: '',
      amount: 0,
      period: 'monthly',
      startDate: today.toISOString().split('T')[0],
      endDate: '',
      color: '#3B82F6',
      alertEnabled: false,
      alertThreshold: 80,
      description: '',
    });
  }
};

const closeModal = () => {
  emit('close');
};

const saveBudget = () => {
  const budgetData = {
    ...form,
    id: props.editingBudget?.id || Date.now(),
    spent: props.editingBudget?.spent || 0,
    createdAt: props.editingBudget?.createdAt || new Date().toISOString(),
  };
  emit('save', budgetData);
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
  () => props.editingBudget,
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

