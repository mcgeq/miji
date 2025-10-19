<script setup lang="ts">
import { computed, ref } from 'vue';
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
const isModalVisible = ref(false);
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
  // 延迟设置可见性，防止闪烁
  setTimeout(() => {
    isModalVisible.value = true;
  }, 10);
}

function closeModal() {
  isModalVisible.value = false;
  // 延迟关闭，等待动画完成
  setTimeout(() => {
    showModal.value = false;
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

// 排序子任务
function moveSubtaskUp(subtask: Todo) {
  const currentOrder = subtask.subtaskOrder || 0;
  updateSubtask(subtask, { subtaskOrder: currentOrder - 1 });
}

function moveSubtaskDown(subtask: Todo) {
  const currentOrder = subtask.subtaskOrder || 0;
  updateSubtask(subtask, { subtaskOrder: currentOrder + 1 });
}
</script>

<template>
  <div class="todo-subtasks">
    <!-- 子任务显示按钮 -->
    <button
      class="todo-btn"
      :class="{
        'todo-btn--active': hasSubtasks,
        'todo-btn--readonly': readonly,
      }"
      :title="hasSubtasks ? `子任务: ${completedSubtasks}/${subtaskCount} (${subtaskProgress}%)` : '添加子任务'"
      @click="openModal"
    >
      <svg class="icon" viewBox="0 0 24 24" fill="currentColor">
        <path d="M3,3V21H21V3H3M19,19H5V5H19V19M11,7H13V9H11V7M11,11H13V13H11V11M11,15H13V17H11V15M7,7H9V9H7V7M7,11H9V13H7V11M7,15H9V17H7V15M15,7H17V9H15V7M15,11H17V13H15V11M15,15H17V17H15V15Z" />
      </svg>
      <span class="subtasks-text">
        {{ hasSubtasks ? `${completedSubtasks}/${subtaskCount}` : '' }}
      </span>
      <div v-if="hasSubtasks" class="progress-bar">
        <div
          class="progress-fill"
          :style="{ width: `${subtaskProgress}%` }"
        />
      </div>
    </button>

    <!-- 子任务模态框 -->
    <Teleport to="body">
      <div v-if="showModal" class="modal-overlay teleport" :class="{ visible: isModalVisible }" @click="closeModal">
        <div class="modal-content teleport" @click.stop>
          <div class="modal-header teleport">
            <h3>子任务</h3>
            <div class="header-actions">
              <span v-if="hasSubtasks" class="progress-text">
                {{ completedSubtasks }}/{{ subtaskCount }} ({{ subtaskProgress }}%)
              </span>
              <button class="close-btn teleport" @click="closeModal">
                ×
              </button>
            </div>
          </div>

          <div class="modal-body teleport">
            <!-- 创建新子任务 -->
            <div class="create-section">
              <div v-if="!showCreateForm" class="create-toggle">
                <button class="create-btn" @click="showCreateSubtaskForm">
                  <svg class="icon" viewBox="0 0 24 24" fill="currentColor">
                    <path d="M19,13H13V19H11V13H5V11H11V5H13V11H19V13Z" />
                  </svg>
                  添加子任务
                </button>
              </div>

              <div v-else class="create-form">
                <div class="input-group">
                  <input
                    v-model="newSubtaskTitle"
                    type="text"
                    placeholder="输入子任务标题..."
                    class="subtask-input"
                    @keyup.enter="createSubtask"
                    @keyup.escape="cancelCreate"
                  >
                  <div class="form-actions">
                    <button class="btn-secondary" @click="cancelCreate">
                      取消
                    </button>
                    <button
                      class="btn-primary"
                      :disabled="!newSubtaskTitle.trim()"
                      @click="createSubtask"
                    >
                      添加
                    </button>
                  </div>
                </div>
              </div>
            </div>

            <!-- 子任务列表 -->
            <div v-if="hasSubtasks" class="subtasks-list">
              <div class="list-header">
                <span>子任务列表</span>
                <span class="count">{{ subtaskCount }} 项</span>
              </div>

              <div class="subtasks-container">
                <div
                  v-for="(subtask, index) in subtasks"
                  :key="subtask.serialNum"
                  class="subtask-item"
                  :class="{ completed: subtask.status === 'Completed' }"
                >
                  <!-- 编辑模式 -->
                  <div v-if="editingSubtask?.serialNum === subtask.serialNum" class="edit-mode">
                    <input
                      v-model="editingSubtask.title"
                      type="text"
                      class="edit-input"
                      @keyup.enter="saveSubtaskEdit"
                      @keyup.escape="cancelEdit"
                    >
                    <div class="edit-actions">
                      <button class="btn-primary" @click="saveSubtaskEdit">
                        保存
                      </button>
                      <button class="btn-secondary" @click="cancelEdit">
                        取消
                      </button>
                    </div>
                  </div>

                  <!-- 显示模式 -->
                  <div v-else class="view-mode">
                    <div class="subtask-main">
                      <button
                        class="status-btn"
                        :class="{ completed: subtask.status === 'Completed' }"
                        @click="toggleSubtaskStatus(subtask)"
                      >
                        <svg v-if="subtask.status === 'Completed'" class="check-icon" viewBox="0 0 24 24" fill="currentColor">
                          <path d="M9,20.42L2.79,14.21L5.62,11.38L9,14.77L18.88,4.88L21.71,7.71L9,20.42Z" />
                        </svg>
                      </button>

                      <span
                        class="subtask-title"
                        :class="{ completed: subtask.status === 'Completed' }"
                        @dblclick="editSubtask(subtask)"
                      >
                        {{ subtask.title }}
                      </span>
                    </div>

                    <div class="subtask-actions">
                      <button
                        class="action-btn"
                        title="编辑"
                        @click="editSubtask(subtask)"
                      >
                        <svg class="icon" viewBox="0 0 24 24" fill="currentColor">
                          <path d="M20.71,7.04C21.1,6.65 21.1,6 20.71,5.63L18.37,3.29C18,2.9 17.35,2.9 16.96,3.29L15.12,5.12L18.87,8.87M3,17.25V21H6.75L17.81,9.93L14.06,6.18L3,17.25Z" />
                        </svg>
                      </button>

                      <button
                        class="action-btn"
                        :disabled="index === 0"
                        title="上移"
                        @click="moveSubtaskUp(subtask)"
                      >
                        <svg class="icon" viewBox="0 0 24 24" fill="currentColor">
                          <path d="M13,20H11V8L5.5,13.5L4.08,12.08L12,4.16L19.92,12.08L18.5,13.5L13,8V20Z" />
                        </svg>
                      </button>

                      <button
                        class="action-btn"
                        :disabled="index === subtasks!.length - 1"
                        title="下移"
                        @click="moveSubtaskDown(subtask)"
                      >
                        <svg class="icon" viewBox="0 0 24 24" fill="currentColor">
                          <path d="M11,4H13V16L18.5,10.5L19.92,11.92L12,19.84L4.08,11.92L5.5,10.5L11,16V4Z" />
                        </svg>
                      </button>

                      <button
                        class="action-btn delete"
                        title="删除"
                        @click="deleteSubtask(subtask)"
                      >
                        <svg class="icon" viewBox="0 0 24 24" fill="currentColor">
                          <path d="M19,4H15.5L14.5,3H9.5L8.5,4H5V6H19M6,19A2,2 0 0,0 8,21H16A2,2 0 0,0 18,19V7H6V19Z" />
                        </svg>
                      </button>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <!-- 空状态 -->
            <div v-else class="empty-state">
              <svg class="empty-icon" viewBox="0 0 24 24" fill="currentColor">
                <path d="M3,3V21H21V3H3M19,19H5V5H19V19M11,7H13V9H11V7M11,11H13V13H11V11M11,15H13V17H11V15M7,7H9V9H7V7M7,11H9V13H7V11M7,15H9V17H7V15M15,7H17V9H15V7M15,11H17V13H15V11M15,15H17V17H15V15Z" />
              </svg>
              <p>还没有子任务</p>
              <p class="empty-hint">
                点击"添加子任务"开始创建
              </p>
            </div>
          </div>

          <div class="modal-footer teleport">
            <button class="btn-secondary teleport" @click="closeModal">
              关闭
            </button>
          </div>
        </div>
      </div>
    </Teleport>
  </div>
</template>

<style scoped lang="postcss">
.todo-subtasks {
  position: relative;
}

/* 按钮样式现在使用全局 .todo-btn 样式 */

.icon {
  width: 0.875rem;
  height: 0.875rem;
  flex-shrink: 0;
}

.subtasks-text {
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  max-width: 4rem;
}

.progress-bar {
  position: absolute;
  bottom: 0;
  left: 0;
  right: 0;
  height: 2px;
  background: rgba(255, 255, 255, 0.3);
  border-radius: 0 0 0.5rem 0.5rem;
}

.progress-fill {
  height: 100%;
  background: var(--color-success);
  border-radius: 0 0 0.5rem 0.5rem;
  transition: width 0.3s ease;
}

/* 模态框样式 */
.modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 10001;
  backdrop-filter: blur(4px);
}

.modal-content {
  background: var(--color-base-100);
  border-radius: 1rem;
  box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1);
  max-width: 600px;
  width: 90%;
  max-height: 80vh;
  overflow-y: auto;
  /* 隐藏滚动条但保留滚动功能 */
  scrollbar-width: none; /* Firefox */
  -ms-overflow-style: none; /* IE and Edge */
}

