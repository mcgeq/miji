<script setup lang="ts">
import { Heart } from 'lucide-vue-next';
import { HealthTipsManager } from '../utils/periodUtils';
import type { PeriodStats } from '@/schema/health/period';

interface Props {
  stats: PeriodStats;
}
const props = defineProps<Props>();

const healthTips = computed(() => {
  return HealthTipsManager.getPersonalizedTips(props.stats.currentPhase);
});
</script>

<template>
  <!-- 健康建议 -->
  <div class="health-tips">
    <div class="health-tips-header">
      <div class="health-tips-icon">
        <Heart class="health-tips-icon-heart" />
      </div>
      <h3 class="health-tips-title">
        健康建议
      </h3>
    </div>

    <div class="health-tips-list">
      <div
        v-for="tip in healthTips"
        :key="tip.id"
        class="health-tip-item"
      >
        <component :is="tip.icon" class="health-tip-icon" />
        <span class="health-tip-text">
          {{ tip.text }}
        </span>
      </div>
    </div>
  </div>
</template>

<style lang="postcss" scoped>
/* 健康建议容器 */
.health-tips {
  padding: 1rem;
  background-color: var(--color-base-100);
  border: 1px solid var(--color-base-300);
  border-radius: 0.5rem;
  box-shadow: 0 1px 2px 0 rgba(0, 0, 0, 0.05);
}

/* 健康建议头部 */
.health-tips-header {
  margin-bottom: 1rem;
  display: flex;
  gap: 0.5rem;
  align-items: center;
}

/* 健康建议图标容器 */
.health-tips-icon {
  background: linear-gradient(to right, var(--color-success), var(--color-success));
  border-radius: 50%;
  display: flex;
  height: 2.5rem;
  width: 2.5rem;
  align-items: center;
  justify-content: center;
}

/* 健康建议图标 */
.health-tips-icon-heart {
  color: var(--color-success-content);
  width: 1.25rem;
  height: 1.25rem;
}

/* 健康建议标题 */
.health-tips-title {
  font-size: 1.125rem;
  color: var(--color-base-content);
  font-weight: 600;
}

/* 健康建议列表 */
.health-tips-list {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

/* 健康建议项目 */
.health-tip-item {
  padding: 0.75rem;
  border-radius: 0.5rem;
  background-color: var(--color-base-200);
  display: flex;
  gap: 0.75rem;
  align-items: center;
}

/* 健康建议项目图标 */
.health-tip-icon {
  color: var(--color-info-content);
  width: 1.25rem;
  height: 1.25rem;
}

/* 健康建议项目文本 */
.health-tip-text {
  font-size: 0.875rem;
  color: var(--color-base-content);
  line-height: 1.6;
}

/* 深色模式适配 */
.dark .health-tips {
  background-color: var(--color-base-200);
  border-color: var(--color-base-300);
}

.dark .health-tip-item {
  background-color: color-mix(in oklch, var(--color-info) 30%, var(--color-base-200));
}
</style>
