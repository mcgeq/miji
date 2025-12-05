<script setup lang="ts">
import PriorityBadge from '@/components/common/PriorityBadge.vue';
import { Descriptions, Modal } from '@/components/ui';
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
import { useTimeProgress } from '../../composables/useTimeProgress';
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

// 时间进度追踪
const { timeProgress, urgency, refresh: refreshTimeProgress } = useTimeProgress(
  todoCopy.value.createdAt,
  todoCopy.value.dueAt,
);

// 组件挂载时，如果当前任务的菜单是打开的，清除它
// 这可以防止页面刷新或导航后菜单状态残留
onMounted(() => {
  if (menuStore.getMenuSerialNum === todoCopy.value.serialNum) {
    menuStore.setMenuSerialNum('');
  }
  // 刷新时间进度
  refreshTimeProgress();
});

// 组件卸载时，如果当前任务的菜单是打开的，关闭它
onBeforeUnmount(() => {
  if (menuStore.getMenuSerialNum === todoCopy.value.serialNum) {
    menuStore.setMenuSerialNum('');
  }
});

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

// 优先级样式计算 - 使用通用组件类
const priorityClass = computed(() => {
  if (!todoCopy.value.priority) return '';

  const priority = todoCopy.value.priority.toUpperCase();
  switch (priority) {
    case 'LOW':
      return 'priority-gradient-low';
    case 'MEDIUM':
      return 'priority-gradient-medium';
    case 'HIGH':
      return 'priority-gradient-high';
    case 'URGENT':
      return 'priority-gradient-urgent';
    default:
      return '';
  }
});

