<script setup lang="ts">
import { ChevronLeft, ChevronRight, Pause, Play } from 'lucide-vue-next';
import StatCard from './StatCard.vue';
import type { ComponentPublicInstance } from 'vue';

// 类型定义
interface CardData {
  id: string;
  title: string;
  value: string;
  currency?: string;
  icon?: string;
  color?: 'primary' | 'success' | 'danger' | 'warning' | 'info';
  loading?: boolean;
  subtitle?: string;
  trend?: string;
  trendType?: 'up' | 'down' | 'neutral';
}

interface CardPosition {
  left: string;
  transform: string;
  zIndex: number;
  opacity: number;
  scale: number;
}

interface Props {
  cards: CardData[];
  autoPlay?: boolean;
  autoPlayDelay?: number;
  showNavButtons?: boolean;
  showPlayControl?: boolean;
  cardWidth?: number;
  cardHeight?: number;
  enableKeyboard?: boolean;
  maxVisibleCards?: number;
  transitionDuration?: number;
}

// Props 定义
const props = withDefaults(defineProps<Props>(), {
  autoPlay: true,
  autoPlayDelay: 6000,
  showNavButtons: true,
  showPlayControl: false,
  cardWidth: 320,
  cardHeight: 176,
  enableKeyboard: true,
  maxVisibleCards: 5,
  transitionDuration: 800,
});

// Emits 定义
const emit = defineEmits<{
  cardChange: [index: number, card: CardData];
  cardClick: [index: number, card: CardData];
}>();

// 响应式状态
const selectedIndex = ref(0);
const isTransitioning = ref(false);
const isAutoPlaying = ref(props.autoPlay);
const touchStartX = ref(0);
const touchEndX = ref(0);
const cardRefs = ref<ComponentPublicInstance[]>([]);

// 自动播放控制
const autoPlayInterval = ref<NodeJS.Timeout | null>(null);

// 计算属性
const containerStyle = computed(() => ({
  height: `${props.cardHeight + 60}px`, // 卡片高度 + 指示器空间
}));

const isPrevDisabled = computed(() =>
  !props.autoPlay && selectedIndex.value === 0,
);

const isNextDisabled = computed(() =>
  !props.autoPlay && selectedIndex.value === props.cards.length - 1,
);

// 可见卡片索引计算（用于未来的虚拟化优化）
const _visibleCardIndices = computed(() => {
  const indices = [];
  const total = props.cards.length;
  const maxVisible = Math.min(props.maxVisibleCards, total);

  for (let i = 0; i < maxVisible; i++) {
    const index = (selectedIndex.value + i - Math.floor(maxVisible / 2) + total) % total;
    indices.push(index);
  }

  return indices;
});

// 性能优化：使用计算属性缓存卡片位置
const cardPositions = computed(() => {
  const positions = new Map<number, CardPosition>();

  props.cards.forEach((_, index) => {
    const diff = index - selectedIndex.value;
    const totalCards = props.cards.length;

    // 标准化差值处理循环
    const normalizedDiff = ((diff % totalCards) + totalCards) % totalCards;
    const adjustedDiff = normalizedDiff > totalCards / 2 ? normalizedDiff - totalCards : normalizedDiff;

    const baseLeft = 50;
    let left = baseLeft;
    let rotation = 0;
    let zIndex = 10;
    let opacity = 1;
    let scale = 1;

    const absDiff = Math.abs(adjustedDiff);

    if (adjustedDiff === 0) {
      zIndex = 30;
      opacity = 1;
      scale = 1;
    }
    else if (absDiff === 1) {
      left = baseLeft + (adjustedDiff > 0 ? 6 : -6);
      rotation = adjustedDiff > 0 ? 2 : -2;
      zIndex = 25;
      opacity = 0.9;
      scale = 0.96;
    }
    else if (absDiff === 2) {
      left = baseLeft + (adjustedDiff > 0 ? 10 : -10);
      rotation = adjustedDiff > 0 ? 4 : -4;
      zIndex = 20;
      opacity = 0.75;
      scale = 0.92;
    }
    else {
      left = baseLeft + (adjustedDiff > 0 ? 14 : -14);
      rotation = adjustedDiff > 0 ? 6 : -6;
      zIndex = 15;
      opacity = 0.5;
      scale = 0.88;
    }

    positions.set(index, {
      left: `${left}%`,
      transform: `translateX(-50%) rotate(${rotation}deg) scale(${scale})`,
      zIndex,
      opacity,
      scale,
    });
  });

  return positions;
});

