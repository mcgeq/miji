<template>
  <div class="period-calendar">
    <!-- 头部导航 -->
    <div class="calendar-header">
      <div class="month-navigation">
        <button @click="goToPreviousMonth" class="nav-button" aria-label="上个月">
          <ChevronUp class="wh-5" />
        </button>
        <h2 class="month-title">{{ currentMonthYear }}</h2>
        <button @click="goToNextMonth" class="nav-button" aria-label="下个月">
          <ChevronDown class="wh-5" />
        </button>
      </div>

      <div class="view-controls">
        <button @click="goToToday" class="control-button">
          今天
        </button>
        <button @click="toggleView" class="control-button">
          <i :class="viewMode === 'calendar' ? 'i-tabler-list' : 'i-tabler-calendar'" class="wh-3 mr-1" />
          {{ viewMode === 'calendar' ? '列表' : '日历' }}
        </button>
      </div>
    </div>

    <!-- 日历视图 -->
    <div v-if="viewMode === 'calendar'" class="calendar-container">
      <!-- 星期标题 -->
      <div class="weekdays-header">
        <div v-for="day in weekDays" :key="day" class="weekday-label">
          {{ day }}
        </div>
      </div>

      <!-- 日期网格 -->
      <div class="calendar-grid">
        <div v-for="day in calendarDays" :key="day.date" class="calendar-cell" :class="getCellClasses(day)"
          @click="selectDate(day.date)">
          <span class="day-number">{{ day.day }}</span>
          <!-- 事件指示器 -->
          <div v-if="day.events.length > 0" class="event-indicators">
            <div v-for="event in day.events.slice(0, 2)" :key="event.type" class="event-dot"
              :class="getEventDotClass(event)" :title="getEventLabel(event)" />
            <div v-if="day.events.length > 2" class="event-dot more-events" :title="`+${day.events.length - 2} 更多事件`" />
          </div>
        </div>
      </div>
    </div>

    <!-- 列表视图 -->
    <div v-else class="list-container">
      <div v-for="day in calendarDays.filter(d => d.events.length > 0)" :key="day.date" class="list-item"
        @click="selectDate(day.date)">
        <div class="list-item-content">
          <div class="date-info">
            <div class="date-primary">{{ formatDateShort(day.date) }}</div>
            <div class="date-secondary">{{ formatDateFull(day.date) }}</div>
          </div>
          <div class="event-badges">
            <div v-for="event in day.events" :key="event.type" class="event-badge" :class="getEventBadgeClass(event)">
              {{ getEventLabel(event) }}
            </div>
          </div>
        </div>
      </div>

      <div v-if="calendarDays.filter(d => d.events.length > 0).length === 0" class="empty-state">
        <i class="i-tabler-calendar-x wh-8 text-gray-400" />
        <p class="text-sm text-gray-500 mt-2">本月暂无记录</p>
      </div>
    </div>

    <!-- 图例 -->
    <div class="legend">
      <div class="legend-item">
        <div class="legend-dot bg-red-500" />
        <span>经期</span>
      </div>
      <div class="legend-item">
        <div class="legend-dot bg-blue-500" />
        <span>排卵期</span>
      </div>
      <div class="legend-item">
        <div class="legend-dot bg-green-500" />
        <span>易孕期</span>
      </div>
      <div class="legend-item">
        <div class="legend-dot bg-yellow-500" />
        <span>PMS</span>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ChevronDown, ChevronUp } from 'lucide-vue-next';
import { PeriodCalendarEvent } from '@/schema/health/period';
import { usePeriodStore } from '@/stores/periodStore';
import { getCurrentDate, getLocalISODateTimeWithOffset } from '@/utils/date';

interface CalendarDay {
  date: string;
  day: number;
  isCurrentMonth: boolean;
  isToday: boolean;
  events: PeriodCalendarEvent[];
}

// Props
interface Props {
  selectedDate?: string;
}

const props = withDefaults(defineProps<Props>(), {
  selectedDate: '',
});

// Emits
const emit = defineEmits<{
  dateSelect: [date: string];
}>();

// Store
const periodStore = usePeriodStore();

// Reactive state
const currentDate = ref(getCurrentDate());
const viewMode = ref<'calendar' | 'list'>('calendar');
const weekDays = ['日', '一', '二', '三', '四', '五', '六'];

// Computed
const currentMonthYear = computed(() => {
  const year = currentDate.value.getFullYear();
  const month = currentDate.value.getMonth() + 1;
  return `${year}年${month}月`;
});

