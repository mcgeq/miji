<!-- src/features/todo/views/TodoView.vue -->
<template>
  <main class="relative flex flex-col min-h-screen max-w-xl mx-auto p-4">
    <!-- 输入框容器 -->
    <div class="relative mb-4 h-[60px]">
      <!-- 切换按钮 -->
      <button
        v-if="showBtn"
        class="
        absolute left-0 top-1/2 -translate-y-1/2 z-10
        w-8 h-8 flex items-center justify-center
        rounded-full bg-white text-blue-600 ring-1 ring-blue-300
        hover:bg-blue-50 hover:text-blue-700 active:scale-95
        shadow-md transition-all duration-300
        "
        @click="toggleInput"
        aria-label="Toggle Input"
      >
        <component :is="showInput ? X : Plus" class="w-4 h-4" :class="showInput ? 'text-red-500 hover:text-red-600' : ''" />
      </button>

      <!-- 展开输入区域 -->
      <Transition name="fade-slide">
        <div
          v-show="showInput"
          class="pl-10"
        >
            <InputCommon v-model="newT" @add="handleAdd" />
        </div>
      </Transition>

      <!-- 过滤按钮 -->
      <Transition name="fade-slide">
        <div
          v-show="!showInput"
          class="
            absolute top-0 left-0 right-0 flex justify-center items-center h-full
            bg-white dark:bg-gray-800
            transition-opacity duration-300 ease-in-out
            "
        >
          <div class="
            inline-flex gap-2 px-3 py-2
            bg-white shadow-sm border border-gray-300 rounded-full
            dark:bg-gray-800 dark:border-gray-700
            transition-all duration-300
          ">
            <button
              v-for="item in filterButtons"
              :key="item.value"
              :data-active="filterBtn === item.value"
              :class="{ 'bg-blue-500 text-white': filterBtn === item.value }"
              @click="changeFilter(item.value)"
              class="
                px-3 py-1 text-sm font-semibold rounded-full
                bg-gray-100 text-gray-700 hover:bg-blue-100 hover:text-blue-700
                dark:bg-gray-700 dark:text-gray-300 dark:hover:bg-blue-800 dark:hover:text-white
                shadow-sm border border-transparent
                transition-all duration-300
                data-[active=true]:bg-blue-500 data-[active=true]:text-white
              "
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
    <div class="mt-auto mb-1">
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

<script setup lang="ts">
import { ref, computed, onMounted, onBeforeUnmount, watch } from 'vue';
import { Plus, X } from 'lucide-vue-next';
import { useI18n } from 'vue-i18n';
import { FilterBtn, FilterBtnSchema } from '@/schema/common';
import { TodoRemain } from '@/schema/todos';
import InputCommon from '@/components/common/InputCommon.vue';
import Pagination from '@/components/common/Pagination.vue';
import TodoList from '@/components/features/todos/TodoList.vue';

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
    label: t('todos.filterBtn.yesterday'),
    value: FilterBtnSchema.enum.YESTERDAY,
  },
  { label: t('todos.filterBtn.today'), value: FilterBtnSchema.enum.TODAY },
  {
    label: t('todos.filterBtn.tomorrow'),
    value: FilterBtnSchema.enum.TOMORROW,
  },
] as const;

const toggleInput = () => {
  showInput.value = !showInput.value;
  filterBtn.value = FilterBtnSchema.enum.TODAY;
};

const handleAdd = (text: string) => {
  if (text.trim()) {
    todoStore.addTodo(text);
    newT.value = '';
  }
};

const handleToggle = (serialNum: string) => {
  todoStore.toggleTodo(serialNum);
};

const handleRemove = (serialNum: string) => {
  todoStore.removeTodo(serialNum);
};

const handleEdit = (serialNum: string, todo: TodoRemain) => {
  todoStore.editTodo(serialNum, todo);
};

const handlePageJump = (page: number) => {
  todoStore.setPage(page);
};

const handlePageSizeChange = (size: number) => {
  todoStore.setPageSize(size);
};

const handleNext = () => {
  todoStore.nextPage();
};

const handlePrev = () => {
  todoStore.prevPage();
};

const handleFirst = () => {
  todoStore.setPage(1);
};

const handleLast = () => {
  todoStore.setPage(todoStore.totalPages);
};

const changeFilter = async (value: FilterBtn) => {
  filterBtn.value = value;
  await todoStore.setFilterBtn(value);
};

onMounted(async () => {
  await todoStore.reloadPage();
  if (todoStore.totalPages) {
    todoStore.setPage(1);
  }
  todoStore.startGlobalTimer();
});

onBeforeUnmount(() => {
  todoStore.stopGlobalTimer();
});

// Keep page and size synced with store
watch(currentPage, (val) => todoStore.setPage(val));
watch(pageSize, (val) => todoStore.setPageSize(val));
watch(
  () => todoStore.currentPage,
  (val) => {
    currentPage.value = val;
  },
);
watch(currentPage, (val) => {
  todoStore.setPage(val);
});
</script>

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
