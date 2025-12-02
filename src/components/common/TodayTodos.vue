<!-- src/components/common/TodayTodos.vue -->
<script setup lang="ts">
import TodoInput from '@/features/todos/components/TodoInput.vue';
import TodoList from '@/features/todos/components/TodoList.vue';
import { useTodosFilters } from '@/features/todos/composables/useTodosFilters';
import { FilterBtnSchema, PrioritySchema, StatusSchema } from '@/schema/common';
import { TodoCreateSchema } from '@/schema/todos';
import { useTodoStore } from '@/stores/todoStore';
import { DateUtils } from '@/utils/date';
import type { Status } from '@/schema/common';
import type { TodoCreate, TodoUpdate } from '@/schema/todos';

const todoStore = useTodoStore();
const newT = ref('');
const showModal = ref(false);
const todos = computed(() => todoStore.todosPaged);

// 使用今日过滤器
const { filterBtn, pagination, loadTodos } = useTodosFilters(
  () => todos.value,
  10, // 增加显示数量，让内容铺满
);

// 设置默认为今日
filterBtn.value = FilterBtnSchema.enum.TODAY;

function openModal() {
  showModal.value = true;
}

function closeModal() {
  showModal.value = false;
  newT.value = '';
}

async function handleAdd(text: string) {
  const trimmed = text.trim();
  if (!trimmed) return;

  const newTodo: TodoCreate = {
    title: trimmed,
    description: null,
    dueAt: DateUtils.getEndOfTodayISOWithOffset(),
    priority: PrioritySchema.enum.Medium,
    status: StatusSchema.enum.InProgress,
    repeatPeriodType: 'None',
    repeat: { type: 'None' },
    completedAt: null,
    assigneeId: null,
    progress: 0,
    location: null,
    ownerId: null,
    isArchived: false,
    isPinned: false,
    estimateMinutes: null,
    reminderCount: 0,
    parentId: null,
    subtaskOrder: null,
    // 提醒相关字段
    reminderEnabled: false,
    reminderAdvanceValue: null,
    reminderAdvanceUnit: null,
    lastReminderSentAt: null,
    reminderFrequency: null,
    snoozeUntil: null,
    reminderMethods: null,
    timezone: null,
    smartReminderEnabled: false,
    locationBasedReminder: false,
    weatherDependent: false,
    priorityBoostEnabled: false,
    batchReminderId: null,
  };

  try {
    const nCreateTodo = TodoCreateSchema.parse(newTodo);
    await todoStore.createTodo(nCreateTodo);
    newT.value = '';
    closeModal();
  } catch (error) {
    console.error('Todo creation validation error:', error);
  }
}

async function handleToggle(serialNum: string, status: Status) {
  await todoStore.toggleTodo(serialNum, status);
}

async function handleRemove(serialNum: string) {
  await todoStore.deleteTodo(serialNum);
}

async function handleEdit(serialNum: string, todo: TodoUpdate) {
  await todoStore.updateTodo(serialNum, todo);
}

// 键盘快捷键：按 'n' 或 '+' 打开添加modal
function handleKeyPress(event: KeyboardEvent) {
  // 排除在输入框中的情况
  const target = event.target as HTMLElement;
  if (target.tagName === 'INPUT' || target.tagName === 'TEXTAREA') {
    return;
  }

  // 快捷键 'n' 或 '+'
  if (event.key === 'n' || event.key === '+') {
    event.preventDefault();
    openModal();
  }

  // ESC 关闭modal
  if (event.key === 'Escape' && showModal.value) {
    event.preventDefault();
    closeModal();
  }
}

onMounted(async () => {
  await loadTodos();
  window.addEventListener('keydown', handleKeyPress);
});

onUnmounted(() => {
  window.removeEventListener('keydown', handleKeyPress);
});

// 暴露方法给父组件
defineExpose({
  openModal,
  getTodoCount: () => pagination.paginatedItems.value.size,
});
</script>

<template>
  <div class="w-full h-full flex flex-col gap-2 p-1 max-w-full overflow-hidden relative">
    <!-- 今日待办任务列表 - 支持滚动但隐藏滚动条 -->
    <div class="flex-1 overflow-y-auto overflow-x-hidden flex flex-col w-full max-w-full scrollbar-none">
      <TodoList
        :todos="pagination.paginatedItems.value"
        @toggle="handleToggle"
        @remove="handleRemove"
        @edit="handleEdit"
      />
    </div>

    <!-- Modal弹窗 -->
    <Teleport to="body">
      <Transition
        enter-active-class="transition-all duration-300 ease-in-out"
        leave-active-class="transition-all duration-300 ease-in-out"
        enter-from-class="opacity-0"
        leave-to-class="opacity-0"
      >
        <div
          v-if="showModal"
          class="fixed inset-0 bg-black/60 dark:bg-black/70 backdrop-blur-md flex items-center justify-center z-[2147483647] p-4 sm:p-2 overflow-y-auto isolate"
          @click="closeModal"
        >
          <Transition
            enter-active-class="transition-transform duration-300 ease-in-out"
            leave-active-class="transition-transform duration-300 ease-in-out"
            enter-from-class="scale-90 translate-y-5"
            leave-to-class="scale-90 translate-y-5"
          >
            <div
              v-if="showModal"
              class="bg-white dark:bg-gray-800 rounded-2xl shadow-2xl border border-gray-200 dark:border-gray-700 w-full max-w-lg max-h-[85vh] sm:max-h-[90vh] overflow-hidden flex flex-col m-auto"
              @click.stop
            >
              <div class="px-6 py-4 sm:px-4 sm:py-3 border-b border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-900 flex-shrink-0">
                <h3 class="text-lg sm:text-base font-semibold m-0 text-gray-900 dark:text-white">
                  {{ $t('todos.addTodo') || '添加待办' }}
                </h3>
              </div>
              <div class="px-6 py-6 sm:px-4 sm:py-4 overflow-y-auto bg-white dark:bg-gray-800 flex-1 min-h-0">
                <TodoInput v-model="newT" :on-add="handleAdd" />
              </div>
            </div>
          </Transition>
        </div>
      </Transition>
    </Teleport>
  </div>
</template>
