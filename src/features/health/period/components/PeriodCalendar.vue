<script setup lang="ts">
import { ChevronDown, ChevronUp } from 'lucide-vue-next';
import { storeToRefs } from 'pinia';
import { usePeriodStore } from '@/stores/periodStore';
import { DateUtils } from '@/utils/date';
import type { PeriodCalendarEvent } from '@/schema/health/period';

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

const props = withDefaults(defineProps<{ selectedDate?: string }>(), {
  selectedDate: '',
});

const emit = defineEmits<{
  dateSelect: [date: string];
}>();

const periodStore = usePeriodStore();
const { periodRecords, periodDailyRecords } = storeToRefs(periodStore);

const currentDate = ref(DateUtils.getCurrentDate());
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

const tooltipTimer: NodeJS.Timeout | null = null;

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
  const today = DateUtils.getTodayDate();

  // 使用 storeToRefs 的响应式引用来确保依赖追踪
  // 访问 .value 以触发响应式更新
  void (periodRecords.value.length + periodDailyRecords.value.length);

  const events = periodStore.getCalendarEvents(
    startDate.toISOString().split('T')[0],
    endDate.toISOString().split('T')[0],
  );

  // 计算总天数
  const totalDays = Math.floor((endDate.getTime() - startDate.getTime()) / (1000 * 60 * 60 * 24)) + 1;

  for (let i = 0; i < totalDays; i++) {
    const d = new Date(startDate);
    d.setDate(startDate.getDate() + i);

    const nd = new Date(d);
    nd.setDate(d.getDate() + 1);
    const dateStr = nd.toISOString().split('T')[0];
    const dayEvents = events.filter(event => event.date === dateStr);

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
  if (viewMode.value === 'list') {
    viewMode.value = 'calendar';
  }
  currentDate.value = new Date();
  selectedDate.value = DateUtils.getTodayDate();
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

  const predictedEvents = day.events.filter(e => e.isPredicted);
  if (predictedEvents.length > 0) {
    classes.push('has-predicted');
    predictedEvents.forEach(event => {
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
    return;
  }

  if (tooltipTimer) {
    clearTimeout(tooltipTimer);
  }

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
    e => e.type === 'ovulation' || e.type === 'predicted-ovulation',
  );
  const hasFertile = day.events.some(
    e => e.type === 'fertile' || e.type === 'predicted-fertile',
  );
  const hasPeriod = day.events.some(
    e => e.type === 'period' || e.type === 'predicted-period',
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
  newSelectedDate => {
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

<template>
  <div class="period-calendar">
    <!-- 头部导航 -->
    <div class="calendar-header">
      <div class="month-navigation">
        <button class="nav-button" aria-label="上个月" @click="goToPreviousMonth">
          <ChevronUp class="wh-5" />
        </button>
        <h2 class="month-title">
          {{ currentMonthYear }}
        </h2>
        <button class="nav-button" aria-label="下个月" @click="goToNextMonth">
          <ChevronDown class="wh-5" />
        </button>
      </div>

      <div class="view-controls">
        <button class="control-button" @click="goToToday">
          今天
        </button>
        <button class="control-button" @click="toggleView">
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
            <div
              v-for="event in day.events.slice(0, 3)" :key="event.type" class="event-dot"
              :class="getEventDotClass(event)"
            />
            <div v-if="day.events.length > 3" class="event-dot more-events" />
          </div>
        </div>
      </div>
    </div>

    <!-- 列表视图 -->
    <div v-else class="list-container">
      <div
        v-for="day in calendarDays.filter(d => d.events.length > 0)" :key="day.date" class="list-item"
        @click="selectDate(day.date)"
      >
        <div class="list-item-content">
          <div class="date-info">
            <div class="date-primary">
              {{ formatDateShort(day.date) }}
            </div>
            <div class="date-secondary">
              {{ formatDateFull(day.date) }}
            </div>
          </div>
          <div class="event-badges">
            <div v-for="event in day.events" :key="event.type" class="event-badge" :class="getEventBadgeClass(event)">
              {{ getEventLabel(event) }}
            </div>
          </div>
        </div>
      </div>

      <div v-if="calendarDays.filter(d => d.events.length > 0).length === 0" class="empty-state">
        <i class="i-tabler-calendar-x text-gray-400 wh-8" />
        <p class="text-sm text-gray-500 mt-2">
          本月暂无记录
        </p>
      </div>
    </div>

    <!-- 图例 -->
    <div class="legend">
      <div class="legend-item">
        <div class="legend-dot bg-green-500" />
        <span>经期</span>
      </div>
      <div class="legend-item">
        <div class="legend-dot predicted predicted-period bg-green-500" />
        <span>预测经期</span>
      </div>
      <div class="legend-item">
        <div class="legend-dot bg-red-500" />
        <span>排卵期</span>
      </div>
      <div class="legend-item">
        <div class="legend-dot predicted predicted-ovulation bg-red-500" />
        <span>预测排卵期</span>
      </div>
      <div class="legend-item">
        <div class="legend-dot bg-orange-500" />
        <span>易孕期</span>
      </div>
      <div class="legend-item">
        <div class="legend-dot predicted predicted-fertile bg-orange-500" />
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
        left: `${tooltip.x}px`,
        top: `${tooltip.y}px`,
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
            <div class="tooltip-event-icon" :class="getEventDotClass(event)" />
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
          <div class="tooltip-divider" />
          <div class="tooltip-extra-text">
            {{ tooltip.extraInfo }}
          </div>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<style scoped lang="postcss">
/* Base Styles */
.period-calendar {
  background-color: white;
  border-radius: 0.5rem;
  border: 1px solid #e5e7eb;
  overflow: hidden;
  position: relative;
}

.dark .period-calendar {
  background-color: #1f2937;
  border-color: #374151;
}

.calendar-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0.75rem;
  background-color: var(--color-base-200);
  border-bottom: 1px solid var(--color-base-300);
}

.dark .calendar-header {
  background-color: #111827;
  border-bottom-color: var(--color-base-300);
}

.month-navigation {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.nav-button {
  width: 1.75rem;
  height: 1.75rem;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 0.375rem;
  color: #6b7280;
  transition: all 0.2s ease-in-out;
}

.nav-button:hover {
  color: #374151;
  background-color: #e5e7eb;
}

.dark .nav-button {
  color: #9ca3af;
}

.dark .nav-button:hover {
  color: #e5e7eb;
  background-color: #374151;
}

.month-title {
  font-size: 1rem;
  font-weight: 600;
  color: #111827;
  padding: 0 0.75rem;
}

.dark .month-title {
  color: white;
}

.view-controls {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.control-button {
  padding: 0.25rem 0.5rem;
  font-size: 0.75rem;
  font-weight: 500;
  border-radius: 0.375rem;
  border: 1px solid var(--color-base-300);
  background-color: var(--color-base-200);
  color: var(--color-base-content);
  transition: all 0.2s ease-in-out;
  display: flex;
  align-items: center;
}

.control-button:hover {
  background-color: #f9fafb;
}

.dark .control-button {
  border-color: #4b5563;
  background-color: #374151;
  color: #d1d5db;
}

.dark .control-button:hover {
  background-color: #4b5563;
}

.calendar-container {
background-color: var(--color-base-200);
  padding: 0.5rem;
}

.weekdays-header {
  display: grid;
  grid-template-columns: repeat(7, 1fr);
  margin-bottom: 0.25rem;
}

.weekday-label {
  text-align: center;
  font-size: 0.75rem;
  font-weight: 500;
  color: #6b7280;
  padding: 0.25rem 0;
}

.dark .weekday-label {
  color: #9ca3af;
}

.calendar-grid {
  display: grid;
  grid-template-columns: repeat(7, 1fr);
}

.calendar-cell {
  position: relative;
  width: 2rem;
  height: 2rem;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  transition: all 0.15s ease-in-out;
}

.calendar-cell:hover {
  background-color: #f3f4f6;
}

.dark .calendar-cell:hover {
  background-color: #374151;
}

.calendar-cell.other-month {
  color: #9ca3af;
}

.dark .calendar-cell.other-month {
  color: #4b5563;
}

.calendar-cell.today {
  background-color: #dbeafe;
  color: #2563eb;
  font-weight: 600;
  border-radius: 0.375rem;
}

.dark .calendar-cell.today {
  background-color: #1e3a8a;
  color: #60a5fa;
}

.calendar-cell.selected {
  outline: 1px solid #3b82f6;
  background-color: #eff6ff;
  border-radius: 0.375rem;
}

.dark .calendar-cell.selected {
  background-color: rgba(30, 58, 138, 0.5);
}

.calendar-cell.has-events {
  font-weight: 500;
}

.calendar-cell.has-predicted::before {
  content: '';
  position: absolute;
  inset: 0;
  border: 2px dashed;
  border-radius: 0.375rem;
  pointer-events: none;
}

.calendar-cell.has-predicted-period::before {
  border-color: #86efac;
}

.dark .calendar-cell.has-predicted-period::before {
  border-color: #16a34a;
}

.calendar-cell.has-predicted-ovulation::before {
  border-color: #fca5a5;
}

.dark .calendar-cell.has-predicted-ovulation::before {
  border-color: #dc2626;
}

.calendar-cell.has-predicted-fertile::before {
  border-color: #fdba74;
}

.dark .calendar-cell.has-predicted-fertile::before {
  border-color: #ea580c;
}

.calendar-cell.predicted-period {
  background-color: #f0fdf4;
  color: #15803d;
}

.dark .calendar-cell.predicted-period {
  background-color: #052e16;
  color: #4ade80;
}

.calendar-cell.predicted-ovulation {
  background-color: #fef2f2;
  color: #dc2626;
}

.dark .calendar-cell.predicted-ovulation {
  background-color: #450a0a;
  color: #f87171;
}

.calendar-cell.predicted-fertile {
  background-color: #fff7ed;
  color: #ea580c;
}

.dark .calendar-cell.predicted-fertile {
  background-color: #431407;
  color: #fb923c;
}

.day-number {
  font-size: 0.875rem;
  line-height: 1;
}

.event-indicators {
  position: absolute;
  bottom: 0;
  left: 50%;
  transform: translateX(-50%);
  display: flex;
  gap: 0.125rem;
}

.event-dot {
  width: 0.25rem;
  height: 0.25rem;
  border-radius: 50%;
}

.event-dot.predicted {
  border: 2px solid white;
  background: repeating-linear-gradient(45deg, transparent, transparent 1px, currentColor 1px, currentColor 2px);
}

.dark .event-dot.predicted {
  border-color: #1f2937;
}

.event-dot.predicted-period {
  color: #22c55e;
}

.event-dot.predicted-ovulation {
  color: #ef4444;
}

.event-dot.predicted-fertile {
  color: #f97316;
}

.more-events {
  background-color: #9ca3af;
  width: 0.25rem;
  height: 0.25rem;
  border-radius: 50%;
}

.list-container {
  padding: 0.75rem;
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  max-height: 12.75rem;
  overflow-y: auto;
  background-color: var(--color-base-100);
  border-radius: 0.5rem;
  /* 隐藏滚动条但保留功能 */
  scrollbar-width: none; /* Firefox */
  -ms-overflow-style: none; /* IE/Edge */
}

/* Webkit浏览器（Chrome, Safari）隐藏滚动条 */
.list-container::-webkit-scrollbar {
  width: 0px;
  background: transparent;
}

.dark .list-container {
  background-color: var(--color-base-200);
}

.list-item {
  padding: 0.75rem;
  border-radius: 0.5rem;
  border: 1px solid var(--color-base-300);
  border-left-width: 4px;
  border-left-color: var(--color-primary);
  background-color: var(--color-base-200);
  cursor: pointer;
  transition: all 0.2s ease-in-out;
  box-shadow: 0 1px 3px 0 rgba(0, 0, 0, 0.1);
}

.list-item:hover {
  background-color: var(--color-base-300);
  border-left-color: var(--color-error);
  transform: translateX(2px);
  box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
}

.dark .list-item {
  background-color: var(--color-base-300);
  border-color: var(--color-base-300);
  border-left-color: var(--color-primary);
}

.dark .list-item:hover {
  background-color: var(--color-base-content);
  border-left-color: var(--color-error);
}

.list-item-content {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.date-info {
  display: flex;
  flex-direction: column;
}

.date-primary {
  font-size: 1rem;
  font-weight: 600;
  color: var(--color-base-content);
  margin-bottom: 0.125rem;
}

.dark .date-primary {
  color: var(--color-base-content);
}

.date-secondary {
  font-size: 0.75rem;
  color: var(--color-neutral);
  font-weight: 500;
}

.dark .date-secondary {
  color: var(--color-neutral);
}

.event-badges {
  display: flex;
  gap: 0.25rem;
  flex-wrap: wrap;
}

.event-badge {
  padding: 0.25rem 0.5rem;
  border-radius: 0.375rem;
  font-size: 0.75rem;
  font-weight: 600;
  box-shadow: 0 1px 2px 0 rgba(0, 0, 0, 0.05);
  transition: all 0.15s ease-in-out;
}

.event-badge:hover {
  transform: scale(1.05);
}

.badge-green {
  background-color: #dcfce7;
  color: #15803d;
}

.dark .badge-green {
  background-color: rgba(5, 46, 22, 0.3);
  color: #4ade80;
}

.badge-orange {
  background-color: #fed7aa;
  color: #ea580c;
}

.dark .badge-orange {
  background-color: rgba(67, 20, 7, 0.3);
  color: #fb923c;
}

.badge-red {
  background-color: #fee2e2;
  color: #dc2626;
}

.dark .badge-red {
  background-color: rgba(69, 10, 10, 0.3);
  color: #f87171;
}

.badge-yellow {
  background-color: #fef3c7;
  color: #d97706;
}

.dark .badge-yellow {
  background-color: rgba(69, 26, 3, 0.3);
  color: #fbbf24;
}

.badge-gray {
  background-color: #f3f4f6;
  color: #374151;
}

.dark .badge-gray {
  background-color: rgba(17, 24, 39, 0.3);
  color: #9ca3af;
}

.event-badge.predicted {
  border: 1px dashed;
}

.event-badge.predicted::before {
  content: '预测 ';
  font-size: 0.75rem;
  opacity: 0.75;
}

.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 2rem 0;
  color: #6b7280;
}

.legend {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 1rem;
  padding: 0.75rem;
  background-color: var(--color-base-200);
  border-top: 1px solid var(--color-base-300);
}

.dark .legend {
  background-color: #111827;
  border-top-color: #374151;
}

.legend-item {
  display: flex;
  align-items: center;
  gap: 0.375rem;
}

.legend-dot {
  width: 0.5rem;
  height: 0.5rem;
  border-radius: 50%;
}

.legend-item span {
  font-size: 0.75rem;
  color: #4b5563;
}

.dark .legend-item span {
  color: #9ca3af;
}

/* Tooltip Styles */
.tooltip {
  position: fixed;
  pointer-events: none;
  z-index: 9999;
  isolation: isolate;
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
  background-color: white;
  border: 1px solid #e5e7eb;
  border-radius: 0.5rem;
  padding: 1rem;
  min-width: 250px;
  max-width: 320px;
  box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25), 0 0 0 1px rgba(0, 0, 0, 0.05);
  position: relative;
  z-index: 1;
}

.dark .tooltip-content {
  background-color: #1f2937;
  border-color: #374151;
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
  border-top-color: #1f2937;
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
  border-bottom-color: #1f2937;
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
  border-left-color: #1f2937;
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
  border-right-color: #1f2937;
}

.dark .tooltip-content {
  box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.5), 0 0 0 1px rgba(255, 255, 255, 0.1);
  background-color: #1f2937;
}

.tooltip-header {
  display: flex;
  align-items: center;
  justify-content: center;
  margin-bottom: 0.5rem;
}

.tooltip-date {
  font-size: 0.875rem;
  font-weight: 600;
  color: inherit;
}

.tooltip-today-badge {
  padding: 0.125rem 0.5rem;
  background-color: #dbeafe;
  color: #1d4ed8;
  font-size: 0.75rem;
  border-radius: 9999px;
}

.dark .tooltip-today-badge {
  background-color: #1e3a8a;
  color: #93c5fd;
}

.tooltip-events {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  text-align: center;
}

.tooltip-event-item {
  display: flex;
  align-items: flex-start;
  gap: 0.5rem;
  justify-content: center;
}

.tooltip-event-icon {
  width: 0.75rem;
  height: 0.75rem;
  border-radius: 50%;
  flex-shrink: 0;
  margin-top: 0.125rem;
}

.tooltip-event-text {
  flex: 1;
  text-align: left;
  max-width: 200px;
}

.tooltip-event-name {
  display: block;
  font-size: 0.875rem;
  font-weight: 500;
  color: inherit;
}

.tooltip-event-detail {
  display: block;
  font-size: 0.75rem;
  opacity: 0.75;
  color: inherit;
}

.tooltip-risk-level {
  display: block;
  font-size: 0.75rem;
  font-weight: 500;
  margin-top: 0.25rem;
}

.tooltip-event-period .tooltip-risk-level {
  color: #22c55e;
}

.tooltip-event-ovulation .tooltip-risk-level {
  color: #ef4444;
}

.tooltip-event-fertile .tooltip-risk-level {
  color: #f97316;
}

.tooltip-event-pms .tooltip-risk-level {
  color: #eab308;
}

.tooltip-extra-info {
  margin-top: 0.5rem;
  text-align: left;
}

.tooltip-divider {
  border-top: 1px solid #e5e7eb;
  margin-bottom: 0.5rem;
}

.dark .tooltip-divider {
  border-color: #4b5563;
}

.tooltip-extra-text {
  font-size: 0.75rem;
  line-height: 1.625;
  opacity: 0.75;
  color: inherit;
}

/* Media Queries */
@media (max-width: 640px) {
  .calendar-header {
    padding: 0.5rem;
  }
  .month-title {
    font-size: 0.875rem;
    padding: 0 0.5rem;
  }
  .nav-button {
    width: 1.5rem;
    height: 1.5rem;
  }
  .control-button {
    padding: 0.375rem 0.5rem;
  }
  .calendar-container {
    padding: 0.25rem;
  }
  .calendar-cell {
    width: 1.75rem;
    height: 1.75rem;
  }
  .day-number {
    font-size: 0.75rem;
  }
  .weekdays-header {
    margin-bottom: 0.125rem;
  }
  .calendar-cell.has-predicted::before {
    border-width: 1px;
  }
  .legend {
    gap: 0.5rem;
    padding: 0.5rem;
    flex-wrap: wrap;
  }
  .legend-item {
    font-size: 0.75rem;
  }
  .legend-item span {
    font-size: 0.75rem;
  }
  .tooltip-content {
    min-width: 180px;
    max-width: 250px;
    font-size: 0.75rem;
  }
  .tooltip-event-name {
    font-size: 0.75rem;
  }
  .tooltip-risk-level {
    font-size: 0.75rem;
  }
}

@media (prefers-color-scheme: dark) {
  .calendar-cell.today {
    box-shadow: 0 1px 2px 0 rgba(0, 0, 0, 0.05);
  }
  .calendar-cell.selected {
    box-shadow: 0 1px 2px 0 rgba(0, 0, 0, 0.05);
  }
  .tooltip-content {
    box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
  }
}

.calendar-cell:hover {
  transform: scale(1.05);
}
.list-item:hover {
  transform: translateX(1px);
}

.calendar-cell:focus, .list-item:focus {
  outline: none;
  box-shadow: 0 0 0 2px #3b82f6, 0 0 0 4px rgba(59, 130, 246, 0.1);
}

@media (prefers-contrast: high) {
  .tooltip-content {
    border: 2px solid #111827;
  }
  .dark .tooltip-content {
    border-color: white;
  }
  .event-dot {
    border: 1px solid #111827;
  }
  .dark .event-dot {
    border-color: white;
  }
}

@media print {
  .calendar-header {
    background-color: white;
    border-bottom: 1px solid #9ca3af;
  }
  .legend {
    background-color: white;
    border-top: 1px solid #9ca3af;
  }
  .calendar-cell:hover {
    background-color: white;
  }
  .tooltip {
    display: none;
  }
}
</style>
