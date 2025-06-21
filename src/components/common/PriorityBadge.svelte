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
<script lang="ts">
import { PrioritySchema, type Priority } from '@/lib/schema/common';
import { t } from 'svelte-i18n';

let {
  serialNum,
  priority = $bindable(''),
  onChangePriority = () => {},
} = $props<import('@/types/todos').TodoPriorityProps>();

let showMenu = $state(false);

const PRIORITY_KEY_MAP = {
  LOW: 'todos.priority.low',
  MEDIUM: 'todos.priority.medium',
  HIGH: 'todos.priority.high',
  URGENT: 'todos.priority.urgent',
} as const;

const PRIORITY_GRADIENT_MAP = {
  LOW: 'from-emerald-300 to-teal-200',
  MEDIUM: 'from-amber-300 to-orange-200',
  HIGH: 'from-rose-400 to-red-300',
  URGENT: 'from-purple-400 to-red-400',
} as const;

const PRIORITY_TEXT_COLOR_MAP = {
  LOW: 'text-emerald-900',
  MEDIUM: 'text-amber-900',
  HIGH: 'text-rose-800',
  URGENT: 'text-purple-800',
} as const;

const PRIORITIES = Object.values(PrioritySchema.enum) as Priority[];

const normalizePriority = (p: string | Priority) =>
  p.toUpperCase() as keyof typeof PRIORITY_KEY_MAP;

const priorityChar = (priority: string | Priority): string => {
  const key = normalizePriority(priority);
  return $t(PRIORITY_KEY_MAP[key] || PRIORITY_KEY_MAP.LOW);
};

const getClasses = (priority: string | Priority) => {
  const key = normalizePriority(priority);

  return {
    gradient: PRIORITY_GRADIENT_MAP[key] || PRIORITY_GRADIENT_MAP.LOW,
    text: PRIORITY_TEXT_COLOR_MAP[key] || PRIORITY_TEXT_COLOR_MAP.LOW,
  };
};

const selectPriority = (p: Priority) => {
  priority = p;
  onChangePriority(serialNum, p);
  showMenu = false;
};
</script>


<button
  onclick={() => showMenu = !showMenu}
  class="absolute left-1 top-1 w-5 h-5 rounded-full flex items-center justify-center text-xs font-semibold
  transition-all duration-300 ease-out
  hover:scale-125 hover:shadow-lg
  bg-opacity-90 backdrop-blur-md
  border border-white/30
  shadow-[0_0_10px_rgba(0,0,0,0.15)] dark:shadow-[0_0_10px_rgba(255,255,255,0.15)]
  animate-pulse-subtle
"
  class:bg-gradient-to-br={getClasses(priority)}
  class:text-emerald-900={priority === 'Low'}
  class:text-amber-900={priority === 'Medium'}
  class:text-red-800={priority === 'High'}
  class:text-purple-800={priority === 'Urgent'}
  style="will-change: transform, box-shadow;"
  title={$t(`todos.priority.${priority.toLowerCase()}`)}
  aria-label={$t(`todos.priority.${priority.toLowerCase()}`)}
>
  <span class="drop-shadow-sm">{priorityChar(priority)}</span>
</button>


{#if showMenu}
  <div
    class="absolute top-7 left-0 z-50 w-10 bg-white dark:bg-neutral-800
           rounded-lg border border-gray-200 dark:border-neutral-700
           shadow-md dark:shadow-lg p-1
           backdrop-blur-md"
  >
    {#each PRIORITIES as p}
    <button
      onclick={() => selectPriority(p)}
      class="block w-full px-2.5 py-1 text-[13px] font-medium tracking-wide
         text-gray-800 dark:text-gray-100
         rounded-md transition-colors duration-150 ease-in-out
         hover:bg-gray-100 dark:hover:bg-neutral-700
         active:scale-[0.98]
         {priority === p ? 'bg-gray-200 dark:bg-neutral-600 font-semibold text-black dark:text-white' : ''}"
    >
      {priorityChar(p)}
    </button>
  {/each}
  </div>
{/if}
<style>

.animate-pulse-subtle:hover {
  animation: pulse-subtle 2s ease-in-out infinite;
}

</style>
