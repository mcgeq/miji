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
  <main class="mx-auto p-4 flex flex-col max-w-xl min-h-screen relative">
    <!-- 输入框容器 -->
    <div class="mb-4 h-[60px] relative">
      <!-- 切换按钮 -->
      <button
        v-if="showBtn" class="text-blue-600 rounded-full bg-white flex h-8 w-8 ring-1 ring-blue-300 shadow-md transition-all duration-300 items-center left-0 top-1/2 justify-center absolute z-10 hover:text-blue-700 hover:bg-blue-50 -translate-y-1/2 active:scale-95" aria-label="Toggle Input" @click="toggleInput"
      >
        <component
          :is="showInput ? X : Plus" class="h-4 w-4"
          :class="showInput ? 'text-red-500 hover:text-red-600' : ''"
        />
      </button>

      <!-- 展开输入区域 -->
      <Transition name="fade-slide">
        <div v-show="showInput" class="pl-10">
          <InputCommon v-model="newT" @add="handleAdd" />
        </div>
      </Transition>

      <!-- 过滤按钮 -->
      <Transition name="fade-slide">
        <div
          v-show="!showInput" class="bg-white flex h-full transition-opacity duration-300 ease-in-out items-center left-0 right-0 top-0 justify-center absolute dark:bg-gray-800"
        >
          <div
            class="px-3 py-2 border border-gray-300 rounded-full bg-white inline-flex gap-2 shadow-sm transition-all duration-300 dark:border-gray-700 dark:bg-gray-800"
          >
            <button
              v-for="item in filterButtons" :key="item.value" :data-active="filterBtn === item.value"
              :class="{ 'bg-blue-500 text-white': filterBtn === item.value }" class="text-sm text-gray-700 font-semibold px-3 py-1 border border-transparent rounded-full bg-gray-100 shadow-sm transition-all duration-300 dark:text-gray-300 data-[active=true]:text-white hover:text-blue-700 dark:bg-gray-700 data-[active=true]:bg-blue-500 hover:bg-blue-100 dark:hover:text-white dark:hover:bg-blue-800" @click="changeFilter(item.value)"
            >
              {{ item.label }}
            </button>
          </div>
        </div>
      </Transition>
    </div>

    <!-- 任务列表 -->
    <TodoList :todos="todos" @toggle="handleToggle" @remove="handleRemove" @edit="handleEdit" />

    <!-- 分页器 -->
    <div class="mb-1 mt-auto">
      <Pagination
        v-model:current-page="currentPage" v-model:page-size="pageSize" :total-pages="totalPages"
        @page-jump="handlePageJump" @page-size-change="handlePageSizeChange" @next="handleNext" @prev="handlePrev"
        @first="handleFirst" @last="handleLast"
      />
    </div>
  </main>
</template>

<style scoped>
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
