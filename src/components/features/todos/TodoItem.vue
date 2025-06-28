<!-- src/components/TodoItem.vue -->
<template>
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

    <!-- 上半部分：主内容 -->
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
            class="absolute z-20 mt-3 w-10 rounded-2xl shadow-xl
                   border border-gray-300/70 dark:border-gray-700/70
                   bg-gradient-to-b from-white to-gray-50 dark:from-gray-950 dark:to-gray-900
                   p-1 transition-all duration-300 ease-out opacity-100
                   [transform:translateY(-4px)]"
            style="left: 50%; top: calc(100%)"
          >
            <div class="flex flex-col gap-1">
              <button class="icon-btn animate-fade-in-up" aria-label="Description" title="Description">
                <StickyNote class="w-5 h-5 group-hover:text-blue-600 dark:group-hover:text-blue-400" />
              </button>
              <button class="icon-btn animate-fade-in-up" aria-label="Label" title="Label">
                <Tag class="w-5 h-5 group-hover:text-blue-600 dark:group-hover:text-blue-400" />
              </button>
              <button class="icon-btn animate-fade-in-up" aria-label="Project" title="Project">
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

    <!-- 底部右下角 dueAt -->
    <div v-if="todo.dueAt" class="text-xs text-gray-500 absolute right-4 bottom-1">
      {{ todo.remainingTime }}
    </div>
  </div>

  <!-- 编辑选项模态框 -->
  <transition name="fade">
    <div
      v-if="showEditOptions"
      class="fixed inset-0 bg-black/60 flex items-center justify-center z-50 backdrop-blur-sm px-4"
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
            class="w-full py-2 px-2 bg-blue-600 hover:bg-blue-700 btn-lucide-icon"
            @click="openEditModal"
          >
            <Pencil class="w-5 h-5" />
          </button>
          <button
            class="w-full py-2 px-4 bg-indigo-500 hover:bg-indigo-600 btn-lucide-icon"
            @click="openDueDateModal"
          >
            <Calendar class="w-5 h-5" />
          </button>
          <button
            class="mt-2 text-sm text-gray-500 hover:text-gray-700 dark:hover:text-gray-300 flex justify-center items-center"
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
    <div v-if="showEditModal" class="fixed inset-0 bg-black/60 flex items-center justify-center z-50 backdrop-blur-sm px-4">
      <transition name="scale">
        <div
          class="bg-white/70 dark:bg-gray-900/80 p-6 rounded-2xl shadow-xl w-96 flex flex-col h-auto backdrop-blur-lg border border-white/20 dark:border-gray-700/30"
        >
          <input
            class="w-full border border-gray-200 dark:border-gray-600 rounded-xl p-3 text-base dark:bg-gray-800 dark:text-gray-100 focus:outline-none focus:ring-2 focus:ring-blue-500/50 transition-all placeholder:text-gray-400"
            v-model="tempTitle"
            placeholder="输入任务标题"
          />
          <div class="flex justify-center gap-4 mt-5">
            <button
              class="px-5 py-2 text-sm font-medium rounded-xl bg-gray-100 hover:bg-gray-200 dark:bg-gray-700 dark:hover:bg-gray-600 text-gray-700 dark:text-gray-200 transition-all hover:scale-105 active:scale-95"
              @click="() => (showEditModal = false)"
            >
              <X class="w-5 h-5" />
            </button>
            <button
              class="px-5 py-2 text-sm font-medium rounded-xl bg-blue-600 hover:bg-blue-700 text-white disabled:bg-gray-400 disabled:hover:scale-100 transition-all hover:scale-105 active:scale-95"
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
    <div v-if="showDueDateModal" class="fixed inset-0 bg-black/60 flex items-center justify-center z-50 backdrop-blur-sm px-4">
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
                'bg-blue-600 hover:bg-blue-700': !isDateTimeContaining(todo.dueAt, tempDueAt)
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
</template>

<script setup lang="ts">
import { ref, computed, toRef } from 'vue';

