<script setup lang="ts">
/**
 * DateTimePanel - 日期时间选择面板
 *
 * 整合 CalendarPanel 和 TimePicker
 */

import { Check, X } from 'lucide-vue-next';
import CalendarPanel from './CalendarPanel.vue';
import TimePicker from './TimePicker.vue';

interface Props {
  /** 当前显示的月份 */
  currentDate: Date;
  /** 选中的日期时间 */
  selectedDate: Date | null;
  /** 小时 */
  hour: number;
  /** 分钟 */
  minute: number;
  /** 秒 */
  second: number;
  /** 是否禁用 */
  disabled?: boolean;
  /** 面板位置 */
  position: { top: number; left: number };
}

interface CalendarDay {
  date: number;
  month: number;
  year: number;
  isOtherMonth: boolean;
  isToday: boolean;
  isSelected: boolean;
  fullDate: Date;
}

const props = withDefaults(defineProps<Props>(), {
  disabled: false,
});

const emit = defineEmits<{
  'selectDate': [day: CalendarDay];
  'update:hour': [value: number];
  'update:minute': [value: number];
  'update:second': [value: number];
  'previousMonth': [];
  'nextMonth': [];
  'confirm': [];
  'cancel': [];
}>();

const panelStyle = computed(() => ({
  position: 'fixed' as const,
  top: `${props.position.top}px`,
  left: `${props.position.left}px`,
  zIndex: 9999999, // 必须高于 Modal 的 z-index (999999)
}));

const timePickerRef = ref<InstanceType<typeof TimePicker>>();

function handleCancel() {
  // 关闭虚拟键盘
  timePickerRef.value?.hideNumpadKeyboard();
  emit('cancel');
}

function handleConfirm() {
  // 关闭虚拟键盘
  timePickerRef.value?.hideNumpadKeyboard();
  emit('confirm');
}
</script>

<template>
  <div
    class="datetime-panel bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-xl shadow-xl p-4 min-w-[280px] max-w-[320px]"
    :style="panelStyle"
    @click.stop
  >
    <!-- 日历面板 -->
    <CalendarPanel
      :current-date="currentDate"
      :selected-date="selectedDate"
      :disabled="disabled"
      @select-date="emit('selectDate', $event)"
      @previous-month="emit('previousMonth')"
      @next-month="emit('nextMonth')"
    />

    <!-- 时间选择器 -->
    <TimePicker
      ref="timePickerRef"
      :hour="hour"
      :minute="minute"
      :second="second"
      :disabled="disabled"
      @update:hour="emit('update:hour', $event)"
      @update:minute="emit('update:minute', $event)"
      @update:second="emit('update:second', $event)"
    />

    <!-- 操作按钮 -->
    <div class="flex items-center justify-center gap-3 mt-4 pt-4 border-t border-gray-200 dark:border-gray-700">
      <button
        type="button"
        title="取消"
        class="flex items-center justify-center w-14 h-14 rounded-full bg-gray-300 hover:bg-gray-400 dark:bg-gray-600 dark:hover:bg-gray-500 text-gray-900 dark:text-white transition-all hover:scale-110 active:scale-95"
        @click="handleCancel"
      >
        <X :size="22" />
      </button>

      <button
        type="button"
        title="确定"
        :disabled="!selectedDate"
        class="flex items-center justify-center w-14 h-14 rounded-full bg-blue-600 hover:bg-blue-700 text-white transition-all hover:scale-110 active:scale-95 disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:scale-100"
        @click="handleConfirm"
      >
        <Check :size="22" :stroke-width="3" />
      </button>
    </div>
  </div>
</template>
