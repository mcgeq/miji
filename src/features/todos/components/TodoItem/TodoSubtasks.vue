<script setup lang="ts">
import { Check, CheckCircle, Edit, ListTodo, Plus, Trash2, X } from 'lucide-vue-next';
import { Modal, TodoButton } from '@/components/ui';
import type { Todo, TodoUpdate } from '@/schema/todos';

const props = defineProps<{
  todo: Todo;
  subtasks?: Todo[];
  readonly?: boolean;
}>();

const emit = defineEmits<{
  update: [update: TodoUpdate];
  createSubtask: [parentId: string, title: string];
  updateSubtask: [serialNum: string, update: TodoUpdate];
  deleteSubtask: [serialNum: string];
}>();

const showModal = ref(false);
const newSubtaskTitle = ref('');
const editingSubtask = ref<Todo | null>(null);
const showCreateForm = ref(false);

// 计算属性
const hasSubtasks = computed(() => (props.subtasks?.length || 0) > 0);
const subtaskCount = computed(() => props.subtasks?.length || 0);
const completedSubtasks = computed(() =>
  props.subtasks?.filter(task => task.status === 'Completed').length || 0,
);
const subtaskProgress = computed(() => {
  if (subtaskCount.value === 0) return 0;
  return Math.round((completedSubtasks.value / subtaskCount.value) * 100);
});

// 方法
function openModal() {
  if (props.readonly) return;
  showModal.value = true;
}

function closeModal() {
  showModal.value = false;
  setTimeout(() => {
    newSubtaskTitle.value = '';
    editingSubtask.value = null;
    showCreateForm.value = false;
  }, 200);
}

function createSubtask() {
  const title = newSubtaskTitle.value.trim();
  if (!title) return;

  emit('createSubtask', props.todo.serialNum, title);
  newSubtaskTitle.value = '';
  showCreateForm.value = false;
}

function updateSubtask(subtask: Todo, update: TodoUpdate) {
  emit('updateSubtask', subtask.serialNum, update);
}

function deleteSubtask(subtask: Todo) {
  emit('deleteSubtask', subtask.serialNum);
}

function editSubtask(subtask: Todo) {
  editingSubtask.value = subtask;
}

function saveSubtaskEdit() {
  if (!editingSubtask.value) return;

  const title = editingSubtask.value.title.trim();
  if (title) {
    updateSubtask(editingSubtask.value, { title });
  }
  editingSubtask.value = null;
}

function cancelEdit() {
  editingSubtask.value = null;
}

function toggleSubtaskStatus(subtask: Todo) {
  const newStatus = subtask.status === 'Completed' ? 'NotStarted' : 'Completed';
  updateSubtask(subtask, { status: newStatus });
}

function showCreateSubtaskForm() {
  showCreateForm.value = true;
}

function cancelCreate() {
  showCreateForm.value = false;
  newSubtaskTitle.value = '';
}
</script>