.modal-content::-webkit-scrollbar {
  display: none; /* Chrome, Safari and Opera */
}

.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1.5rem 1.5rem 0;
}

.modal-header h3 {
  margin: 0;
  font-size: 1.25rem;
  font-weight: 600;
}

.header-actions {
  display: flex;
  align-items: center;
  gap: 1rem;
}

.progress-text {
  font-size: 0.875rem;
  color: var(--color-base-content);
  font-weight: 500;
}

.close-btn {
  background: none;
  border: none;
  font-size: 1.5rem;
  cursor: pointer;
  color: var(--color-base-content);
  padding: 0.25rem;
  border-radius: 0.25rem;
}

.close-btn:hover {
  background: var(--color-base-200);
}

.modal-body {
  padding: 1.5rem;
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
}

/* 创建子任务部分 */
.create-section {
  border: 1px solid var(--color-base-300);
  border-radius: 0.5rem;
  overflow: hidden;
}

.create-toggle {
  padding: 1rem;
}

.create-btn {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.75rem 1rem;
  border: 1px dashed var(--color-base-300);
  border-radius: 0.5rem;
  background: var(--color-base-100);
  color: var(--color-base-content);
  cursor: pointer;
  transition: all 0.2s ease;
  width: 100%;
}

.create-btn:hover {
  border-color: var(--color-primary);
  background: var(--color-base-200);
}

