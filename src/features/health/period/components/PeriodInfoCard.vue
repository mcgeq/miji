<script setup lang="ts">
  import type { Component } from 'vue';
  import Card from '@/components/ui/Card.vue';

  interface Props {
    title: string;
    icon: Component;
    color?: 'blue' | 'green' | 'purple' | 'orange';
    helpText?: string; // 可选的右侧提示文字
    showBottomBorder?: boolean; // 是否显示标题底部边框
    bgClass?: string; // 可选的背景色类名
  }

  const props = withDefaults(defineProps<Props>(), {
    color: 'blue',
    helpText: undefined,
    showBottomBorder: true,
    bgClass: undefined,
  });

  // 根据颜色生成对应的类名
  const colorClasses = computed(() => {
    const colorMap = {
      blue: {
        border: 'border-l-blue-500 dark:border-l-blue-400',
        bottomBorder: 'border-blue-500 dark:border-blue-400',
        icon: 'text-blue-600 dark:text-blue-400',
        title: 'text-blue-600 dark:text-blue-400',
        helpText: 'text-blue-500 dark:text-blue-400',
      },
      green: {
        border: 'border-l-green-500 dark:border-l-green-400',
        bottomBorder: 'border-green-500 dark:border-green-400',
        icon: 'text-green-600 dark:text-green-400',
        title: 'text-green-600 dark:text-green-400',
        helpText: 'text-green-500 dark:text-green-400',
      },
      purple: {
        border: 'border-l-purple-500 dark:border-l-purple-400',
        bottomBorder: 'border-purple-500 dark:border-purple-400',
        icon: 'text-purple-600 dark:text-purple-400',
        title: 'text-purple-600 dark:text-purple-400',
        helpText: 'text-purple-500 dark:text-purple-400',
      },
      orange: {
        border: 'border-l-orange-500 dark:border-l-orange-400',
        bottomBorder: 'border-orange-500 dark:border-orange-400',
        icon: 'text-orange-600 dark:text-orange-400',
        title: 'text-orange-600 dark:text-orange-400',
        helpText: 'text-orange-500 dark:text-orange-400',
      },
    };

    return colorMap[props.color];
  });

  // 合并背景色类名
  const cardClasses = computed(() => {
    const classes = ['flex-1 self-stretch border-l-4', colorClasses.value.border];
    if (props.bgClass) {
      classes.push(props.bgClass);
    }
    return classes;
  });
</script>

<template>
  <Card shadow="md" padding="md" :class="cardClasses">
    <!-- 自定义头部 -->
    <template #header>
      <div
        class="flex items-center justify-between gap-2.5"
        :class="[
          showBottomBorder ? 'pb-2.5 border-b-2' : 'mb-1',
          showBottomBorder ? colorClasses.bottomBorder : '',
        ]"
      >
        <!-- 左侧：图标+标题 -->
        <div class="flex items-center gap-2.5">
          <component :is="icon" class="w-5 h-5" :class="[colorClasses.icon]" />
          <h3 class="text-base font-bold m-0" :class="[colorClasses.title]">{{ title }}</h3>
        </div>

        <!-- 右侧：可选的提示文字 -->
        <span v-if="helpText" class="text-xs" :class="[colorClasses.helpText]">
          {{ helpText }}
        </span>
      </div>
    </template>

    <!-- 内容插槽 -->
    <slot />
  </Card>
</template>
