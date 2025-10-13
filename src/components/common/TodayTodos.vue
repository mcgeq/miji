<!-- src/components/common/TodayTodos.vue -->
<script setup lang="ts">
import { Plus } from 'lucide-vue-next';
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
</script>

<template>
  <div class="today-todos">
    <div class="todo-header">
      <button
        class="toggle-btn"
        aria-label="Add Todo"
        @click="openModal"
      >
        <Plus class="toggle-icon" />
      </button>
      <span class="todo-count">{{ pagination.paginatedItems.value.size }}</span>
    </div>

    <!-- 今日待办任务列表 - 支持滚动但隐藏滚动条 -->
    <div class="todo-list-container">
      <TodoList
        :todos="pagination.paginatedItems.value"
        @toggle="handleToggle"
        @remove="handleRemove"
        @edit="handleEdit"
      />
    </div>

    <!-- Modal弹窗 -->
    <Teleport to="body">
      <Transition name="modal-fade">
        <div
          v-if="showModal"
          class="modal-overlay"
          @click="closeModal"
        >
          <div
            class="modal-content"
            @click.stop
          >
            <div class="modal-header">
              <h3 class="modal-title">
                {{ $t('todos.addTodo') || '添加待办' }}
              </h3>
            </div>
            <div class="modal-body">
              <InputCommon v-model="newT" @add="handleAdd" />
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>
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
  max-width: 100%;
  overflow: hidden;
  box-sizing: border-box;
}

.todo-header {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.25rem;
}

.todo-count {
  font-size: 0.875rem;
  font-weight: 600;
  color: var(--color-error-content);
  opacity: 0.9;
  margin-left: auto;
}

.toggle-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 1.5rem;
  height: 1.5rem;
  border-radius: 50%;
  background-color: color-mix(in oklch, var(--color-error-content) 20%, transparent);
  border: none;
  cursor: pointer;
  transition: all 0.2s ease-in-out;
  color: var(--color-error-content);
}

.toggle-btn:hover {
  background-color: color-mix(in oklch, var(--color-error-content) 30%, transparent);
  transform: scale(1.1);
}

.toggle-icon {
  width: 1rem;
  height: 1rem;
  transition: transform 0.2s ease-in-out;
}

/* 列表容器 - 支持滚动但隐藏滚动条 */
.todo-list-container {
  flex: 1;
  overflow-y: auto;
  overflow-x: hidden;
  display: flex;
  flex-direction: column;
  width: 100%;
  max-width: 100%;
  box-sizing: border-box;
  /* 隐藏滚动条 - Firefox */
  scrollbar-width: none;
  /* 隐藏滚动条 - IE/Edge */
  -ms-overflow-style: none;
}

/* 隐藏滚动条 - Chrome/Safari/Opera */
.todo-list-container::-webkit-scrollbar {
  display: none;
}

/* 确保TodoList组件也能铺满容器 */
.todo-list-container :deep(.todolist-main) {
  display: flex;
  flex-direction: column;
}

/* Modal 样式 */
.modal-overlay {
  position: fixed;
  inset: 0;
  background-color: color-mix(in oklch, var(--color-neutral) 60%, transparent);
  backdrop-filter: blur(6px);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 9999;
  padding: 1rem;
  /* 确保在移动端也能正常滚动 */
  overflow-y: auto;
}

.modal-content {
  background-color: var(--color-base-100);
  border-radius: 1rem;
  box-shadow: 0 10px 40px color-mix(in oklch, var(--color-neutral) 30%, transparent);
  border: 1px solid var(--color-base-300);
  width: 100%;
  max-width: 500px;
  max-height: 85vh;
  overflow: hidden;
  display: flex;
  flex-direction: column;
  /* 移动端优化 */
  margin: auto;
}

.modal-header {
  padding: 1rem 1.5rem 0.75rem;
  border-bottom: 1px solid var(--color-base-300);
  background-color: var(--color-base-200);
  flex-shrink: 0;
}

.modal-title {
  font-size: 1.125rem;
  font-weight: 600;
  margin: 0;
  color: var(--color-base-content);
}

.modal-body {
  padding: 1rem 1.5rem 1.5rem;
  overflow-y: auto;
  background-color: var(--color-base-100);
  flex: 1;
  min-height: 0;
}

/* Modal 过渡动画 */
.modal-fade-enter-active,
.modal-fade-leave-active {
  transition: all 0.3s ease-in-out;
}

.modal-fade-enter-from,
.modal-fade-leave-to {
  opacity: 0;
}

.modal-fade-enter-from .modal-content,
.modal-fade-leave-to .modal-content {
  transform: scale(0.9) translateY(20px);
}

.modal-fade-enter-active .modal-content,
.modal-fade-leave-active .modal-content {
  transition: transform 0.3s ease-in-out;
}

/* 响应式 */
@media (max-width: 640px) {
  .modal-overlay {
    padding: 0.5rem;
    align-items: flex-start;
    padding-top: 10vh;
  }

  .modal-content {
    max-width: 95vw;
    max-height: 80vh;
  }

  .modal-header {
    padding: 0.75rem 1rem 0.5rem;
  }

  .modal-title {
    font-size: 1rem;
  }

  .modal-body {
    padding: 0.75rem 1rem 1rem;
  }
}
</style>
