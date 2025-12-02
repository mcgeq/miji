<script setup lang="ts">
import { LucideChevronLeft, LucideChevronRight, LucidePause, LucidePlay } from 'lucide-vue-next';
import StatCard from './StatCard.vue';
import type { CardData } from '../common/moneyCommon';
import type { ComponentPublicInstance } from 'vue';

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
  disabled?: boolean;
}

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
  disabled: false,
});

const emit = defineEmits<{
  cardChange: [index: number, card: CardData];
  cardClick: [index: number, card: CardData];
}>();

const selectedIndex = ref(0);
const isTransitioning = ref(false);
const isAutoPlaying = ref(props.autoPlay);
const touchStartX = ref(0);
const touchEndX = ref(0);
const cardRefs = ref<ComponentPublicInstance[]>([]);
const autoPlayInterval = ref<NodeJS.Timeout | null>(null);

const containerStyle = computed(() => ({
  height: `${props.cardHeight + 60}px`,
}));

const isPrevDisabled = computed(() =>
  props.disabled || (!props.autoPlay && selectedIndex.value === 0),
);
const isNextDisabled = computed(() =>
  props.disabled || (!props.autoPlay && selectedIndex.value === props.cards.length - 1),
);

const cardPositions = computed(() => {
  const positions = new Map<number, CardPosition>();

  props.cards.forEach((_, index) => {
    const diff = index - selectedIndex.value;
    const totalCards = props.cards.length;
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
    } else if (absDiff === 1) {
      left = baseLeft + (adjustedDiff > 0 ? 6 : -6);
      rotation = adjustedDiff > 0 ? 2 : -2;
      zIndex = 25;
      opacity = 0.9;
      scale = 0.96;
    } else if (absDiff === 2) {
      left = baseLeft + (adjustedDiff > 0 ? 10 : -10);
      rotation = adjustedDiff > 0 ? 4 : -4;
      zIndex = 20;
      opacity = 0.75;
      scale = 0.92;
    } else {
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

async function selectCard(index: number) {
  if (props.disabled || isTransitioning.value || index === selectedIndex.value || index < 0 || index >= props.cards.length) {
    return;
  }

  isTransitioning.value = true;
  selectedIndex.value = index;

  emit('cardChange', index, props.cards[index]);
  emit('cardClick', index, props.cards[index]);

  resetAutoPlay();

  await nextTick();
  const targetCard = cardRefs.value[index];
  if (targetCard?.$el) {
    targetCard.$el.focus();
  }

  setTimeout(() => {
    isTransitioning.value = false;
  }, props.transitionDuration);
}

function previousCard() {
  if (props.disabled || isTransitioning.value) return;
  const newIndex = props.autoPlay
    ? (selectedIndex.value - 1 + props.cards.length) % props.cards.length
    : Math.max(0, selectedIndex.value - 1);
  selectCard(newIndex);
}
function nextCard() {
  if (props.disabled || isTransitioning.value) return;
  const newIndex = props.autoPlay
    ? (selectedIndex.value + 1) % props.cards.length
    : Math.min(props.cards.length - 1, selectedIndex.value + 1);
  selectCard(newIndex);
}

function getCardStyle(index: number) {
  const position = cardPositions.value.get(index);
  if (!position) return {};
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

function handleTouchStart(e: TouchEvent) {
  if (props.disabled) return;
  touchStartX.value = e.touches[0].clientX;
  pauseAutoPlay();
}
function handleTouchMove(e: TouchEvent) {
  if (props.disabled) return;
  e.preventDefault();
}
function handleTouchEnd(e: TouchEvent) {
  if (props.disabled) return;
  touchEndX.value = e.changedTouches[0].clientX;
  handleSwipe();
  resetAutoPlay();
}
function handleSwipe() {
  if (props.disabled || isTransitioning.value) return;
  const swipeThreshold = 50;
  const diff = touchStartX.value - touchEndX.value;
  if (Math.abs(diff) < swipeThreshold) return;
  if (diff > 0) nextCard();
  else previousCard();
}

function handleCardKeydown(e: KeyboardEvent, index: number) {
  if (props.disabled || !props.enableKeyboard || isTransitioning.value) return;
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
  if (props.disabled || !props.enableKeyboard || isTransitioning.value) return;
  if (e.target === document.body || e.target === document.documentElement) {
    handleCardKeydown(e, selectedIndex.value);
  }
}

function startAutoPlay() {
  if (props.disabled || !props.autoPlay || props.cards.length <= 1) return;
  stopAutoPlay();
  isAutoPlaying.value = true;
  autoPlayInterval.value = setInterval(() => {
    if (!props.disabled) nextCard();
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
  if (props.disabled || !props.autoPlay) return;
  stopAutoPlay();
  setTimeout(() => {
    startAutoPlay();
  }, 2000);
}
function toggleAutoPlay() {
  if (props.disabled) return;
  if (isAutoPlaying.value) stopAutoPlay();
  else startAutoPlay();
}

watch(() => props.cards.length, newLength => {
  if (selectedIndex.value >= newLength) {
    selectedIndex.value = Math.max(0, newLength - 1);
  }
});
watch(() => props.autoPlay, newValue => {
  if (props.disabled) return;
  if (newValue) startAutoPlay();
  else stopAutoPlay();
});
watch(() => props.disabled, newValue => {
  if (newValue) stopAutoPlay();
  else if (props.autoPlay) startAutoPlay();
});

onMounted(() => {
  if (props.enableKeyboard) {
    window.addEventListener('keydown', handleGlobalKeydown);
  }
  if (props.autoPlay && !props.disabled) {
    startAutoPlay();
  }
});
onUnmounted(() => {
  stopAutoPlay();
  if (props.enableKeyboard) {
    window.removeEventListener('keydown', handleGlobalKeydown);
  }
});

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
    class="relative overflow-hidden [perspective:1200px]"
    :style="containerStyle"
    role="tablist"
    :aria-label="`统计卡片轮播，共 ${cards.length} 张`"
    :aria-disabled="disabled"
    @touchstart="handleTouchStart"
    @touchmove="handleTouchMove"
    @touchend="handleTouchEnd"
  >
    <!-- 卡片容器 -->
    <div class="relative w-full h-full" :style="{ height: `${cardHeight}px` }">
      <div
        v-for="(card, index) in cards"
        :key="card.id"
        ref="cardRefs"
        class="stat-card-stacked"
        :class="disabled ? 'pointer-events-none opacity-75' : 'cursor-pointer'"
        :style="getCardStyle(index)"
        :tabindex="disabled ? -1 : (selectedIndex === index ? 0 : -1)"
        :aria-selected="selectedIndex === index"
        :aria-label="`${card.title}: ${card.value}`"
        :aria-disabled="disabled"
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
          class="h-full shadow-md hover:shadow-xl transition-shadow duration-300"
        />
      </div>
    </div>

    <!-- 底部指示器 -->
    <div class="mt-4 flex gap-2 justify-center" role="tablist" aria-label="卡片导航指示器">
      <button
        v-for="(card, index) in cards"
        :key="`indicator-${index}`"
        class="w-3 h-3 rounded-full border-0 transition-all duration-300 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-500 focus-visible:ring-offset-2"
        :class="[
          selectedIndex === index
            ? 'bg-blue-600 scale-110 shadow-md'
            : 'bg-gray-300 hover:bg-gray-400 dark:bg-gray-600 dark:hover:bg-gray-500',
          (disabled || isTransitioning) && 'opacity-50 cursor-not-allowed',
        ]"
        :aria-label="`切换到第 ${index + 1} 张卡片: ${card.title}`"
        :aria-pressed="selectedIndex === index"
        :disabled="disabled || isTransitioning"
        :tabindex="disabled ? -1 : 0"
        @click="selectCard(index)"
      />
    </div>

    <!-- 左右按钮 -->
    <Transition name="nav-fade">
      <button
        v-if="showNavButtons && cards.length > 1"
        class="absolute top-1/2 -translate-y-1/2 left-4 md:left-4 w-10 h-10 md:w-10 md:h-10 sm:w-8 sm:h-8 rounded-full bg-blue-600/15 dark:bg-blue-500/20 border border-blue-600/50 dark:border-blue-500/50 backdrop-blur-md flex items-center justify-center text-gray-600 dark:text-gray-300 transition-all duration-300 hover:bg-blue-600/30 hover:shadow-lg hover:scale-110 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-500 focus-visible:ring-offset-2 disabled:opacity-30 disabled:cursor-not-allowed"
        :aria-label="isPrevDisabled ? '已是第一张卡片' : '上一张卡片'"
        :disabled="isTransitioning || isPrevDisabled"
        :tabindex="disabled ? -1 : 0"
        @click="previousCard"
      >
        <LucideChevronLeft class="w-5 h-5" />
      </button>
    </Transition>

    <Transition name="nav-fade">
      <button
        v-if="showNavButtons && cards.length > 1"
        class="absolute top-1/2 -translate-y-1/2 right-4 md:right-4 w-10 h-10 md:w-10 md:h-10 sm:w-8 sm:h-8 rounded-full bg-blue-600/15 dark:bg-blue-500/20 border border-blue-600/50 dark:border-blue-500/50 backdrop-blur-md flex items-center justify-center text-gray-600 dark:text-gray-300 transition-all duration-300 hover:bg-blue-600/30 hover:shadow-lg hover:scale-110 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-500 focus-visible:ring-offset-2 disabled:opacity-30 disabled:cursor-not-allowed"
        :aria-label="isNextDisabled ? '已是最后一张卡片' : '下一张卡片'"
        :disabled="isTransitioning || isNextDisabled"
        :tabindex="disabled ? -1 : 0"
        @click="nextCard"
      >
        <LucideChevronRight class="w-5 h-5" />
      </button>
    </Transition>

    <!-- 播放按钮 -->
    <button
      v-if="showPlayControl"
      class="absolute top-4 right-4 z-50 w-8 h-8 rounded-full border border-gray-200 dark:border-gray-700 bg-white/80 dark:bg-gray-800/80 backdrop-blur-md flex items-center justify-center text-gray-600 dark:text-gray-400 transition-colors hover:text-blue-600 dark:hover:text-blue-400 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-500 focus-visible:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed"
      :aria-label="isAutoPlaying ? '暂停自动播放' : '开始自动播放'"
      :disabled="disabled"
      :tabindex="disabled ? -1 : 0"
      @click="toggleAutoPlay"
    >
      <LucidePause v-if="isAutoPlaying" class="w-4 h-4" />
      <LucidePlay v-else class="w-4 h-4" />
    </button>
  </div>
</template>

<style scoped>
/* 3D 变换样式（无法用 Tailwind 替代） */
.stat-card-stacked {
  position: absolute;
  top: 0;
  transform-style: preserve-3d;
  will-change: transform, opacity, z-index;
  backface-visibility: hidden;
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

/* 打印模式 */
@media print {
  .stat-card-stacked {
    position: static !important;
    transform: none !important;
    opacity: 1 !important;
  }
}
</style>
