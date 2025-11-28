<script setup lang="ts">
import { Modal } from '@/components/ui';
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
const quickProgressOptions: number[] = [];

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
</script>

<template>
  <div class="todo-progress">
    <!-- 进度条显示和快速设置按钮 -->
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

    <!-- 进度编辑模态框 -->
    <Modal
      :open="showEditModal"
      title="设置进度"
      size="md"
      @close="closeEditModal"
      @confirm="updateProgress(editingProgress)"
    >
      <div class="space-y-6">
        <!-- 滑块输入 -->
        <div class="space-y-2">
          <label class="block text-sm font-medium mb-2">进度: {{ editingProgress }}%</label>
          <input
            v-model="editingProgress"
            type="range"
            min="0"
            max="100"
            step="5"
            class="w-full h-2 bg-gray-200 rounded-lg appearance-none cursor-pointer progress-slider"
          >
          <div class="flex justify-between text-xs text-gray-500 mt-1">
            <span>0%</span>
            <span>25%</span>
            <span>50%</span>
            <span>75%</span>
            <span>100%</span>
          </div>
        </div>

        <!-- 数字输入 -->
        <div class="flex items-center gap-2">
          <label class="text-sm font-medium">精确数值:</label>
          <input
            v-model="editingProgress"
            type="number"
            min="0"
            max="100"
            class="w-20 px-3 py-2 border border-gray-300 rounded-lg text-center"
          >
          <span>%</span>
        </div>

        <!-- 快速选择 -->
        <div class="space-y-2">
          <label class="block text-sm font-medium">快速选择:</label>
          <div class="grid grid-cols-5 gap-2">
            <button
              v-for="value in quickProgressOptions"
              :key="value"
              class="px-3 py-2 text-sm border rounded-lg transition-colors"
              :class="editingProgress === value ? 'bg-blue-600 text-white border-blue-600' : 'bg-white border-gray-300 hover:border-blue-500'"
              @click="editingProgress = value"
            >
              <LucidePlay v-if="value === 0" class="w-4 h-4" />
              <LucideCheckCircle v-else-if="value === 100" class="w-4 h-4" />
              <span v-else>{{ value }}%</span>
            </button>
          </div>
        </div>

        <!-- 预览 -->
        <div class="space-y-2">
          <label class="block text-sm font-medium">预览:</label>
          <div class="h-4 bg-gray-200 rounded-full overflow-hidden">
            <div
              class="h-full rounded-full transition-all duration-300"
              :style="{
                width: `${Math.min(Math.max(editingProgress, 0), 100)}%`,
                backgroundColor: progressColor,
              }"
            />
          </div>
          <div class="flex items-center justify-center gap-1 text-sm font-medium">
            <LucidePlay v-if="editingProgress === 0" class="w-4 h-4" />
            <LucideCheckCircle v-else-if="editingProgress === 100" class="w-4 h-4" />
            <span v-else>{{ editingProgress }}%</span>
          </div>
        </div>
      </div>
    </Modal>
  </div>
</template>

<style scoped lang="postcss">
.todo-progress {
  display: flex;
  flex-direction: column;
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
  border: 2px solid var(--color-gray-300);
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
  background: var(--color-gray-200);
  border-radius: 0.375rem;
  overflow: hidden;
  position: relative;
  box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.1);
  min-height: 0.75rem;
}

.progress-fill {
  height: 100%;
  background: var(--color-info);
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

/* 滑块自定义样式 */
.progress-slider {
  outline: none;
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

/* 响应式设计 */
@media (max-width: 768px) {
  .todo-progress {
    width: 100%;
  }

  .progress-container {
    width: 100%;
    flex: none;
    max-width: none;
  }
}
</style>
