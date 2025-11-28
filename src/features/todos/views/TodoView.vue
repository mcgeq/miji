<!-- src/features/todo/views/TodoView.vue -->
<script setup lang="ts">
import { Plus, X } from 'lucide-vue-next';
import { Pagination } from '@/components/ui';
import { FilterBtnSchema, PrioritySchema, StatusSchema } from '@/schema/common';
import { TodoCreateSchema } from '@/schema/todos';
import { DateUtils } from '@/utils/date';
import TodoInput from '../components/TodoInput.vue';
import TodoList from '../components/TodoList.vue';
import { useTodosFilters } from '../composables/useTodosFilters';
import type { FilterBtn, Status } from '@/schema/common';
import type { TodoCreate, TodoUpdate } from '@/schema/todos';

const todoStore = useTodoStore();
const newT = ref('');
const showInput = ref(false);
const todos = computed(() => todoStore.todosPaged);
const { filterBtn, filterButtons, showBtn, pagination, loadTodos } = useTodosFilters(
  () => todos.value,
  4,
);
function toggleInput() {
  showInput.value = !showInput.value;
  filterBtn.value = FilterBtnSchema.enum.TODAY;
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
    todoStore.createTodo(nCreateTodo);
    newT.value = '';
    await loadTodos();
  } catch (error) {
    console.error('Todo creation validation error:', error);
    // 显示用户友好的错误提示
    if (error instanceof Error && error.message.includes('max')) {
      // 如果是因为长度超限，显示友好提示
      console.warn('标题长度超出限制，请缩短标题');
    }
    // 不清空输入框，让用户修改
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
// 处理页码变化
async function handlePageChange(page: number) {
  pagination.setPage(page);
}

// 处理页面大小变化
async function handlePageSizeChange(pageSize: number) {
  pagination.pageSize.value = pageSize;
}

async function changeFilter(value: FilterBtn) {
  filterBtn.value = value;
}

onMounted(async () => {
  await loadTodos();
});
// Keep page and size synced with store
</script>

<template>
  <main class="mx-auto px-4 py-4 flex flex-col w-full max-w-2xl min-h-screen relative bg-base-200 z-0">
    <!-- 输入框容器 -->
    <div class="mb-4 h-[60px] relative z-[10000]">
      <!-- 切换按钮 -->
      <button
        v-if="showBtn"
        class="absolute top-1/2 left-0 z-10 flex h-8 w-8 items-center justify-center bg-base-300 text-base-content rounded-full border border-base-200 shadow-sm -translate-y-1/2 transition-all duration-300 hover:bg-neutral hover:text-neutral-content active:scale-95"
        aria-label="Toggle Input"
        @click="toggleInput"
      >
        <component
          :is="showInput ? X : Plus"
          class="h-4 w-4"
          :class="showInput ? 'text-error' : ''"
        />
      </button>

      <!-- 展开输入区域 -->
      <Transition name="fade-slide">
        <div v-show="showInput" class="w-full pl-[2.1rem]">
          <TodoInput v-model="newT" :on-add="handleAdd" />
        </div>
      </Transition>

      <!-- 过滤按钮 -->
      <Transition name="fade-slide">
        <div v-show="!showInput" class="absolute inset-0 flex items-center justify-center transition-opacity duration-300">
          <div class="filter-btn-group">
            <button
              v-for="item in filterButtons"
              :key="item.value"
              class="filter-btn"
              :class="filterBtn === item.value ? 'filter-btn-active' : ''"
              @click="changeFilter(item.value)"
            >
              {{ item.label }}
            </button>
          </div>
        </div>
      </Transition>
    </div>

    <!-- 任务列表 -->
    <TodoList
      :todos="pagination.paginatedItems.value"
      @toggle="handleToggle"
      @remove="handleRemove"
      @edit="handleEdit"
    />

    <!-- 分页器 -->
    <div
      v-if="pagination.totalItems.value > pagination.pageSize.value"
      class="mb-1 mt-auto md:mb-0 md:[&>:deep(.pagination-container)]:shadow-none md:[&>:deep(.pagination-container)]:!bg-transparent"
    >
      <Pagination
        :current-page="pagination.currentPage.value"
        :total-pages="pagination.totalPages.value"
        :total-items="pagination.totalItems.value"
        :page-size="pagination.pageSize.value"
        :show-total="false"
        :show-page-size="false"
        :page-size-options="[4, 5, 10, 15, 20]"
        @page-change="handlePageChange"
        @page-size-change="handlePageSizeChange"
      />
    </div>
  </main>
</template>

<style scoped>
/* Toast 全局z-index */

:global(.Vue-Toastification__container) {
  z-index: 2147483647 !important;
  pointer-events: none !important;
}
:global(.Vue-Toastification__toast) {
  pointer-events: auto !important;
}

/* 移动端样式 */
@media (max-width: 768px) {
  main {
    width: 100%;
    padding: 0.25rem;
    padding-bottom: 4rem;
  }

  main > div:last-child {
    margin-bottom: 4rem;
    margin-top: 0.5rem;
    position: sticky;
    bottom: 0;
    background-color: transparent;
    padding: 0.25rem 0.5rem;
    border-radius: 0.5rem;
    box-shadow: 0 -2px 8px rgba(0, 0, 0, 0.1);
  }

  main > div:last-child :deep(.pagination-container) {
    box-shadow: none;
    background-color: transparent !important;
  }
}
</style>
