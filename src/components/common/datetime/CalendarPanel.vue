<script setup lang="ts">
  /**
   * CalendarPanel - 日历面板组件
   *
   * 功能：
   * - 显示月份日历
   * - 支持月份切换
   * - 日期选择
   * - 标记今日和选中日期
   */

  interface Props {
    /** 当前显示的月份 */
    currentDate: Date;
    /** 选中的日期 */
    selectedDate: Date | null;
    /** 是否禁用 */
    disabled?: boolean;
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
    selectDate: [day: CalendarDay];
    previousMonth: [];
    nextMonth: [];
  }>();

  // 星期标题
  const weekdays = ['日', '一', '二', '三', '四', '五', '六'];

  // 当前月份年份显示
  const currentMonthYear = computed(() => {
    return `${props.currentDate.getFullYear()}年${props.currentDate.getMonth() + 1}月`;
  });

  // 生成日历数据
  const calendarDays = computed(() => {
    const year = props.currentDate.getFullYear();
    const month = props.currentDate.getMonth();

    // 获取当月第一天和最后一天
    const firstDay = new Date(year, month, 1);
    const lastDay = new Date(year, month + 1, 0);

    // 获取第一天是星期几（0-6，0是星期日）
    const firstDayOfWeek = firstDay.getDay();

    // 获取上个月的最后几天
    const prevMonth = new Date(year, month - 1, 0);
    const prevMonthLastDay = prevMonth.getDate();

    const days: CalendarDay[] = [];

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
      const isSelected = props.selectedDate
        ? fullDate.toDateString() === props.selectedDate.toDateString()
        : false;

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

  function handleSelectDate(day: CalendarDay) {
    if (!props.disabled) {
      emit('selectDate', day);
    }
  }
</script>

<template>
  <div class="calendar-panel">
    <!-- 日历头部 -->
    <div class="flex items-center justify-center mb-4">
      <button
        type="button"
        :disabled="disabled"
        class="p-2 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
        @click="emit('previousMonth')"
      >
        <span class="text-lg">‹</span>
      </button>

      <span class="mx-4 min-w-[120px] text-center font-semibold text-gray-900 dark:text-white">
        {{ currentMonthYear }}
      </span>

      <button
        type="button"
        :disabled="disabled"
        class="p-2 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
        @click="emit('nextMonth')"
      >
        <span class="text-lg">›</span>
      </button>
    </div>

    <!-- 星期标题 -->
    <div class="grid grid-cols-7 gap-1 mb-2">
      <div
        v-for="day in weekdays"
        :key="day"
        class="text-center text-xs font-medium text-gray-500 dark:text-gray-400 py-2"
      >
        {{ day }}
      </div>
    </div>

    <!-- 日期网格 -->
    <div class="grid grid-cols-7 gap-1">
      <button
        v-for="day in calendarDays"
        :key="`${day.date}-${day.month}`"
        type="button"
        :disabled="disabled"
        class="aspect-square flex items-center justify-center rounded-lg text-sm transition-all"
        :class="{
          'text-gray-400 dark:text-gray-500': day.isOtherMonth,
          'text-gray-900 dark:text-white': !day.isOtherMonth,
          'bg-blue-100 dark:bg-blue-900/30 text-blue-600 dark:text-blue-400 font-semibold': day.isToday && !day.isSelected,
          'bg-blue-600 dark:bg-blue-500 text-white font-semibold': day.isSelected,
          'hover:bg-gray-100 dark:hover:bg-gray-700': !day.isSelected && !disabled,
          'cursor-not-allowed opacity-50': disabled,
        }"
        @click="handleSelectDate(day)"
      >
        {{ day.date }}
      </button>
    </div>
  </div>
</template>
