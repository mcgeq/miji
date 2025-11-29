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

  // 使用 storeToRefs 的响应式引用来确保依赖追�?
  // 访问 .value 以触发响应式更新
  void (periodRecords.value.length + periodDailyRecords.value.length);

  const events = periodStore.getCalendarEvents(
    startDate.toISOString().split('T')[0],
    endDate.toISOString().split('T')[0],
  );

  // 计算总天�?
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

function getCellClasses(day: CalendarDay): string {
  const baseClasses = [
    'relative w-8 h-8 flex flex-col items-center justify-center cursor-pointer transition-all duration-150 rounded-md',
    'hover:bg-gray-100 dark:hover:bg-gray-700',
    'hover:scale-105',
    'focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2',
  ];

  if (!day.isCurrentMonth) {
    baseClasses.push('text-gray-400 dark:text-gray-600');
  }

  if (day.isToday) {
    baseClasses.push('bg-blue-100 dark:bg-blue-900 text-blue-600 dark:text-blue-400 font-semibold rounded-md');
  }

  if (selectedDate.value === day.date) {
    baseClasses.push('ring-1 ring-blue-500 bg-blue-50 dark:bg-blue-900/50 rounded-md');
  }

  if (day.events.length > 0) {
    baseClasses.push('font-medium');
  }

  const hasPredictedPeriod = day.events.some(e => e.type === 'predicted-period');
  const hasPredictedOvulation = day.events.some(e => e.type === 'predicted-ovulation');
  const hasPredictedFertile = day.events.some(e => e.type === 'predicted-fertile');

  const hasPredicted = hasPredictedPeriod || hasPredictedOvulation || hasPredictedFertile;

  if (hasPredicted) {
    baseClasses.push("before:content-[''] before:absolute before:inset-0 before:border-2 before:border-dashed before:rounded-md before:pointer-events-none");

    if (hasPredictedPeriod) {
      baseClasses.push('before:border-green-300 dark:before:border-green-600 bg-green-50 dark:bg-green-950 text-green-700 dark:text-green-400');
    }
    if (hasPredictedOvulation) {
      baseClasses.push('before:border-red-300 dark:before:border-red-600 bg-red-50 dark:bg-red-950 text-red-700 dark:text-red-400');
    }
    if (hasPredictedFertile) {
      baseClasses.push('before:border-orange-300 dark:before:border-orange-600 bg-orange-50 dark:bg-orange-950 text-orange-700 dark:text-orange-400');
    }
  }

  return baseClasses.join(' ');
}

function getEventDotClass(event: PeriodCalendarEvent): string {
  const baseClasses = ['w-1 h-1 rounded-full'];

  if (event.isPredicted) {
    baseClasses.push('border-2 border-white dark:border-gray-800 bg-[repeating-linear-gradient(45deg,transparent,transparent_1px,currentColor_1px,currentColor_2px)]');
  }

  switch (event.type) {
    case 'period':
      baseClasses.push('bg-green-500');
      break;
    case 'predicted-period':
      baseClasses.push('text-green-500');
      break;
    case 'ovulation':
      baseClasses.push('bg-red-500');
      break;
    case 'predicted-ovulation':
      baseClasses.push('text-red-500');
      break;
    case 'fertile':
      baseClasses.push('bg-orange-500');
      break;
    case 'predicted-fertile':
      baseClasses.push('text-orange-500');
      break;
    case 'pms':
      baseClasses.push('bg-yellow-500');
      break;
    default:
      baseClasses.push('bg-gray-400');
  }

  return baseClasses.join(' ');
}

