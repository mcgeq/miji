<!-- src/components/TodoItem.vue -->
<template>
  <div>
  <div
    class="p-4 bg-white rounded-2xl border border-gray-200 flex flex-col h-18 mb-2 relative"
  >
    <PriorityBadge
      v-if="todo.priority"
      :serialNum="todo.serialNum"
      v-model:priority="todo.priority"
      :completed="completed"
      @changePriority="onChangePriorityHandler"
    />

    <!-- 主内容区 -->
    <div class="flex items-center justify-between flex-1">
      <div class="flex items-center gap-2">
        <button
          type="button"
          class="flex items-center focus:outline-none"
          :aria-pressed="completed"
          :disabled="completed"
          @click="onToggleHandler"
        >
          <CheckCircle v-if="completed" class="w-5 h-5 text-green-500" />
          <Circle v-else class="w-5 h-5 text-gray-400" />
        </button>

        <span
          class="text-left text-sm leading-snug line-clamp-1"
          :class="{ 'text-gray-400': completed }"
          :title="todo.title"
          v-html="displayTextHtml"
        />
      </div>

      <div class="flex items-center gap-3">
        <!-- 编辑按钮 -->
        <button
          type="button"
          :disabled="completed"
          aria-label="Edit task"
          class="transition text-gray-400 hover:text-blue-500 disabled:text-gray-300 disabled:cursor-not-allowed disabled:hover:text-gray-300"
          @click="onEditClick"
        >
          <span :class="{ rotating: isRotatingEdit && !completed }">
            <Pencil class="w-4 h-4" />
          </span>
          <span class="sr-only">Edit</span>
        </button>

        <!-- 添加菜单按钮 -->
        <div class="relative">
          <button
            type="button"
            aria-label="Add task"
            class="transition text-blue-500 hover:text-blue-700 disabled:text-gray-300 disabled:cursor-not-allowed disabled:hover:text-gray-300"
            @click="toggleMenu"
          >
            <span :class="{ rotating: isRotatingAdd }">
              <Plus class="w-5 h-5" />
            </span>
            <span class="sr-only">Add</span>
          </button>

          <div
            v-if="showMenu"
            class="absolute z-20 mt-3 w-10 rounded-2xl shadow-xl border border-gray-300/70 dark:border-gray-700/70
                   bg-gradient-to-b from-white to-gray-50 dark:from-gray-950 dark:to-gray-900
                   p-1 transition-all duration-300 ease-out opacity-100
                   [transform:translateY(-4px)]"
            style="left: 50%; top: calc(100%)"
          >
            <div class="flex flex-col gap-1">
              <button
                class="icon-btn animate-fade-in-up"
                aria-label="Description"
                title="Description"
              >
                <StickyNote class="w-5 h-5 group-hover:text-blue-600 dark:group-hover:text-blue-400" />
              </button>
              <button
                class="icon-btn animate-fade-in-up"
                aria-label="Label"
                title="Label"
              >
                <Tag class="w-5 h-5 group-hover:text-blue-600 dark:group-hover:text-blue-400" />
              </button>
              <button
                class="icon-btn animate-fade-in-up"
                aria-label="Project"
                title="Project"
              >
                <Folder class="w-5 h-5 group-hover:text-blue-600 dark:group-hover:text-blue-400" />
              </button>
            </div>
          </div>
        </div>

        <!-- 删除按钮 -->
        <button
          type="button"
          :disabled="completed"
          aria-label="Delete task"
          class="transition text-red-400 hover:text-red-600 disabled:text-gray-300 disabled:cursor-not-allowed disabled:hover:text-gray-300"
          @click="onRemoveClick"
        >
          <span :class="{ rotating: isRotatingRemove && !completed }">
            <Trash2 class="w-5 h-5" />
          </span>
          <span class="sr-only">Delete</span>
        </button>
      </div>
    </div>

    <!-- 右下角截止时间 -->
    <div v-if="todo.dueAt" class="text-xs text-gray-500 absolute right-4 bottom-1">
      {{ todo.remainingTime }}
    </div>
  </div>

  <!-- 编辑选项模态框 -->
  <transition name="fade">
    <div
      v-if="showEditOptions"
      class="fixed inset-0 bg-black/60 z-50 backdrop-blur-sm px-4 flex justify-center items-center"
      role="button"
      tabindex="0"
      @keydown.enter.space="showEditOptions = false"
      @click="showEditOptions = false"
    >
      <transition name="scale">
        <div
          class="bg-white/70 dark:bg-gray-900/80 p-6 rounded-2xl shadow-xl w-40 flex flex-col gap-4 border border-white/20 dark:border-gray-700/30"
          @click.stop
          role="dialog"
          tabindex="0"
          aria-modal="true"
          @keydown.enter.space.stop
        >
          <button
            class="w-full rounded-xl py-2 px-2 bg-blue-600 hover:bg-blue-700 btn-lucide-icon flex justify-center"
            @click="openEditModal"
          >
            <Pencil class="w-5 h-5" />
          </button>
          <button
            class="w-full rounded-xl py-2 px-4 bg-indigo-500 hover:bg-indigo-600 btn-lucide-icon flex justify-center"
            @click="openDueDateModal"
          >
            <Calendar class="w-5 h-5" />
          </button>
          <button
            class="mt-2 text-sm text-gray-500 hover:text-gray-700 dark:hover:text-gray-300 flex justify-center"
            @click="() => (showEditOptions = false)"
          >
            <X class="w-4 h-4" />
          </button>
        </div>
      </transition>
    </div>
  </transition>

  <!-- 编辑标题模态框 -->
  <transition name="fade">
    <div
      v-if="showEditModal"
      class="fixed inset-0 bg-black/60 flex items-center justify-center z-50 backdrop-blur-sm px-4"
    >
      <transition name="scale">
        <div
          class="bg-white/70 dark:bg-gray-900/80 p-6 rounded-2xl shadow-xl w-96 flex flex-col h-auto backdrop-blur-lg border border-white/20 dark:border-gray-700/30"
        >
          <input
            class="w-full border border-gray-200 dark:border-gray-600 rounded-xl p-3 text-base dark:bg-gray-800 dark:text-gray-100
                   focus:outline-none focus:ring-2 focus:ring-blue-500/50 transition-all placeholder:text-gray-400"
            v-model="tempTitle"
            placeholder="输入任务标题"
          />
          <div class="flex justify-center gap-4 mt-5">
            <button
              class="px-5 py-2 text-sm font-medium rounded-xl bg-gray-100 hover:bg-gray-200 dark:bg-gray-700 dark:hover:bg-gray-600
                     text-gray-700 dark:text-gray-200 transition-all hover:scale-105 active:scale-95"
              @click="() => (showEditModal = false)"
            >
              <X class="w-5 h-5" />
            </button>
            <button
              class="px-5 py-2 text-sm font-medium rounded-xl bg-blue-600 hover:bg-blue-700 text-white disabled:bg-gray-400 disabled:hover:scale-100
                     transition-all hover:scale-105 active:scale-95"
              :disabled="tempTitle.trim() === todo.title.trim()"
              @click="submitTitleChange"
            >
              <Check class="w-5 h-5" />
            </button>
          </div>
        </div>
      </transition>
    </div>
  </transition>

  <!-- 编辑截止日期模态框 -->
  <transition name="fade">
    <div
      v-if="showDueDateModal"
      class="fixed inset-0 bg-black/60 flex items-center justify-center z-50 backdrop-blur-sm px-4"
    >
      <transition name="scale">
        <div
          class="bg-white/70 dark:bg-gray-900/80 p-6 rounded-2xl shadow-xl w-96 flex flex-col backdrop-blur-lg border border-white/20 dark:border-gray-700/30"
        >
          <input
            type="datetime-local"
            v-model="tempDueAt"
            class="w-full border border-gray-300 rounded-xl p-3 mt-1 dark:bg-gray-800 dark:text-gray-100"
          />
          <div class="flex justify-center gap-4 mt-5">
            <button
              class="px-5 py-2 bg-gray-100 dark:bg-gray-700 rounded-xl"
              @click="() => (showDueDateModal = false)"
            >
              <X class="w-5 h-5" />
            </button>
            <button
              :class="{
                'px-5 py-2 text-white rounded-xl': true,
                'bg-gray-400': isDateTimeContaining(todo.dueAt, tempDueAt),
                'bg-blue-600 hover:bg-blue-700': !isDateTimeContaining(todo.dueAt, tempDueAt),
              }"
              :disabled="isDateTimeContaining(todo.dueAt, tempDueAt)"
              @click="submitDueDateChange"
            >
              <Check class="w-5 h-5" />
            </button>
          </div>
        </div>
      </transition>
    </div>
  </transition>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue';

