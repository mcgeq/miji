<script setup lang="ts">
import type { Component } from 'vue';

/**
 * Avatar - 头像组件
 *
 * 支持图片、文字、图标、状态指示
 * 100% Tailwind CSS 4
 */

interface Props {
  /** 头像图片URL */
  src?: string;
  /** 备用文字 (通常是姓名首字母) */
  alt?: string;
  /** 尺寸 */
  size?: 'xs' | 'sm' | 'md' | 'lg' | 'xl' | '2xl';
  /** 形状 */
  shape?: 'circle' | 'square';
  /** 状态指示器 */
  status?: 'online' | 'offline' | 'busy' | 'away' | null;
  /** 自定义图标 */
  icon?: Component;
}

const props = withDefaults(defineProps<Props>(), {
  size: 'md',
  shape: 'circle',
  status: null,
});

// 尺寸映射
const sizeClasses = {
  'xs': 'w-6 h-6 text-xs',
  'sm': 'w-8 h-8 text-sm',
  'md': 'w-10 h-10 text-base',
  'lg': 'w-12 h-12 text-lg',
  'xl': 'w-16 h-16 text-xl',
  '2xl': 'w-20 h-20 text-2xl',
};

// 状态颜色
const statusColors = {
  online: 'bg-green-500',
  offline: 'bg-gray-400',
  busy: 'bg-red-500',
  away: 'bg-yellow-500',
};

// 状态指示器尺寸
const statusSizes = {
  'xs': 'w-1.5 h-1.5',
  'sm': 'w-2 h-2',
  'md': 'w-2.5 h-2.5',
  'lg': 'w-3 h-3',
  'xl': 'w-3.5 h-3.5',
  '2xl': 'w-4 h-4',
};

// 获取首字母
const initials = computed(() => {
  if (!props.alt) return '';
  const words = props.alt.trim().split(' ');
  if (words.length >= 2) {
    return (words[0][0] + words[1][0]).toUpperCase();
  }
  return props.alt.slice(0, 2).toUpperCase();
});
</script>

<template>
  <div class="relative inline-block">
    <!-- 头像容器 -->
    <div
      class="inline-flex items-center justify-center overflow-hidden bg-gradient-to-br from-blue-500 to-purple-600 text-white font-semibold" :class="[
        sizeClasses[size],
        shape === 'circle' ? 'rounded-full' : 'rounded-lg',
      ]"
    >
      <!-- 图片 -->
      <img
        v-if="src"
        :src="src"
        :alt="alt"
        class="w-full h-full object-cover"
      >

      <!-- 自定义图标 -->
      <component
        :is="icon"
        v-else-if="icon"
        :class="[
          size === 'xs' && 'w-3 h-3',
          size === 'sm' && 'w-4 h-4',
          size === 'md' && 'w-5 h-5',
          size === 'lg' && 'w-6 h-6',
          size === 'xl' && 'w-8 h-8',
          size === '2xl' && 'w-10 h-10',
        ]"
      />

      <!-- 首字母 -->
      <span v-else-if="initials">
        {{ initials }}
      </span>

      <!-- 默认图标 -->
      <LucideUser
        v-else
        :class="[
          size === 'xs' && 'w-3 h-3',
          size === 'sm' && 'w-4 h-4',
          size === 'md' && 'w-5 h-5',
          size === 'lg' && 'w-6 h-6',
          size === 'xl' && 'w-8 h-8',
          size === '2xl' && 'w-10 h-10',
        ]"
      />
    </div>

    <!-- 状态指示器 -->
    <span
      v-if="status"
      class="absolute bottom-0 right-0 block rounded-full ring-2 ring-white dark:ring-gray-900" :class="[
        statusColors[status],
        statusSizes[size],
      ]"
    />
  </div>
</template>