.create-form {
  padding: 1rem;
  background: var(--color-base-200);
}

.input-group {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.subtask-input {
  padding: 0.75rem;
  border: 1px solid var(--color-base-300);
  border-radius: 0.5rem;
  font-size: 1rem;
  background: var(--color-base-100);
  color: var(--color-base-content);
}

.subtask-input:focus {
  outline: none;
  border-color: var(--color-primary);
  box-shadow: 0 0 0 3px rgba(var(--color-primary-rgb), 0.1);
}

.form-actions {
  display: flex;
  gap: 0.5rem;
  justify-content: flex-end;
}

/* 子任务列表 */
.subtasks-list {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.list-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-weight: 500;
  color: var(--color-base-content);
}

.count {
  font-size: 0.875rem;
  color: var(--color-base-content);
  opacity: 0.7;
}

.subtasks-container {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.subtask-item {
  border: 1px solid var(--color-base-300);
  border-radius: 0.5rem;
  background: var(--color-base-100);
  transition: all 0.2s ease;
}

.subtask-item.completed {
  background: var(--color-base-200);
  opacity: 0.8;
}

.subtask-item:hover {
  border-color: var(--color-primary);
}

/* 编辑模式 */
.edit-mode {
  padding: 1rem;
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.edit-input {
  padding: 0.75rem;
  border: 1px solid var(--color-primary);
  border-radius: 0.5rem;
  font-size: 1rem;
  background: var(--color-base-100);
  color: var(--color-base-content);
}

.edit-input:focus {
  outline: none;
  box-shadow: 0 0 0 3px rgba(var(--color-primary-rgb), 0.1);
}

.edit-actions {
  display: flex;
  gap: 0.5rem;
  justify-content: flex-end;
}

/* 显示模式 */
.view-mode {
  padding: 1rem;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.subtask-main {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  flex: 1;
  min-width: 0;
}

.status-btn {
  width: 1.25rem;
  height: 1.25rem;
  border: 2px solid var(--color-base-300);
  border-radius: 0.25rem;
  background: var(--color-base-100);
  cursor: pointer;
  transition: all 0.2s ease;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.status-btn:hover {
  border-color: var(--color-primary);
}

.status-btn.completed {
  background: var(--color-success);
  border-color: var(--color-success);
  color: var(--color-success-content);
}

.check-icon {
  width: 0.875rem;
  height: 0.875rem;
}

.subtask-title {
  flex: 1;
  min-width: 0;
  cursor: pointer;
  transition: all 0.2s ease;
}

.subtask-title:hover {
  color: var(--color-primary);
}

.subtask-title.completed {
  text-decoration: line-through;
  opacity: 0.7;
}

.subtask-actions {
  display: flex;
  gap: 0.25rem;
  flex-shrink: 0;
}

.action-btn {
  width: 2rem;
  height: 2rem;
  border: 1px solid var(--color-base-300);
  border-radius: 0.375rem;
  background: var(--color-base-100);
  color: var(--color-base-content);
  cursor: pointer;
  transition: all 0.2s ease;
  display: flex;
  align-items: center;
  justify-content: center;
}

.action-btn:hover:not(:disabled) {
  background: var(--color-base-200);
  border-color: var(--color-primary);
}

.action-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.action-btn.delete:hover:not(:disabled) {
  background: var(--color-error);
  color: var(--color-error-content);
  border-color: var(--color-error);
}

.action-btn .icon {
  width: 0.875rem;
  height: 0.875rem;
}

/* 空状态 */
.empty-state {
  text-align: center;
  padding: 2rem;
  color: var(--color-base-content);
  opacity: 0.7;
}

.empty-icon {
  width: 3rem;
  height: 3rem;
  margin: 0 auto 1rem;
  opacity: 0.5;
}

.empty-hint {
  font-size: 0.875rem;
  margin-top: 0.5rem;
}

.modal-footer {
  display: flex;
  justify-content: flex-end;
  padding: 1.5rem;
  border-top: 1px solid var(--color-base-200);
}

.btn-secondary,
.btn-primary {
  padding: 0.75rem 1.5rem;
  border-radius: 0.5rem;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s ease;
}

.btn-secondary {
  background: var(--color-base-200);
  color: var(--color-base-content);
  border: 1px solid var(--color-base-300);
}

.btn-secondary:hover {
  background: var(--color-base-300);
}

.btn-primary {
  background: var(--color-primary);
  color: var(--color-primary-content);
  border: 1px solid var(--color-primary);
}

.btn-primary:hover:not(:disabled) {
  background: var(--color-primary-focus);
}

.btn-primary:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

/* 响应式设计 */
@media (max-width: 768px) {
  .modal-content {
    width: 95%;
    margin: 1rem;
  }

  .subtask-main {
    flex-direction: column;
    align-items: flex-start;
    gap: 0.5rem;
  }

  .subtask-actions {
    align-self: flex-end;
  }

  .form-actions {
    flex-direction: column;
  }

  .edit-actions {
    flex-direction: column;
  }
}
</style>
