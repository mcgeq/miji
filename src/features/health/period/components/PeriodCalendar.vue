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
        <div 
          v-for="day in calendarDays" 
          :key="day.date" 
          class="calendar-cell" 
          :class="getCellClasses(day)"
          @click="selectDate(day.date)"
          @mouseenter="showTooltip($event, day)"
          @mouseleave="hideTooltip"
        >
          <span class="day-number">{{ day.day }}</span>
          <!-- 事件指示器 -->
          <div v-if="day.events.length > 0" class="event-indicators">
            <div v-for="event in day.events.slice(0, 3)" :key="event.type" class="event-dot"
              :class="getEventDotClass(event)" />
            <div v-if="day.events.length > 3" class="event-dot more-events" />
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
        <div class="legend-dot bg-green-500" />
        <span>经期</span>
      </div>
      <div class="legend-item">
        <div class="legend-dot bg-green-500 predicted predicted-period" />
        <span>预测经期</span>
      </div>
      <div class="legend-item">
        <div class="legend-dot bg-red-500" />
        <span>排卵期</span>
      </div>
      <div class="legend-item">
        <div class="legend-dot bg-red-500 predicted predicted-ovulation" />
        <span>预测排卵期</span>
      </div>
      <div class="legend-item">
        <div class="legend-dot bg-orange-500" />
        <span>易孕期</span>
      </div>
      <div class="legend-item">
        <div class="legend-dot bg-orange-500 predicted predicted-fertile" />
        <span>预测易孕期</span>
      </div>
      <div class="legend-item">
        <div class="legend-dot bg-yellow-500" />
        <span>PMS</span>
      </div>
    </div>
  </div>

  <!-- 使用 Teleport 将提示框渲染到 body，避免被父容器遮挡 -->
  <Teleport to="body">
    <div 
      v-if="tooltip.show" 
      class="tooltip" 
      :class="tooltip.position"
      :style="{ 
        left: tooltip.x + 'px', 
        top: tooltip.y + 'px' 
      }"
    >
      <div class="tooltip-content">
        <!-- 日期标题 -->
        <div class="tooltip-header">
          <span class="tooltip-date">{{ tooltip.date }}</span>
          <span v-if="tooltip.isToday" class="tooltip-today-badge">今天</span>
        </div>
        
        <!-- 事件列表 -->
        <div class="tooltip-events">
          <div 
            v-for="event in tooltip.events" 
            :key="event.type" 
            class="tooltip-event-item"
            :class="getTooltipEventClass(event)"
          >
            <div class="tooltip-event-icon" :class="getEventDotClass(event)"></div>
            <div class="tooltip-event-text">
              <span class="tooltip-event-name">{{ getEventLabel(event) }}</span>
              <span v-if="event.intensity" class="tooltip-event-detail">
                强度: {{ getIntensityLabel(event.intensity) }}
              </span>
              <span v-if="getRiskLevel(event)" class="tooltip-risk-level">
                {{ getRiskLevel(event) }}
              </span>
            </div>
          </div>
        </div>

        <!-- 额外信息 -->
        <div v-if="tooltip.extraInfo" class="tooltip-extra-info">
          <div class="tooltip-divider"></div>
          <div class="tooltip-extra-text">
            {{ tooltip.extraInfo }}
          </div>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<script setup lang="ts">
import {ChevronDown, ChevronUp} from 'lucide-vue-next';
import {Teleport} from 'vue';
import {PeriodCalendarEvent} from '@/schema/health/period';
import {usePeriodStore} from '@/stores/periodStore';
import {getCurrentDate, getLocalISODateTimeWithOffset} from '@/utils/date';

interface CalendarDay {
  date: string;
  day: number;
  isCurrentMonth: boolean;
  isToday: boolean;
  events: PeriodCalendarEvent[];
}

interface TooltipData {
  show: boolean;
  x: number;
  y: number;
  date: string;
  isToday: boolean;
  events: PeriodCalendarEvent[];
  extraInfo?: string;
  position: 'top' | 'bottom' | 'left' | 'right';
}

