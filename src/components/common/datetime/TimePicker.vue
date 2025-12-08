<script setup lang="ts">
  /**
   * TimePicker - 时间选择器组件
   *
   * 功能：
   * - 小时、分钟、秒选择
   * - 键盘上下键调整
   * - 鼠标滚轮调整
   * - 悬停显示 spinner
   * - 移动端虚拟键盘支持
   */

  import { isMobile } from '@/utils/platform';
  import NumpadKeyboard from '../NumpadKeyboard.vue';

  interface Props {
    /** 小时 (0-23) */
    hour: number;
    /** 分钟 (0-59) */
    minute: number;
    /** 秒 (0-59) */
    second: number;
    /** 是否禁用 */
    disabled?: boolean;
  }

  const props = withDefaults(defineProps<Props>(), {
    disabled: false,
  });

  const emit = defineEmits<{
    'update:hour': [value: number];
    'update:minute': [value: number];
    'update:second': [value: number];
  }>();

  // 检测是否为移动设备
  const isMobileDevice = isMobile();

  // Spinner 显示状态
  const showHourSpinner = ref(false);
  const showMinuteSpinner = ref(false);
  const showSecondSpinner = ref(false);

  // 虚拟键盘状态
  const showNumpad = ref(false);
  const activeTimeInput = ref<'hour' | 'minute' | 'second' | null>(null);
  const numpadPosition = ref({ top: 0, left: 0, width: 0 });
  const currentTimeValue = ref('');

  // 显示值（输入过程中显示 currentValue，否则显示实际值）
  const displayHour = computed(() => {
    if (activeTimeInput.value === 'hour' && currentTimeValue.value !== '') {
      return currentTimeValue.value;
    }
    return props.hour;
  });

  const displayMinute = computed(() => {
    if (activeTimeInput.value === 'minute' && currentTimeValue.value !== '') {
      return currentTimeValue.value;
    }
    return props.minute;
  });

  const displaySecond = computed(() => {
    if (activeTimeInput.value === 'second' && currentTimeValue.value !== '') {
      return currentTimeValue.value;
    }
    return props.second;
  });

  // 时间调整函数 - 循环递增/递减
  function adjustTime(type: 'hour' | 'minute' | 'second', delta: number) {
    if (props.disabled) return;

    const maxValues = { hour: 23, minute: 59, second: 59 };
    const currentValue =
      type === 'hour' ? props.hour : type === 'minute' ? props.minute : props.second;
    const maxValue = maxValues[type];

    let newValue = currentValue + delta;
    if (newValue > maxValue) newValue = 0;
    if (newValue < 0) newValue = maxValue;

    if (type === 'hour') {
      emit('update:hour', newValue);
    } else if (type === 'minute') {
      emit('update:minute', newValue);
    } else {
      emit('update:second', newValue);
    }
  }

  // 鼠标滚轮事件
  function handleWheel(type: 'hour' | 'minute' | 'second', event: WheelEvent) {
    event.preventDefault();
    adjustTime(type, event.deltaY < 0 ? 1 : -1);
  }

  // 虚拟键盘相关函数
  function showNumpadKeyboard(type: 'hour' | 'minute' | 'second', inputElement: HTMLInputElement) {
    if (props.disabled || !isMobileDevice) return;

    if (activeTimeInput.value === type && showNumpad.value) return;

    activeTimeInput.value = type;
    const rect = inputElement.getBoundingClientRect();
    const keyboardWidth = Math.max(rect.width, 200);
    const keyboardHeight = 140;
    const viewportWidth = window.innerWidth;
    const viewportHeight = window.innerHeight;

    let left = rect.left;
    let top = rect.bottom + 5;

    if (left + keyboardWidth > viewportWidth) {
      left = Math.max(5, viewportWidth - keyboardWidth - 5);
    }

    if (top + keyboardHeight > viewportHeight) {
      top = Math.max(5, rect.top - keyboardHeight - 5);
    }

    numpadPosition.value = { top, left, width: keyboardWidth };

    // 初始化当前值
    const value = type === 'hour' ? props.hour : type === 'minute' ? props.minute : props.second;
    currentTimeValue.value = String(value);

    showNumpad.value = true;
  }

  function hideNumpadKeyboard() {
    showNumpad.value = false;
    activeTimeInput.value = null;
    currentTimeValue.value = '';
  }

  function handleNumpadInput(value: string) {
    if (!activeTimeInput.value) return;

    if (currentTimeValue.value.length >= 2) {
      currentTimeValue.value = value;
    } else {
      currentTimeValue.value += value;
    }
  }

  function handleNumpadDelete() {
    if (currentTimeValue.value.length > 0) {
      currentTimeValue.value = currentTimeValue.value.slice(0, -1);
    }
  }

  function handleNumpadConfirm() {
    if (!activeTimeInput.value || currentTimeValue.value === '') {
      hideNumpadKeyboard();
      return;
    }

    const numValue = Number.parseInt(currentTimeValue.value, 10);
    if (!Number.isNaN(numValue)) {
      const maxValues = { hour: 23, minute: 59, second: 59 };
      const clampedValue = Math.max(0, Math.min(maxValues[activeTimeInput.value], numValue));

      if (activeTimeInput.value === 'hour') {
        emit('update:hour', clampedValue);
      } else if (activeTimeInput.value === 'minute') {
        emit('update:minute', clampedValue);
      } else if (activeTimeInput.value === 'second') {
        emit('update:second', clampedValue);
      }
    }

    hideNumpadKeyboard();
  }

  defineExpose({ hideNumpadKeyboard });
</script>