// 方法
async function selectCard(index: number) {
  if (isTransitioning.value || index === selectedIndex.value || index < 0 || index >= props.cards.length) {
    return;
  }

  isTransitioning.value = true;
  selectedIndex.value = index;

  // 触发事件
  emit('cardChange', index, props.cards[index]);
  emit('cardClick', index, props.cards[index]);

  // 重置自动播放
  resetAutoPlay();

  // 焦点管理
  await nextTick();
  const targetCard = cardRefs.value[index];
  if (targetCard?.$el) {
    targetCard.$el.focus();
  }

  // 解锁过渡状态
  setTimeout(() => {
    isTransitioning.value = false;
  }, props.transitionDuration);
}

function previousCard() {
  if (isTransitioning.value)
    return;

  const newIndex = props.autoPlay
    ? (selectedIndex.value - 1 + props.cards.length) % props.cards.length
    : Math.max(0, selectedIndex.value - 1);

  selectCard(newIndex);
}

function nextCard() {
  if (isTransitioning.value)
    return;

  const newIndex = props.autoPlay
    ? (selectedIndex.value + 1) % props.cards.length
    : Math.min(props.cards.length - 1, selectedIndex.value + 1);

  selectCard(newIndex);
}

function getCardClasses(index: number) {
  const position = cardPositions.value.get(index);
  if (!position)
    return '';

  return `z-${position.zIndex}`;
}

function getCardStyle(index: number) {
  const position = cardPositions.value.get(index);
  if (!position)
    return {};

  return {
    left: position.left,
    transform: position.transform,
    opacity: position.opacity,
    width: `${props.cardWidth}px`,
    height: `${props.cardHeight}px`,
    transition: `all ${props.transitionDuration}ms cubic-bezier(0.4, 0, 0.2, 1)`,
    zIndex: position.zIndex,
  };
}

// 触摸事件处理（防抖优化）
let touchMoveThrottled = false;
function handleTouchStart(e: TouchEvent) {
  touchStartX.value = e.touches[0].clientX;
  pauseAutoPlay();
}

function handleTouchMove(e: TouchEvent) {
  if (touchMoveThrottled)
    return;
  touchMoveThrottled = true;

  setTimeout(() => {
    touchMoveThrottled = false;
  }, 16); // 60fps

  e.preventDefault();
}

function handleTouchEnd(e: TouchEvent) {
  touchEndX.value = e.changedTouches[0].clientX;
  handleSwipe();
  resetAutoPlay();
}

function handleSwipe() {
  if (isTransitioning.value)
    return;

  const swipeThreshold = 50;
  const diff = touchStartX.value - touchEndX.value;

  if (Math.abs(diff) < swipeThreshold)
    return;

  if (diff > 0) {
    nextCard();
  }
  else {
    previousCard();
  }
}

// 键盘事件处理
function handleCardKeydown(e: KeyboardEvent, index: number) {
  if (!props.enableKeyboard || isTransitioning.value)
    return;

  switch (e.key) {
    case 'ArrowLeft':
      e.preventDefault();
      previousCard();
      break;
    case 'ArrowRight':
      e.preventDefault();
      nextCard();
      break;
    case 'Home':
      e.preventDefault();
      selectCard(0);
      break;
    case 'End':
      e.preventDefault();
      selectCard(props.cards.length - 1);
      break;
    case 'Enter':
    case ' ':
      e.preventDefault();
      selectCard(index);
      break;
  }
}

function handleGlobalKeydown(e: KeyboardEvent) {
  if (!props.enableKeyboard || isTransitioning.value)
    return;

  if (e.target === document.body || e.target === document.documentElement) {
    handleCardKeydown(e, selectedIndex.value);
  }
}

