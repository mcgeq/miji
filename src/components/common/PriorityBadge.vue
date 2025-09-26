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

const priorityKeyMap = {
  LOW: 'todos.priority.low',
  MEDIUM: 'todos.priority.medium',
  HIGH: 'todos.priority.high',
  URGENT: 'todos.priority.urgent',
} as const;

const gradientMap = {
  LOW: 'from-emerald-300 to-teal-200',
  MEDIUM: 'from-amber-300 to-orange-200',
  HIGH: 'from-rose-400 to-red-300',
  URGENT: 'from-purple-400 to-red-400',
} as const;

const textColorMap = {
  LOW: 'text-emerald-900',
  MEDIUM: 'text-amber-900',
  HIGH: 'text-red-800',
  URGENT: 'text-purple-800',
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
    :class="[priorityClasses.gradient, priorityClasses.text]"
    :title="priorityLabel"
    :aria-label="priorityLabel"
    :disabled="completed"
    @click="showMenu = !showMenu"
  >
    <span class="priority-label">{{ priorityLabel }}</span>
  </button>

  <!-- 下拉菜单 -->
  <div v-if="showMenu" class="priority-menu">
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
</template>

<style scoped lang="postcss">
/* 优先级按钮 */
.priority-btn {
  position: absolute;
  top: 0.25rem; /* top-1 */
  left: 0.25rem; /* left-1 */
  display: flex;
  align-items: center;
  justify-content: center;
  height: 1.25rem; /* h-5 */
  width: 1.25rem;  /* w-5 */
  border: 1px solid rgba(255, 255, 255, 0.3); /* border-white/30 */
  border-radius: 9999px; /* rounded-full */
  font-size: 0.75rem; /* text-xs */
  font-weight: 600; /* font-semibold */
  background-color: rgba(255, 255, 255, 0.9); /* bg-opacity-90 */
  backdrop-filter: blur(8px); /* backdrop-blur-md */
  box-shadow: 0 0 10px rgba(0, 0, 0, 0.15);
  transition: all 0.3s ease-out;
  cursor: pointer;
}
.priority-btn:hover {
  box-shadow: 0 10px 15px rgba(0, 0, 0, 0.25);
  transform: scale(1.25);
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
  position: absolute;
  top: 1.75rem; /* top-7 */
  left: 0;
  z-index: 50;
  width: 2.5rem; /* w-10 */
  padding: 0.25rem; /* p-1 */
  border: 1px solid #e5e7eb; /* border-gray-200 */
  border-radius: 0.5rem; /* rounded-lg */
  background: #fff;
  backdrop-filter: blur(8px);
  box-shadow: 0 4px 6px rgba(0,0,0,0.15);
}

/* 深色模式 */
@media (prefers-color-scheme: dark) {
  .priority-btn {
    box-shadow: 0 0 10px rgba(255, 255, 255, 0.15);
  }
  .priority-menu {
    background: #1f2937; /* neutral-800 */
    border-color: #374151; /* neutral-700 */
    box-shadow: 0 8px 16px rgba(0,0,0,0.4);
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
  background: #e5e7eb; /* bg-gray-200 */
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
