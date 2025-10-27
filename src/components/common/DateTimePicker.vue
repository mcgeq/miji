<script setup lang="ts">
import { useI18n } from 'vue-i18n';

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
  'change': [value: Date | null];
}>();

interface Props {
  modelValue?: Date | string | null;
  disabled?: boolean;
  placeholder?: string;
  format?: string;
}

const { t } = useI18n();

// 响应式数据
const isOpen = ref(false);
const currentDate = ref(new Date());
const selectedDate = ref<Date | null>(null);
const selectedHour = ref(0);
const selectedMinute = ref(0);
const selectedSecond = ref(0);

// spinner显示状态
const showHourSpinner = ref(false);
const showMinuteSpinner = ref(false);
const showSecondSpinner = ref(false);
const panelPosition = ref({ top: 0, left: 0 });

// 星期标题
const weekdays = ['日', '一', '二', '三', '四', '五', '六'];

// 计算属性
const displayValue = computed(() => {
  if (!props.modelValue) return props.placeholder || t('common.selectDate');
  const date = typeof props.modelValue === 'string'
    ? new Date(props.modelValue)
    : props.modelValue;
  if (Number.isNaN(date.getTime())) return props.placeholder || t('common.selectDate');

  return formatDate(date, props.format);
});

const currentMonthYear = computed(() => {
  return `${currentDate.value.getFullYear()}年${currentDate.value.getMonth() + 1}月`;
});

const calendarDays = computed(() => {
  const year = currentDate.value.getFullYear();
  const month = currentDate.value.getMonth();
  // 获取当月第一天和最后一天
  const firstDay = new Date(year, month, 1);
  const lastDay = new Date(year, month + 1, 0);
  // 获取第一天是星期几（0-6，0是星期日）
  const firstDayOfWeek = firstDay.getDay();
  // 获取上个月的最后几天
  const prevMonth = new Date(year, month - 1, 0);
  const prevMonthLastDay = prevMonth.getDate();
  const days = [];
  // 添加上个月的日期
  for (let i = firstDayOfWeek - 1; i >= 0; i--) {
    days.push({
      date: prevMonthLastDay - i,
      month: month - 1,
      year,
      isOtherMonth: true,
      isToday: false,
      isSelected: false,
      fullDate: new Date(year, month - 1, prevMonthLastDay - i),
    });
  }
  // 添加当月的日期
  const today = new Date();
  for (let day = 1; day <= lastDay.getDate(); day++) {
    const fullDate = new Date(year, month, day);
    const isToday = fullDate.toDateString() === today.toDateString();
    const isSelected = selectedDate.value && fullDate.toDateString() === selectedDate.value.toDateString();
    days.push({
      date: day,
      month,
      year,
      isOtherMonth: false,
      isToday,
      isSelected,
      fullDate,
    });
  }
  // 添加下个月的日期（填满6行）
  const remainingDays = 42 - days.length;
  for (let day = 1; day <= remainingDays; day++) {
    days.push({
      date: day,
      month: month + 1,
      year: month === 11 ? year + 1 : year,
      isOtherMonth: true,
      isToday: false,
      isSelected: false,
      fullDate: new Date(month === 11 ? year + 1 : year, month + 1, day),
    });
  }
  return days;
});

const panelStyle = computed(() => ({
  position: 'fixed' as const,
  top: `${panelPosition.value.top}px`,
  left: `${panelPosition.value.left}px`,
  zIndex: 10004, // 确保高于TransactionModal的z-index (10003)
}));

// 方法
function formatDate(date: Date, format: string): string {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  const hour = String(date.getHours()).padStart(2, '0');
  const minute = String(date.getMinutes()).padStart(2, '0');
  const second = String(date.getSeconds()).padStart(2, '0');
  return format
    .replace('yyyy', String(year))
    .replace('MM', month)
    .replace('dd', day)
    .replace('HH', hour)
    .replace('mm', minute)
    .replace('ss', second);
}

function togglePicker() {
  if (props.disabled) return;

  if (isOpen.value) {
    closePicker();
  } else {
    openPicker();
  }
}