<template>
  <div class="relative">
    <!-- 子任务显示按钮 -->
    <div class="relative">
      <TodoButton
        :icon="ListTodo"
        :text="hasSubtasks ? `${completedSubtasks}/${subtaskCount}` : ''"
        :active="hasSubtasks"
        :readonly="props.readonly"
        :title="hasSubtasks ? `子任务: ${completedSubtasks}/${subtaskCount} (${subtaskProgress}%)` : '添加子任务'"
        @click="openModal"
      />
      <!-- 进度条 -->
      <div v-if="hasSubtasks" class="absolute bottom-0 left-0 right-0 h-0.5 bg-white/30 dark:bg-gray-700/30 rounded-b-lg">
        <div
          class="h-full bg-green-500 dark:bg-green-400 rounded-b-lg transition-all duration-300"
          :style="{ width: `${subtaskProgress}%` }"
        />
      </div>
    </div>

    <!-- 子任务模态框 -->
    <Modal
      :open="showModal"
      title="子任务"
      size="lg"
      :show-footer="false"
      @close="closeModal"
    >
      <template #header>
        <div class="flex items-center justify-between w-full">
          <h3 class="text-xl font-semibold">
            子任务
          </h3>
          <span v-if="hasSubtasks" class="text-sm text-gray-500">
            {{ completedSubtasks }}/{{ subtaskCount }} ({{ subtaskProgress }}%)
          </span>
        </div>
      </template>
      <div class="space-y-4">
        <!-- 创建新子任务 -->
        <div v-if="!showCreateForm">
          <button
            class="w-full flex items-center justify-center gap-2 px-4 py-3 border-2 border-dashed border-gray-300 dark:border-gray-600 rounded-lg hover:border-blue-500 dark:hover:border-blue-400 hover:bg-blue-50 dark:hover:bg-blue-900/20 transition-colors text-gray-700 dark:text-gray-300"
            @click="showCreateSubtaskForm"
          >
            <Plus :size="16" />
            添加子任务
          </button>
        </div>

        <div v-else class="flex gap-2">
          <input
            v-model="newSubtaskTitle"
            type="text"
            placeholder="输入子任务标题..."
            class="flex-1 px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            @keyup.enter="createSubtask"
            @keyup.escape="cancelCreate"
          >
          <button
            class="px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors"
            @click="cancelCreate"
          >
            <X :size="20" />
          </button>
          <button
            class="px-3 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 dark:bg-blue-500 dark:hover:bg-blue-600 disabled:opacity-50 transition-colors"
            :disabled="!newSubtaskTitle.trim()"
            @click="createSubtask"
          >
            <Plus :size="20" />
          </button>
        </div>

        <!-- 子任务列表 -->
        <div v-if="hasSubtasks" class="space-y-3">
          <div class="flex items-center justify-between text-sm">
            <span class="font-medium text-gray-900 dark:text-white">子任务列表</span>
            <span class="text-gray-500 dark:text-gray-400">{{ subtaskCount }} 项</span>
          </div>

          <div class="space-y-2">
            <div
              v-for="subtask in subtasks"
              :key="subtask.serialNum"
              class="flex items-center gap-3 p-3 bg-gray-50 dark:bg-gray-800 rounded-lg hover:bg-gray-100 transition-colors"
              :class="{ 'opacity-60': subtask.status === 'Completed' }"
            >
              <!-- 编辑模式 -->
              <div v-if="editingSubtask?.serialNum === subtask.serialNum" class="flex items-center gap-2 flex-1">
                <input
                  v-model="editingSubtask.title"
                  type="text"
                  class="flex-1 px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  @keyup.enter="saveSubtaskEdit"
                  @keyup.escape="cancelEdit"
                >
                <button
                  class="p-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 dark:bg-blue-500 dark:hover:bg-blue-600 transition-colors"
                  @click="saveSubtaskEdit"
                >
                  <Check :size="20" />
                </button>
                <button
                  class="p-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors"
                  @click="cancelEdit"
                >
                  <X :size="20" />
                </button>
              </div>

              <!-- 显示模式 -->
              <template v-else>
                <button
                  class="flex-shrink-0 w-5 h-5 rounded border-2 flex items-center justify-center transition-colors"
                  :class="subtask.status === 'Completed' ? 'bg-green-500 border-green-500' : 'border-gray-300 hover:border-green-500'"
                  @click="toggleSubtaskStatus(subtask)"
                >
                  <CheckCircle v-if="subtask.status === 'Completed'" class="text-white" :size="16" />
                </button>

                <span
                  class="flex-1 cursor-pointer text-gray-900 dark:text-white"
                  :class="{ 'line-through text-gray-500 dark:text-gray-400': subtask.status === 'Completed' }"
                  @dblclick="editSubtask(subtask)"
                >
                  {{ subtask.title }}
                </span>

                <div class="flex items-center gap-1">
                  <button
                    class="p-2 rounded-lg hover:bg-gray-200 dark:hover:bg-gray-700 text-gray-600 dark:text-gray-400 transition-colors"
                    title="编辑"
                    @click="editSubtask(subtask)"
                  >
                    <Edit :size="16" />
                  </button>
                  <button
                    class="p-2 rounded-lg hover:bg-red-50 dark:hover:bg-red-900/20 text-red-600 dark:text-red-400 disabled:opacity-30 transition-colors"
                    title="删除"
                    @click="deleteSubtask(subtask)"
                  >
                    <Trash2 :size="16" />
                  </button>
                </div>
              </template>
            </div>
          </div>
        </div>

        <!-- 空状态 -->
        <div v-else class="text-center py-8 text-gray-400 dark:text-gray-500">
          <ListTodo class="mx-auto mb-2" :size="48" />
          <p class="text-sm">
            还没有子任务
          </p>
          <p class="text-xs mt-1">
            点击“添加子任务”开始创建
          </p>
        </div>
      </div>
    </Modal>
  </div>
</template>

<style scoped>
/* 所有样式已使用 Tailwind CSS 4 */
</style>
