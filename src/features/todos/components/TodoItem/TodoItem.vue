<script setup lang="ts">
import Descriptions from '@/components/common/Descriptions.vue';
import PopupWrapper from '@/components/common/PopupWrapper.vue';
import PriorityBadge from '@/components/common/PriorityBadge.vue';
import ProjectsView from '@/features/projects/views/ProjectsView.vue';
import TagsView from '@/features/tags/views/TagsView.vue';
import { StatusSchema } from '@/schema/common';
import { useMenuStore } from '@/stores/menuStore';
import { DateUtils } from '@/utils/date';
import TodoActions from './TodoActions.vue';
import TodoAddMenus from './TodoAddMenus.vue';
import TodoCheckbox from './TodoCheckbox.vue';
import TodoEditDueDateModal from './TodoEditDueDateModal.vue';
import TodoEditOptionsModal from './TodoEditOptionsModal.vue';
import TodoEditRepeatModal from './TodoEditRepeatModal.vue';
import TodoEditTitleModal from './TodoEditTitleModal.vue';
import TodoTitle from './TodoTitle.vue';
import type { Priority, RepeatPeriod } from '@/schema/common';
import type { TodoRemain } from '@/schema/todos';

const props = defineProps<{
  todo: TodoRemain;
}>();
const emit = defineEmits(['update:todo', 'toggle', 'remove', 'edit']);

const menuStore = useMenuStore();

// 本地副本，初始值为 props.todo，但后续只通过 updateTodo 更新
const todoCopy = ref<TodoRemain>({ ...props.todo });

// UI 状态控制
const currentPopup = ref('');
const showActions = ref(false);
const showEditOptions = ref(false);
const showEditModal = ref(false);
const showDueDateModal = ref(false);
const showEditRepeatModal = ref(false);
const isRotatingAdd = ref(false);

// 计算属性
const completed = computed(
  () => todoCopy.value.status === StatusSchema.enum.Completed,
);
const showMenu = computed(
  () => menuStore.getMenuSerialNum === todoCopy.value.serialNum,
);

// const showPriorityBar = computed(() => {
//   return PrioritySchema.safeParse(todoCopy.value.priority).success;
// });
//
// const priorityBarClass = computed(() => {
//   if (!showPriorityBar.value) return '';
//
//   const styleMap: Record<Priority, string> = {
//     Urgent:
//       'bg-gradient-to-b from-red-600 to-red-700 shadow-lg shadow-red-500/20',
//     High: 'bg-gradient-to-b from-red-500 to-red-600 shadow-md shadow-red-500/15',
//     Medium:
//       'bg-gradient-to-b from-yellow-500 to-yellow-600 shadow-md shadow-yellow-500/15',
//     Low: 'bg-gradient-to-b from-blue-500 to-blue-600 shadow-md shadow-blue-500/15',
//   };
//
//   return styleMap[todoCopy.value.priority as Priority];
// });

// 👇 所有修改 todo 都使用这个函数
function updateTodo(partial: Partial<TodoRemain>) {
  todoCopy.value = { ...todoCopy.value, ...partial };
  emit('update:todo', { ...todoCopy.value });
}

function onToggleHandler() {
  if (!completed.value) {
    updateTodo({ status: StatusSchema.enum.Completed });
    emit('toggle');
  }
}

function onEditClick() {
  if (!completed.value) {
    showEditOptions.value = true;
  }
}

function onRemoveClick() {
  if (!completed.value) {
    emit('remove');
  }
}

function toggleMenu() {
  isRotatingAdd.value = true;
  const currentSerial = todoCopy.value.serialNum;
  menuStore.setMenuSerialNum(
    menuStore.getMenuSerialNum === currentSerial ? '' : currentSerial,
  );
  setTimeout(() => (isRotatingAdd.value = false), 500);
}

function openEditModal() {
  showEditOptions.value = false;
  showEditModal.value = true;
}

function openDueDateModal() {
  showEditOptions.value = false;
  showDueDateModal.value = true;
}

function openEditRepeatModal() {
  showEditOptions.value = false;
  showEditRepeatModal.value = true;
}

function submitTitleChange(newTitle: string) {
  const trimmed = newTitle.trim();
  if (trimmed && trimmed !== todoCopy.value.title) {
    updateTodo({ title: trimmed });
    emit('edit');
  }
  showEditModal.value = false;
}

function submitDueDateChange(newDueAt: string) {
  const newDue = DateUtils.parseToISO(newDueAt);
  if (newDue !== todoCopy.value.dueAt) {
    updateTodo({ dueAt: newDue });
    emit('edit');
  }
  showDueDateModal.value = false;
}

function submitRepeatChange(repeat: RepeatPeriod) {
  if (repeat !== todoCopy.value.repeat) {
    updateTodo({ repeat });
    emit('edit');
  }
}