function openPicker() {
  isOpen.value = true;
  updatePanelPosition();

  // 初始化选中日期
  if (props.modelValue) {
    const date = typeof props.modelValue === 'string'
      ? new Date(props.modelValue)
      : props.modelValue;

    if (!Number.isNaN(date.getTime())) {
      selectedDate.value = new Date(date);
      selectedHour.value = date.getHours();
      selectedMinute.value = date.getMinutes();
      selectedSecond.value = date.getSeconds();
      currentDate.value = new Date(date);
    }
  } else {
    selectedDate.value = new Date();
    selectedHour.value = new Date().getHours();
    selectedMinute.value = new Date().getMinutes();
    selectedSecond.value = new Date().getSeconds();
  }
}

function closePicker() {
  isOpen.value = false;
}

function updatePanelPosition() {
  const viewportWidth = window.innerWidth;
  const viewportHeight = window.innerHeight;
  // 移动端和桌面端使用不同的定位策略
  if (viewportWidth <= 768) {
    // 移动端：水平居中，靠顶部显示
    panelPosition.value = {
      top: 20, // 从顶部显示，保留20px间距
      left: 16,
    };
  } else {
    // 桌面端：完全居中
    const panelWidth = 320; // 面板最大宽度
    const panelHeight = 400; // 预估面板高度
    // 计算真正的中心位置
    const centerX = (viewportWidth - panelWidth) / 2;
    const centerY = (viewportHeight - panelHeight) / 2;
    panelPosition.value = {
      top: centerY,
      left: centerX,
    };
  }
}

function selectDate(day: any) {
  if (props.disabled) return;

  selectedDate.value = day.fullDate;
  currentDate.value = new Date(day.year, day.month, day.date);
}

function previousMonth() {
  if (props.disabled) return;
  currentDate.value = new Date(currentDate.value.getFullYear(), currentDate.value.getMonth() - 1, 1);
}

function nextMonth() {
  if (props.disabled) return;
  currentDate.value = new Date(currentDate.value.getFullYear(), currentDate.value.getMonth() + 1, 1);
}

function updateTime() {
  if (!selectedDate.value) return;

  selectedDate.value = new Date(
    selectedDate.value.getFullYear(),
    selectedDate.value.getMonth(),
    selectedDate.value.getDate(),
    selectedHour.value,
    selectedMinute.value,
    selectedSecond.value,
  );
}

// 时间递减函数 - 实现循环递减
function decrementHour() {
  if (props.disabled) return;
  const currentHour = selectedHour.value;
  if (currentHour <= 0) {
    selectedHour.value = 23; // 0减1变成23
  } else {
    selectedHour.value = currentHour - 1;
  }
  updateTime();
}

function decrementMinute() {
  if (props.disabled) return;
  const currentMinute = selectedMinute.value;
  if (currentMinute <= 0) {
    selectedMinute.value = 59; // 0减1变成59
  } else {
    selectedMinute.value = currentMinute - 1;
  }
  updateTime();
}

function decrementSecond() {
  if (props.disabled) return;
  const currentSecond = selectedSecond.value;
  if (currentSecond <= 0) {
    selectedSecond.value = 59; // 0减1变成59
  } else {
    selectedSecond.value = currentSecond - 1;
  }
  updateTime();
}

// 时间递增函数 - 实现循环递增
function incrementHour() {
  if (props.disabled) return;
  const currentHour = selectedHour.value;
  if (currentHour >= 23) {
    selectedHour.value = 0; // 23加1变成0
  } else {
    selectedHour.value = currentHour + 1;
  }
  updateTime();
}

function incrementMinute() {
  if (props.disabled) return;
  const currentMinute = selectedMinute.value;
  if (currentMinute >= 59) {
    selectedMinute.value = 0; // 59加1变成0
  } else {
    selectedMinute.value = currentMinute + 1;
  }
  updateTime();
}

function incrementSecond() {
  if (props.disabled) return;
  const currentSecond = selectedSecond.value;
  if (currentSecond >= 59) {
    selectedSecond.value = 0; // 59加1变成0
  } else {
    selectedSecond.value = currentSecond + 1;
  }
  updateTime();
}

// 鼠标滚轮事件处理
function handleHourWheel(event: WheelEvent) {
  event.preventDefault();
  if (event.deltaY < 0) {
    incrementHour();
  } else {
    decrementHour();
  }
}

function handleMinuteWheel(event: WheelEvent) {
  event.preventDefault();
  if (event.deltaY < 0) {
    incrementMinute();
  } else {
    decrementMinute();
  }
}

