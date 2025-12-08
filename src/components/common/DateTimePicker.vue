<script setup lang="ts">
  /**
   * DateTimePickerV2 - 重构后的日期时间选择器
   *
   * 改进：
   * - 组件化拆分，易于维护
   * - 使用 Tailwind CSS，减少自定义样式
   * - 保持完整功能和移动端兼容
   * - 更清晰的代码结构
   */

  import { useI18n } from 'vue-i18n';
  import DateInput from './datetime/DateInput.vue';
  import DateTimePanel from './datetime/DateTimePanel.vue';

  // 禁用自动属性继承
  defineOptions({
    inheritAttrs: false,
  });

  const props = withDefaults(defineProps<Props>(), {
    disabled: false,
    placeholder: '',
    format: 'yyyy-MM-dd HH:mm:ss',
  });

  const emit = defineEmits<{
    'update:modelValue': [value: Date | null];
    change: [value: Date | null];
  }>();

  interface Props {
    modelValue?: Date | string | null;
    disabled?: boolean;
    placeholder?: string;
    format?: string;
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

  const { t } = useI18n();

  // 响应式数据
  const isOpen = ref(false);
  const currentDate = ref(new Date());
  const selectedDate = ref<Date | null>(null);
  const selectedHour = ref(0);
  const selectedMinute = ref(0);
  const selectedSecond = ref(0);
  const panelPosition = ref({ top: 0, left: 0 });
  const ignoreNextOutsideClick = ref(false);

  // 打开/关闭选择器
  function openPicker() {
    if (props.disabled) return;

    // 设置标记，忽略本次点击触发的 document 点击事件
    ignoreNextOutsideClick.value = true;

    isOpen.value = true;
    updatePanelPosition();

    // 初始化选中日期
    if (props.modelValue) {
      const date =
        typeof props.modelValue === 'string' ? new Date(props.modelValue) : props.modelValue;

      if (!Number.isNaN(date.getTime())) {
        selectedDate.value = new Date(date);
        selectedHour.value = date.getHours();
        selectedMinute.value = date.getMinutes();
        selectedSecond.value = date.getSeconds();
        currentDate.value = new Date(date);
      }
    } else {
      const now = new Date();
      selectedDate.value = now;
      selectedHour.value = now.getHours();
      selectedMinute.value = now.getMinutes();
      selectedSecond.value = now.getSeconds();
    }

    // 在下一个事件循环后重置标记
    setTimeout(() => {
      ignoreNextOutsideClick.value = false;
    }, 0);
  }

  function closePicker() {
    isOpen.value = false;
  }

  // 更新面板位置
  function updatePanelPosition() {
    const viewportWidth = window.innerWidth;
    const viewportHeight = window.innerHeight;

    // 移动端和桌面端使用不同的定位策略
    if (viewportWidth <= 768) {
      // 移动端：水平居中，靠顶部显示
      panelPosition.value = {
        top: 20,
        left: 16,
      };
    } else {
      // 桌面端：完全居中
      const panelWidth = 320;
      const panelHeight = 450;
      const centerX = (viewportWidth - panelWidth) / 2;
      const centerY = (viewportHeight - panelHeight) / 2;

      panelPosition.value = {
        top: Math.max(20, centerY),
        left: Math.max(20, centerX),
      };
    }
  }

  // 选择日期
  function handleSelectDate(day: CalendarDay) {
    if (props.disabled) return;

    // 保留当前选中的时分秒，只更新日期部分
    selectedDate.value = new Date(
      day.year,
      day.month,
      day.date,
      selectedHour.value,
      selectedMinute.value,
      selectedSecond.value,
    );

    currentDate.value = new Date(day.year, day.month, day.date);
  }

  // 更新时间
  function updateTime(type: 'hour' | 'minute' | 'second', value: number) {
    if (!selectedDate.value) return;

    if (type === 'hour') selectedHour.value = value;
    else if (type === 'minute') selectedMinute.value = value;
    else selectedSecond.value = value;

    selectedDate.value = new Date(
      selectedDate.value.getFullYear(),
      selectedDate.value.getMonth(),
      selectedDate.value.getDate(),
      selectedHour.value,
      selectedMinute.value,
      selectedSecond.value,
    );
  }

  // 月份切换
  function previousMonth() {
    if (props.disabled) return;
    currentDate.value = new Date(
      currentDate.value.getFullYear(),
      currentDate.value.getMonth() - 1,
      1,
    );
  }

  function nextMonth() {
    if (props.disabled) return;
    currentDate.value = new Date(
      currentDate.value.getFullYear(),
      currentDate.value.getMonth() + 1,
      1,
    );
  }

  // 确认选择
  function confirmSelection() {
    if (selectedDate.value) {
      emit('update:modelValue', selectedDate.value);
      emit('change', selectedDate.value);
    }
    closePicker();
  }

  // 取消选择
  function cancelSelection() {
    closePicker();
  }

  // 清除值
  function clearValue() {
    selectedDate.value = null;
    emit('update:modelValue', null);
    emit('change', null);
  }

  // 点击外部关闭
  function handleClickOutside(event: Event) {
    // 如果标记为忽略，则跳过
    if (ignoreNextOutsideClick.value) {
      return;
    }

    // 如果面板未打开，不需要处理
    if (!isOpen.value) {
      return;
    }

    const target = event.target as HTMLElement;
    const inInput = target.closest('.datetime-input');
    const inPanel = target.closest('.datetime-panel');
    const inKeyboard = target.closest('.numpad-keyboard');

    if (!(inInput || inPanel || inKeyboard)) {
      closePicker();
    }
  }

  // 窗口大小变化处理
  function handleResize() {
    if (isOpen.value) {
      updatePanelPosition();
    }
  }

  // 生命周期
  onMounted(() => {
    document.addEventListener('click', handleClickOutside);
    window.addEventListener('resize', handleResize);
  });

  onUnmounted(() => {
    document.removeEventListener('click', handleClickOutside);
    window.removeEventListener('resize', handleResize);
  });

  // 监听 modelValue 变化
  watch(
    () => props.modelValue,
    newValue => {
      if (newValue) {
        const date = typeof newValue === 'string' ? new Date(newValue) : newValue;
        if (!Number.isNaN(date.getTime())) {
          selectedDate.value = new Date(date);
          selectedHour.value = date.getHours();
          selectedMinute.value = date.getMinutes();
          selectedSecond.value = date.getSeconds();
        }
      } else {
        selectedDate.value = null;
      }
    },
    { immediate: true },
  );
</script>

<template>
  <!-- 输入框 -->
  <DateInput
    :model-value="modelValue"
    :placeholder="placeholder || t('common.selectDate')"
    :format="format"
    :disabled="disabled"
    :is-focused="isOpen"
    :class="$attrs.class"
    @click="openPicker"
    @clear="clearValue"
  />

  <!-- 选择面板 -->
  <Teleport to="body">
    <Transition name="fade">
      <DateTimePanel
        v-if="isOpen"
        :current-date="currentDate"
        :selected-date="selectedDate"
        :hour="selectedHour"
        :minute="selectedMinute"
        :second="selectedSecond"
        :disabled="disabled"
        :position="panelPosition"
        @select-date="handleSelectDate"
        @update:hour="updateTime('hour', $event)"
        @update:minute="updateTime('minute', $event)"
        @update:second="updateTime('second', $event)"
        @previous-month="previousMonth"
        @next-month="nextMonth"
        @confirm="confirmSelection"
        @cancel="cancelSelection"
      />
    </Transition>
  </Teleport>

  <!-- 遮罩层 -->
  <Teleport to="body">
    <div v-if="isOpen" class="fixed inset-0 z-[9999998] bg-transparent" @click="closePicker" />
  </Teleport>
</template>

<style scoped>
  /* 过渡动画 */
  .fade-enter-active,
  .fade-leave-active {
    transition: opacity 0.2s ease;
  }

  .fade-enter-from,
  .fade-leave-to {
    opacity: 0;
  }
</style>
