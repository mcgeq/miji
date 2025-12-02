<!--
  -----------------------------------------------------------------------------
  Copyright (C) 2025 mcge. All rights reserved.
  Author:         mcge
  Email:          <mcgeq@outlook.com>
  File:           PriorityBadge.svelte
  Description:    About Priority
  Create   Date:  2025-06-21 20:20:20
  Last Modified:  2025-06-21 20:20:20
  Modified   By:  mcge <mcgeq@outlook.com>
  -----------------------------------------------------------------------------
-->
<script setup lang="ts">
import { PrioritySchema } from '@/schema/common';
import type { Priority } from '@/schema/common';
import type { CSSProperties } from 'vue';

const props = defineProps<{
  serialNum: string;
  priority: Priority;
  completed: boolean;
  onChangePriority: (serialNum: string, p: Priority) => void;
}>();

const emit = defineEmits<{
  (e: 'changePriority', serialNum: string, priority: Priority): void;
}>();

const priorities: Priority[] = PrioritySchema.options;

const showMenu = ref(false);
const { t } = useI18n();

// 弹窗位置计算
const menuStyle = computed<Partial<CSSProperties>>(() => {
  if (!showMenu.value) return {};

  // 获取按钮位置
  const button = document.querySelector(`[data-priority-btn="${props.serialNum}"]`) as HTMLElement;
  if (!button) return {};

  const rect = button.getBoundingClientRect();
  return {
    position: 'fixed',
    top: `${rect.bottom + 4}px`,
    left: `${rect.left}px`,
    zIndex: '10000',
  };
});

const priorityKeyMap = {
  LOW: 'todos.priority.low',
  MEDIUM: 'todos.priority.medium',
  HIGH: 'todos.priority.high',
  URGENT: 'todos.priority.urgent',
} as const;

const gradientMap = {
  LOW: 'from-emerald-400 to-emerald-500',
  MEDIUM: 'from-amber-400 to-amber-500',
  HIGH: 'from-red-400 to-red-500',
  URGENT: 'from-red-600 to-red-700', // 更深的红色，更加醒目
} as const;

const textColorMap = {
  LOW: 'text-white font-bold',
  MEDIUM: 'text-white font-bold',
  HIGH: 'text-white font-bold',
  URGENT: 'text-white font-bold',
} as const;

const normalizedPriority = computed(
  () => props.priority.toUpperCase() as keyof typeof priorityKeyMap,
);

const priorityLabel = computed(() =>
  t(priorityKeyMap[normalizedPriority.value]),
);

const priorityClasses = computed(() => ({
  gradient: gradientMap[normalizedPriority.value],
  text: textColorMap[normalizedPriority.value],
}));

function selectPriority(serialNum: string, p: Priority) {
  showMenu.value = false;
  emit('changePriority', serialNum, p);
}

// 获取优先级按钮类名
function getPriorityButtonClass() {
  const baseClasses = [
    'absolute top-2 left-3',
    'flex items-center justify-center',
    'h-5 w-5 shrink-0',
    'border-2 border-white/30 rounded-full',
    'text-xs font-bold',
    'backdrop-blur-md',
    'shadow-[0_2px_8px_rgba(0,0,0,0.2)]',
    'transition-all duration-300 ease-out',
    'cursor-pointer z-10',
    `bg-gradient-to-br ${priorityClasses.value.gradient}`,
    priorityClasses.value.text,
  ];

  const hoverClasses = [
    'hover:shadow-[0_10px_15px_rgba(0,0,0,0.25)]',
    'hover:scale-125',
  ];

  const disabledClasses = props.completed
    ? ['cursor-not-allowed', 'opacity-60']
    : [];

  const urgentClasses = normalizedPriority.value === 'URGENT'
    ? ['animate-[urgent-pulse_2s_ease-in-out_infinite]', 'shadow-[0_0_12px_rgba(220,38,38,0.5)]']
    : [];

  return [...baseClasses, ...hoverClasses, ...disabledClasses, ...urgentClasses].join(' ');
}

// 获取菜单选项类名
function getMenuOptionClass(p: Priority) {
  const baseClasses = [
    'block w-full',
    'px-2.5 py-1',
    'text-[13px] font-medium',
    'rounded-md text-left',
    'transition-all duration-150 ease-in-out',
  ];

  const isActive = p === props.priority;

  const stateClasses = isActive
    ? [
        'bg-[light-dark(#e5e7eb,#4b5563)]',
        'font-semibold',
        'text-[light-dark(#000,#fff)]',
      ]
    : [
        'text-[light-dark(#1f2937,#f9fafb)]',
        'hover:bg-[light-dark(#f3f4f6,#374151)]',
        'active:scale-[0.98]',
      ];

  return [...baseClasses, ...stateClasses].join(' ');
}
</script>

<template>
  <!-- 优先级按钮 -->
  <button
    :class="getPriorityButtonClass()"
    :title="priorityLabel"
    :aria-label="priorityLabel"
    :disabled="completed"
    :data-priority-btn="serialNum"
    @click="showMenu = !showMenu"
  >
    <span class="drop-shadow-[0_1px_2px_rgba(0,0,0,0.25)]">{{ priorityLabel }}</span>
  </button>

  <!-- 下拉菜单 -->
  <Teleport to="body">
    <div
      v-if="showMenu"
      :style="menuStyle"
      class="w-10 p-1 border border-[light-dark(#e5e7eb,#374151)] rounded-lg bg-[light-dark(white,#1f2937)] backdrop-blur-md shadow-[0_8px_16px_rgba(0,0,0,0.2)] dark:shadow-[0_12px_24px_rgba(0,0,0,0.5)]"
    >
      <button
        v-for="p in priorities"
        :key="p"
        :class="getMenuOptionClass(p)"
        @click="selectPriority(serialNum, p)"
      >
        {{ t(priorityKeyMap[p.toUpperCase() as keyof typeof priorityKeyMap] || priorityKeyMap.LOW) }}
      </button>
    </div>
  </Teleport>
</template>