function handleSecondWheel(event: WheelEvent) {
  event.preventDefault();
  if (event.deltaY < 0) {
    incrementSecond();
  } else {
    decrementSecond();
  }
}

// spinner显示/隐藏控制
function showSpinner(type: 'hour' | 'minute' | 'second') {
  if (props.disabled) return;
  switch (type) {
    case 'hour':
      showHourSpinner.value = true;
      break;
    case 'minute':
      showMinuteSpinner.value = true;
      break;
    case 'second':
      showSecondSpinner.value = true;
      break;
  }
}

function hideSpinner(type: 'hour' | 'minute' | 'second') {
  switch (type) {
    case 'hour':
      showHourSpinner.value = false;
      break;
    case 'minute':
      showMinuteSpinner.value = false;
      break;
    case 'second':
      showSecondSpinner.value = false;
      break;
  }
}

function confirmSelection() {
  if (selectedDate.value) {
    emit('update:modelValue', selectedDate.value);
    emit('change', selectedDate.value);
  }
  closePicker();
}

function cancelSelection() {
  closePicker();
}

function clearValue() {
  selectedDate.value = null;
  emit('update:modelValue', null);
  emit('change', null);
}

// 监听外部点击关闭面板
function handleClickOutside(event: Event) {
  const target = event.target as HTMLElement;
  if (!target.closest('.datetime-input') && !target.closest('.datetime-panel')) {
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
watch(() => props.modelValue, newValue => {
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
}, { immediate: true });
</script>

<template>
  <!-- 输入框 -->
  <div
    class="datetime-input"
    :class="[
      { 'is-focused': isOpen, 'is-disabled': disabled },
      $attrs.class,
    ]"
    @click="togglePicker"
  >
    <div class="input-content">
      <span class="date-text">{{ displayValue }}</span>
      <div class="input-actions">
        <button
          v-if="modelValue && !disabled"
          type="button"
          class="clear-btn"
          :title="t('common.actions.clear')"
          @click.stop="clearValue"
        >
          ×
        </button>
        <div class="calendar-icon">
          📅
        </div>
      </div>
    </div>
  </div>

  <!-- 弹出面板 -->
  <Teleport to="body">
    <div
      v-if="isOpen"
      class="datetime-panel"
      :style="panelStyle"
      @click.stop
    >
      <!-- 日历头部 -->
      <div class="panel-header">
        <div class="month-year">
          <button type="button" class="nav-btn" :disabled="disabled" @click="previousMonth">
            ‹
          </button>
          <span class="current-month">{{ currentMonthYear }}</span>
          <button type="button" class="nav-btn" :disabled="disabled" @click="nextMonth">
            ›
          </button>
        </div>
      </div>

      <!-- 星期标题 -->
      <div class="weekdays">
        <div v-for="day in weekdays" :key="day" class="weekday">
          {{ day }}
        </div>
      </div>

      <!-- 日期网格 -->
      <div class="calendar-grid">
        <div
          v-for="day in calendarDays"
          :key="`${day.date}-${day.month}`"
          class="calendar-day"
          :class="{
            'is-other-month': day.isOtherMonth,
            'is-today': day.isToday,
            'is-selected': day.isSelected,
            'is-disabled': disabled,
          }"
          @click="selectDate(day)"
        >
          {{ day.date }}
        </div>
      </div>

      <!-- 时间选择器 -->
      <div class="time-picker">
        <div class="time-inputs">
          <div class="time-input-group">
            <div class="time-input-container">
              <input
                v-model="selectedHour"
                type="number"
                min="0"
                max="23"
                class="time-input"
                :disabled="disabled"
                @change="updateTime"
                @wheel="handleHourWheel"
                @keydown.up="incrementHour"
                @keydown.down="decrementHour"
                @mouseenter="showSpinner('hour')"
                @mouseleave="hideSpinner('hour')"
              >
              <div v-show="showHourSpinner" class="custom-spinner">
                <button
                  type="button"
                  class="spinner-btn increment-btn"
                  :disabled="disabled"
                  title="增加小时"
                  @click="incrementHour"
                >
                  ▲
                </button>
                <button
                  type="button"
                  class="spinner-btn decrement-btn"
                  :disabled="disabled"
                  title="减少小时"
                  @click="decrementHour"
                >
                  ▼
                </button>
              </div>
            </div>
          </div>
          <div class="time-separator">
            :
          </div>
          <div class="time-input-group">
            <div class="time-input-container">
              <input
                v-model="selectedMinute"
                type="number"
                min="0"
                max="59"
                class="time-input"
                :disabled="disabled"
                @change="updateTime"
                @wheel="handleMinuteWheel"
                @keydown.up="incrementMinute"
                @keydown.down="decrementMinute"
                @mouseenter="showSpinner('minute')"
                @mouseleave="hideSpinner('minute')"
              >
              <div v-show="showMinuteSpinner" class="custom-spinner">
                <button
                  type="button"
                  class="spinner-btn increment-btn"
                  :disabled="disabled"
                  title="增加分钟"
                  @click="incrementMinute"
                >
                  ▲
                </button>
                <button
                  type="button"
                  class="spinner-btn decrement-btn"
                  :disabled="disabled"
                  title="减少分钟"
                  @click="decrementMinute"
                >
                  ▼
                </button>
              </div>
            </div>
          </div>
          <div class="time-separator">
            :
          </div>
          <div class="time-input-group">
            <div class="time-input-container">
              <input
                v-model="selectedSecond"
                type="number"
                min="0"
                max="59"
                class="time-input"
                :disabled="disabled"
                @change="updateTime"
                @wheel="handleSecondWheel"
                @keydown.up="incrementSecond"
                @keydown.down="decrementSecond"
                @mouseenter="showSpinner('second')"
                @mouseleave="hideSpinner('second')"
              >

              <div v-show="showSecondSpinner" class="custom-spinner">
                <button
                  type="button"
                  class="spinner-btn increment-btn"
                  :disabled="disabled"
                  title="增加秒"
                  @click="incrementSecond"
                >
                  ▲
                </button>
                <button
                  type="button"
                  class="spinner-btn decrement-btn"
                  :disabled="disabled"
                  title="减少秒"
                  @click="decrementSecond"
                >
                  ▼
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- 操作按钮 -->
      <div class="panel-actions">
        <button
          type="button"
          class="action-btn cancel-btn"
          title="取消"
          @click="cancelSelection"
        />
        <button
          type="button"
          class="action-btn confirm-btn"
          :disabled="!selectedDate"
          title="确定"
          @click="confirmSelection"
        />
      </div>
    </div>
  </Teleport>

  <!-- 遮罩层 -->
  <div v-if="isOpen" class="datetime-overlay" @click="closePicker" />
