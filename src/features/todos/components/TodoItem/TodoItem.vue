<template>
  <div class="p-4 bg-white rounded-2xl border border-gray-200 flex flex-col h-18 mb-2 relative" @mouseenter="showActions = true" @mouseleave="showActions = false">
    <!-- Left Section with Checkbox, Priority, and Title -->
    <div class="flex items-center justify-between flex-1">
      <div class="flex items-center gap-2">
        <PriorityBadge
          v-if="todoCopy.priority"
          :serialNum="todoCopy.serialNum"
          :priority="todoCopy.priority"
          :completed="completed"
          @changePriority="onChangePriorityHandler"
        />
        <TodoCheckbox :completed="completed" @toggle="onToggleHandler" />
        <TodoTitle :title="todoCopy.title" :completed="completed" @toggle="onToggleHandler" />
      </div>

      <!-- Right Section with Actions -->
      <TodoActions
        :completed="completed"
        :show="showActions"
        @edit="onEditClick"
        @add="toggleMenu"
        @remove="onRemoveClick"
      />
    </div>

    <!-- Due Date -->
    <div v-if="todoCopy.dueAt" class="text-xs text-gray-500 absolute right-4 bottom-1">
      {{ todoCopy.remainingTime }}
    </div>

    <!-- Menus and Modals -->
    <TodoAddMenus
      v-if="showMenu"
      @openPopup="openPopup"
      @close="toggleMenu"
    />
    <TodoEditOptionsModal
      v-if="showEditOptions"
      @editTitle="openEditModal"
      @editDueDate="openDueDateModal"
      @editRepeat="openEditRepeatModal"
      @close="showEditOptions = false"
    />
    <TodoEditTitleModal
      v-if="showEditModal"
      :title="todoCopy.title"
      @save="submitTitleChange"
      @close="showEditModal = false"
    />
    <TodoEditDueDateModal
      v-if="showDueDateModal"
      :dueDate="todoCopy.dueAt"
      @save="submitDueDateChange"
      @close="showDueDateModal = false"
    />
    <TodoEditRepeatModal
      v-if="showEditRepeatModal"
      :repeat="todoCopy.repeat ?? {type: 'None'}"
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

<script setup lang="ts">
import PriorityBadge from '@/components/common/PriorityBadge.vue';
import TodoCheckbox from './TodoCheckbox.vue';
import TodoActions from './TodoActions.vue';
import TodoAddMenus from './TodoAddMenus.vue';
import TodoEditOptionsModal from './TodoEditOptionsModal.vue';
import TodoEditTitleModal from './TodoEditTitleModal.vue';
import TodoEditDueDateModal from './TodoEditDueDateModal.vue';
import TodoEditRepeatModal from './TodoEditRepeatModal.vue';
import PopupWrapper from '@/components/common/PopupWrapper.vue';
import TagsView from '@/features/tags/views/TagsView.vue';
import ProjectsView from '@/features/projects/views/ProjectsView.vue';
import Descriptions from '@/components/common/Descriptions.vue';
import { TodoRemain } from '@/schema/todos';
import { Priority, RepeatPeriod, StatusSchema } from '@/schema/common';
import { parseToISO } from '@/utils/date';
import { useMenuStore } from '@/stores/menuStore';
import TodoTitle from './TodoTitle.vue';

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
const updateTodo = (partial: Partial<TodoRemain>) => {
  todoCopy.value = { ...todoCopy.value, ...partial };
  emit('update:todo', { ...todoCopy.value });
};

const onToggleHandler = () => {
  if (!completed.value) {
    updateTodo({ status: StatusSchema.enum.Completed });
    emit('toggle');
  }
};

const onEditClick = () => {
  if (!completed.value) {
    showEditOptions.value = true;
  }
};

const onRemoveClick = () => {
  if (!completed.value) {
    emit('remove');
  }
};

const toggleMenu = () => {
  isRotatingAdd.value = true;
  const currentSerial = todoCopy.value.serialNum;
  menuStore.setMenuSerialNum(
    menuStore.getMenuSerialNum === currentSerial ? '' : currentSerial,
  );
  setTimeout(() => (isRotatingAdd.value = false), 500);
};

const openEditModal = () => {
  showEditOptions.value = false;
  showEditModal.value = true;
};

const openDueDateModal = () => {
  showEditOptions.value = false;
  showDueDateModal.value = true;
};

const openEditRepeatModal = () => {
  showEditOptions.value = false;
  showEditRepeatModal.value = true;
};

const submitTitleChange = (newTitle: string) => {
  const trimmed = newTitle.trim();
  if (trimmed && trimmed !== todoCopy.value.title) {
    updateTodo({ title: trimmed });
    emit('edit');
  }
  showEditModal.value = false;
};

const submitDueDateChange = (newDueAt: string) => {
  const newDue = parseToISO(newDueAt);
  if (newDue !== todoCopy.value.dueAt) {
    updateTodo({ dueAt: newDue });
    emit('edit');
  }
  showDueDateModal.value = false;
};

const submitRepeatChange = (repeat: RepeatPeriod) => {
  if (repeat !== todoCopy.value.repeat) {
    updateTodo({ repeat: repeat });
    emit('edit');
  }
};

const onChangePriorityHandler = (serialNum: string, priority: Priority) => {
  if (serialNum === todoCopy.value.serialNum) {
    updateTodo({ priority });
  }
};

const openPopup = (type: string) => {
  currentPopup.value = type;
};

const closeMenu = () => {
  currentPopup.value = '';
  toggleMenu();
};
</script>

<style scoped>
.rotating {
  animation: rotating 0.5s linear;
}
@keyframes rotating {
  from { transform: rotate(0deg); }
  to { transform: rotate(360deg); }
}
.fade-enter-active, .fade-leave-active {
  transition: opacity 0.25s ease-out, transform 0.25s ease-out;
}
.fade-enter-from, .fade-leave-to {
  opacity: 0;
  transform: translateY(8px);
}
.scale-enter-active, .scale-leave-active {
  transition: transform 0.2s ease-out;
}
.scale-enter-from, .scale-leave-to {
  transform: scale(0.9);
}
</style>
