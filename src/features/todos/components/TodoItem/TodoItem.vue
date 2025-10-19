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
import TodoEstimate from './TodoEstimate.vue';
import TodoLocation from './TodoLocation.vue';
import TodoProgress from './TodoProgress.vue';
import TodoReminderSettings from './TodoReminderSettings.vue';
import TodoSmartFeatures from './TodoSmartFeatures.vue';
import TodoSubtasks from './TodoSubtasks.vue';
import TodoTitle from './TodoTitle.vue';
import type { Priority, RepeatPeriod } from '@/schema/common';
import type { Todo, TodoUpdate } from '@/schema/todos';

const props = defineProps<{
  todo: Todo;
  subtasks?: Todo[];
}>();
const emit = defineEmits(['update:todo', 'toggle', 'remove', 'createSubtask', 'updateSubtask', 'deleteSubtask']);

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

// 子任务处理方法
function onCreateSubtask(parentId: string, title: string) {
  emit('createSubtask', parentId, title);
}

function onUpdateSubtask(serialNum: string, update: TodoUpdate) {
  emit('updateSubtask', serialNum, update);
}

function onDeleteSubtask(serialNum: string) {
  emit('deleteSubtask', serialNum);
}

function openPopup(type: string) {
  // 先关闭菜单，再打开弹窗
  menuStore.setMenuSerialNum('');
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

    <!-- 扩展信息区域 -->
    <div v-if="!completed" class="todo-extended">
      <!-- 进度条 -->
      <TodoProgress
        :progress="todoCopy.progress"
        @update="(update) => updateTodo(todoCopy.serialNum, update)"
      />

      <!-- 时间估算 -->
      <TodoEstimate
        :estimate-minutes="todoCopy.estimateMinutes"
        @update="(update) => updateTodo(todoCopy.serialNum, update)"
      />

      <!-- 位置 -->
      <TodoLocation
        :location="todoCopy.location"
        @update="(update) => updateTodo(todoCopy.serialNum, update)"
      />

      <!-- 提醒设置 -->
      <TodoReminderSettings
        :todo="todoCopy"
        @update="(update) => updateTodo(todoCopy.serialNum, update)"
      />

      <!-- 子任务 -->
      <TodoSubtasks
        :todo="todoCopy"
        :subtasks="subtasks"
        @create-subtask="onCreateSubtask"
        @update-subtask="onUpdateSubtask"
        @delete-subtask="onDeleteSubtask"
      />

      <!-- 智能功能 -->
      <TodoSmartFeatures
        :todo="todoCopy"
        @update="(update) => updateTodo(todoCopy.serialNum, update)"
      />
    </div>

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
  padding: 0.875rem 1rem;
  border-radius: 1rem;
  border: 1px solid color-mix(in oklch, var(--color-base-300) 30%, transparent);
  background: linear-gradient(
    135deg,
    var(--color-base-100) 0%,
    color-mix(in oklch, var(--color-base-100) 95%, var(--color-primary)) 100%
  );
  display: flex;
  flex-direction: column;
  position: relative;
  min-height: 4rem;
  transition: all 0.25s cubic-bezier(0.4, 0, 0.2, 1);
  overflow: visible;
  z-index: 1; /* 恢复正常z-index，确保TodoItem可见 */
  box-shadow: 0 1px 3px color-mix(in oklch, var(--color-neutral) 8%, transparent);
  width: 100%;
  max-width: 100%;
  box-sizing: border-box;
}

/* 优先级颜色条 - 作为容器的一部分 */
.todo-item::before {
  content: '';
  position: absolute;
  left: 0;
  top: 0;
  bottom: 0;
  width: 3px;
  border-radius: 1rem 0 0 1rem;
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
  z-index: 1;
  opacity: 0.9;
}

/* 低优先级 - 绿色系 */
.priority-low::before {
  background: linear-gradient(
    180deg,
    var(--color-success) 0%,
    color-mix(in oklch, var(--color-success) 85%, var(--color-info)) 100%
  );
}

.priority-low {
  background: linear-gradient(
    135deg,
    color-mix(in oklch, var(--color-base-100) 98%, var(--color-success)) 0%,
    color-mix(in oklch, var(--color-base-100) 95%, var(--color-success)) 100%
  );
}

/* 中等优先级 - 橙色系 */
.priority-medium::before {
  background: linear-gradient(
    180deg,
    var(--color-warning) 0%,
    color-mix(in oklch, var(--color-warning) 90%, var(--color-error)) 100%
  );
}

.priority-medium {
  background: linear-gradient(
    135deg,
    color-mix(in oklch, var(--color-base-100) 98%, var(--color-warning)) 0%,
    color-mix(in oklch, var(--color-base-100) 95%, var(--color-warning)) 100%
  );
}