function getEventBadgeClass(event: PeriodCalendarEvent): string {
  const baseClasses = ['py-1 px-2 rounded-md text-xs font-semibold shadow-sm transition-all duration-150 hover:scale-105'];

  if (event.isPredicted) {
    baseClasses.push('border border-dashed');
  }

  switch (event.type) {
    case 'period':
    case 'predicted-period':
      baseClasses.push('bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-400');
      break;
    case 'ovulation':
    case 'predicted-ovulation':
      baseClasses.push('bg-red-100 dark:bg-red-900/30 text-red-700 dark:text-red-400');
      break;
    case 'fertile':
    case 'predicted-fertile':
      baseClasses.push('bg-orange-100 dark:bg-orange-900/30 text-orange-700 dark:text-orange-400');
      break;
    case 'pms':
      baseClasses.push('bg-yellow-100 dark:bg-yellow-900/30 text-yellow-700 dark:text-yellow-400');
      break;
    default:
      baseClasses.push('bg-gray-100 dark:bg-gray-900/30 text-gray-700 dark:text-gray-400');
  }

  return baseClasses.join(' ');
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

function getTooltipRiskClass(event: PeriodCalendarEvent): string {
  switch (event.type) {
    case 'period':
    case 'predicted-period':
      return 'text-green-500';
    case 'ovulation':
    case 'predicted-ovulation':
      return 'text-red-500';
    case 'fertile':
    case 'predicted-fertile':
      return 'text-orange-500';
    case 'pms':
      return 'text-yellow-500';
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
  <div class="h-full flex flex-col bg-white dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-700 overflow-hidden">
    <!-- 头部导航 -->
    <div class="flex items-center justify-between px-3 py-2 bg-gray-50 dark:bg-gray-900 border-b border-gray-200 dark:border-gray-700">
      <div class="flex items-center gap-2">
        <button
          class="w-7 h-7 flex items-center justify-center rounded-md text-gray-500 dark:text-gray-400 transition-all duration-200 hover:text-gray-700 hover:bg-gray-200 dark:hover:text-gray-200 dark:hover:bg-gray-700"
          aria-label="上个月"
          @click="goToPreviousMonth"
        >
          <ChevronUp class="wh-5" />
        </button>
        <h2 class="text-base font-semibold text-gray-900 dark:text-white px-3">
          {{ currentMonthYear }}
        </h2>
        <button
          class="w-7 h-7 flex items-center justify-center rounded-md text-gray-500 dark:text-gray-400 transition-all duration-200 hover:text-gray-700 hover:bg-gray-200 dark:hover:text-gray-200 dark:hover:bg-gray-700"
          aria-label="下个月"
          @click="goToNextMonth"
        >
          <ChevronDown class="wh-5" />
        </button>
      </div>

      <div class="flex items-center gap-2">
        <button
          class="py-1 px-2 text-xs font-medium rounded-md border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-700 dark:text-gray-300 transition-all duration-200 hover:bg-gray-100 dark:hover:bg-gray-600 flex items-center"
          @click="goToToday"
        >
          今天
        </button>
        <button
          class="py-1 px-2 text-xs font-medium rounded-md border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-700 dark:text-gray-300 transition-all duration-200 hover:bg-gray-100 dark:hover:bg-gray-600 flex items-center"
          @click="toggleView"
        >
          <i :class="viewMode === 'calendar' ? 'i-tabler-list' : 'i-tabler-calendar'" class="wh-3 mr-1" />
          {{ viewMode === 'calendar' ? '列表' : '日历' }}
        </button>
      </div>
    </div>

    <!-- 日历视图 -->
    <div v-if="viewMode === 'calendar'" class="flex-1 flex flex-col min-h-0 bg-gray-50 dark:bg-gray-900 p-2">
      <!-- 星期标题 -->
      <div class="grid grid-cols-7 mb-1">
        <div v-for="day in weekDays" :key="day" class="text-center text-xs font-medium text-gray-500 dark:text-gray-400 py-1">
          {{ day }}
        </div>
      </div>

      <!-- 日期网格 -->
      <div class="grid grid-cols-7">
        <div
          v-for="day in calendarDays"
          :key="day.date"
          :class="getCellClasses(day)"
          @click="selectDate(day.date)"
          @mouseenter="showTooltip($event, day)"
          @mouseleave="hideTooltip"
        >
          <span class="text-sm leading-none">{{ day.day }}</span>
          <!-- 事件指示器 -->
          <div v-if="day.events.length > 0" class="absolute bottom-0 left-1/2 -translate-x-1/2 flex gap-0.5">
            <div
              v-for="event in day.events.slice(0, 3)" :key="event.type"
              :class="getEventDotClass(event)"
            />
            <div v-if="day.events.length > 3" class="w-1 h-1 rounded-full bg-gray-400" />
          </div>
        </div>
      </div>
    </div>

    <!-- 列表视图 -->
    <div v-else class="p-3 flex flex-col gap-2 max-h-[204px] overflow-y-auto bg-white dark:bg-gray-900 rounded-lg scrollbar-hide">
      <div
        v-for="day in calendarDays.filter(d => d.events.length > 0)" :key="day.date"
        class="p-3 rounded-lg border border-gray-200 border-l-4 border-l-blue-500 bg-gray-50 dark:bg-gray-800 cursor-pointer transition-all duration-200 shadow-sm hover:bg-gray-100 dark:hover:bg-gray-700 hover:border-l-red-500 hover:translate-x-0.5 hover:shadow-md"
        @click="selectDate(day.date)"
      >
        <div class="flex items-center justify-between">
          <div class="flex flex-col">
            <div class="text-base font-semibold text-gray-900 dark:text-white mb-0.5">
              {{ formatDateShort(day.date) }}
            </div>
            <div class="text-xs text-gray-600 dark:text-gray-400 font-medium">
              {{ formatDateFull(day.date) }}
            </div>
          </div>
          <div class="flex gap-1 flex-wrap">
            <div v-for="event in day.events" :key="event.type" :class="getEventBadgeClass(event)">
              {{ getEventLabel(event) }}
            </div>
          </div>
        </div>
      </div>

      <div v-if="calendarDays.filter(d => d.events.length > 0).length === 0" class="flex flex-col items-center justify-center py-8 text-gray-500">
        <i class="i-tabler-calendar-x text-gray-400 wh-8" />
        <p class="text-sm mt-2">
          本月暂无记录
        </p>
      </div>
    </div>

    <!-- 图例 -->
    <div class="flex items-center justify-center gap-4 px-3 py-2 bg-gray-50 dark:bg-gray-900 border-t border-gray-200 dark:border-gray-700 max-sm:gap-2 max-sm:py-2 max-sm:flex-wrap">
      <div class="flex items-center gap-1.5">
        <div class="w-2 h-2 rounded-full bg-green-500" />
        <span class="text-xs text-gray-600 dark:text-gray-400">经期</span>
      </div>
      <div class="flex items-center gap-1.5">
        <div class="w-2 h-2 rounded-full border-2 border-white dark:border-gray-800 bg-[repeating-linear-gradient(45deg,transparent,transparent_1px,#22c55e_1px,#22c55e_2px)]" />
        <span class="text-xs text-gray-600 dark:text-gray-400">预测经期</span>
      </div>
      <div class="flex items-center gap-1.5">
        <div class="w-2 h-2 rounded-full bg-red-500" />
        <span class="text-xs text-gray-600 dark:text-gray-400">排卵期</span>
      </div>
      <div class="flex items-center gap-1.5">
        <div class="w-2 h-2 rounded-full border-2 border-white dark:border-gray-800 bg-[repeating-linear-gradient(45deg,transparent,transparent_1px,#ef4444_1px,#ef4444_2px)]" />
        <span class="text-xs text-gray-600 dark:text-gray-400">预测排卵期</span>
      </div>
      <div class="flex items-center gap-1.5">
        <div class="w-2 h-2 rounded-full bg-orange-500" />
        <span class="text-xs text-gray-600 dark:text-gray-400">易孕期</span>
      </div>
      <div class="flex items-center gap-1.5">
        <div class="w-2 h-2 rounded-full border-2 border-white dark:border-gray-800 bg-[repeating-linear-gradient(45deg,transparent,transparent_1px,#f97316_1px,#f97316_2px)]" />
        <span class="text-xs text-gray-600 dark:text-gray-400">预测易孕期</span>
      </div>
      <div class="flex items-center gap-1.5">
        <div class="w-2 h-2 rounded-full bg-yellow-500" />
        <span class="text-xs text-gray-600 dark:text-gray-400">PMS</span>
      </div>
    </div>
  </div>

  <!-- 使用 Teleport 将提示框渲染到 body，避免被父容器遮挡 -->
  <Teleport to="body">
    <div
      v-if="tooltip.show"
      class="fixed pointer-events-none z-[9999] isolate animate-[tooltipFadeIn_0.2s_ease-out]"
      :style="{
        left: `${tooltip.x}px`,
        top: `${tooltip.y}px`,
      }"
    >
      <div class="bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg p-4 min-w-[250px] max-w-[320px] shadow-[0_25px_50px_-12px_rgba(0,0,0,0.25),0_0_0_1px_rgba(0,0,0,0.05)] dark:shadow-[0_25px_50px_-12px_rgba(0,0,0,0.5),0_0_0_1px_rgba(255,255,255,0.1)] relative z-1">
        <!-- 日期标题 -->
        <div class="flex items-center justify-center mb-2">
          <span class="text-sm font-semibold">{{ tooltip.date }}</span>
          <span v-if="tooltip.isToday" class="py-0.5 px-2 bg-blue-100 dark:bg-blue-900 text-blue-700 dark:text-blue-300 text-xs rounded-full ml-2">今天</span>
        </div>

        <!-- 事件列表 -->
        <div class="flex flex-col gap-2 text-center">
          <div
            v-for="event in tooltip.events"
            :key="event.type"
            class="flex items-start gap-2 justify-center"
          >
            <div :class="getEventDotClass(event)" class="w-3 h-3 shrink-0 mt-0.5" />
            <div class="flex-1 text-left max-w-[200px]">
              <span class="block text-sm font-medium">{{ getEventLabel(event) }}</span>
              <span v-if="event.intensity" class="block text-xs opacity-75">
                强度: {{ getIntensityLabel(event.intensity) }}
              </span>
              <span v-if="getRiskLevel(event)" :class="getTooltipRiskClass(event)" class="block text-xs font-medium mt-1">
                {{ getRiskLevel(event) }}
              </span>
            </div>
          </div>
        </div>

        <!-- 额外信息 -->
        <div v-if="tooltip.extraInfo" class="mt-2 text-left">
          <div class="border-t border-gray-200 dark:border-gray-600 mb-2" />
          <div class="text-xs leading-relaxed opacity-75">
            {{ tooltip.extraInfo }}
          </div>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<style scoped>
/* Tailwind 动画 */
@keyframes tooltipFadeIn {
  from { opacity: 0; }
  to { opacity: 1; }
}

/* 隐藏滚动条但保留功能 */
.scrollbar-hide {
  scrollbar-width: none; /* Firefox */
  -ms-overflow-style: none; /* IE/Edge */
}

.scrollbar-hide::-webkit-scrollbar {
  width: 0px;
  background: transparent;
}
</style>
