<script setup lang="ts">
/**
 * FilterBar - 通用过滤器容器组件
 *
 * 用于List组件的过滤器区域，提供统一的样式和展开/收起功能
 * 100% Tailwind CSS 4
 */

import { MoreHorizontal, RotateCcw } from 'lucide-vue-next';
import { Button } from '@/components/ui';

interface Props {
  /** 是否显示更多过滤器 */
  showMoreFilters?: boolean;
  /** 是否显示展开按钮 */
  showExpandButton?: boolean;
  /** 是否显示重置按钮 */
  showResetButton?: boolean;
}

withDefaults(defineProps<Props>(), {
  showMoreFilters: true,
  showExpandButton: true,
  showResetButton: true,
});

const emit = defineEmits<{
  toggleFilters: [];
  reset: [];
}>();
</script>

<template>
  <div class="bg-white dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-700 p-4 w-full">
    <div class="flex flex-wrap gap-3 items-center justify-center">
      <!-- 主要过滤器（始终显示） -->
      <slot name="primary" />

      <!-- 更多过滤器（可展开/收起） -->
      <template v-if="showMoreFilters">
        <slot name="secondary" />
      </template>

      <!-- 操作按钮组 -->
      <div class="flex gap-2 ml-auto">
        <!-- 展开/收起按钮 -->
        <Button
          v-if="showExpandButton"
          variant="secondary"
          size="sm"
          :icon="MoreHorizontal"
          @click="emit('toggleFilters')"
        />

        <!-- 重置按钮 -->
        <Button
          v-if="showResetButton"
          variant="secondary"
          size="sm"
          :icon="RotateCcw"
          @click="emit('reset')"
        />

        <!-- 自定义操作按钮 -->
        <slot name="actions" />
      </div>
    </div>
  </div>
</template>