<template>
  <div class="time-picker border-t border-gray-200 dark:border-gray-700 pt-3 mt-3">
    <div class="flex items-center justify-center gap-1">
      <!-- 小时 -->
      <div class="relative">
        <input
          :value="displayHour"
          type="number"
          min="0"
          max="23"
          :disabled="disabled"
          :readonly="isMobileDevice"
          class="w-16 h-8 px-2 text-center text-sm font-medium border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500 disabled:opacity-50 disabled:cursor-not-allowed [appearance:textfield] [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none"
          @focus="showNumpadKeyboard('hour', $event.target as HTMLInputElement)"
          @click="showNumpadKeyboard('hour', $event.target as HTMLInputElement)"
          @wheel="handleWheel('hour', $event)"
          @keydown.up.prevent="adjustTime('hour', 1)"
          @keydown.down.prevent="adjustTime('hour', -1)"
          @mouseenter="showHourSpinner = true"
          @mouseleave="showHourSpinner = false"
        />

        <!-- Spinner 按钮 -->
        <div
          v-show="showHourSpinner && !disabled"
          class="absolute right-1 top-1/2 -translate-y-1/2 flex flex-col gap-0.5"
        >
          <button
            type="button"
            class="w-4 h-3 flex items-center justify-center text-[8px] bg-gray-200 dark:bg-gray-700 hover:bg-gray-300 dark:hover:bg-gray-600 rounded-sm transition-colors"
            @click="adjustTime('hour', 1)"
          >
            ▲
          </button>
          <button
            type="button"
            class="w-4 h-3 flex items-center justify-center text-[8px] bg-gray-200 dark:bg-gray-700 hover:bg-gray-300 dark:hover:bg-gray-600 rounded-sm transition-colors"
            @click="adjustTime('hour', -1)"
          >
            ▼
          </button>
        </div>
      </div>

      <span class="text-lg font-medium text-gray-500 dark:text-gray-400">:</span>

      <!-- 分钟 -->
      <div class="relative">
        <input
          :value="displayMinute"
          type="number"
          min="0"
          max="59"
          :disabled="disabled"
          :readonly="isMobileDevice"
          class="w-16 h-8 px-2 text-center text-sm font-medium border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500 disabled:opacity-50 disabled:cursor-not-allowed [appearance:textfield] [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none"
          @focus="showNumpadKeyboard('minute', $event.target as HTMLInputElement)"
          @click="showNumpadKeyboard('minute', $event.target as HTMLInputElement)"
          @wheel="handleWheel('minute', $event)"
          @keydown.up.prevent="adjustTime('minute', 1)"
          @keydown.down.prevent="adjustTime('minute', -1)"
          @mouseenter="showMinuteSpinner = true"
          @mouseleave="showMinuteSpinner = false"
        />

        <!-- Spinner 按钮 -->
        <div
          v-show="showMinuteSpinner && !disabled"
          class="absolute right-1 top-1/2 -translate-y-1/2 flex flex-col gap-0.5"
        >
          <button
            type="button"
            class="w-4 h-3 flex items-center justify-center text-[8px] bg-gray-200 dark:bg-gray-700 hover:bg-gray-300 dark:hover:bg-gray-600 rounded-sm transition-colors"
            @click="adjustTime('minute', 1)"
          >
            ▲
          </button>
          <button
            type="button"
            class="w-4 h-3 flex items-center justify-center text-[8px] bg-gray-200 dark:bg-gray-700 hover:bg-gray-300 dark:hover:bg-gray-600 rounded-sm transition-colors"
            @click="adjustTime('minute', -1)"
          >
            ▼
          </button>
        </div>
      </div>

      <span class="text-lg font-medium text-gray-500 dark:text-gray-400">:</span>

      <!-- 秒 -->
      <div class="relative">
        <input
          :value="displaySecond"
          type="number"
          min="0"
          max="59"
          :disabled="disabled"
          :readonly="isMobileDevice"
          class="w-16 h-8 px-2 text-center text-sm font-medium border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500 disabled:opacity-50 disabled:cursor-not-allowed [appearance:textfield] [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none"
          @focus="showNumpadKeyboard('second', $event.target as HTMLInputElement)"
          @click="showNumpadKeyboard('second', $event.target as HTMLInputElement)"
          @wheel="handleWheel('second', $event)"
          @keydown.up.prevent="adjustTime('second', 1)"
          @keydown.down.prevent="adjustTime('second', -1)"
          @mouseenter="showSecondSpinner = true"
          @mouseleave="showSecondSpinner = false"
        />

        <!-- Spinner 按钮 -->
        <div
          v-show="showSecondSpinner && !disabled"
          class="absolute right-1 top-1/2 -translate-y-1/2 flex flex-col gap-0.5"
        >
          <button
            type="button"
            class="w-4 h-3 flex items-center justify-center text-[8px] bg-gray-200 dark:bg-gray-700 hover:bg-gray-300 dark:hover:bg-gray-600 rounded-sm transition-colors"
            @click="adjustTime('second', 1)"
          >
            ▲
          </button>
          <button
            type="button"
            class="w-4 h-3 flex items-center justify-center text-[8px] bg-gray-200 dark:bg-gray-700 hover:bg-gray-300 dark:hover:bg-gray-600 rounded-sm transition-colors"
            @click="adjustTime('second', -1)"
          >
            ▼
          </button>
        </div>
      </div>
    </div>

    <!-- 虚拟数字键盘 -->
    <NumpadKeyboard
      :visible="showNumpad"
      :position="numpadPosition"
      :current-value="currentTimeValue"
      :active-type="activeTimeInput"
      @input="handleNumpadInput"
      @delete="handleNumpadDelete"
      @confirm="handleNumpadConfirm"
      @close="hideNumpadKeyboard"
    />
  </div>
</template>
