<template>
  <div class="modal-mask">
    <div class="modal-mask-window-money">
      <div class="flex justify-between items-center mb-4">
        <h3 class="text-lg font-semibold">{{ props.reminder ? '编辑提醒' : '添加提醒' }}</h3>
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
            v-model="form.name"
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
            <option value="Bill">账单提醒</option>
            <option value="income">收入提醒</option>
            <option value="Budget">预算提醒</option>
            <option value="Goal">目标提醒</option>
            <option value="Investment">投资提醒</option>
            <option value="Other">其他</option>
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
            v-model="form.remindDate"
            type="date"
            required
            class="w-2/3 modal-input-select"
          />
        </div>
        <div class="mb-4 flex items-center justify-between">
          <label class="text-sm font-medium text-gray-700 mb-2">重复频率</label>
          <select
            v-model="form.repeatPeriod"
            class="w-2/3 modal-input-select"
          >
            <option value="None">不重复</option>
            <option value="Daily">每日</option>
            <option value="Weekly">每周</option>
            <option value="Monthly">每月</option>
            <option value="Yearly">每年</option>
          </select>
        </div>
        <div class="mb-2 flex items-center justify-between">
          <label class="text-sm font-medium text-gray-700 mb-2">优先级</label>
          <select
            v-model="form.priority"
            class="w-2/3 modal-input-select"
          >
            <option value="Low">低</option>
            <option value="Medium">中</option>
            <option value="High">高</option>
            <option value="Urgent">急</option>
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
          <ColorSelector
            v-model="form.color"
            :color-names="colorNameMap"
          />
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

<script setup lang="ts">
import { Check, X } from 'lucide-vue-next';
import { COLORS_MAP, DEFAULT_CURRENCY } from '@/constants/moneyConst';
import ColorSelector from '@/components/common/ColorSelector.vue';
import { uuid } from '@/utils/uuid';
import { getLocalISODateTimeWithOffset } from '@/utils/date';
import { BilReminder } from '@/schema/money';
import {
  CategorySchema,
  PrioritySchema,
  ReminderTypeSchema,
} from '@/schema/common';

const colorNameMap = ref(COLORS_MAP);

interface Props {
  reminder: BilReminder | null;
}
const props = defineProps<Props>();
const emit = defineEmits(['close', 'save']);

const reminder = props.reminder || {
  serialNum: '',
  name: '',
  enabled: true,
  type: ReminderTypeSchema.enum.Notification,
  description: '',
  category: CategorySchema.enum.Food,
  amount: '',
  currency: DEFAULT_CURRENCY[1],
  dueDate: '',
  billDate: '',
  remindDate: '',
  repeatPeriod: { type: 'None' },
  isPaid: false,
  priority: PrioritySchema.enum.Medium,
  advanceValue: 0,
  advanceUnit: '',
  color: COLORS_MAP[0].code,
  relatedTransactionSerialNum: '',
  createdAt: '',
  updatedAt: '',
};

const form = reactive<BilReminder>({
  serialNum: reminder.serialNum,
  name: reminder.name,
  enabled: reminder.enabled,
  type: reminder.type,
  description: reminder.description,
  category: reminder.category,
  amount: reminder.amount,
  currency: reminder.currency,
  dueDate: reminder.dueDate,
  billDate: reminder.billDate,
  remindDate: reminder.remindDate,
  repeatPeriod: reminder.repeatPeriod,
  isPaid: reminder.isPaid,
  priority: reminder.priority,
  advanceValue: reminder.advanceValue,
  advanceUnit: reminder.advanceUnit,
  color: reminder.color,
  relatedTransactionSerialNum: reminder.relatedTransactionSerialNum,
  createdAt: reminder.createdAt,
  updatedAt: reminder.updatedAt,
});

const closeModal = () => {
  emit('close');
};

const saveReminder = () => {
  const reminderData = {
    ...form,
    serialNum: props.reminder?.serialNum || uuid(38),
    createdAt: props.reminder?.createdAt || getLocalISODateTimeWithOffset(),
  };
  emit('save', reminderData);
  closeModal();
};

watch(
  () => props.reminder,
  (newVal) => {
    if (newVal) {
      const clonedReminder = JSON.parse(JSON.stringify(newVal));
      Object.assign(form, clonedReminder);
    }
  },
  { immediate: true, deep: true },
);
</script>

<style scoped>
/* 自定义样式 */
</style>

