<script setup lang="ts">
import TodayTodos from '@/components/common/TodayTodos.vue';
</script>

<template>
  <div class="grid-container">
    <div class="grid-item red">
      <TodayTodos />
    </div>
    <div class="grid-item blue">
      区域 2
    </div>
    <div class="grid-item purple">
      区域 3
    </div>
    <div class="grid-item yellow">
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
  box-shadow: 0 4px 6px rgba(0,0,0,0.1);
  backdrop-filter: blur(8px);
  display: flex;
  justify-content: center;
  align-items: center;
  font-size: 1.5rem;
  font-weight: bold;
  transition: all 0.4s ease-in-out;
}

/* 红色区域 */
.red {
  color: var(--color-error-content);
  --gradient-angle: 135deg;
  --mix-ratio: clamp(15%, 20%, 25%);
  flex-direction: column;
  align-items: stretch;
  justify-content: flex-start;
}

/* 蓝色区域 */
.blue {
  color: var(--color-info-content);
  --gradient-angle: 135deg;
  --mix-ratio: clamp(15%, 20%, 25%);
  background: linear-gradient(
    var(--gradient-angle),
    var(--color-base-200) 0%,
    var(--color-info) 100%
  );
}

.blue:hover {
  background: linear-gradient(
    var(--gradient-angle),
    var(--color-info) 0%,
    color-mix(in oklch, var(--color-info) var(--mix-ratio), var(--color-base-200)) 100%
  );
}

/* 紫色区域 */
.purple {
  color: var(--color-primary-content);
  --gradient-angle: 135deg;
  --mix-ratio: clamp(15%, 20%, 25%);
  background: linear-gradient(
    var(--gradient-angle),
    var(--color-base-200) 0%,
    var(--color-primary) 100%
  );
}

.purple:hover {
  background: linear-gradient(
    var(--gradient-angle),
    var(--color-primary) 0%,
    color-mix(in oklch, var(--color-primary) var(--mix-ratio), var(--color-base-200)) 100%
  );
}

/* 黄色区域 */
.yellow {
  color: var(--color-warning-content);
  --gradient-angle: 135deg;
  --mix-ratio: clamp(15%, 20%, 25%);
  background: linear-gradient(
    var(--gradient-angle),
    var(--color-base-200) 0%,
    var(--color-warning) 100%
  );
}

.yellow:hover {
  background: linear-gradient(
    var(--gradient-angle),
    var(--color-warning) 0%,
    color-mix(in oklch, var(--color-warning) var(--mix-ratio), var(--color-base-200)) 100%
  );
}

/* 大屏幕调整渐变角度 */
@media (min-width: 768px) {
  .red { --gradient-angle: 135deg; }
  .blue { --gradient-angle: 225deg; }
  .purple { --gradient-angle: 45deg; }
  .yellow { --gradient-angle: 315deg; }
}
</style>