// 自动播放控制
function startAutoPlay() {
  if (!props.autoPlay || props.cards.length <= 1)
    return;

  stopAutoPlay();
  isAutoPlaying.value = true;

  autoPlayInterval.value = setInterval(() => {
    nextCard();
  }, props.autoPlayDelay);
}

function stopAutoPlay() {
  if (autoPlayInterval.value) {
    clearInterval(autoPlayInterval.value);
    autoPlayInterval.value = null;
  }
  isAutoPlaying.value = false;
}

function pauseAutoPlay() {
  stopAutoPlay();
}

function resetAutoPlay() {
  if (!props.autoPlay)
    return;

  stopAutoPlay();
  setTimeout(() => {
    startAutoPlay();
  }, 2000);
}

function toggleAutoPlay() {
  if (isAutoPlaying.value) {
    stopAutoPlay();
  }
  else {
    startAutoPlay();
  }
}

// 监听器
watch(() => props.cards.length, (newLength) => {
  if (selectedIndex.value >= newLength) {
    selectedIndex.value = Math.max(0, newLength - 1);
  }
});

watch(() => props.autoPlay, (newValue) => {
  if (newValue) {
    startAutoPlay();
  }
  else {
    stopAutoPlay();
  }
});

// 生命周期
onMounted(() => {
  if (props.enableKeyboard) {
    window.addEventListener('keydown', handleGlobalKeydown);
  }

  if (props.autoPlay) {
    startAutoPlay();
  }
});

onUnmounted(() => {
  stopAutoPlay();

  if (props.enableKeyboard) {
    window.removeEventListener('keydown', handleGlobalKeydown);
  }
});

// 暴露方法给父组件
defineExpose({
  selectCard,
  previousCard,
  nextCard,
  startAutoPlay,
  stopAutoPlay,
  toggleAutoPlay,
  getCurrentIndex: () => selectedIndex.value,
  getCurrentCard: () => props.cards[selectedIndex.value],
});
</script>

<template>
  <div
    class="stacked-cards-container relative overflow-hidden"
    :style="containerStyle"
    role="tablist"
    :aria-label="`统计卡片轮播，共 ${cards.length} 张`"
    @touchstart="handleTouchStart"
    @touchmove="handleTouchMove"
    @touchend="handleTouchEnd"
  >
    <!-- 卡片容器 -->
    <div
      class="cards-wrapper relative h-full w-full"
      :style="{ height: `${cardHeight}px` }"
    >
      <div
        v-for="(card, index) in cards"
        :key="card.id"
        ref="cardRefs"
        class="stat-card-stacked absolute top-0 cursor-pointer" :class="[
          getCardClasses(index),
        ]"
        :style="getCardStyle(index)"
        :tabindex="selectedIndex === index ? 0 : -1"
        :aria-selected="selectedIndex === index"
        :aria-label="`${card.title}: ${card.value}`"
        role="tab"
        @click="selectCard(index)"
        @keydown="handleCardKeydown($event, index)"
      >
        <StatCard
          :title="card.title"
          :value="card.value"
          :currency="card.currency"
          :icon="card.icon"
          :color="card.color"
          :loading="card.loading"
          :subtitle="card.subtitle"
          :trend="card.trend"
          :trend-type="card.trendType"
          class="h-full shadow-lg transition-shadow duration-300 hover:shadow-xl"
        />
      </div>
    </div>

    <!-- 导航指示器 -->
    <div
      class="mt-4 flex justify-center gap-2"
      role="tablist"
      aria-label="卡片导航指示器"
    >
      <button
        v-for="(card, index) in cards"
        :key="`indicator-${index}`"
        class="indicator-dot h-3 w-3 rounded-full transition-all duration-300 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500" :class="[
          selectedIndex === index
            ? 'bg-blue-500 scale-110 shadow-md'
            : 'bg-gray-300 hover:bg-gray-400',
        ]"
        :aria-label="`切换到第 ${index + 1} 张卡片: ${card.title}`"
        :aria-pressed="selectedIndex === index"
        :disabled="isTransitioning"
        @click="selectCard(index)"
      />
    </div>

    <!-- 左右导航按钮 -->
    <Transition name="nav-fade">
      <button
        v-if="showNavButtons && cards.length > 1"
        class="nav-btn nav-btn-prev absolute left-4 top-1/2 z-50 -translate-y-1/2"
        :aria-label="isPrevDisabled ? '已是第一张卡片' : '上一张卡片'"
        :disabled="isTransitioning || isPrevDisabled"
        @click="previousCard"
      >
        <ChevronLeft class="h-5 w-5" />
      </button>
    </Transition>

    <Transition name="nav-fade">
      <button
        v-if="showNavButtons && cards.length > 1"
        class="nav-btn nav-btn-next absolute right-4 top-1/2 z-50 -translate-y-1/2"
        :aria-label="isNextDisabled ? '已是最后一张卡片' : '下一张卡片'"
        :disabled="isTransitioning || isNextDisabled"
        @click="nextCard"
      >
        <ChevronRight class="h-5 w-5" />
      </button>
    </Transition>

    <!-- 播放/暂停控制（可选） -->
    <button
      v-if="showPlayControl"
      class="play-control absolute right-4 top-4 z-50 h-8 w-8 flex items-center justify-center border border-gray-200 rounded-full bg-white/80 text-gray-600 backdrop-blur-sm transition-colors duration-200 hover:text-blue-500"
      :aria-label="isAutoPlaying ? '暂停自动播放' : '开始自动播放'"
      @click="toggleAutoPlay"
    >
      <Pause v-if="isAutoPlaying" class="h-4 w-4" />
      <Play v-else class="h-4 w-4" />
    </button>
  </div>