/* 高优先级 - 红色系 */
.priority-high::before {
  background: linear-gradient(
    180deg,
    var(--color-error) 0%,
    color-mix(in oklch, var(--color-error) 85%, var(--color-accent)) 100%
  );
}

.priority-high {
  background: linear-gradient(
    135deg,
    color-mix(in oklch, var(--color-base-100) 98%, var(--color-error)) 0%,
    color-mix(in oklch, var(--color-base-100) 95%, var(--color-error)) 100%
  );
}

/* 紧急优先级 - 深红色系，更加醒目 */
.priority-urgent::before {
  background: linear-gradient(
    180deg,
    color-mix(in oklch, var(--color-error) 90%, var(--color-accent)) 0%,
    color-mix(in oklch, var(--color-error) 70%, black) 100%
  );
  box-shadow: 0 0 10px color-mix(in oklch, var(--color-error) 30%, transparent);
  animation: urgent-glow 2s ease-in-out infinite;
}

.priority-urgent {
  background: linear-gradient(
    135deg,
    color-mix(in oklch, var(--color-base-100) 96%, var(--color-error)) 0%,
    color-mix(in oklch, var(--color-base-100) 92%, var(--color-error)) 100%
  );
  border-color: color-mix(in oklch, var(--color-error) 20%, transparent);
}

@keyframes urgent-glow {
  0%, 100% {
    box-shadow: 0 0 10px color-mix(in oklch, var(--color-error) 30%, transparent);
  }
  50% {
    box-shadow: 0 0 16px color-mix(in oklch, var(--color-error) 45%, transparent);
  }
}

.todo-item:hover {
  box-shadow:
    0 4px 12px color-mix(in oklch, var(--color-neutral) 12%, transparent),
    0 2px 4px color-mix(in oklch, var(--color-neutral) 8%, transparent);
  border-color: color-mix(in oklch, var(--color-primary) 20%, transparent);
  transform: translateY(-2px);
  background: linear-gradient(
    135deg,
    var(--color-base-100) 0%,
    color-mix(in oklch, var(--color-base-100) 92%, var(--color-primary)) 100%
  );
}

.todo-item:hover::before {
  width: 4px;
  opacity: 1;
}

/* 主行容器 */
.todo-main {
  display: flex;
  justify-content: space-between;
  align-items: center;
  flex: 1;
  width: 100%;
  max-width: 100%;
  min-width: 0;
  overflow: hidden;
}

/* 左侧: 优先级、复选框、标题 */
.todo-left {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  flex: 1;
  min-width: 0;
  max-width: 100%;
  padding-left: 0.5rem;
  overflow: hidden;
}

/* 移动端减少内边距 */
@media (max-width: 768px) {
  .todo-item {
    padding: 0.75rem 0.5rem;
  }

  .todo-left {
    padding-left: 0.25rem;
    gap: 0.375rem;
  }

  .todo-extended {
    flex-direction: column;
    gap: 0.375rem;
  }
}

/* 扩展信息区域 */
.todo-extended {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  margin-top: 0.75rem;
  padding-top: 0.75rem;
  border-top: 1px solid var(--color-base-300);
  position: relative;
  z-index: 0; /* 降低z-index，避免遮盖其他内容 */
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
    border-color: color-mix(in oklch, var(--color-base-300) 40%, transparent);
    background: linear-gradient(
      135deg,
      var(--color-base-200) 0%,
      color-mix(in oklch, var(--color-base-200) 95%, var(--color-primary)) 100%
    );
  }

  .todo-item:hover {
    background: linear-gradient(
      135deg,
      var(--color-base-200) 0%,
      color-mix(in oklch, var(--color-base-200) 92%, var(--color-primary)) 100%
    );
  }

  .priority-low {
    background: linear-gradient(
      135deg,
      color-mix(in oklch, var(--color-base-200) 98%, var(--color-success)) 0%,
      color-mix(in oklch, var(--color-base-200) 95%, var(--color-success)) 100%
    );
  }

  .priority-medium {
    background: linear-gradient(
      135deg,
      color-mix(in oklch, var(--color-base-200) 98%, var(--color-warning)) 0%,
      color-mix(in oklch, var(--color-base-200) 95%, var(--color-warning)) 100%
    );
  }

  .priority-high {
    background: linear-gradient(
      135deg,
      color-mix(in oklch, var(--color-base-200) 98%, var(--color-error)) 0%,
      color-mix(in oklch, var(--color-base-200) 95%, var(--color-error)) 100%
    );
  }

  .priority-urgent {
    background: linear-gradient(
      135deg,
      color-mix(in oklch, var(--color-base-200) 96%, var(--color-error)) 0%,
      color-mix(in oklch, var(--color-base-200) 92%, var(--color-error)) 100%
    );
  }

  .todo-due-date {
    color: var(--color-neutral-content);
  }
}
</style>