</template>

<style scoped>
.datetime-input {
  background-color: var(--color-base-200);
  border: 1px solid var(--color-base-300);
  border-radius: 6px;
  padding: 0.5rem 0.75rem;
  cursor: pointer;
  transition: all 0.2s ease;
  min-height: 2.5rem;
  display: flex;
  align-items: center;
}

.datetime-input:hover:not(.is-disabled) {
  border-color: var(--color-base-400);
}

.datetime-input.is-focused {
  border-color: var(--color-primary);
  box-shadow: 0 0 0 2px var(--color-primary-soft);
}

.datetime-input.is-disabled {
  background-color: var(--color-base-300);
  color: var(--color-neutral);
  cursor: not-allowed;
}

.input-content {
  display: flex;
  align-items: center;
  justify-content: space-between;
  width: 100%;
}

.date-text {
  flex: 1;
  color: var(--color-base-content);
  font-size: 0.875rem;
}

.input-actions {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.clear-btn {
  background: none;
  border: none;
  color: var(--color-base-content-soft);
  cursor: pointer;
  font-size: 1.2rem;
  line-height: 1;
  padding: 0.25rem;
  border-radius: 50%;
  width: 1.5rem;
  height: 1.5rem;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.2s ease;
}

.clear-btn:hover {
  background-color: var(--color-base-300);
  color: var(--color-base-content);
}

.calendar-icon {
  font-size: 1rem;
  color: var(--color-base-content-soft);
}

.datetime-panel {
  background-color: var(--color-base-100);
  border: 1px solid var(--color-base-300);
  border-radius: 8px;
  box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
  padding: 1rem;
  min-width: 280px;
  max-width: 320px;
  z-index: 10004; /* 确保高于TransactionModal */
}

.panel-header {
  display: flex;
  justify-content: center;
  margin-bottom: 1rem;
}

.month-year {
  display: flex;
  align-items: center;
  gap: 1rem;
}

.nav-btn {
  background: none;
  border: none;
  color: var(--color-base-content);
  cursor: pointer;
  font-size: 1.2rem;
  padding: 0.25rem 0.5rem;
  border-radius: 4px;
  transition: all 0.2s ease;
}

.nav-btn:hover:not(:disabled) {
  background-color: var(--color-base-200);
}

.nav-btn:disabled {
  color: var(--color-base-content-soft);
  cursor: not-allowed;
}

.current-month {
  font-weight: 600;
  color: var(--color-base-content);
  min-width: 120px;
  text-align: center;
}

.weekdays {
  display: grid;
  grid-template-columns: repeat(7, 1fr);
  gap: 0.25rem;
  margin-bottom: 0.5rem;
}

.weekday {
  text-align: center;
  font-size: 0.75rem;
  font-weight: 500;
  color: var(--color-base-content-soft);
  padding: 0.5rem 0;
}

.calendar-grid {
  display: grid;
  grid-template-columns: repeat(7, 1fr);
  gap: 0.25rem;
  margin-bottom: 1rem;
}

.calendar-day {
  aspect-ratio: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  border-radius: 4px;
  font-size: 0.875rem;
  transition: all 0.2s ease;
  color: var(--color-base-content);
}

.calendar-day:hover:not(.is-disabled) {
  background-color: var(--color-base-200);
}

.calendar-day.is-other-month {
  color: var(--color-base-content-soft);
}

.calendar-day.is-today {
  background-color: var(--color-primary-soft);
  color: var(--color-primary);
  font-weight: 600;
}

.calendar-day.is-selected {
  background-color: var(--color-primary);
  color: var(--color-primary-content);
  font-weight: 600;
}

.calendar-day.is-disabled {
  cursor: not-allowed;
  opacity: 0.5;
}

.time-picker {
  border-top: 1px solid var(--color-base-300);
  padding-top: 0.5rem;
  margin-bottom: 0.25rem;
}

.time-inputs {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.25rem;
  height: 2rem; /* 设置固定高度确保对齐 */
}

.time-separator {
  font-size: 1.2rem;
  color: var(--color-base-content-soft);
  display: flex;
  align-items: center;
  justify-content: center;
  height: 2rem; /* 与输入框相同高度 */
  line-height: 1;
  font-weight: 500; /* 与输入框字体粗细一致 */
  margin: 0 0.25rem; /* 添加左右间距 */
}

.time-input-group {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  height: 2.5rem; /* 与分隔符相同高度 */
}

.time-input-container {
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center; /* 确保容器内容居中 */
  cursor: pointer; /* 鼠标悬停时显示手型光标 */
  height: 2.5rem; /* 确保容器高度与输入框一致 */
}

.custom-spinner {
  position: absolute;
  right: 4px;
  top: 50%;
  transform: translateY(-50%);
  display: flex;
  flex-direction: column;
  gap: 1px;
  background: transparent; /* 移除背景颜色 */
  border-radius: 2px;
  padding: 1px;
}

.spinner-btn {
  width: 16px;
  height: 12px;
  border: none;
  background: var(--color-base-200);
  color: var(--color-base-content);
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 8px;
  line-height: 1;
  border-radius: 1px;
  transition: all 0.15s ease;
  user-select: none;
}

.spinner-btn:hover:not(:disabled) {
  background: var(--color-base-300);
  color: var(--color-primary);
}

.spinner-btn:active:not(:disabled) {
  background: var(--color-primary);
  color: var(--color-primary-content);
}

.spinner-btn:disabled {
  background: var(--color-base-300);
  color: var(--color-base-content-soft);
  cursor: not-allowed;
  opacity: 0.5;
}

.time-input {
  width: 4rem;
  height: 2rem; /* 设置固定高度 */
  padding: 0;
  border: 1px solid var(--color-base-300);
  border-radius: 0.2rem;
  text-align: center;
  font-size: 0.875rem;
  font-weight: 500; /* 稍微加粗数字 */
  background-color: var(--color-base-100);
  color: var(--color-base-content);
  cursor: pointer; /* 鼠标悬停时显示手型光标 */
  display: flex;
  align-items: center;
  justify-content: center;
  line-height: 1; /* 确保行高一致 */
  box-sizing: border-box; /* 确保边框包含在宽度内 */
  /* 隐藏原生spinner按钮 */
  -moz-appearance: textfield; /* Firefox */
  appearance: textfield; /* 标准属性 */
}

/* 隐藏Webkit浏览器的spinner按钮 */
.time-input::-webkit-outer-spin-button,
.time-input::-webkit-inner-spin-button {
  -webkit-appearance: none;
  margin: 0;
}

.time-input:focus {
  outline: none;
  border-color: var(--color-primary);
  box-shadow: 0 0 0 2px var(--color-primary-soft);
}

.time-input:disabled {
  background-color: var(--color-base-300);
  color: var(--color-neutral);
  cursor: not-allowed;
}

.panel-actions {
  display: flex;
  justify-content: center; /* 按钮居中 */
  gap: 1rem;
  margin-top: 1rem;
  padding-top: 1rem;
  border-top: 1px solid var(--color-base-300);
}

.action-btn {
  width: 3rem;
  height: 3rem;
  border-radius: 50%;
  border: 1px solid var(--color-base-300); /* 默认边框，与输入框一致 */
  background-color: var(--color-base-200); /* 默认背景色 */
  color: var(--color-base-content);
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 1.2rem;
  font-weight: bold;
  transition: all 0.2s ease;
}

.action-btn:hover:not(:disabled),
.action-btn:focus:not(:disabled) {
  background-color: var(--color-base-300);
  border-color: var(--color-primary); /* 悬停/聚焦时边框变蓝 */
  color: var(--color-primary); /* 悬停/聚焦时图标变蓝 */
  transform: scale(1.05);
  box-shadow: 0 0 0 2px var(--color-primary-soft); /* 蓝色光晕效果，与输入框一致 */
}

.cancel-btn {
  background-color: var(--color-base-200) !important; /* 确保取消按钮使用中性背景 */
  color: var(--color-base-content) !important; /* 确保取消按钮使用中性文字颜色 */
  border-color: var(--color-base-300) !important; /* 确保取消按钮使用中性边框 */
  background: var(--color-base-200) !important; /* 覆盖任何可能的background简写 */
}

.cancel-btn::before {
  content: '×';
  color: var(--color-base-content) !important; /* 确保图标颜色也是中性的 */
}

.confirm-btn {
  background-color: var(--color-base-200) !important; /* 确保确认按钮使用中性背景 */
  color: var(--color-base-content) !important; /* 确保确认按钮使用中性文字颜色 */
  border-color: var(--color-base-300) !important; /* 确保确认按钮使用中性边框 */
  background: var(--color-base-200) !important; /* 覆盖任何可能的background简写 */
}

.confirm-btn::before {
  content: '√';
  color: var(--color-base-content) !important; /* 确保图标颜色也是中性的 */
}

/* 强制覆盖任何可能的红色样式 */
.cancel-btn:hover,
.cancel-btn:focus,
.cancel-btn:active {
  background-color: var(--color-base-300) !important;
  color: var(--color-primary) !important;
  border-color: var(--color-primary) !important;
  background: var(--color-base-300) !important;
}

.confirm-btn:hover,
.confirm-btn:focus,
.confirm-btn:active {
  background-color: var(--color-base-300) !important;
  color: var(--color-primary) !important;
  border-color: var(--color-primary) !important;
  background: var(--color-base-300) !important;
}

.action-btn:disabled {
  background-color: var(--color-base-300);
  color: var(--color-base-content-soft);
  cursor: not-allowed;
  transform: none;
  border-color: var(--color-base-300);
}

.datetime-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  z-index: 10003; /* 确保高于TransactionModal但低于日期选择面板 */
  background-color: transparent;
}

/* 移动端适配 */
@media (max-width: 768px) {
  .datetime-panel {
    min-width: calc(100vw - 2rem);
    max-width: calc(100vw - 2rem);
    width: calc(100vw - 2rem) !important;
    /* 移除强制定位，使用JavaScript计算的定位 */
    transform: none !important;
  }
  .time-inputs {
    flex-wrap: wrap;
  }
}
</style>