</template>

<style scoped lang="postcss">
.stacked-cards-container {
  perspective: 1200px;
  contain: layout style paint;
}

.stat-card-stacked {
  transform-style: preserve-3d;
  will-change: transform, opacity, z-index;
  backface-visibility: hidden;
  -webkit-backface-visibility: hidden;
  contain: layout style paint;
}

.nav-btn {
  @apply w-10 h-10 rounded-full bg-white/90 backdrop-blur-sm border border-gray-200
         flex items-center justify-center text-gray-600 hover:text-blue-500
         hover:bg-white hover:shadow-md transition-all duration-300
         disabled:opacity-30 disabled:cursor-not-allowed disabled:hover:text-gray-600
         focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2;
}

.nav-btn:hover:not(:disabled) {
  transform: translateY(-50%) scale(1.1);
}

.play-control {
  @apply focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2;
}

.indicator-dot {
  @apply focus:outline-none;
}

/* 动画过渡 */
.nav-fade-enter-active,
.nav-fade-leave-active {
  transition: opacity 0.3s ease;
}

.nav-fade-enter-from,
.nav-fade-leave-to {
  opacity: 0;
}

/* 防止布局抖动 */
.stat-card-stacked * {
  backface-visibility: hidden;
  -webkit-backface-visibility: hidden;
}

/* 性能优化 */
@media (prefers-reduced-motion: reduce) {
  .stat-card-stacked {
    transition-duration: 0.1s !important;
  }

  .nav-btn {
    transition-duration: 0.1s !important;
  }
}

/* 高对比度模式支持 */
@media (prefers-contrast: high) {
  .nav-btn {
    @apply border-2 border-gray-800;
  }

  .indicator-dot {
    @apply border-2 border-gray-800;
  }
}

/* 响应式设计 */
@media (max-width: 768px) {
  .nav-btn {
    @apply w-8 h-8;
  }

  .nav-btn-prev {
    left: 8px;
  }

  .nav-btn-next {
    right: 8px;
  }
}

@media (max-width: 480px) {
  .nav-btn {
    @apply w-7 h-7;
  }
}

/* 打印样式 */
@media print {
  .nav-btn,
  .play-control,
  .indicator-dot {
    display: none !important;
  }

  .stat-card-stacked {
    position: static !important;
    transform: none !important;
    opacity: 1 !important;
  }
}
</style>