import PriorityBadge from '@/components/common/PriorityBadge.vue';
import { TodoRemain } from '@/schema/todos';

import {
  Check,
  CheckCircle,
  Circle,
  Pencil,
  Plus,
  Trash2,
  X,
  Calendar,
  StickyNote,
  Tag,
  Folder,
} from 'lucide-vue-next';
import { Priority } from '@/schema/common';
import { useMenuStore } from '@/stores/menuStore';
import { parseToISO } from '@/utils/date';

const props = defineProps<{
  todo: TodoRemain;
  onToggle: () => void;
  onRemove: () => void;
  onEdit: () => void;
}>();

const emit = defineEmits(['update:todo', 'toggle', 'remove', 'edit']);

const menuStore = useMenuStore();

const todoCopy = ref({ ...props.todo });

watch(
  () => props.todo,
  (newVal) => {
    todoCopy.value = { ...newVal };
  },
  { deep: true },
);

const todo = todoCopy;

const completed = computed(() => todo.value.status === 'Completed');

const showEditOptions = ref(false);
const showEditModal = ref(false);
const showDueDateModal = ref(false);

const isRotatingAdd = ref(false);
const isRotatingEdit = ref(false);
const isRotatingRemove = ref(false);

const tempTitle = ref(todo.value.title);
const tempDueAt = ref(
  todo.value.dueAt ? todo.value.dueAt.substring(0, 16) : '',
);