// 优先级边框样式 - 与 PriorityBadge 颜色保持一致
const priorityBorderClass = computed(() => {
  if (!todoCopy.value.priority || completed.value) return '';

  const priority = todoCopy.value.priority.toUpperCase();
  switch (priority) {
    case 'LOW':
      return 'border-l-4 !border-l-emerald-500 dark:!border-l-emerald-400';
    case 'MEDIUM':
      return 'border-l-4 !border-l-amber-500 dark:!border-l-amber-400';
    case 'HIGH':
      return 'border-l-4 !border-l-red-500 dark:!border-l-red-400';
    case 'URGENT':
      return 'border-l-4 !border-l-red-600 dark:!border-l-red-500';
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
  const isCurrentlyOpen = menuStore.getMenuSerialNum === currentSerial;
  const newSerial = isCurrentlyOpen ? '' : currentSerial;

  menuStore.setMenuSerialNum(newSerial);

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
    class="relative w-full mb-1 p-4 md:p-6 lg:p-6 rounded-xl md:rounded-[1.25rem] border border-gray-300 dark:border-gray-700 bg-white dark:bg-gray-800 shadow-sm backdrop-blur-sm transition-all duration-300 ease-out hover:shadow-lg hover:border-blue-500 dark:hover:border-blue-400 hover:-translate-y-0.5 overflow-visible z-[1] time-progress-card"
    :class="[
      priorityClass,
      priorityBorderClass,
      todoCopy.dueAt ? `urgency-${urgency}` : ''
    ]"
    :style="todoCopy.dueAt && timeProgress !== null ? {
      '--time-progress': `${timeProgress}%`,
    } : {}"
    @mouseenter="handleMouseEnter"
    @mouseleave="handleMouseLeave"
  >
    <!-- 时间进度边框 - 使用伪元素 -->
    <div 
      v-if="!completed && todoCopy.dueAt && timeProgress !== null"
      class="absolute inset-0 rounded-xl md:rounded-[1.25rem] pointer-events-none time-progress-overlay"
    />
    
    <!-- Left Section: Checkbox, Priority, Title -->
    <div class="flex justify-between items-center flex-1 w-full max-w-full min-w-0 overflow-hidden">
      <div class="flex items-center gap-2 md:gap-2 flex-1 min-w-0 max-w-full pl-0.5 md:pl-2 overflow-hidden">
        <PriorityBadge
          v-if="todoCopy.priority"
          :serial-num="todoCopy.serialNum"
          :priority="todoCopy.priority"
          :completed="completed"
          @change-priority="onChangePriorityHandler"
        />
        <TodoCheckbox :completed="completed" @toggle="onToggleHandler" />
        <TodoTitle :title="todoCopy.title" :completed="completed" />
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

    <!-- Menus and Modals -->
    <TodoAddMenus :show="showMenu" @open-popup="openPopup" @close="toggleMenu" />
    <TodoEditOptionsModal
      :show="showEditOptions"
      :todo="todoCopy"
      :subtasks="subtasks"
      @edit-title="openEditModal"
      @edit-due-date="openDueDateModal"
      @edit-repeat="openEditRepeatModal"
      @update="(update) => updateTodo(todoCopy.serialNum, update)"
      @create-subtask="onCreateSubtask"
      @update-subtask="onUpdateSubtask"
      @delete-subtask="onDeleteSubtask"
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
    <Modal
      :open="currentPopup === 'description'"
      title="编辑描述"
      size="lg"
      :show-footer="false"
      @close="closeMenu"
    >
      <Descriptions v-model="todoCopy.description" @close="closeMenu" />
    </Modal>

    <Modal
      :open="currentPopup === 'tags'"
      title="选择标签"
      size="lg"
      cancel-text="关闭"
      :show-confirm="false"
      @close="closeMenu"
      @cancel="closeMenu"
    >
      <TagsView />
    </Modal>

    <Modal
      :open="currentPopup === 'projects'"
      title="选择项目"
      size="lg"
      cancel-text="关闭"
      :show-confirm="false"
      @close="closeMenu"
      @cancel="closeMenu"
    >
      <ProjectsView />
    </Modal>
  </div>
</template>

<style scoped>
/* 优先级样式 - 背景渐变与 PriorityBadge 颜色一致 */
.priority-gradient-low {
  background: linear-gradient(to bottom right,
    light-dark(oklch(94% 0.015 90), color-mix(in srgb, oklch(20% 0.01 45) 98%, transparent)),
    color-mix(in srgb, rgb(16, 185, 129) light-dark(3%, 5%), transparent)); /* emerald-500 */
}

.priority-gradient-medium {
  background: linear-gradient(to bottom right,
    light-dark(oklch(94% 0.015 90), color-mix(in srgb, oklch(20% 0.01 45) 98%, transparent)),
    color-mix(in srgb, rgb(245, 158, 11) light-dark(3%, 5%), transparent)); /* amber-500 */
}

.priority-gradient-high {
  background: linear-gradient(to bottom right,
    light-dark(oklch(94% 0.015 90), color-mix(in srgb, oklch(20% 0.01 45) 98%, transparent)),
    color-mix(in srgb, rgb(239, 68, 68) light-dark(3%, 5%), transparent)); /* red-500 */
}

.priority-gradient-urgent {
  background: linear-gradient(to bottom right,
    light-dark(oklch(94% 0.015 90), color-mix(in srgb, oklch(20% 0.01 45) 96%, transparent)),
    color-mix(in srgb, rgb(220, 38, 38) light-dark(5%, 8%), transparent)); /* red-600 */
}

/* 时间进度边框 */
.time-progress-card {
  position: relative;
}

/* 时间进度边框叠加层 */
.time-progress-overlay {
  border: 2px solid transparent;
  border-radius: inherit;
  background: var(--border-gradient) border-box;
  -webkit-mask: linear-gradient(#fff 0 0) padding-box, linear-gradient(#fff 0 0);
  -webkit-mask-composite: xor;
  mask: linear-gradient(#fff 0 0) padding-box, linear-gradient(#fff 0 0);
  mask-composite: exclude;
}

/* 时间进度边框 - 统一使用灰色渐变，随进度加深 */
.time-progress-overlay {
  --border-gradient: conic-gradient(
    from -90deg,
    rgb(107, 114, 128) 0%,
    rgb(107, 114, 128) calc(var(--time-progress) * 1%),
    rgb(209, 213, 219) calc(var(--time-progress) * 1%),
    rgb(209, 213, 219) 100%
  );
}

/* 脉冲动画 */
@keyframes pulse-border {
  0%, 100% {
    opacity: 1;
  }
  50% {
    opacity: 0.6;
  }
}


/* 深色模式适配 - 使用更亮的灰色 */
.dark .time-progress-overlay {
  --border-gradient: conic-gradient(
    from -90deg,
    rgb(156, 163, 175) 0%,
    rgb(156, 163, 175) calc(var(--time-progress) * 1%),
    rgb(75, 85, 99) calc(var(--time-progress) * 1%),
    rgb(75, 85, 99) 100%
  );
}
</style>