const calendarDays = computed((): CalendarDay[] => {
  const year = currentDate.value.getFullYear();
  const month = currentDate.value.getMonth();

  // 获取本月第一天和最后一天
  const firstDay = new Date(year, month, 1);
  const lastDay = new Date(year, month + 1, 0);

  // 获取日历开始日期（包含上月末尾的日期）
  const startDate = new Date(firstDay);
  startDate.setDate(startDate.getDate() - firstDay.getDay());

  // 获取日历结束日期（包含下月开始的日期）
  const endDate = new Date(lastDay);
  endDate.setDate(endDate.getDate() + (6 - lastDay.getDay()));

  const days: CalendarDay[] = [];
  const today = getLocalISODateTimeWithOffset().split('T')[0];

  // 获取事件数据
  const events = periodStore.getCalendarEvents(
    startDate.toISOString().split('T')[0],
    endDate.toISOString().split('T')[0],
  );

  for (let d = new Date(startDate); d <= endDate; d.setDate(d.getDate() + 1)) {
    const dayEvents = events.filter((event) => event.date === dateStr);
    let nd = new Date(d);
    nd.setDate(d.getDate() + 1);
    const dateStr = nd.toISOString().split('T')[0];
    days.push({
      date: dateStr,
      day: d.getDate(),
      isCurrentMonth: d.getMonth() === month,
      isToday: dateStr === today,
      events: dayEvents,
    });
  }
  return days;
});

// Methods
function goToPreviousMonth() {
  currentDate.value = new Date(
    currentDate.value.getFullYear(),
    currentDate.value.getMonth() - 1,
    1,
  );
}

function goToNextMonth() {
  currentDate.value = new Date(
    currentDate.value.getFullYear(),
    currentDate.value.getMonth() + 1,
    1,
  );
}

function goToToday() {
  currentDate.value = new Date();
}

function toggleView() {
  viewMode.value = viewMode.value === 'calendar' ? 'list' : 'calendar';
}

function selectDate(date: string) {
  emit('dateSelect', date);
}

function getCellClasses(day: CalendarDay): string[] {
  const classes = [];

  if (!day.isCurrentMonth) {
    classes.push('other-month');
  }

  if (day.isToday) {
    classes.push('today');
  }

  if (props.selectedDate === day.date) {
    classes.push('selected');
  }

  if (day.events.length > 0) {
    classes.push('has-events');
  }

  return classes;
}

function getEventDotClass(event: PeriodCalendarEvent): string {
  switch (event.type) {
    case 'period':
      return 'bg-red-500';
    case 'ovulation':
      return 'bg-blue-500';
    case 'fertile':
      return 'bg-green-500';
    case 'pms':
      return 'bg-yellow-500';
    default:
      return 'bg-gray-400';
  }
}

function getEventBadgeClass(event: PeriodCalendarEvent): string {
  switch (event.type) {
    case 'period':
      return 'badge-red';
    case 'ovulation':
      return 'badge-blue';
    case 'fertile':
      return 'badge-green';
    case 'pms':
      return 'badge-yellow';
    default:
      return 'badge-gray';
  }
}

function getEventLabel(event: PeriodCalendarEvent): string {
  switch (event.type) {
    case 'period':
      return '经期';
    case 'ovulation':
      return '排卵期';
    case 'fertile':
      return '易孕期';
    case 'pms':
      return 'PMS';
    default:
      return '未知';
  }
}

function formatDateShort(date: string): string {
  const d = new Date(date);
  const month = d.getMonth() + 1;
  const day = d.getDate();
  return `${month}/${day}`;
}

function formatDateFull(date: string): string {
  const d = new Date(date);
  const month = d.getMonth() + 1;
  const day = d.getDate();
  const weekDay = weekDays[d.getDay()];
  return `${month}月${day}日 ${weekDay}`;
}

// Lifecycle
onMounted(() => {
  periodStore.initialize();
});
</script>

<style scoped lang="postcss">
.period-calendar {
  @apply bg-white dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-700 overflow-hidden;
}

/* 头部样式 */
.calendar-header {
  @apply flex items-center justify-between p-3 bg-gray-50 dark:bg-gray-900 border-b border-gray-200 dark:border-gray-700;
}

.month-navigation {
  @apply flex items-center gap-2;
}

.nav-button {
  @apply w-7 h-7 flex items-center justify-center rounded-md text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-200 hover:bg-gray-200 dark:hover:bg-gray-700 transition-colors;
}

.month-title {
  @apply text-base font-semibold text-gray-900 dark:text-white px-3;
}

.view-controls {
  @apply flex items-center gap-2;
}

