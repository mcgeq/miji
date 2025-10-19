<script setup lang="ts">
import { CheckCircle, Play } from 'lucide-vue-next';
import { computed, ref } from 'vue';
import type { TodoUpdate } from '@/schema/todos';

const props = defineProps<{
  progress: number;
  readonly?: boolean;
}>();

const emit = defineEmits<{
  update: [update: TodoUpdate];
}>();

const showEditModal = ref(false);
const isModalVisible = ref(false);
const editingProgress = ref(props.progress);

// 计算属性
const progressPercentage = computed(() => Math.min(Math.max(props.progress, 0), 100));
const progressColor = computed(() => {
  if (progressPercentage.value === 100) return 'var(--color-success)';
  if (progressPercentage.value >= 75) return 'var(--color-info)';
  if (progressPercentage.value >= 50) return 'var(--color-warning)';
  return 'var(--color-error)';
});

// 预设进度值
const quickProgressOptions = [0, 25, 50, 75, 100];

// 方法
function openEditModal() {
  if (props.readonly) return;
  editingProgress.value = props.progress;
  showEditModal.value = true;
  // 延迟设置可见性，防止闪烁
  setTimeout(() => {
    isModalVisible.value = true;
  }, 10);
}

function closeEditModal() {
  isModalVisible.value = false;
  // 延迟关闭，等待动画完成
  setTimeout(() => {
    showEditModal.value = false;
  }, 200);
}

function updateProgress(newProgress: number) {
  const clampedProgress = Math.min(Math.max(newProgress, 0), 100);
  emit('update', { progress: clampedProgress });
  closeEditModal();
}

function setQuickProgress(progress: number) {
  updateProgress(progress);
}
</script>

<template>
  <div class="todo-progress">
    <!-- 进度条显示和快速设置按钮 -->
    <div class="progress-row">
      <!-- 进度条显示 -->
      <div class="progress-container" :class="{ readonly }" @click="openEditModal">
        <div class="progress-bar">
          <div
            class="progress-fill"
            :style="{
              width: `${progressPercentage}%`,
              backgroundColor: progressColor,
            }"
          />
        </div>
      </div>

      <!-- 快速设置按钮 -->
      <div v-if="!readonly" class="quick-progress">
        <button
          v-for="value in quickProgressOptions"
          :key="value"
          class="todo-btn todo-btn--icon-only"
          :class="{ 'todo-btn--active': progress === value }"
          :title="value === 0 ? '未开始' : value === 100 ? '已完成' : `${value}%`"
          @click="setQuickProgress(value)"
        >
          <Play v-if="value === 0" class="quick-icon" :size="14" />
          <CheckCircle v-else-if="value === 100" class="quick-icon" :size="14" />
          <span v-else>{{ value }}%</span>
        </button>
      </div>
    </div>

    <!-- 进度编辑模态框 -->
    <Teleport to="body">
      <div v-if="showEditModal" class="modal-overlay teleport" :class="{ visible: isModalVisible }" @click="closeEditModal">
        <div class="modal-content teleport" @click.stop>
          <div class="modal-header">
            <h3>设置进度</h3>
            <button class="close-btn" @click="closeEditModal">
              ×
            </button>
          </div>

          <div class="modal-body">
            <!-- 滑块输入 -->
            <div class="slider-container">
              <label for="progress-slider">进度: {{ editingProgress }}%</label>
              <input
                id="progress-slider"
                v-model="editingProgress"
                type="range"
                min="0"
                max="100"
                step="5"
                class="progress-slider"
              >
              <div class="slider-labels">
                <span>0%</span>
                <span>25%</span>
                <span>50%</span>
                <span>75%</span>
                <span>100%</span>
              </div>
            </div>

            <!-- 数字输入 -->
            <div class="number-input-container">
              <label for="progress-number">精确数值:</label>
              <input
                id="progress-number"
                v-model="editingProgress"
                type="number"
                min="0"
                max="100"
                class="progress-number"
              >
              <span>%</span>
            </div>

            <!-- 快速选择 -->
            <div class="quick-select">
              <label>快速选择:</label>
              <div class="quick-options">
                <button
                  v-for="value in quickProgressOptions"
                  :key="value"
                  class="quick-option"
                  :class="{ active: editingProgress === value }"
                  @click="editingProgress = value"
                >
                  <Play v-if="value === 0" class="modal-icon" :size="16" />
                  <CheckCircle v-else-if="value === 100" class="modal-icon" :size="16" />
                  <span v-else>{{ value }}%</span>
                </button>
              </div>
            </div>

            <!-- 预览 -->
            <div class="progress-preview">
              <label>预览:</label>
              <div class="preview-bar">
                <div
                  class="preview-fill"
                  :style="{
                    width: `${Math.min(Math.max(editingProgress, 0), 100)}%`,
                    backgroundColor: progressColor,
                  }"
                />
              </div>
              <div class="preview-text">
                <Play v-if="editingProgress === 0" class="preview-icon" :size="16" />
                <CheckCircle v-else-if="editingProgress === 100" class="preview-icon" :size="16" />
                <span v-else>{{ editingProgress }}%</span>
              </div>
            </div>
          </div>

          <div class="modal-footer">
            <button class="btn-secondary" @click="closeEditModal">
              取消
            </button>
            <button class="btn-primary" @click="updateProgress(editingProgress)">
              保存
            </button>
          </div>
        </div>
      </div>
    </Teleport>
  </div>
</template>

