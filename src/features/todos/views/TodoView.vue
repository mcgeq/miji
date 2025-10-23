<!-- src/features/todo/views/TodoView.vue -->
<script setup lang="ts">
import { Plus, X } from 'lucide-vue-next';
import InputCommon from '@/components/common/InputCommon.vue';
import { FilterBtnSchema, PrioritySchema, StatusSchema } from '@/schema/common';
import { TodoCreateSchema } from '@/schema/todos';
import { DateUtils } from '@/utils/date';
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
  <main class="main-container">
    <!-- 输入框容器 -->
    <div class="input-wrapper">
      <!-- 切换按钮 -->
      <button
        v-if="showBtn"
        class="toggle-btn"
        aria-label="Toggle Input"
        @click="toggleInput"
      >
        <component
          :is="showInput ? X : Plus"
          class="toggle-icon"
          :class="showInput ? 'toggle-icon-close' : ''"
        />
      </button>

      <!-- 展开输入区域 -->
      <Transition name="fade-slide">
        <div v-show="showInput" class="input-area">
          <InputCommon v-model="newT" @add="handleAdd" />
        </div>
      </Transition>

      <!-- 过滤按钮 -->
      <Transition name="fade-slide">
        <div v-show="!showInput" class="filter-container">
          <div class="filter-group">
            <button
              v-for="item in filterButtons"
              :key="item.value"
              :data-active="filterBtn === item.value"
              class="filter-btn"
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
      class="pagination-wrapper"
    >
      <SimplePagination
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

<style scoped lang="postcss">
.main-container {
  margin: 0 auto;
  padding: 1rem;
  display: flex;
  flex-direction: column;
  width: 40rem;
  min-height: 100vh;
  position: relative;
  background-color: var(--color-base-200);
  /* 创建较低的层叠上下文，避免覆盖全局 toast */
  z-index: 0;
}

:global(.Vue-Toastification__container) {
  z-index: 2147483647 !important;
  pointer-events: none !important;
}
:global(.Vue-Toastification__toast) {
  pointer-events: auto !important;
}

/* 输入框容器 */
.input-wrapper {
  margin-bottom: 1rem;
  height: 60px;
  position: relative;
  z-index: 10000; /* 确保输入框在TodoList之上 */
}

/* 切换按钮 */
.toggle-btn {
  position: absolute;
  top: 50%;
  left: 0;
  z-index: 10;
  display: flex;
  height: 2rem;
  width: 2rem;
  align-items: center;
  justify-content: center;
  background-color: var(--color-base-300);
  color: var(--color-info);
  border-radius: 9999px;
  border: 1px solid var(--color-info);
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
  transform: translateY(-50%);
  transition: all 0.3s ease;
}

.toggle-btn:hover {
  background-color: var(--color-neutral);
  color: var(--color-neutral-content);
}

.toggle-btn:active {
  transform: translateY(-50%) scale(0.95);
}

/* 按钮里的图标 */
.toggle-icon {
  height: 1rem;
  width: 1rem;
}

.toggle-icon-close {
  color: var(--color-error, #ef4444);
}

/* 输入框展开区域 */
.input-area {
  width: 100%;
  padding-left: 2.1rem;
}

/* 过滤容器 */
.filter-container {
  position: absolute;
  border-radius: 6rem;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--color-base-100);
  box-shadow: 0 4px 6px rgba(0,0,0,0.1);
  transition: opacity 0.3s ease-in-out;
}

.filter-group {
  display: inline-flex;
  gap: 0.5rem;
  padding: 0.5rem 0.75rem;
  background-color: var(--color-base-200, #fff);
  border: 1px solid var(--color-neutral);
  border-radius: 9999px;
  box-shadow: 0 1px 2px rgba(0,0,0,0.05);
  transition: all 0.3s ease;
}

/* 单个过滤按钮 */
.filter-btn {
  font-size: 0.875rem;
  font-weight: 600;
  padding: 0.25rem 0.75rem;
  border-radius: 9999px;
  border: 1px solid transparent;
  background-color: var(--color-neutral-content, #f3f4f6);
  color: var(--color-base-content, #374151);
  cursor: pointer;
  transition: all 0.3s ease;
}

.filter-btn:hover {
  background-color: var(--color-info-soft, #e0f2fe);
  color: var(--color-info, #1d4ed8);
}

/* 激活状态 */
.filter-btn[data-active="true"] {
  background-color: var(--color-info, #2563eb);
  color: var(--color-primary-content, #fff);
}

/* 分页容器 */
.pagination-wrapper {
  margin-bottom: 0.25rem;
  margin-top: auto;
}

/* 移除分页组件自身的阴影和背景色 */
.pagination-wrapper :deep(.pagination-container) {
  box-shadow: none;
  background-color: transparent !important;
}

/* 动画 */
.fade-slide-enter-active,
.fade-slide-leave-active {
  transition: opacity 0.3s ease, transform 0.3s ease;
  will-change: opacity, transform;
}

.fade-slide-enter-from,
.fade-slide-leave-to {
  opacity: 0;
  transform: scale(0.95) translateY(-6px);
}

.fade-slide-enter-to,
.fade-slide-leave-from {
  opacity: 1;
  transform: scale(1) translateY(0);
}
.fade-slide-enter-active,
.fade-slide-leave-active {
  transition: opacity 0.3s ease, transform 0.3s ease;
  will-change: opacity, transform;
}

.fade-slide-enter-from,
.fade-slide-leave-to {
  opacity: 0;
  transform: scale(0.95) translateY(-6px);
}

.fade-slide-enter-to,
.fade-slide-leave-from {
  opacity: 1;
  transform: scale(1) translateY(0);
}

@media (max-width: 768px) {
  .main-container {
    width: 100%;
    padding: 0.25rem;
    padding-bottom: 4rem; /* 为底部导航留出空间 */
  }
  .input-area {
    padding-left: 0.5rem;
    z-index: 10001; /* 确保输入区域在TodoList之上 */
  }
  .toggle-btn {
    left: 0.25rem;
  }
  .input-wrapper {
    padding: 0.5rem;
  }

  .pagination-wrapper {
    margin-bottom: 4rem; /* 为底部导航栏预留空间 */
    margin-top: 0.5rem;
    position: sticky;
    bottom: 0;
    background-color: transparent;
    padding: 0.25rem 0.5rem;
    border-radius: 0.5rem;
    box-shadow: 0 -2px 8px rgba(0, 0, 0, 0.1);
  }

  /* 移除分页组件自身的阴影和背景色，避免双重阴影 */
  .pagination-wrapper :deep(.pagination-container) {
    box-shadow: none;
    background-color: transparent !important;
  }
}
</style>