const props = withDefaults(defineProps<{selectedDate?: string}>(), {
  selectedDate: '',
});

const emit = defineEmits<{
  dateSelect: [date: string];
}>();

const periodStore = usePeriodStore();

const currentDate = ref(getCurrentDate());
const viewMode = ref<'calendar' | 'list'>('calendar');
const selectedDate = ref(props.selectedDate || '');

const weekDays = ['日', '一', '二', '三', '四', '五', '六'];

const tooltip = ref<TooltipData>({
  show: false,
  x: 0,
  y: 0,
  date: '',
  isToday: false,
  events: [],
  extraInfo: undefined,
  position: 'top',
});

let tooltipTimer: NodeJS.Timeout | null = null;

const currentMonthYear = computed(() => {
  const year = currentDate.value.getFullYear();
  const month = currentDate.value.getMonth() + 1;
  return `${year}年${month}月`;
});

const calendarDays = computed((): CalendarDay[] => {
  const year = currentDate.value.getFullYear();
  const month = currentDate.value.getMonth();

  const firstDay = new Date(year, month, 1);
  const lastDay = new Date(year, month + 1, 0);

  const startDate = new Date(firstDay);
  startDate.setDate(startDate.getDate() - firstDay.getDay());

  const endDate = new Date(lastDay);
  endDate.setDate(endDate.getDate() + (6 - lastDay.getDay()));

  const days: CalendarDay[] = [];
  const today = getLocalISODateTimeWithOffset().split('T')[0];

  const events = periodStore.getCalendarEvents(
    startDate.toISOString().split('T')[0],
    endDate.toISOString().split('T')[0],
  );

  for (let d = new Date(startDate); d <= endDate; d.setDate(d.getDate() + 1)) {
    let nd = new Date(d);
    nd.setDate(d.getDate() + 1);
    const dateStr = nd.toISOString().split('T')[0];
    const dayEvents = events.filter((event) => event.date === dateStr);

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
  selectedDate.value = getLocalISODateTimeWithOffset().split('T')[0];
  emit('dateSelect', selectedDate.value);
}

function toggleView() {
  viewMode.value = viewMode.value === 'calendar' ? 'list' : 'calendar';
}

function selectDate(date: string) {
  selectedDate.value = date;
  emit('dateSelect', date);
}

function getCellClasses(day: CalendarDay): string[] {
  const classes = [];
  if (!day.isCurrentMonth) classes.push('other-month');
  if (day.isToday) classes.push('today');
  if (selectedDate.value === day.date) classes.push('selected'); // Use internal state
  if (day.events.length > 0) classes.push('has-events');

  const predictedEvents = day.events.filter((e) => e.isPredicted);
  if (predictedEvents.length > 0) {
    classes.push('has-predicted');
    predictedEvents.forEach((event) => {
      switch (event.type) {
        case 'predicted-period':
          classes.push('predicted-period', 'has-predicted-period');
          break;
        case 'predicted-ovulation':
          classes.push('predicted-ovulation', 'has-predicted-ovulation');
          break;
        case 'predicted-fertile':
          classes.push('predicted-fertile', 'has-predicted-fertile');
          break;
      }
    });
  }
  return classes;
}

function getEventDotClass(event: PeriodCalendarEvent): string {
  const predictedClass = event.isPredicted ? 'predicted' : '';
  switch (event.type) {
    case 'period':
      return 'bg-green-500';
    case 'predicted-period':
      return `${predictedClass} predicted-period bg-green-500`;
    case 'ovulation':
      return 'bg-red-500';
    case 'predicted-ovulation':
      return `${predictedClass} predicted-ovulation bg-red-500`;
    case 'fertile':
      return 'bg-orange-500';
    case 'predicted-fertile':
      return `${predictedClass} predicted-fertile bg-orange-500`;
    case 'pms':
      return 'bg-yellow-500';
    default:
      return 'bg-gray-400';
  }
}

function getEventBadgeClass(event: PeriodCalendarEvent): string {
  const predictedClass = event.isPredicted ? 'predicted' : '';
  switch (event.type) {
    case 'period':
      return 'badge-green';
    case 'predicted-period':
      return `badge-green ${predictedClass}`;
    case 'ovulation':
      return 'badge-red';
    case 'predicted-ovulation':
      return `badge-red ${predictedClass}`;
    case 'fertile':
      return 'badge-orange';
    case 'predicted-fertile':
      return `badge-orange ${predictedClass}`;
    case 'pms':
      return 'badge-yellow';
    default:
      return 'badge-gray';
  }
}

function getEventLabel(event: PeriodCalendarEvent): string {
  const predictedPrefix = event.isPredicted ? '预测' : '';
  switch (event.type) {
    case 'period':
      return '经期';
    case 'predicted-period':
      return `${predictedPrefix}经期`;
    case 'ovulation':
      return '排卵期';
    case 'predicted-ovulation':
      return `${predictedPrefix}排卵期`;
    case 'fertile':
      return '易孕期';
    case 'predicted-fertile':
      return `${predictedPrefix}易孕期`;
    case 'pms':
      return 'PMS';
    default:
      return '未知';
  }
}

function showTooltip(event: MouseEvent, day: CalendarDay) {
  if (day.events.length === 0) {
    console.log('[Early Return] No events on this day.');
    return;
  }

  if (tooltipTimer) {
    console.log('[Timer] Clearing existing tooltip timer.');
    clearTimeout(tooltipTimer);
  }

  console.log('[Action] Preparing to show tooltip.');

  const mouseX = event.clientX;
  const mouseY = event.clientY;
  const scrollY = window.scrollY || document.documentElement.scrollTop;
  const scrollX = window.scrollX || document.documentElement.scrollLeft;

  const tooltipWidth = 280;
  const tooltipHeight = 140;
  const offset = 15;

  const viewportWidth = window.innerWidth;
  const viewportHeight = window.innerHeight;

  let x, y;
  let position: 'top' | 'bottom' | 'left' | 'right' = 'bottom';

  const spaceRight = viewportWidth - mouseX;
  const spaceLeft = mouseX;
  const spaceBottom = viewportHeight - mouseY;
  const spaceTop = mouseY;

  if (
    spaceRight >= tooltipWidth + offset &&
    spaceBottom >= tooltipHeight + offset
  ) {
    position = 'bottom';
    x = mouseX + scrollX + offset;
    y = mouseY + scrollY + offset;
  } else if (
    spaceLeft >= tooltipWidth + offset &&
    spaceBottom >= tooltipHeight + offset
  ) {
    position = 'left';
    x = mouseX + scrollX - tooltipWidth - offset;
    y = mouseY + scrollY + offset;
  } else if (
    spaceRight >= tooltipWidth + offset &&
    spaceTop >= tooltipHeight + offset
  ) {
    position = 'top';
    x = mouseX + scrollX + offset;
    y = mouseY + scrollY - tooltipHeight - offset;
  } else if (
    spaceLeft >= tooltipWidth + offset &&
    spaceTop >= tooltipHeight + offset
  ) {
    position = 'left';
    x = mouseX + scrollX - tooltipWidth - offset;
    y = mouseY + scrollY - tooltipHeight - offset;
  } else {
    if (spaceRight >= spaceLeft) {
      position = spaceBottom >= spaceTop ? 'bottom' : 'top';
      x = mouseX + scrollX + offset;
      y =
        spaceBottom >= spaceTop
          ? mouseY + scrollY + offset
          : mouseY + scrollY - tooltipHeight - offset;
    } else {
      position = 'left';
      x = mouseX + scrollX - tooltipWidth - offset;
      y =
        spaceBottom >= spaceTop
          ? mouseY + scrollY + offset
          : mouseY + scrollY - tooltipHeight - offset;
    }
  }

  if (x < scrollX + 10) x = scrollX + 10;
  else if (x + tooltipWidth > scrollX + viewportWidth - 10)
    x = scrollX + viewportWidth - tooltipWidth - 10;

  if (y < scrollY + 10) y = scrollY + 10;
  else if (y + tooltipHeight > scrollY + viewportHeight - 10)
    y = scrollY + viewportHeight - tooltipHeight - 10;

  const date = new Date(day.date);
  const formattedDate = `${date.getMonth() + 1}月${date.getDate()}日 ${weekDays[date.getDay()]}`;
  const extraInfo = generateExtraInfo(day);

  tooltip.value = {
    show: true,
    x,
    y,
    date: formattedDate,
    isToday: day.isToday,
    events: day.events,
    extraInfo,
    position,
  };
}

function hideTooltip() {
  if (tooltipTimer) clearTimeout(tooltipTimer);
  tooltip.value.show = false;
}

function getTooltipEventClass(event: PeriodCalendarEvent): string {
  switch (event.type) {
    case 'period':
    case 'predicted-period':
      return 'tooltip-event-period';
    case 'ovulation':
    case 'predicted-ovulation':
      return 'tooltip-event-ovulation';
    case 'fertile':
    case 'predicted-fertile':
      return 'tooltip-event-fertile';
    case 'pms':
      return 'tooltip-event-pms';
    default:
      return '';
  }
}

function getIntensityLabel(intensity: string): string {
  const labels: Record<string, string> = {
    Light: '轻度',
    Medium: '中度',
    Heavy: '重度',
  };
  return labels[intensity] || intensity;
}

function getRiskLevel(event: PeriodCalendarEvent): string {
  switch (event.type) {
    case 'ovulation':
    case 'predicted-ovulation':
      return '💥 怀孕高风险期';
    case 'fertile':
    case 'predicted-fertile':
      return '! 怀孕风险期';
    case 'period':
    case 'predicted-period':
      return '✅ 相对安全期';
    default:
      return '';
  }
}

function generateExtraInfo(day: CalendarDay): string | undefined {
  const hasOvulation = day.events.some(
    (e) => e.type === 'ovulation' || e.type === 'predicted-ovulation',
  );
  const hasFertile = day.events.some(
    (e) => e.type === 'fertile' || e.type === 'predicted-fertile',
  );
  const hasPeriod = day.events.some(
    (e) => e.type === 'period' || e.type === 'predicted-period',
  );

  if (hasOvulation) return '建议: 避孕用户需特别注意，备孕用户的最佳时机';
  else if (hasFertile) return '建议: 仍有怀孕可能，请注意避孕措施';
  else if (hasPeriod) return '建议: 注意休息，保持温暖，适量运动';
  return undefined;
}

function formatDateShort(date: string): string {
  const d = new Date(date);
  return `${d.getMonth() + 1}/${d.getDate()}`;
}

function formatDateFull(date: string): string {
  const d = new Date(date);
  return `${d.getMonth() + 1}月${d.getDate()}日 ${weekDays[d.getDay()]}`;
}

watch(
  () => props.selectedDate,
  (newSelectedDate) => {
    selectedDate.value = newSelectedDate;
  },
);

onBeforeUnmount(() => {
  if (tooltipTimer) clearTimeout(tooltipTimer);
});

onMounted(() => {
  periodStore.initialize();
});
</script>

<style scoped lang="postcss">
/* Base Styles */
.period-calendar {
  @apply bg-white dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-700 overflow-hidden relative;
}

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

.calendar-cell.has-predicted::before {
  content: '';
  @apply absolute inset-0 border-2 border-dashed rounded-md pointer-events-none;
}

.calendar-cell.has-predicted-period::before {
  @apply border-green-300 dark:border-green-600;
}

.calendar-cell.has-predicted-ovulation::before {
  @apply border-red-300 dark:border-red-600;
}

.calendar-cell.has-predicted-fertile::before {
  @apply border-orange-300 dark:border-orange-600;
}

.calendar-cell.predicted-period {
  @apply bg-green-50 dark:bg-green-950 text-green-700 dark:text-green-400;
}

.calendar-cell.predicted-ovulation {
  @apply bg-red-50 dark:bg-red-950 text-red-700 dark:text-red-400;
}

.calendar-cell.predicted-fertile {
  @apply bg-orange-50 dark:bg-orange-950 text-orange-700 dark:text-orange-400;
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

.event-dot.predicted {
  @apply border-2 border-white dark:border-gray-800;
  background: repeating-linear-gradient(45deg, transparent, transparent 1px, currentColor 1px, currentColor 2px);
}

.event-dot.predicted-period {
  @apply text-green-500;
}

.event-dot.predicted-ovulation {
  @apply text-red-500;
}

.event-dot.predicted-fertile {
  @apply text-orange-500;
}

.more-events {
  @apply bg-gray-400 w-1 h-1 rounded-full;
}

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

.badge-green {
  @apply bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400;
}

.badge-orange {
  @apply bg-orange-100 text-orange-700 dark:bg-orange-900/30 dark:text-orange-400;
}

.badge-red {
  @apply bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400;
}

.badge-yellow {
  @apply bg-yellow-100 text-yellow-700 dark:bg-yellow-900/30 dark:text-yellow-400;
}

.badge-gray {
  @apply bg-gray-100 text-gray-700 dark:bg-gray-900/30 dark:text-gray-400;
}

.event-badge.predicted {
  @apply border border-dashed;
}

.event-badge.predicted::before {
  content: '预测 ';
  @apply text-xs opacity-75;
}

.empty-state {
  @apply flex flex-col items-center justify-center py-8 text-gray-500;
}

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

/* Tooltip Styles */
.tooltip {
  @apply fixed pointer-events-none z-[9999] isolation-isolate;
  animation: tooltipFadeIn 0.2s ease-out;
}

@keyframes tooltipFadeIn {
  from { opacity: 0; }
  to { opacity: 1; }
}

.tooltip.top {
  transform: translateX(-50%) translateY(-100%);
}

.tooltip.bottom {
  transform: translateX(-50%) translateY(0%);
}

.tooltip.left {
  transform: translateX(-100%) translateY(-50%);
}

.tooltip.right {
  transform: translateX(0%) translateY(-50%);
}

.tooltip-content {
  @apply bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg p-4 min-w-[250px] max-w-[320px];
  box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25), 0 0 0 1px rgba(0, 0, 0, 0.05);
  position: relative;
  z-index: 1;
  background-color: white;
}

.tooltip.top .tooltip-content::after {
  content: '';
  position: absolute;
  top: 100%;
  left: 50%;
  transform: translateX(-50%);
  border-left: 8px solid transparent;
  border-right: 8px solid transparent;
  border-top: 8px solid white;
}

.dark .tooltip.top .tooltip-content::after {
  border-top-color: rgb(31 41 55);
}

.tooltip.bottom .tooltip-content::after {
  content: '';
  position: absolute;
  bottom: 100%;
  left: 50%;
  transform: translateX(-50%);
  border-left: 8px solid transparent;
  border-right: 8px solid transparent;
  border-bottom: 8px solid white;
}

.dark .tooltip.bottom .tooltip-content::after {
  border-bottom-color: rgb(31 41 55);
}

.tooltip.left .tooltip-content::after {
  content: '';
  position: absolute;
  left: 100%;
  top: 50%;
  transform: translateY(-50%);
  border-top: 8px solid transparent;
  border-bottom: 8px solid transparent;
  border-left: 8px solid white;
}

.dark .tooltip.left .tooltip-content::after {
  border-left-color: rgb(31 41 55);
}

.tooltip.right .tooltip-content::after {
  content: '';
  position: absolute;
  right: 100%;
  top: 50%;
  transform: translateY(-50%);
  border-top: 8px solid transparent;
  border-bottom: 8px solid transparent;
  border-right: 8px solid white;
}

.dark .tooltip.right .tooltip-content::after {
  border-right-color: rgb(31 41 55);
}

.dark .tooltip-content {
  box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.5), 0 0 0 1px rgba(255, 255, 255, 0.1);
  background-color: rgb(31 41 55);
}

.tooltip-header {
  @apply flex items-center justify-center mb-2;
}

.tooltip-date {
  @apply text-sm font-semibold;
  color: inherit;
}

.tooltip-today-badge {
  @apply px-2 py-0.5 bg-blue-100 text-blue-700 text-xs rounded-full;
}

.dark .tooltip-today-badge {
  @apply bg-blue-900 text-blue-300;
}

.tooltip-events {
  @apply space-y-2 text-center;
}

.tooltip-event-item {
  @apply flex items-start gap-2 justify-center;
}

.tooltip-event-icon {
  @apply w-3 h-3 rounded-full flex-shrink-0 mt-0.5;
}

.tooltip-event-text {
  @apply flex-1 text-left max-w-[200px]; /* 添加最大宽度限制 */
}

.tooltip-event-name {
  @apply block text-sm font-medium;
  color: inherit;
}

.tooltip-event-detail {
  @apply block text-xs opacity-75;
  color: inherit;
}

.tooltip-risk-level {
  @apply block text-xs font-medium mt-1;
}

.tooltip-event-period .tooltip-risk-level {
  color: rgb(34 197 94);
}

.tooltip-event-ovulation .tooltip-risk-level {
  color: rgb(239 68 68);
}

.tooltip-event-fertile .tooltip-risk-level {
  color: rgb(249 115 22);
}

.tooltip-event-pms .tooltip-risk-level {
  color: rgb(234 179 8);
}

.tooltip-extra-info {
  @apply mt-2 text-left;
}

.tooltip-divider {
  @apply border-t border-gray-200 mb-2;
}

.dark .tooltip-divider {
  @apply border-gray-600;
}

.tooltip-extra-text {
  @apply text-xs leading-relaxed opacity-75;
  color: inherit;
}

/* Media Queries */
@media (max-width: 640px) {
  .calendar-header { @apply p-2; }
  .month-title { @apply text-sm px-2; }
  .nav-button { @apply w-6 h-6; }
  .control-button { @apply px-1.5 py-0.5; }
  .calendar-container { @apply p-1; }
  .calendar-cell { @apply w-7 h-7; }
  .day-number { @apply text-xs; }
  .weekdays-header { @apply mb-0.5; }
  .calendar-cell.has-predicted::before { @apply border-1; }
  .legend { @apply gap-2 p-2 flex-wrap; }
  .legend-item { @apply text-xs; }
  .legend-item span { @apply text-xs; }
  .tooltip-content { @apply min-w-[180px] max-w-[250px] text-xs; }
  .tooltip-event-name { @apply text-xs; }
  .tooltip-risk-level { @apply text-xs; }
}

@media (prefers-color-scheme: dark) {
  .calendar-cell.today { @apply shadow-sm; }
  .calendar-cell.selected { @apply shadow-sm; }
  .tooltip-content { @apply shadow-2xl; }
}

.calendar-cell:hover { @apply transform scale-105; }
.list-item:hover { @apply transform translateX(1px); }

.calendar-cell:focus, .list-item:focus {
  @apply outline-none ring-2 ring-blue-500 ring-offset-2;
}

@media (prefers-contrast: high) {
  .tooltip-content { @apply border-2 border-gray-900 dark:border-white; }
  .event-dot { @apply border border-gray-900 dark:border-white; }
}

@media print {
  .calendar-header { @apply bg-white border-b border-gray-400; }
  .legend { @apply bg-white border-t border-gray-400; }
  .calendar-cell { @apply hover:bg-white; }
  .tooltip { @apply hidden; }
}
</style>
