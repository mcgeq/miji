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
    <div class="grid-item grid-item-scrollable">
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
  gap: 0.75rem;
  padding: 0.75rem;
  box-sizing: border-box;
  width: 100%;
  /* 移动端：计算高度 = 视口高度 - 底部导航（4rem） */
  height: calc(100vh - 4rem);
  overflow-y: auto;
  overflow-x: hidden;
  /* 隐藏滚动条 */
  scrollbar-width: none;
  -ms-overflow-style: none;
}

.grid-container::-webkit-scrollbar {
  display: none;
}

/* 响应式桌面布局：2×2 */
@media (min-width: 768px) {
  .grid-container {
    grid-template-columns: repeat(2, 1fr);
    grid-template-rows: repeat(2, 1fr);
    gap: 1rem;
    padding: 1rem;
    height: calc(100vh - 2rem);
  }
}

/* 公共区域样式 */
.grid-item {
  height: 16rem;
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
  overflow: hidden;
  box-sizing: border-box;
  width: 100%;
  --gradient-angle: 135deg;
  --mix-ratio: clamp(15%, 20%, 25%);
}

/* 可滚动区域样式 - 用于待办任务等需要滚动的区域 */
.grid-item-scrollable {
  align-items: stretch;
  justify-content: stretch;
  padding: 0;
}
</style>
