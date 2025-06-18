<!-- src/components/TodoItem.svelte -->

<script lang="ts">
import { escapeHTML } from '@/lib/utils/sanitize';
import { CheckCircle, Circle, Pencil, Trash2 } from '@lucide/svelte';
import { differenceInSeconds, intervalToDuration, format } from 'date-fns';
import { onDestroy } from 'svelte';
import { t } from 'svelte-i18n';

let {
  text,
  completed,
  dueAt,
  onToggle = () => {},
  onRemove = () => {},
  onEdit = () => {},
} = $props<import('@/types/todos').TodoItemProps>();

let maxChars = $state(18);
let displayText = $derived.by(() => {
  return text.length > maxChars ? `${text.slice(0, maxChars)}...` : text;
});

let remainingTime = $state('');
let intervalId: ReturnType<typeof setInterval> | null = null;
let prevDueAt: string | Date | undefined;
let prevCompleted: boolean | undefined;

$effect(() => {
  if (dueAt !== prevDueAt || completed !== prevCompleted) {
    prevDueAt = dueAt;
    prevCompleted = completed;
    setupInterval();
  }
});

function calculateRemainingTime(dueDate: string | Date) {
  const now = new Date();
  const diffSeconds = differenceInSeconds(new Date(dueDate), now);

  if (diffSeconds <= 0) {
    clearIntervalSafe();
    return $t('todos.expired');
  }
  const duration = intervalToDuration({ start: 0, end: diffSeconds * 1000 });

  if ((duration.days || 0) > 0) {
    return `${$t('todos.due_at')}: ${duration.days || 0}d ${duration.hours || 0}h ${duration.minutes || 0}m`;
  }

  return `${$t('todos.due_at')}: ${duration.hours || 0}h ${duration.minutes || 0}m`;
}

function clearIntervalSafe() {
  if (intervalId !== null) {
    clearInterval(intervalId);
    intervalId = null;
  }
}

function setupInterval() {
  clearIntervalSafe();

  if (!dueAt) {
    remainingTime = '';
    return;
  }

  if (completed) {
    remainingTime = `${$t('todos.completed')}: ${format(new Date(), 'yyyy-MM-dd HH:mm:ss')}`;
    return;
  }
  updateRemainingTime();

  intervalId = setInterval(
    () => {
      updateRemainingTime();
    },
    5 * 60 * 1000,
  );
}

function updateRemainingTime() {
  if (!dueAt) {
    remainingTime = '';
    return;
  }
  remainingTime = calculateRemainingTime(dueAt);
}

onDestroy(() => {
  clearIntervalSafe();
});
</script>


<div
  class="p-4 bg-white rounded-2xl border border-gray-200 flex flex-col h-18 mb-1 relative">
  <!-- 上半部分：主内容 -->
  <div class="flex items-center justify-between flex-1">
    <div class="flex items-center gap-2">
      <button
        type="button"
        class="flex items-center focus:outline-none"
        onclick={onToggle}
        aria-pressed={completed}
      >
        {#if completed}
          <CheckCircle class="w-5 h-5 text-green-500" />
        {:else}
          <Circle class="w-5 h-5 text-gray-400" />
        {/if}
      </button>

      <span
        class="text-left text-sm leading-snug line-clamp-1"
        class:text-gray-400={completed}
        title={text}
      >
        {@html escapeHTML(displayText)}
      </span>
    </div>

    <div class="flex items-center gap-3">  <!-- 右侧按钮，垂直居中 -->
      <button
        type="button"
        onclick={onEdit}
        aria-label="Edit task"
        class="text-gray-400 hover:text-blue-500 transition"
      >
        <Pencil class="w-4 h-4" />
        <span class="sr-only">Edit</span>
      </button>

      <button
        type="button"
        onclick={onRemove}
        aria-label="Delete task"
        class="text-red-400 hover:text-red-600 transition"
      >
        <Trash2 class="w-5 h-5" />
        <span class="sr-only">Delete</span>
      </button>
    </div>
  </div>

  <!-- 底部右下角 dueAt -->
  {#if dueAt}
    <div class="text-xs text-gray-500 absolute right-4 bottom-1">
      {remainingTime}
    </div>
  {/if}
</div>