import PriorityBadge from '@/components/common/PriorityBadge.vue';
import {
  Calendar,
  Check,
  CheckCircle,
  Circle,
  Folder,
  Pencil,
  Plus,
  StickyNote,
  Tag,
  Trash2,
  X,
} from 'lucide-vue-next';

import {
  formatForDisplay,
  getLocalISODateTimeWithOffset,
  isDateTimeContaining,
  parseToISO,
} from '@/utils/date';
import { escapeHTML } from '@/utils/sanitize';
import { useMenuStore } from '@/stores/menuStore';
import { Priority } from '@/schema/common';

const props = defineProps<{
  todo: import('@/schema/todos').TodoRemain;
  onToggle: () => void;
  onRemove: () => void;
  onEdit: () => void;
  onChangePriority: (serialNum: string, priority: Priority) => void;
}>();

const menuStore = useMenuStore();

// 这里改用 toRef 保持响应式，方便使用 todo.value
const todo = toRef(props, 'todo');

// 计算是否完成
const completed = computed(() => todo.value.status === 'Completed');

const maxChars = 18;

// 显示标题缩略和转义HTML
const displayText = computed(() => {
  return todo.value.title.length > maxChars
    ? `${todo.value.title.slice(0, maxChars)}...`
    : todo.value.title;
});
const displayTextHtml = computed(() => escapeHTML(displayText.value));

// 旋转状态
const isRotatingAdd = ref(false);
const isRotatingEdit = ref(false);
const isRotatingRemove = ref(false);

// 菜单显示状态
const showMenu = computed(
  () => useMenuStore().getMenuSerialNum === todo.value.serialNum,
);

// 编辑模态框状态
const showEditModal = ref(false);
const showDueDateModal = ref(false);
const showEditOptions = ref(false);

// 临时数据存储
const tempTitle = ref('');
const tempDueAt = ref(
  formatForDisplay(todo.value.dueAt ?? getLocalISODateTimeWithOffset()),
);

// 旋转按钮函数
function handleRotate(button: 'add' | 'edit' | 'remove', callback: () => void) {
  if (completed.value) {
    callback();
    return;
  }
  let stateRef;
  switch (button) {
    case 'add':
      stateRef = isRotatingAdd;
      break;
    case 'edit':
      stateRef = isRotatingEdit;
      break;
    case 'remove':
      stateRef = isRotatingRemove;
      break;
  }
  stateRef.value = true;
  callback();
  setTimeout(() => {
    stateRef.value = false;
  }, 500);
}

function onToggleHandler() {
  if (!completed.value) props.onToggle();
}

function onChangePriorityHandler() {
  props.onChangePriority(todo.value.serialNum, todo.value.priority);
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

function onRemoveClick() {
  if (completed.value) return;
  handleRotate('remove', props.onRemove);
}

function openEditModal() {
  tempTitle.value = todo.value.title;
  showEditOptions.value = false;
  showEditModal.value = true;
}

function openDueDateModal() {
  tempDueAt.value = formatForDisplay(
    todo.value.dueAt ?? getLocalISODateTimeWithOffset(),
  );
  showEditOptions.value = false;
  showDueDateModal.value = true;
}

function submitTitleChange() {
  const newTitle = tempTitle.value.trim();
  if (newTitle && newTitle !== todo.value.title.trim()) {
    todo.value.title = newTitle;
    props.onEdit();
  }
  showEditModal.value = false;
  showEditOptions.value = false;
}

function submitDueDateChange() {
  if (!tempDueAt.value) return;
  const newDue = parseToISO(tempDueAt.value);
  if (newDue !== todo.value.dueAt) {
    todo.value.dueAt = newDue;
    props.onEdit();
  }
  showDueDateModal.value = false;
  showEditOptions.value = false;
}
</script>

<style scoped>
.rotating {
  animation: rotating 0.5s linear;
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
  transition: opacity 0.3s ease;
}
.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}

.scale-enter-active,
.scale-leave-active {
  transition: transform 0.3s ease;
}
.scale-enter-from,
.scale-leave-to {
  transform: scale(0.8);
}
</style>
