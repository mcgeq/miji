<script setup lang="ts">
import { CheckCircle, Play } from 'lucide-vue-next';
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
const quickProgressOptions: number[] = [0, 25, 50, 75, 100];

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
  <div class="flex flex-col gap-2">
    <!-- 进度条容器 -->
    <div
      class="flex w-32 md:w-32 items-center px-3 py-1.5 rounded-lg border-2 shadow-sm backdrop-blur-sm transition-all duration-300 ease-out flex-1"
      :class="[
        props.readonly
          ? 'cursor-default opacity-80 bg-gradient-to-br from-white to-gray-50 dark:from-gray-800 dark:to-gray-800/95 border-gray-300 dark:border-gray-600'
          : 'cursor-pointer bg-gradient-to-br from-white to-blue-50/50 dark:from-gray-800 dark:to-gray-800/90 border-gray-300 dark:border-gray-600 hover:to-blue-100/60 dark:hover:to-gray-700/90 hover:border-blue-500 dark:hover:border-blue-400 hover:shadow-md hover:-translate-y-px',
      ]"
      @click="openEditModal"
    >
      <!-- 进度条 -->
      <div class="w-full h-3 bg-gray-200 dark:bg-gray-700 rounded-md overflow-hidden relative shadow-inner">
        <div
          class="h-full rounded-md relative shadow-sm transition-all duration-400 ease-out"
          :style="{
            width: `${progressPercentage}%`,
            backgroundColor: progressColor,
          }"
        >
          <!-- 闪光动画效果 -->
          <div class="absolute inset-0 bg-gradient-to-r from-transparent via-white/30 to-transparent animate-shimmer" />
        </div>
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
        <div class="space-y-3">
          <label class="block text-sm font-medium text-gray-900 dark:text-white">
            进度: <span class="text-blue-600 dark:text-blue-400 font-semibold">{{ editingProgress }}%</span>
          </label>
          <input
            v-model="editingProgress"
            type="range"
            min="0"
            max="100"
            step="5"
            class="w-full h-2 bg-gray-200 dark:bg-gray-700 rounded-lg appearance-none cursor-pointer outline-none
                   [&::-webkit-slider-thumb]:appearance-none [&::-webkit-slider-thumb]:w-5 [&::-webkit-slider-thumb]:h-5
                   [&::-webkit-slider-thumb]:rounded-full [&::-webkit-slider-thumb]:bg-blue-600 [&::-webkit-slider-thumb]:cursor-pointer
                   [&::-webkit-slider-thumb]:border-2 [&::-webkit-slider-thumb]:border-white [&::-webkit-slider-thumb]:shadow-md
                   [&::-moz-range-thumb]:w-5 [&::-moz-range-thumb]:h-5 [&::-moz-range-thumb]:rounded-full
                   [&::-moz-range-thumb]:bg-blue-600 [&::-moz-range-thumb]:cursor-pointer [&::-moz-range-thumb]:border-2
                   [&::-moz-range-thumb]:border-white [&::-moz-range-thumb]:shadow-md"
          >
          <div class="flex justify-between text-xs text-gray-500 dark:text-gray-400 mt-2">
            <span>0%</span>
            <span>25%</span>
            <span>50%</span>
            <span>75%</span>
            <span>100%</span>
          </div>
        </div>

        <!-- 数字输入 -->
        <div class="flex items-center gap-3">
          <label class="text-sm font-medium text-gray-900 dark:text-white">精确数值:</label>
          <input
            v-model.number="editingProgress"
            type="number"
            min="0"
            max="100"
            class="w-20 px-3 py-2 text-center border border-gray-300 dark:border-gray-600 rounded-lg
                   bg-white dark:bg-gray-800 text-gray-900 dark:text-white
                   focus:outline-none focus:ring-2 focus:ring-blue-500 dark:focus:ring-blue-400 focus:border-transparent"
          >
          <span class="text-sm text-gray-600 dark:text-gray-400">%</span>
        </div>

        <!-- 快速选择 -->
        <div class="space-y-3">
          <label class="block text-sm font-medium text-gray-900 dark:text-white">快速选择:</label>
          <div class="grid grid-cols-5 gap-2">
            <button
              v-for="value in quickProgressOptions"
              :key="value"
              type="button"
              class="flex items-center justify-center px-3 py-2.5 text-sm font-medium rounded-lg border-2 transition-all"
              :class="[
                editingProgress === value
                  ? 'bg-blue-600 text-white border-blue-600 shadow-md'
                  : 'bg-white dark:bg-gray-800 text-gray-900 dark:text-white border-gray-300 dark:border-gray-600 hover:border-blue-500 dark:hover:border-blue-400',
              ]"
              @click="editingProgress = value"
            >
              <Play v-if="value === 0" class="w-4 h-4" />
              <CheckCircle v-else-if="value === 100" class="w-4 h-4" />
              <span v-else>{{ value }}%</span>
            </button>
          </div>
        </div>

        <!-- 预览 -->
        <div class="space-y-3">
          <label class="block text-sm font-medium text-gray-900 dark:text-white">预览:</label>
          <div class="h-4 bg-gray-200 dark:bg-gray-700 rounded-full overflow-hidden shadow-inner">
            <div
              class="h-full rounded-full transition-all duration-300 ease-out relative"
              :style="{
                width: `${Math.min(Math.max(editingProgress, 0), 100)}%`,
                backgroundColor: progressColor,
              }"
            >
              <div class="absolute inset-0 bg-gradient-to-r from-transparent via-white/30 to-transparent animate-shimmer" />
            </div>
          </div>
          <div class="flex items-center justify-center gap-2 text-sm font-semibold text-gray-900 dark:text-white">
            <Play v-if="editingProgress === 0" class="w-4 h-4" />
            <CheckCircle v-else-if="editingProgress === 100" class="w-4 h-4 text-green-600" />
            <span v-else>{{ editingProgress }}%</span>
          </div>
        </div>
      </div>
    </Modal>
  </div>
</template>

<style scoped>
@keyframes shimmer {
  0% { transform: translateX(-100%); }
  100% { transform: translateX(100%); }
}

.animate-shimmer {
  animation: shimmer 2s infinite;
}
</style>
