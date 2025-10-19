<script setup lang="ts">
import { computed, ref } from 'vue';
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
    const _position = await new Promise<GeolocationPosition>((resolve, reject) => {
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
      class="location-btn"
      :class="{
        hasLocation,
        readonly,
      }"
      :title="hasLocation ? `位置: ${props.location}` : '设置位置'"
      @click="openModal"
    >
      <svg class="icon" viewBox="0 0 24 24" fill="currentColor">
        <path d="M12 2C8.13 2 5 5.13 5 9C5 14.25 12 22 12 22S19 14.25 19 9C19 5.13 15.87 2 12 2ZM12 11.5C10.62 11.5 9.5 10.38 9.5 9S10.62 6.5 12 6.5S14.5 7.62 14.5 9S13.38 11.5 12 11.5Z" />
      </svg>
      <span class="location-text">{{ locationDisplay }}</span>
    </button>

    <!-- 位置设置模态框 -->
    <Teleport to="body">
      <div v-if="showModal" class="modal-overlay teleport" :class="{ visible: isModalVisible }" @click="closeModal">
        <div class="modal-content teleport" @click.stop>
          <div class="modal-header teleport">
            <h3>设置位置</h3>
            <button class="close-btn teleport" @click="closeModal">
              ×
            </button>
          </div>

          <div class="modal-body teleport">
            <!-- 位置输入 -->
            <div class="input-section">
              <label for="location-input">位置名称</label>
              <div class="input-group">
                <input
                  id="location-input"
                  v-model="editingLocation"
                  type="text"
                  placeholder="输入位置名称..."
                  class="location-input"
                  maxlength="100"
                >
                <button
                  class="clear-btn"
                  :disabled="!editingLocation"
                  title="清空位置"
                  @click="clearLocation"
                >
                  ×
                </button>
              </div>
            </div>

            <!-- 获取当前位置 -->
            <div class="current-location-section">
              <button
                class="current-location-btn"
                @click="getCurrentLocation"
              >
                <svg class="icon" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M12 8C13.1 8 14 8.9 14 10S13.1 12 12 12 10 11.1 10 10 10.9 8 12 8M12 14C15.31 14 18 11.31 18 8S15.31 2 12 2 6 4.69 6 8 8.69 14 12 14M12 16C7.58 16 4 12.42 4 8S7.58 0 12 0 20 3.58 20 8 16.42 16 12 16M12 4C9.79 4 8 5.79 8 8S9.79 12 12 12 16 10.21 16 8 14.21 4 12 4" />
                </svg>
                获取当前位置
              </button>
            </div>

            <!-- 常用位置 -->
            <div class="common-locations-section">
              <div class="section-header">
                <label>常用位置</label>
                <button
                  class="toggle-btn"
                  :class="{ active: showLocationPicker }"
                  @click="openLocationPicker"
                >
                  {{ showLocationPicker ? '收起' : '展开' }}
                </button>
              </div>

              <div v-if="showLocationPicker" class="locations-grid">
                <button
                  v-for="locationOption in commonLocations"
                  :key="locationOption"
                  class="location-option"
                  :class="{ selected: editingLocation === locationOption }"
                  @click="selectLocation(locationOption)"
                >
                  {{ locationOption }}
                </button>
              </div>
            </div>

            <!-- 位置预览 -->
            <div v-if="editingLocation" class="location-preview">
              <label>位置预览:</label>
              <div class="preview-content">
                <svg class="icon" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M12 2C8.13 2 5 5.13 5 9C5 14.25 12 22 12 22S19 14.25 19 9C19 5.13 15.87 2 12 2ZM12 11.5C10.62 11.5 9.5 10.38 9.5 9S10.62 6.5 12 6.5S14.5 7.62 14.5 9S13.38 11.5 12 11.5Z" />
                </svg>
                <span>{{ editingLocation }}</span>
              </div>
            </div>
          </div>

          <div class="modal-footer teleport">
            <button class="btn-secondary teleport" @click="closeModal">
              取消
            </button>
            <button class="btn-primary teleport" @click="saveLocation">
              保存位置
            </button>
          </div>
        </div>
      </div>
    </Teleport>
  </div>
</template>

<style scoped lang="postcss">
.todo-location {
  position: relative;
}

.location-btn {
  display: flex;
  align-items: center;
  gap: 0.375rem;
  padding: 0.25rem 0.5rem;
  border: 1px solid var(--color-base-300);
  border-radius: 0.5rem;
  background: var(--color-base-100);
  color: var(--color-base-content);
  cursor: pointer;
  transition: all 0.2s ease;
  font-size: 0.75rem;
  min-width: 0;
}

.location-btn:hover:not(.readonly) {
  background: var(--color-base-200);
  border-color: var(--color-primary);
}

.location-btn.hasLocation {
  background: var(--color-base-200);
  color: var(--color-base-content);
  border-color: var(--color-base-content);
  font-weight: 600;
}

.location-btn.readonly {
  cursor: default;
  opacity: 0.6;
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
  z-index: 9999;
  backdrop-filter: blur(4px);
}

.modal-content {
  background: var(--color-base-100);
  border-radius: 1rem;
  box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1);
  max-width: 500px;
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

.input-section {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.input-section label {
  font-weight: 500;
  color: var(--color-base-content);
}

.input-group {
  display: flex;
  gap: 0.5rem;
}

.location-input {
  flex: 1;
  padding: 0.75rem;
  border: 1px solid var(--color-base-300);
  border-radius: 0.5rem;
  font-size: 1rem;
  background: var(--color-base-100);
  color: var(--color-base-content);
}

.location-input:focus {
  outline: none;
  border-color: var(--color-primary);
  box-shadow: 0 0 0 3px rgba(var(--color-primary-rgb), 0.1);
}

.clear-btn {
  padding: 0.75rem;
  border: 1px solid var(--color-base-300);
  border-radius: 0.5rem;
  background: var(--color-base-100);
  color: var(--color-base-content);
  cursor: pointer;
  font-size: 1.25rem;
  line-height: 1;
  min-width: 3rem;
}

.clear-btn:hover:not(:disabled) {
  background: var(--color-base-200);
  border-color: var(--color-error);
  color: var(--color-error);
}

.clear-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.current-location-section {
  display: flex;
  justify-content: center;
}

.current-location-btn {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.75rem 1.5rem;
  border: 1px solid var(--color-info);
  border-radius: 0.5rem;
  background: var(--color-info);
  color: var(--color-info-content);
  cursor: pointer;
  font-weight: 500;
  transition: all 0.2s ease;
}

.current-location-btn:hover {
  background: var(--color-info-focus);
  border-color: var(--color-info-focus);
}

.common-locations-section {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.section-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.section-header label {
  font-weight: 500;
  color: var(--color-base-content);
}

.toggle-btn {
  padding: 0.25rem 0.75rem;
  border: 1px solid var(--color-base-300);
  border-radius: 0.375rem;
  background: var(--color-base-100);
  color: var(--color-base-content);
  cursor: pointer;
  font-size: 0.875rem;
  transition: all 0.2s ease;
}

.toggle-btn:hover {
  background: var(--color-base-200);
  border-color: var(--color-primary);
}

.toggle-btn.active {
  background: var(--color-primary);
  color: var(--color-primary-content);
  border-color: var(--color-primary);
}

.locations-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(120px, 1fr));
  gap: 0.5rem;
  max-height: 200px;
  overflow-y: auto;
}

.location-option {
  padding: 0.75rem;
  border: 1px solid var(--color-base-300);
  border-radius: 0.5rem;
  background: var(--color-base-100);
  color: var(--color-base-content);
  cursor: pointer;
  transition: all 0.2s ease;
  font-size: 0.875rem;
  text-align: center;
}

.location-option:hover {
  background: var(--color-base-200);
  border-color: var(--color-primary);
}

.location-option.selected {
  background: var(--color-primary);
  color: var(--color-primary-content);
  border-color: var(--color-primary);
}

.location-preview {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  padding: 1rem;
  background: var(--color-base-200);
  border-radius: 0.5rem;
  border: 1px solid var(--color-base-300);
}

.location-preview label {
  font-weight: 500;
  color: var(--color-base-content);
}

.preview-content {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  color: var(--color-base-content);
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
  .modal-content {
    width: 95%;
    margin: 1rem;
  }

  .locations-grid {
    grid-template-columns: repeat(2, 1fr);
  }

  .modal-footer {
    flex-direction: column;
    gap: 0.5rem;
  }

  .btn-secondary,
  .btn-primary {
    width: 100%;
  }

  .input-group {
    flex-direction: column;
  }

  .clear-btn {
    align-self: flex-end;
    max-width: 4rem;
  }
}
</style>