const showMenu = computed(
  () => menuStore.getMenuSerialNum === todo.value.serialNum,
);
// 显示文本 HTML，支持高亮或格式处理（如果有）
const displayTextHtml = computed(() => {
  // 这里简单返回纯文本，你可以自行扩展格式化
  return todo.value.title;
});

// 辅助函数：判断截止时间是否未改变
function isDateTimeContaining(
  original: string | undefined,
  newDateTime: string,
) {
  if (!original) return false;
  return original.startsWith(newDateTime);
}

function updateTodo(newTodo: TodoRemain) {
  todoCopy.value = { ...newTodo };
  emit('update:todo', todoCopy.value);
}

function submitTitleChange() {
  const newTitle = tempTitle.value.trim();
  if (newTitle && newTitle !== todo.value.title.trim()) {
    const updated = { ...todo.value, title: newTitle };
    updateTodo(updated);
    emit('edit');
  }
  showEditModal.value = false;
  showEditOptions.value = false;
}

function submitDueDateChange() {
  if (!tempDueAt.value) return;
  const newDue = parseToISO(tempDueAt.value);
  if (newDue !== todo.value.dueAt) {
    const updated = { ...todo.value, dueAt: newDue };
    updateTodo(updated);
    emit('edit');
  }
  showDueDateModal.value = false;
  showEditOptions.value = false;
}

function onChangePriorityHandler(serialNum: string, priority: Priority) {
  if (serialNum === todo.value.serialNum) {
    const updated = { ...todo.value, priority: priority };
    updateTodo(updated);
  }
}

function onToggleHandler() {
  if (!completed.value) {
    emit('toggle');
  }
}

function onRemoveClick() {
  if (completed.value) return;
  emit('remove');
}

function onEditClick() {
  if (completed.value) return;
  tempTitle.value = todo.value.title;
  handleRotate('edit', () => {
    showEditOptions.value = true;
  });
}

function toggleMenu() {
  isRotatingAdd.value = true;
  if (menuStore.getMenuSerialNum === todo.value.serialNum) {
    menuStore.setMenuSerialNum('');
  } else {
    menuStore.setMenuSerialNum(todo.value.serialNum);
  }
  setTimeout(() => {
    isRotatingAdd.value = false;
  }, 500);
}

// 模拟旋转动画状态管理
function handleRotate(type: 'edit' | 'remove' | 'add', callback: () => void) {
  if (type === 'edit') {
    isRotatingEdit.value = true;
  } else if (type === 'remove') {
    isRotatingRemove.value = true;
  } else if (type === 'add') {
    isRotatingAdd.value = true;
  }
  setTimeout(() => {
    if (type === 'edit') {
      isRotatingEdit.value = false;
    } else if (type === 'remove') {
      isRotatingRemove.value = false;
    } else if (type === 'add') {
      isRotatingAdd.value = false;
    }
    callback();
  }, 300);
}

function openEditModal() {
  showEditModal.value = true;
  showEditOptions.value = false;
}

function openDueDateModal() {
  showDueDateModal.value = true;
  showEditOptions.value = false;
}
</script>

<style scoped>
.rotating {
  animation: rotating 0.5s linear;
  will-change: transform;
}

@keyframes rotating {
  from {
    transform: rotate(0deg);
  }
  to {
    transform: rotate(360deg);
  }
}
.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.25s ease-out, transform 0.25s ease-out;
  will-change: opacity, transform;
}
.fade-enter-from,
.fade-leave-to {
  opacity: 0;
  transform: translateY(8px);
}

.scale-enter-active,
.scale-leave-active {
  transition: transform 0.2s ease-out;
  will-change: transform;
}
.scale-enter-from,
.scale-leave-to {
  transform: scale(0.9);
}
</style>