function onChangePriorityHandler(serialNum: string, priority: Priority) {
  if (serialNum === todoCopy.value.serialNum) {
    updateTodo({ priority });
  }
}

function openPopup(type: string) {
  currentPopup.value = type;
}

function closeMenu() {
  currentPopup.value = '';
  toggleMenu();
}
</script>

<template>
  <div
    class="todo-item"
    @mouseenter="showActions = true"
    @mouseleave="showActions = false"
  >
    <!-- Left Section: Checkbox, Priority, Title -->
    <div class="todo-main">
      <div class="todo-left">
        <PriorityBadge
          v-if="todoCopy.priority"
          :serial-num="todoCopy.serialNum"
          :priority="todoCopy.priority"
          :completed="completed"
          @change-priority="onChangePriorityHandler"
        />
        <TodoCheckbox :completed="completed" @toggle="onToggleHandler" />
        <TodoTitle :title="todoCopy.title" :completed="completed" @toggle="onToggleHandler" />
      </div>

      <!-- Right Section: Actions -->
      <TodoActions
        :completed="completed"
        :show="showActions"
        @edit="onEditClick"
        @add="toggleMenu"
        @remove="onRemoveClick"
      />
    </div>

    <!-- Due Date -->
    <div v-if="todoCopy.dueAt" class="todo-due-date">
      {{ todoCopy.remainingTime }}
    </div>

    <!-- Menus and Modals -->
    <TodoAddMenus :show="showMenu" @open-popup="openPopup" @close="toggleMenu" />
    <TodoEditOptionsModal
      :show="showEditOptions"
      @edit-title="openEditModal"
      @edit-due-date="openDueDateModal"
      @edit-repeat="openEditRepeatModal"
      @close="showEditOptions = false"
    />
    <TodoEditTitleModal
      :show="showEditModal"
      :title="todoCopy.title"
      @save="submitTitleChange"
      @close="showEditModal = false"
    />
    <TodoEditDueDateModal
      :show="showDueDateModal"
      :due-date="todoCopy.dueAt"
      @save="submitDueDateChange"
      @close="showDueDateModal = false"
    />
    <TodoEditRepeatModal
      :show="showEditRepeatModal"
      :repeat="todoCopy.repeat ?? { type: 'None' }"
      @save="submitRepeatChange"
      @close="showEditRepeatModal = false"
    />

    <!-- Popups -->
    <PopupWrapper v-if="currentPopup === 'description'" @close="closeMenu">
      <Descriptions v-model="todoCopy.description" @close="closeMenu" />
    </PopupWrapper>
    <PopupWrapper v-if="currentPopup === 'tags'" @close="closeMenu">
      <TagsView />
    </PopupWrapper>
    <PopupWrapper v-if="currentPopup === 'projects'" @close="closeMenu">
      <ProjectsView />
    </PopupWrapper>
  </div>
</template>

<style scoped lang="postcss">
.todo-item {
  margin-bottom: 0.5rem;
  padding: 1rem;
  border-radius: 1.25rem;
  border: 1px solid var(--color-neutral, #e5e7eb);
  background-color: var(--color-base-200, #fff);
  display: flex;
  flex-direction: column;
  position: relative;
  height: 4.5rem;
  transition: box-shadow 0.2s ease, background-color 0.2s ease;
}

.todo-item:hover {
  box-shadow: 0 4px 12px rgba(0,0,0,0.08);
}

/* 主行容器 */
.todo-main {
  display: flex;
  justify-content: space-between;
  align-items: center;
  flex: 1;
}

/* 左侧: 优先级、复选框、标题 */
.todo-left {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

/* 到期时间 */
.todo-due-date {
  position: absolute;
  bottom: 0.25rem;
  right: 1rem;
  font-size: 0.75rem;
  color: var(--color-neutral-content, #6b7280);
}

/* 动画类 */
.rotating {
  animation: rotating 0.5s linear;
}
@keyframes rotating {
  from { transform: rotate(0deg); }
  to { transform: rotate(360deg); }
}

/* 淡入淡出 */
.fade-enter-active, .fade-leave-active {
  transition: opacity 0.25s ease-out, transform 0.25s ease-out;
}
.fade-enter-from, .fade-leave-to {
  opacity: 0;
  transform: translateY(8px);
}

/* 缩放动画 */
.scale-enter-active, .scale-leave-active {
  transition: transform 0.2s ease-out;
}
.scale-enter-from, .scale-leave-to {
  transform: scale(0.9);
}

/* Dark Theme 支持 */
@media (prefers-color-scheme: dark) {
  .todo-item {
    border-color: var(--color-neutral, #374151);
    background-color: var(--color-base-200, #1f2937);
  }

  .todo-due-date {
    color: var(--color-neutral-content, #9ca3af);
  }
}
</style>
