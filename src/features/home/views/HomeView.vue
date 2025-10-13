<script setup lang="ts">
import QuickMoneyActions from '@/components/common/QuickMoneyActions.vue';
import TodayPeriod from '@/components/common/TodayPeriod.vue';
import TodayTodos from '@/components/common/TodayTodos.vue';
</script>

<template>
  <div class="grid-container">
    <div class="grid-item">
      <QuickMoneyActions />
    </div>
    <div class="grid-item">
      <TodayPeriod />
    </div>
    <div class="grid-item">
      <TodayTodos />
    </div>
    <div class="grid-item">
      区域 4
    </div>
  </div>
</template>

<style lang="postcss">
/* 外层网格 */
.grid-container {
  display: grid;
  grid-template-columns: 1fr;
  grid-template-rows: repeat(4, 1fr);
  gap: 1rem;
  padding: 1rem;
}

/* 响应式桌面布局：2×2 */
@media (min-width: 768px) {
  .grid-container {
    grid-template-columns: repeat(2, 1fr);
    grid-template-rows: repeat(2, 1fr);
  }
}

/* 公共区域样式 */
.grid-item {
  height: 17rem;
  border: 1px solid var(--color-base-300);
  border-radius: 1rem;
  box-shadow: 0 4px 6px color-mix(in oklch, var(--color-neutral) 10%, transparent);
  backdrop-filter: blur(8px);
  display: flex;
  justify-content: center;
  align-items: center;
  font-size: 1.5rem;
  font-weight: bold;
  transition: all 0.4s ease-in-out;
  overflow: visible;
  --gradient-angle: 135deg;
  --mix-ratio: clamp(15%, 20%, 25%);
}
</style>