<style scoped lang="postcss">
.todo-progress {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.progress-row {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.progress-container {
  display: flex;
  width: 8rem;
  align-items: center;
  padding: 0.375rem 0.75rem;
  border-radius: 0.5rem;
  background: linear-gradient(
    135deg,
    var(--color-base-100) 0%,
    color-mix(in oklch, var(--color-base-100) 95%, var(--color-primary)) 100%
  );
  border: 2px solid #d1d5db;
  cursor: pointer;
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
  box-shadow: var(--shadow-sm);
  backdrop-filter: blur(10px);
  flex: 1;
}

.progress-container:hover {
  background: linear-gradient(
    135deg,
    var(--color-base-100) 0%,
    color-mix(in oklch, var(--color-base-100) 90%, var(--color-primary)) 100%
  );
  border-color: var(--color-primary);
  box-shadow: var(--shadow-md);
  transform: translateY(-1px);
}

.progress-container.readonly {
  cursor: default;
  opacity: 0.8;
}

.progress-container.readonly:hover {
  background: linear-gradient(
    135deg,
    var(--color-base-100) 0%,
    color-mix(in oklch, var(--color-base-100) 95%, var(--color-primary)) 100%
  );
  border-color: var(--color-base-300);
  box-shadow: var(--shadow-sm);
  transform: none;
}

.progress-bar {
  width: 100%;
  height: 0.75rem;
  background: #e5e7eb;
  border-radius: 0.375rem;
  overflow: hidden;
  position: relative;
  box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.1);
  min-height: 0.75rem;
}

.progress-fill {
  height: 100%;
  background: #3b82f6;
  border-radius: 0.375rem;
  transition: width 0.4s cubic-bezier(0.4, 0, 0.2, 1), background-color 0.3s ease;
  position: relative;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.2);
}

.progress-fill::after {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: linear-gradient(
    90deg,
    transparent 0%,
    rgba(255, 255, 255, 0.3) 50%,
    transparent 100%
  );
  animation: shimmer 2s infinite;
}

@keyframes shimmer {
  0% { transform: translateX(-100%); }
  100% { transform: translateX(100%); }
}

.quick-progress {
  display: flex;
  gap: 0.375rem;
  justify-content: flex-end;
  flex-shrink: 0;
}

/* 快速设置按钮样式现在使用全局 .todo-btn 样式 */

.quick-icon {
  color: currentColor;
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
}

.modal-content {
  background: var(--color-base-100);
  border-radius: 1rem;
  box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1);
  max-width: 400px;
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

.slider-container {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.slider-container label {
  font-weight: 500;
  color: var(--color-base-content);
}

.progress-slider {
  width: 100%;
  height: 0.5rem;
  border-radius: 0.25rem;
  background: var(--color-base-300);
  outline: none;
  cursor: pointer;
}

.progress-slider::-webkit-slider-thumb {
  appearance: none;
  width: 1.25rem;
  height: 1.25rem;
  border-radius: 50%;
  background: var(--color-primary);
  cursor: pointer;
  border: 2px solid var(--color-base-100);
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

.progress-slider::-moz-range-thumb {
  width: 1.25rem;
  height: 1.25rem;
  border-radius: 50%;
  background: var(--color-primary);
  cursor: pointer;
  border: 2px solid var(--color-base-100);
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

.slider-labels {
  display: flex;
  justify-content: space-between;
  font-size: 0.75rem;
  color: var(--color-base-content);
  margin-top: 0.25rem;
}

.number-input-container {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.number-input-container label {
  font-weight: 500;
  color: var(--color-base-content);
}

.progress-number {
  width: 4rem;
  padding: 0.5rem;
  border: 1px solid var(--color-base-300);
  border-radius: 0.375rem;
  text-align: center;
}

.quick-select {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.quick-select label {
  font-weight: 500;
  color: var(--color-base-content);
}

.quick-options {
  display: grid;
  grid-template-columns: repeat(5, 1fr);
  gap: 0.5rem;
}

.quick-option {
  padding: 0.5rem;
  border: 1px solid var(--color-base-300);
  border-radius: 0.375rem;
  background: var(--color-base-100);
  color: var(--color-base-content);
  cursor: pointer;
  transition: all 0.2s ease;
  font-size: 0.875rem;
}

.quick-option:hover {
  background: var(--color-base-200);
  border-color: var(--color-primary);
}

.quick-option.active {
  background: var(--color-base-200);
  color: var(--color-base-content);
  border-color: var(--color-base-content);
  font-weight: 600;
}

.modal-icon {
  color: currentColor;
}

.progress-preview {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.progress-preview label {
  font-weight: 500;
  color: var(--color-base-content);
}

.preview-bar {
  height: 1rem;
  background: var(--color-base-300);
  border-radius: 0.5rem;
  overflow: hidden;
}

.preview-fill {
  height: 100%;
  border-radius: 0.5rem;
  transition: width 0.3s ease;
}

.preview-text {
  text-align: center;
  font-weight: 500;
  color: var(--color-base-content);
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.25rem;
}

.preview-icon {
  color: currentColor;
}

.modal-footer {
  display: flex;
  justify-content: space-between;
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

.btn-primary:hover {
  background: var(--color-primary-focus);
}

/* 响应式设计 */
@media (max-width: 768px) {
  .progress-row {
    flex-direction: column;
    gap: 0.5rem;
    align-items: stretch;
  }

  .progress-container {
    width: 100%;
    flex: none;
  }

  .quick-progress {
    display: flex;
    justify-content: center;
    gap: 0.375rem;
    flex-wrap: wrap;
  }

  .quick-options {
    grid-template-columns: repeat(3, 1fr);
  }

  .modal-footer {
    flex-direction: column;
    gap: 0.5rem;
  }

  .btn-secondary,
  .btn-primary {
    width: 100%;
  }
}
</style>
