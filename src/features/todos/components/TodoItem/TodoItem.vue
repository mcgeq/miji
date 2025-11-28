<script setup lang="ts">
import PopupWrapper from '@/components/common/PopupWrapper.vue';
import PriorityBadge from '@/components/common/PriorityBadge.vue';
import { Descriptions } from '@/components/ui';
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

// 组件挂载时，如果当前任务的菜单是打开的，清除它
// 这可以防止页面刷新或导航后菜单状态残留
onMounted(() => {
  if (menuStore.getMenuSerialNum === todoCopy.value.serialNum) {
    menuStore.setMenuSerialNum('');
  }
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
    class="todo-card"
    :class="priorityClass"
    @mouseenter="handleMouseEnter"
    @mouseleave="handleMouseLeave"
  >
    <!-- Left Section: Checkbox, Priority, Title -->
    <div class="flex justify-between items-center flex-1 w-full max-w-full min-w-0 overflow-hidden">
      <div class="flex items-center gap-2 flex-1 min-w-0 max-w-full pl-2 overflow-hidden">
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

    <!-- 扩展信息区域 -->
    <div v-if="!completed" class="flex flex-wrap gap-3 mt-1.5 pt-1.5 border-t border-base-300 relative z-0 rounded-b-2xl -mx-5 px-5 justify-center items-center lg:-mx-6 lg:px-6">
      <!-- 进度条 -->
      <TodoProgress
        :progress="todoCopy.progress"
        @update="(update) => updateTodo(todoCopy.serialNum, update)"
      />

      <!-- 功能按钮组 -->
      <div class="flex flex-wrap gap-3 items-center justify-center">
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

<style scoped>
/* 动画类 - 其余样式全部使用Tailwind */
.rotating {
  animation: rotating 0.5s linear;
}
@keyframes rotating {
  from { transform: rotate(0deg); }
  to { transform: rotate(360deg); }
}

/* 移动端优化 */
@media (max-width: 768px) {
  .todo-card {
    padding: 0.875rem 1rem;
    margin-bottom: 0.625rem;
    border-radius: 1rem;
  }

  .flex.items-center.gap-2 {
    padding-left: 0.5rem;
    gap: 0.5rem;
  }
}
</style>
