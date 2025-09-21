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
    class="stacked-cards-container"
    :style="containerStyle"
    role="tablist"
    :aria-label="`统计卡片轮播，共 ${cards.length} 张`"
    :aria-disabled="disabled"
    @touchstart="handleTouchStart"
    @touchmove="handleTouchMove"
    @touchend="handleTouchEnd"
  >
    <!-- 卡片容器 -->
    <div class="cards-wrapper" :style="{ height: `${cardHeight}px` }">
      <div
        v-for="(card, index) in cards"
        :key="card.id"
        ref="cardRefs"
        class="stat-card-stacked"
        :class="[disabled ? 'card-disabled' : 'card-active']"
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
          class="inner-card"
        />
      </div>
    </div>

    <!-- 底部指示器 -->
    <div class="indicator-wrapper" role="tablist" aria-label="卡片导航指示器">
      <button
        v-for="(card, index) in cards"
        :key="`indicator-${index}`"
        class="indicator-dot"
        :class="[selectedIndex === index ? 'indicator-active' : '']"
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
        class="nav-btn nav-btn-prev"
        :aria-label="isPrevDisabled ? '已是第一张卡片' : '上一张卡片'"
        :disabled="isTransitioning || isPrevDisabled"
        :tabindex="disabled ? -1 : 0"
        @click="previousCard"
      >
        <LucideChevronLeft class="icon" />
      </button>
    </Transition>

    <Transition name="nav-fade">
      <button
        v-if="showNavButtons && cards.length > 1"
        class="nav-btn nav-btn-next"
        :aria-label="isNextDisabled ? '已是最后一张卡片' : '下一张卡片'"
        :disabled="isTransitioning || isNextDisabled"
        :tabindex="disabled ? -1 : 0"
        @click="nextCard"
      >
        <LucideChevronRight class="icon" />
      </button>
    </Transition>

    <!-- 播放按钮 -->
    <button
      v-if="showPlayControl"
      class="play-control"
      :aria-label="isAutoPlaying ? '暂停自动播放' : '开始自动播放'"
      :disabled="disabled"
      :tabindex="disabled ? -1 : 0"
      @click="toggleAutoPlay"
    >
      <LucidePause v-if="isAutoPlaying" class="icon-small" />
      <LucidePlay v-else class="icon-small" />
    </button>
  </div>
</template>

<style scoped>
/* 容器基础 */
.stacked-cards-container {
  position: relative;
  overflow: hidden;
  perspective: 1200px;
  contain: layout style paint;
}
.cards-wrapper {
  position: relative;
  width: 100%;
  height: 100%;
}
.stat-card-stacked {
  position: absolute;
  top: 0;
  transform-style: preserve-3d;
  will-change: transform, opacity, z-index;
  backface-visibility: hidden;
  contain: layout style paint;
}
.card-active {
  cursor: pointer;
}
.card-disabled {
  pointer-events: none;
  opacity: 0.75;
}
.inner-card {
  height: 100%;
  box-shadow: 0 4px 12px rgba(0,0,0,0.1);
  transition: box-shadow 0.3s ease;
}
.inner-card:hover {
  box-shadow: 0 8px 20px rgba(0,0,0,0.15);
}

/* 导航按钮 */
.nav-btn {
  width: 40px;
  height: 40px;
  border-radius: 50%;
  background: rgba(59, 130, 246, 0.15);
  border: 1px solid rgba(59, 130, 246, 0.5);
  backdrop-filter: blur(6px);
  position: absolute;
  top: 50%;
  transform: translateY(-50%);
  color: #4b5563;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.3s;
}
.nav-btn:hover:not(:disabled) {
  background: rgba(59, 130, 246, 0.3); /* Hover 加深背景 */
  box-shadow: 0 4px 12px rgba(0,0,0,0.15);
  transform: translateY(-50%) scale(1.15);
}
.nav-btn:focus-visible {
  outline: none;
  box-shadow: 0 0 0 3px #3b82f6, 0 0 0 5px #ffffff; /* 蓝色 focus 环 + 白色间距 */
}
.nav-btn:disabled {
  opacity: 0.3;
  cursor: not-allowed;
}
.nav-btn-prev {
  left: 16px;
}
.nav-btn-next {
  right: 16px;
}
.icon {
  width: 20px;
  height: 20px;
  color: inherit;
}

/* focus 高亮 */
.nav-btn:focus-visible,
.play-control:focus-visible,
.indicator-dot:focus-visible {
  outline: none;
  box-shadow: 0 0 0 2px #3b82f6, 0 0 0 4px #ffffff;
}

/* 播放控制 */
.play-control {
  position: absolute;
  top: 16px;
  right: 16px;
  z-index: 50;
  width: 32px;
  height: 32px;
  border-radius: 50%;
  border: 1px solid #e5e7eb;
  background: rgba(255,255,255,0.8);
  backdrop-filter: blur(6px);
  display: flex;
  align-items: center;
  justify-content: center;
  color: #4b5563;
  transition: color 0.2s;
}
.play-control:hover {
  color: #3b82f6;
}
.play-control:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
.icon-small {
  width: 16px;
  height: 16px;
}

/* 指示器 */
.indicator-wrapper {
  margin-top: 16px;
  display: flex;
  gap: 8px;
  justify-content: center;
}
.indicator-dot {
  width: 12px;
  height: 12px;
  border-radius: 50%;
  background: #d1d5db;
  transition: all 0.3s;
  box-shadow: none;
  border: none;
}
.indicator-dot:hover {
  background: #9ca3af;
}
.indicator-active {
  background: #3b82f6;
  transform: scale(1.1);
  box-shadow: 0 2px 6px rgba(0,0,0,0.2);
}
.indicator-dot:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

/* 动画 */
.nav-fade-enter-active,
.nav-fade-leave-active {
  transition: opacity 0.3s ease;
}
.nav-fade-enter-from,
.nav-fade-leave-to {
  opacity: 0;
}

/* 响应式 */
@media (max-width: 768px) {
  .nav-btn {
    width: 32px;
    height: 32px;
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
    width: 28px;
    height: 28px;
  }
}

/* 打印模式 */
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
