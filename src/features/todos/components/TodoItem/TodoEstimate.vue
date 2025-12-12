<script setup lang="ts">
  import { Clock } from 'lucide-vue-next';
  import { computed, ref } from 'vue';
  import { Modal, TodoButton } from '@/components/ui';
  import type { TodoUpdate } from '@/schema/todos';

  const props = defineProps<{
    estimateMinutes: number | null;
    readonly?: boolean;
  }>();

  const emit = defineEmits<{
    update: [update: TodoUpdate];
  }>();

  const showModal = ref(false);
  const editingMinutes = ref(props.estimateMinutes || 0);
  const editingHours = ref(0);
  const editingDays = ref(0);

  // 计算属性
  const hasEstimate = computed(() => !!props.estimateMinutes);

  const totalMinutes = computed(() => {
    return editingDays.value * 24 * 60 + editingHours.value * 60 + editingMinutes.value;
  });

  // 预设时间选项
  const quickEstimates = [
    { label: '15分钟', minutes: 15 },
    { label: '30分钟', minutes: 30 },
    { label: '1小时', minutes: 60 },
    { label: '2小时', minutes: 120 },
    { label: '4小时', minutes: 240 },
    { label: '1天', minutes: 480 }, // 8小时工作日
    { label: '2天', minutes: 960 },
    { label: '1周', minutes: 2400 }, // 5个工作日
  ];

  // 方法
  function formatTime(minutes: number): string {
    if (minutes < 60) {
      return `${minutes}分钟`;
    }

    const hours = Math.floor(minutes / 60);
    const remainingMinutes = minutes % 60;

    if (hours < 8) {
      if (remainingMinutes === 0) {
        return `${hours}小时`;
      }
      return `${hours}小时${remainingMinutes}分钟`;
    }

    const days = Math.floor(hours / 8);
    const remainingHours = hours % 8;

    if (days === 1 && remainingHours === 0 && remainingMinutes === 0) {
      return '1天';
    }

    let result = `${days}天`;
    if (remainingHours > 0) {
      result += `${remainingHours}小时`;
    }
    if (remainingMinutes > 0) {
      result += `${remainingMinutes}分钟`;
    }

    return result;
  }

  function parseTime(minutes: number) {
    editingDays.value = Math.floor(minutes / (24 * 60));
    editingHours.value = Math.floor((minutes % (24 * 60)) / 60);
    editingMinutes.value = minutes % 60;
  }

  function openModal() {
    if (props.readonly) return;
    parseTime(props.estimateMinutes || 0);
    showModal.value = true;
  }

  function closeModal() {
    showModal.value = false;
  }

  function saveEstimate() {
    emit('update', { estimateMinutes: totalMinutes.value || null });
    closeModal();
  }

  function setQuickEstimate(minutes: number) {
    parseTime(minutes);
  }

  function clearEstimate() {
    editingDays.value = 0;
    editingHours.value = 0;
    editingMinutes.value = 0;
  }

  // 验证输入
  function validateInput() {
    editingDays.value = Math.max(0, Math.floor(editingDays.value));
    editingHours.value = Math.max(0, Math.min(23, Math.floor(editingHours.value)));
    editingMinutes.value = Math.max(0, Math.min(59, Math.floor(editingMinutes.value)));
  }

  // 监听输入变化
  watch([editingDays, editingHours, editingMinutes], validateInput);
</script>

<template>
  <div class="relative">
    <!-- 时间估算显示按钮 -->
    <TodoButton
      :icon="Clock"
      :active="hasEstimate"
      :readonly="props.readonly"
      :title="hasEstimate ? `时间估算: ${formatTime(props.estimateMinutes!)}` : '设置时间估算'"
      @click="openModal"
    />

    <!-- 时间估算设置模态框 -->
    <Modal
      :open="showModal"
      title="设置时间估算"
      size="md"
      :show-delete="true"
      @close="closeModal"
      @confirm="saveEstimate"
      @delete="clearEstimate"
    >
      <div class="space-y-6">
        <!-- 时间输入 -->
        <div class="space-y-3">
          <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">
            预计完成时间
          </label>
          <div class="grid grid-cols-3 gap-4">
            <div>
              <label class="block text-xs text-gray-500 dark:text-gray-400 mb-1">天</label>
              <input
                v-model.number="editingDays"
                type="number"
                min="0"
                max="365"
                class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg text-center bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              />
            </div>
            <div>
              <label class="block text-xs text-gray-500 dark:text-gray-400 mb-1">小时</label>
              <input
                v-model.number="editingHours"
                type="number"
                min="0"
                max="23"
                class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg text-center bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              />
            </div>
            <div>
              <label class="block text-xs text-gray-500 dark:text-gray-400 mb-1">分钟</label>
              <input
                v-model.number="editingMinutes"
                type="number"
                min="0"
                max="59"
                class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg text-center bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              />
            </div>
          </div>
        </div>

        <!-- 快速选择 -->
        <div class="space-y-3">
          <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">快速选择</label>
          <div class="grid grid-cols-2 gap-2">
            <button
              v-for="estimate in quickEstimates"
              :key="estimate.minutes"
              class="px-3 py-2 text-sm border rounded-lg transition-colors"
              :class="totalMinutes === estimate.minutes ? 'bg-blue-600 text-white border-blue-600' : 'bg-white dark:bg-gray-800 border-gray-300 dark:border-gray-600 hover:border-blue-500 dark:hover:border-blue-400 text-gray-900 dark:text-gray-100'"
              @click="setQuickEstimate(estimate.minutes)"
            >
              {{ estimate.label }}
            </button>
          </div>
        </div>

        <!-- 时间预览 -->
        <div class="space-y-2">
          <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">
            时间预览:
          </label>
          <div
            class="flex items-center gap-2 p-3 bg-gray-100 dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-700"
          >
            <Clock class="w-4 h-4 text-blue-600 dark:text-blue-400" />
            <span class="font-medium text-gray-900 dark:text-white"
              >{{ totalMinutes > 0 ? formatTime(totalMinutes) : '未设置时间' }}</span
            >
            <span class="text-sm text-gray-500 dark:text-gray-400">({{ totalMinutes }}分钟)</span>
          </div>
        </div>

        <!-- 时间统计 -->
        <div
          v-if="totalMinutes > 0"
          class="grid grid-cols-3 gap-4 p-4 bg-blue-50 dark:bg-blue-900/20 rounded-lg border border-blue-100 dark:border-blue-800/30"
        >
          <div class="text-center">
            <div class="text-xs text-gray-500 dark:text-gray-400 mb-1">总时间</div>
            <div class="text-sm font-semibold text-gray-900 dark:text-white">
              {{ formatTime(totalMinutes) }}
            </div>
          </div>
          <div class="text-center">
            <div class="text-xs text-gray-500 dark:text-gray-400 mb-1">工作日</div>
            <div class="text-sm font-semibold text-gray-900 dark:text-white">
              {{ Math.ceil(totalMinutes / 480) }}天
            </div>
          </div>
          <div class="text-center">
            <div class="text-xs text-gray-500 dark:text-gray-400 mb-1">总分钟</div>
            <div class="text-sm font-semibold text-gray-900 dark:text-white">
              {{ totalMinutes }}分钟
            </div>
          </div>
        </div>
      </div>
    </Modal>
  </div>
</template>

<style scoped>
  /* 所有样式已使用 Tailwind CSS 4 */
</style>
