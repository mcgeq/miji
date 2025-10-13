<!-- src/components/common/TodayTodos.vue -->
<script setup lang="ts">
import { Plus, X } from 'lucide-vue-next';
import InputCommon from '@/components/common/InputCommon.vue';
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
const showInput = ref(false);
const todos = computed(() => todoStore.todosPaged);

// 使用今日过滤器
const { filterBtn, pagination, loadTodos } = useTodosFilters(
  () => todos.value,
  5, // 增加显示数量，让内容铺满
);

// 设置默认为今日
filterBtn.value = FilterBtnSchema.enum.TODAY;

function toggleInput() {
  showInput.value = !showInput.value;
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
  };

  try {
    const nCreateTodo = TodoCreateSchema.parse(newTodo);
    await todoStore.createTodo(nCreateTodo);
    newT.value = '';
    showInput.value = false;
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

onMounted(async () => {
  await loadTodos();
});
</script>

<template>
  <div class="today-todos">
    <div class="todo-header">
      <button
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
    </div>

    <!-- 快速添加输入框 -->
    <Transition name="fade-slide">
      <div v-show="showInput" class="input-area">
        <InputCommon v-model="newT" @add="handleAdd" />
      </div>
    </Transition>

    <!-- 今日待办任务列表 -->
    <div class="todo-list-container">
      <TodoList
        :todos="pagination.paginatedItems.value"
        @toggle="handleToggle"
        @remove="handleRemove"
        @edit="handleEdit"
      />
    </div>
  </div>
</template>

<style scoped lang="postcss">
.today-todos {
  width: 100%;
  height: 100%;
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  padding: 0.25rem;
}

.todo-title {
  font-size: 1.25rem;
  font-weight: 600;
  margin: 0;
  color: var(--color-error-content);
}

.toggle-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 1rem;
  height: 1rem;
  border-radius: 50%;
  background-color: rgba(255, 255, 255, 0.2);
  border: none;
  cursor: pointer;
  transition: all 0.2s ease-in-out;
  color: var(--color-error-content);
}

.toggle-btn:hover {
  background-color: rgba(255, 255, 255, 0.3);
  transform: scale(1.1);
}

.toggle-icon {
  width: 1rem;
  height: 1rem;
  transition: transform 0.2s ease-in-out;
}

.toggle-icon-close {
  transform: rotate(45deg);
}

.input-area {
  margin-bottom: 0.25rem;
}

.todo-list-container {
  flex: 1;
  overflow: hidden;
  display: flex;
  flex-direction: column;
}

/* 确保TodoList组件也能铺满容器 */
.todo-list-container :deep(.todolist-main) {
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

/* 过渡动画 */
.fade-slide-enter-active,
.fade-slide-leave-active {
  transition: all 0.3s ease-in-out;
}

.fade-slide-enter-from,
.fade-slide-leave-to {
  opacity: 0;
  transform: translateY(-10px);
}
</style>
