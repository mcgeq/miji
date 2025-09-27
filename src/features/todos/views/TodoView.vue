<!-- src/features/todo/views/TodoView.vue -->
<script setup lang="ts">
import { Plus, X } from 'lucide-vue-next';
import InputCommon from '@/components/common/InputCommon.vue';
import Pagination from '@/components/common/Pagination.vue';
import { FilterBtnSchema } from '@/schema/common';
import TodoList from '../components/TodoList.vue';
import type { FilterBtn } from '@/schema/common';
import type { TodoRemain } from '@/schema/todos';

const { t } = useI18n();

const todoStore = useTodoStore();

const filterBtn = ref<FilterBtn>(FilterBtnSchema.enum.TODAY);
const newT = ref('');
const showInput = ref(false);

const showBtn = computed(
  () => filterBtn.value !== FilterBtnSchema.enum.YESTERDAY,
);

const todos = computed(() => todoStore.getPagedTodos());
const totalPages = computed(() => todoStore.totalPages);
const currentPage = ref(todoStore.currentPage);
const pageSize = ref(todoStore.pageSize);

const filterButtons = [
  {
    label: t('todos.quickFilter.yesterday'),
    value: FilterBtnSchema.enum.YESTERDAY,
  },
  { label: t('todos.quickFilter.today'), value: FilterBtnSchema.enum.TODAY },
  {
    label: t('todos.quickFilter.tomorrow'),
    value: FilterBtnSchema.enum.TOMORROW,
  },
] as const;

function toggleInput() {
  showInput.value = !showInput.value;
  filterBtn.value = FilterBtnSchema.enum.TODAY;
}

function handleAdd(text: string) {
  if (text.trim()) {
    todoStore.addTodo(text);
    newT.value = '';
  }
}

function handleToggle(serialNum: string) {
  todoStore.toggleTodo(serialNum);
}

function handleRemove(serialNum: string) {
  todoStore.removeTodo(serialNum);
}

function handleEdit(serialNum: string, todo: TodoRemain) {
  todoStore.editTodo(serialNum, todo);
}

function handlePageJump(page: number) {
  todoStore.setPage(page);
}

function handlePageSizeChange(size: number) {
  todoStore.setPageSize(size);
}

function handleNext() {
  todoStore.nextPage();
}

function handlePrev() {
  todoStore.prevPage();
}

function handleFirst() {
  todoStore.setPage(1);
}

function handleLast() {
  todoStore.setPage(todoStore.totalPages);
}

async function changeFilter(value: FilterBtn) {
  filterBtn.value = value;
  await todoStore.setFilterBtn(value);
}

onMounted(async () => {
  await todoStore.reloadPage();
  if (totalPages.value !== 0) {
    todoStore.setPage(1);
    currentPage.value = 1;
  }
  todoStore.startGlobalTimer();
});

onBeforeUnmount(() => {
  todoStore.stopGlobalTimer();
});

// Keep page and size synced with store
watch(currentPage, val => todoStore.setPage(val));
watch(pageSize, val => todoStore.setPageSize(val));
watch(
  () => todoStore.currentPage,
  val => {
    currentPage.value = val;
  },
);
watch(currentPage, val => {
  todoStore.setPage(val);
});
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
      :todos="todos"
      @toggle="handleToggle"
      @remove="handleRemove"
      @edit="handleEdit"
    />

    <!-- 分页器 -->
    <div class="pagination-wrapper">
      <Pagination
        v-model:current-page="currentPage"
        v-model:page-size="pageSize"
        :total-pages="totalPages"
        @page-jump="handlePageJump"
        @page-size-change="handlePageSizeChange"
        @next="handleNext"
        @prev="handlePrev"
        @first="handleFirst"
        @last="handleLast"
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
  max-width: 40rem;
  min-height: 100vh;
  position: relative;
  background-color: var(--color-base-200);
}

/* 输入框容器 */
.input-wrapper {
  margin-bottom: 1rem;
  height: 60px;
  position: relative;
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
  background-color: var(--color-base-200, #fff);
  color: var(--color-info, #2563eb);
  border-radius: 9999px;
  border: 1px solid var(--color-info, #93c5fd);
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
  transform: translateY(-50%);
  transition: all 0.3s ease;
}

.toggle-btn:hover {
  background-color: var(--color-info-soft, #eff6ff);
  color: var(--color-info, #1d4ed8);
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
  padding-left: 2.5rem;
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
  border: 1px solid var(--color-neutral, #d1d5db);
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
</style>
