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
import type { Todo, TodoUpdate } from '@/schema/todos';

const props = defineProps<{
  todo: Todo;
}>();
const emit = defineEmits(['update:todo', 'toggle', 'remove']);

const menuStore = useMenuStore();

// 本地副本，初始值为 props.todo，但后续只通过 updateTodo 更新
const todoCopy = ref<Todo>({ ...props.todo });

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
// 判断是否有modal打开
const hasModalOpen = computed(() => {
  return showEditOptions.value || showMenu.value || showEditModal.value || showDueDateModal.value || showEditRepeatModal.value || !!currentPopup.value;
});

// 优先级样式计算
const priorityClass = computed(() => {
  if (!todoCopy.value.priority) return '';

  const priority = todoCopy.value.priority.toUpperCase();
  switch (priority) {
    case 'LOW':
      return 'priority-low';
    case 'MEDIUM':
      return 'priority-medium';
    case 'HIGH':
      return 'priority-high';
    case 'URGENT':
      return 'priority-urgent';
    default:
      return '';
  }
});

// 👇 所有修改 todo 都使用这个函数
function updateTodo(serialNum: string, partial: TodoUpdate) {
  todoCopy.value = { ...todoCopy.value, ...partial };
  emit('update:todo', serialNum, { ...partial });
}

function onToggleHandler() {
  if (!completed.value) {
    updateTodo(todoCopy.value.serialNum, { status: StatusSchema.enum.Completed });
    emit('toggle');
  }
}

function onEditClick() {
  if (!completed.value) {
    showEditOptions.value = true;
    // 打开modal时保持actions显示
    showActions.value = true;
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
    updateTodo(todoCopy.value.serialNum, { title: trimmed });
  }
  showEditModal.value = false;
  showActions.value = false;
}

function submitDueDateChange(newDueAt: string) {
  const newDue = DateUtils.parseToISO(newDueAt);
  if (newDue !== todoCopy.value.dueAt) {
    updateTodo(todoCopy.value.serialNum, { dueAt: newDue });
  }
  showDueDateModal.value = false;
  showActions.value = false;
}

function submitRepeatChange(repeat: RepeatPeriod) {
  if (repeat !== todoCopy.value.repeat) {
    updateTodo(todoCopy.value.serialNum, { repeat });
  }
  showEditRepeatModal.value = false;
  showActions.value = false;
}

function onChangePriorityHandler(serialNum: string, priority: Priority) {
  if (serialNum === todoCopy.value.serialNum) {
    updateTodo(todoCopy.value.serialNum, { priority });
  }
}

function openPopup(type: string) {
  currentPopup.value = type;
}

function closeMenu() {
  currentPopup.value = '';
  toggleMenu();
}

// 关闭编辑选项modal
function closeEditOptions() {
  showEditOptions.value = false;
  showActions.value = false;
}

// 关闭编辑标题modal
function closeEditModal() {
  showEditModal.value = false;
  showActions.value = false;
}

// 关闭编辑日期modal
function closeDueDateModal() {
  showDueDateModal.value = false;
  showActions.value = false;
}

// 关闭编辑重复modal
function closeEditRepeatModal() {
  showEditRepeatModal.value = false;
  showActions.value = false;
}

// 处理鼠标进入
function handleMouseEnter() {
  // 只有在没有modal打开时才显示actions
  if (!hasModalOpen.value) {
    showActions.value = true;
  }
}

// 处理鼠标离开
function handleMouseLeave() {
  // 只有在没有modal打开时才隐藏actions
  if (!hasModalOpen.value) {
    showActions.value = false;
  }
}
</script>

<template>
  <div
    class="todo-item"
    :class="priorityClass"
    @mouseenter="handleMouseEnter"
    @mouseleave="handleMouseLeave"
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
    <!-- <div v-if="todoCopy.dueAt" class="todo-due-date"> -->
    <!--   {{ todoCopy.remainingTime }} -->
    <!-- </div> -->

    <!-- Menus and Modals -->
    <TodoAddMenus :show="showMenu" @open-popup="openPopup" @close="toggleMenu" />
    <TodoEditOptionsModal
      :show="showEditOptions"
      @edit-title="openEditModal"
      @edit-due-date="openDueDateModal"
      @edit-repeat="openEditRepeatModal"
      @close="closeEditOptions"
    />
    <TodoEditTitleModal
      :show="showEditModal"
      :title="todoCopy.title"
      @save="submitTitleChange"
      @close="closeEditModal"
    />
    <TodoEditDueDateModal
      :show="showDueDateModal"
      :due-date="todoCopy.dueAt"
      @save="submitDueDateChange"
      @close="closeDueDateModal"
    />
    <TodoEditRepeatModal
      :show="showEditRepeatModal"
      :repeat="todoCopy.repeat ?? { type: 'None' }"
      @save="submitRepeatChange"
      @close="closeEditRepeatModal"
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
  padding: 0.875rem;
  border-radius: 0.875rem;
  border: 1px solid color-mix(in oklch, var(--color-base-300) 50%, transparent);
  background-color: color-mix(in oklch, var(--color-base-100) 80%, white);
  display: flex;
  flex-direction: column;
  position: relative;
  height: 4rem;
  transition: all 0.2s ease;
  overflow: hidden; /* 保持圆角效果 */
}

/* 优先级颜色条 - 作为容器的一部分 */
.todo-item::before {
  content: '';
  position: absolute;
  left: 0;
  top: 0;
  bottom: 0;
  width: 4px;
  border-radius: 1.25rem 0 0 1.25rem; /* 左侧圆角与容器匹配 */
  transition: all 0.3s ease;
  z-index: 1;
}

/* 低优先级 - 绿色系 */
.priority-low::before {
  background: linear-gradient(to bottom, var(--color-success), color-mix(in oklch, var(--color-success) 80%, black));
}

/* 中等优先级 - 橙色系 */
.priority-medium::before {
  background: linear-gradient(to bottom, var(--color-warning), color-mix(in oklch, var(--color-warning) 80%, black));
}

/* 高优先级 - 红色系 */
.priority-high::before {
  background: linear-gradient(to bottom, var(--color-error), color-mix(in oklch, var(--color-error) 80%, black));
}

/* 紧急优先级 - 深红色系，更加醒目 */
.priority-urgent::before {
  background: linear-gradient(to bottom, color-mix(in oklch, var(--color-error) 80%, black), color-mix(in oklch, var(--color-error) 60%, black));
  box-shadow: 0 0 8px color-mix(in oklch, var(--color-error) 40%, transparent); /* 添加发光效果 */
}

.todo-item:hover {
  box-shadow: 0 2px 8px color-mix(in oklch, var(--color-neutral) 15%, transparent);
  border-color: var(--color-base-300);
  transform: translateY(-1px);
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
  flex: 1;
  min-width: 0;
  padding-left: 1rem;
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
