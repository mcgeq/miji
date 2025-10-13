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
const menuStyle = computed(() => {
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
</script>

<template>
  <!-- 优先级按钮 -->
  <button
    class="priority-btn"
    :class="[
      priorityClasses.gradient,
      priorityClasses.text,
      { urgent: normalizedPriority === 'URGENT' },
    ]"
    :title="priorityLabel"
    :aria-label="priorityLabel"
    :disabled="completed"
    :data-priority-btn="serialNum"
    @click="showMenu = !showMenu"
  >
    <span class="priority-label">{{ priorityLabel }}</span>
  </button>

  <!-- 下拉菜单 -->
  <Teleport to="body">
    <div
      v-if="showMenu"
      class="priority-menu"
      :style="menuStyle"
    >
      <button
        v-for="p in priorities"
        :key="p"
        class="priority-option"
        :class="[
          p === priority
            ? 'priority-option--active'
            : 'priority-option--inactive',
        ]"
        @click="selectPriority(serialNum, p)"
      >
        {{ t(priorityKeyMap[p.toUpperCase() as keyof typeof priorityKeyMap] || priorityKeyMap.LOW) }}
      </button>
    </div>
  </Teleport>
</template>

<style scoped lang="postcss">
/* 优先级按钮 */
.priority-btn {
  position: absolute;
  top: 0.25rem; /* top-1 */
  left: 0.5rem; /* 向右移动，避免与颜色条重叠 */
  display: flex;
  align-items: center;
  justify-content: center;
  height: 1.5rem; /* h-6 */
  width: 1.5rem;  /* w-6 */
  border: 2px solid rgba(255, 255, 255, 0.3);
  border-radius: 9999px; /* rounded-full */
  font-size: 0.75rem; /* text-xs */
  font-weight: 700; /* font-bold */
  background: linear-gradient(135deg, var(--gradient-start), var(--gradient-end));
  backdrop-filter: blur(8px); /* backdrop-blur-md */
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.2);
  transition: all 0.3s ease-out;
  cursor: pointer;
  text-shadow: 0 1px 2px rgba(0, 0, 0, 0.3);
}
.priority-btn:hover {
  box-shadow: 0 10px 15px rgba(0, 0, 0, 0.25);
  transform: scale(1.25);
}

/* 紧急优先级特殊效果 */
.priority-btn.urgent {
  animation: urgent-pulse 2s ease-in-out infinite;
  box-shadow: 0 0 12px rgba(220, 38, 38, 0.5);
}

@keyframes urgent-pulse {
  0%, 100% {
    box-shadow: 0 0 12px rgba(220, 38, 38, 0.5);
  }
  50% {
    box-shadow: 0 0 20px rgba(220, 38, 38, 0.8);
  }
}
.priority-btn:disabled {
  cursor: not-allowed;
  opacity: 0.6;
}

/* 内部文字 */
.priority-label {
  text-shadow: 0 1px 2px rgba(0, 0, 0, 0.25); /* drop-shadow-sm */
}

/* 动画 */
.priority-btn:hover {
  animation: pulse-subtle 2s ease-in-out infinite;
}
@keyframes pulse-subtle {
  0%, 100% {
    transform: scale(1);
    opacity: 1;
  }
  50% {
    transform: scale(1.1);
    opacity: 0.8;
  }
}

/* 下拉菜单容器 */
.priority-menu {
  width: 2.5rem; /* w-10 */
  padding: 0.25rem; /* p-1 */
  border: 1px solid var(--color-base-300); /* border-gray-200 */
  border-radius: 0.5rem; /* rounded-lg */
  background: var(--color-base-100);
  backdrop-filter: blur(8px);
  box-shadow: 0 8px 16px rgba(0,0,0,0.2);
}

/* 深色模式 */
@media (prefers-color-scheme: dark) {
  .priority-btn {
    box-shadow: 0 0 10px rgba(255, 255, 255, 0.15);
  }
  .priority-menu {
    background: #1f2937; /* neutral-800 */
    border-color: #374151; /* neutral-700 */
    box-shadow: 0 12px 24px rgba(0,0,0,0.5);
  }
}

/* 菜单项 */
.priority-option {
  display: block;
  width: 100%;
  padding: 0.25rem 0.625rem; /* px-2.5 py-1 */
  font-size: 13px;
  font-weight: 500;
  border-radius: 0.375rem; /* rounded-md */
  text-align: left;
  transition: background-color 0.15s ease-in-out, transform 0.1s ease-in-out;
}
.priority-option:hover {
  background: #f3f4f6; /* hover:bg-gray-100 */
}
.priority-option:active {
  transform: scale(0.98); /* active:scale-[0.98] */
}

/* 激活状态 */
.priority-option--active {
  background: var(--color-neutral-content); /* bg-gray-200 */
  font-weight: 600;
  color: #000;
}
.priority-option--inactive {
  color: #1f2937; /* text-gray-800 */
}

/* 深色模式菜单项 */
@media (prefers-color-scheme: dark) {
  .priority-option--active {
    background: #4b5563; /* neutral-600 */
    color: #fff;
  }
  .priority-option--inactive {
    color: #f9fafb; /* gray-100 */
  }
  .priority-option:hover {
    background: #374151; /* neutral-700 */
  }
}
</style>
