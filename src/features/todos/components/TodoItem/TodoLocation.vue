<script setup lang="ts">
import { MapPin, Navigation, Trash2 } from 'lucide-vue-next';
import { computed, ref } from 'vue';
import { Modal } from '@/components/ui';
import type { TodoUpdate } from '@/schema/todos';

const props = defineProps<{
  location: string | null;
  readonly?: boolean;
}>();

const emit = defineEmits<{
  update: [update: TodoUpdate];
}>();

const showModal = ref(false);
const isModalVisible = ref(false);
const editingLocation = ref(props.location || '');
const showLocationPicker = ref(false);

// 计算属性
const hasLocation = computed(() => !!props.location);
const locationDisplay = computed(() => {
  if (!props.location) return '';
  if (props.location.length > 20) {
    return `${props.location.substring(0, 20)}...`;
  }
  return props.location;
});

// 预设位置选项
const commonLocations = [
  '办公室',
  '家',
  '学校',
  '健身房',
  '咖啡厅',
  '图书馆',
  '商场',
  '医院',
  '银行',
  '邮局',
  '机场',
  '车站',
  '公园',
  '餐厅',
  '超市',
];

// 方法
function openModal() {
  if (props.readonly) return;
  editingLocation.value = props.location || '';
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
    showLocationPicker.value = false;
  }, 200);
}

function saveLocation() {
  const trimmedLocation = editingLocation.value.trim();
  emit('update', { location: trimmedLocation || null });
  closeModal();
}

function selectLocation(location: string) {
  editingLocation.value = location;
  showLocationPicker.value = false;
}

function clearLocation() {
  editingLocation.value = '';
}

function openLocationPicker() {
  showLocationPicker.value = !showLocationPicker.value;
}

// 模拟获取当前位置
async function getCurrentLocation() {
  if (!navigator.geolocation) {
    console.warn('您的浏览器不支持地理位置功能');
    return;
  }

  try {
    // 获取当前位置（模拟实现）
    await new Promise<GeolocationPosition>((resolve, reject) => {
      navigator.geolocation.getCurrentPosition(resolve, reject);
    });

    // 这里可以调用地理编码API获取地址
    // 目前使用模拟数据
    editingLocation.value = '当前位置 (模拟)';
  } catch (error) {
    console.error('获取位置失败:', error);
    console.warn('获取位置失败，请手动输入');
  }
}
</script>

<template>
  <div class="todo-location">
    <!-- 位置显示按钮 -->
    <button
      class="todo-btn"
      :class="{
        'todo-btn--active': hasLocation,
        'todo-btn--readonly': readonly,
      }"
      :title="hasLocation ? `位置: ${props.location}` : '设置位置'"
      @click="openModal"
    >
      <MapPin class="icon" :size="14" />
      <span class="location-text">{{ locationDisplay }}</span>
    </button>

    <!-- 位置设置模态框 -->
    <Modal
      :open="showModal"
      title="设置位置"
      size="md"
      :show-delete="true"
      @close="closeModal"
      @confirm="saveLocation"
      @delete="clearLocation"
    >
      <div class="space-y-6">
        <!-- 位置输入 -->
        <div class="space-y-2">
          <label class="block text-sm font-medium">位置名称</label>
          <div class="flex gap-2">
            <input
              v-model="editingLocation"
              type="text"
              placeholder="输入位置名称..."
              class="flex-1 px-3 py-2 border border-gray-300 rounded-lg"
              maxlength="100"
            >
            <button
              class="px-3 py-2 border border-gray-300 rounded-lg hover:bg-gray-100 disabled:opacity-50"
              :disabled="!editingLocation"
              title="清空位置"
              @click="clearLocation"
            >
              <Trash2 :size="16" />
            </button>
          </div>
        </div>

        <!-- 获取当前位置 -->
        <button
          class="w-full flex items-center justify-center gap-2 px-4 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
          @click="getCurrentLocation"
        >
          <Navigation :size="16" />
          获取当前位置
        </button>

        <!-- 常用位置 -->
        <div class="space-y-3">
          <div class="flex items-center justify-between">
            <label class="text-sm font-medium">常用位置</label>
            <button
              class="text-sm text-blue-600 hover:text-blue-700"
              @click="openLocationPicker"
            >
              {{ showLocationPicker ? '收起' : '展开' }}
            </button>
          </div>

          <div v-if="showLocationPicker" class="grid grid-cols-3 gap-2 max-h-48 overflow-y-auto">
            <button
              v-for="locationOption in commonLocations"
              :key="locationOption"
              class="px-3 py-2 text-sm border rounded-lg transition-colors"
              :class="editingLocation === locationOption ? 'bg-blue-600 text-white border-blue-600' : 'bg-white border-gray-300 hover:border-blue-500'"
              @click="selectLocation(locationOption)"
            >
              {{ locationOption }}
            </button>
          </div>
        </div>

        <!-- 位置预览 -->
        <div v-if="editingLocation" class="p-3 bg-gray-100 dark:bg-gray-800 rounded-lg">
          <label class="block text-sm font-medium mb-2">位置预览:</label>
          <div class="flex items-center gap-2">
            <MapPin class="w-4 h-4 text-blue-600" />
            <span class="font-medium">{{ editingLocation }}</span>
          </div>
        </div>
      </div>
    </Modal>
  </div>
</template>

<style scoped lang="postcss">
.todo-location {
  position: relative;
}

.icon {
  width: 0.875rem;
  height: 0.875rem;
  flex-shrink: 0;
}

.location-text {
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  max-width: 6rem;
}
</style>