.control-button {
  @apply px-2 py-1 text-xs font-medium rounded-md border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-600 transition-colors flex items-center;
}

/* 日历容器 */
.calendar-container {
  @apply p-2;
}

.weekdays-header {
  @apply grid grid-cols-7 mb-1;
}

.weekday-label {
  @apply text-center text-xs font-medium text-gray-500 dark:text-gray-400 py-1;
}

.calendar-grid {
  @apply grid grid-cols-7;
}

.calendar-cell {
  @apply relative w-8 h-8 flex flex-col items-center justify-center cursor-pointer transition-all duration-150 hover:bg-gray-100 dark:hover:bg-gray-700;
}

.calendar-cell.other-month {
  @apply text-gray-400 dark:text-gray-600;
}

.calendar-cell.today {
  @apply bg-blue-100 dark:bg-blue-900 text-blue-600 dark:text-blue-400 font-semibold rounded-md;
}

.calendar-cell.selected {
  @apply ring-1 ring-blue-500 bg-blue-50 dark:bg-blue-900/50 rounded-md;
}

.calendar-cell.has-events {
  @apply font-medium;
}

.day-number {
  @apply text-sm leading-none;
}

.event-indicators {
  @apply absolute bottom-0 left-1/2 transform -translate-x-1/2 flex gap-0.5;
}

.event-dot {
  @apply w-1 h-1 rounded-full;
}

.more-events {
  @apply bg-gray-400 w-1 h-1 rounded-full;
}

/* 列表容器 */
.list-container {
  @apply p-3 space-y-2 max-h-64 overflow-y-auto;
}

.list-item {
  @apply p-2 rounded-md border border-gray-200 dark:border-gray-700 hover:bg-gray-50 dark:hover:bg-gray-700 cursor-pointer transition-colors;
}

.list-item-content {
  @apply flex items-center justify-between;
}

.date-info {
  @apply flex flex-col;
}

.date-primary {
  @apply text-sm font-medium text-gray-900 dark:text-white;
}

.date-secondary {
  @apply text-xs text-gray-500 dark:text-gray-400;
}

.event-badges {
  @apply flex gap-1 flex-wrap;
}

.event-badge {
  @apply px-1.5 py-0.5 rounded text-xs font-medium;
}

.badge-red {
  @apply bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400;
}

.badge-blue {
  @apply bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-400;
}

.badge-green {
  @apply bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400;
}

.badge-yellow {
  @apply bg-yellow-100 text-yellow-700 dark:bg-yellow-900/30 dark:text-yellow-400;
}

.badge-gray {
  @apply bg-gray-100 text-gray-700 dark:bg-gray-900/30 dark:text-gray-400;
}

.empty-state {
  @apply flex flex-col items-center justify-center py-8 text-gray-500;
}

/* 图例 */
.legend {
  @apply flex items-center justify-center gap-4 p-3 bg-gray-50 dark:bg-gray-900 border-t border-gray-200 dark:border-gray-700;
}

.legend-item {
  @apply flex items-center gap-1.5;
}

.legend-dot {
  @apply w-2 h-2 rounded-full;
}

.legend-item span {
  @apply text-xs text-gray-600 dark:text-gray-400;
}

/* 响应式优化 */
@media (max-width: 640px) {
  .calendar-header {
    @apply p-2;
  }

  .month-title {
    @apply text-sm px-2;
  }

  .nav-button {
    @apply w-6 h-6;
  }

  .control-button {
    @apply px-1.5 py-0.5;
  }

  .calendar-container {
    @apply p-1;
  }

  .calendar-cell {
    @apply w-7 h-7;
  }

  .day-number {
    @apply text-xs;
  }

  .weekdays-header {
    @apply mb-0.5;
  }

  .legend {
    @apply gap-2 p-2;
  }

  .legend-item span {
    @apply text-xs;
  }
}


/* 深色模式优化 */
@media (prefers-color-scheme: dark) {
  .calendar-cell.today {
    @apply shadow-sm;
  }

  .calendar-cell.selected {
    @apply shadow-sm;
  }
}

/* 动画效果 */
.calendar-cell:hover {
  @apply transform scale-105;
}

.list-item:hover {
  @apply transform translateX(1px);
}

/* 无障碍访问 */
.calendar-cell:focus,
.list-item:focus {
  @apply outline-none ring-2 ring-blue-500 ring-offset-2;
}

/* 打印样式 */
@media print {
  .calendar-header {
    @apply bg-white border-b border-gray-400;
  }

  .legend {
    @apply bg-white border-t border-gray-400;
  }

  .calendar-cell {
    @apply hover:bg-white;
  }
}
</style>
