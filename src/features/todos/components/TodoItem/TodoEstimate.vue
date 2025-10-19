<script setup lang="ts">
import { computed, ref } from 'vue';
import type { TodoUpdate } from '@/schema/todos';

const props = defineProps<{
  estimateMinutes: number | null;
  readonly?: boolean;
}>();

const emit = defineEmits<{
  update: [update: TodoUpdate];
}>();

const showModal = ref(false);
const isModalVisible = ref(false);
const editingMinutes = ref(props.estimateMinutes || 0);
const editingHours = ref(0);
const editingDays = ref(0);

// 计算属性
const hasEstimate = computed(() => !!props.estimateMinutes);
const estimateDisplay = computed(() => {
  if (!props.estimateMinutes) return '';
  return formatTime(props.estimateMinutes);
});

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
  }, 200);
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
  <div class="todo-estimate">
    <!-- 时间估算显示按钮 -->
    <button
      class="estimate-btn"
      :class="{
        hasEstimate,
        readonly,
      }"
      :title="hasEstimate ? `时间估算: ${formatTime(props.estimateMinutes!)}` : '设置时间估算'"
      @click="openModal"
    >
      <svg class="icon" viewBox="0 0 24 24" fill="currentColor">
        <path d="M12,20A8,8 0 0,0 20,12A8,8 0 0,0 12,4A8,8 0 0,0 4,12A8,8 0 0,0 12,20M12,2A10,10 0 0,1 22,12A10,10 0 0,1 12,22C6.47,22 2,17.5 2,12A10,10 0 0,1 12,2M12.5,7V12.25L17,14.92L16.25,16.15L11,13V7H12.5Z" />
      </svg>
      <span class="estimate-text">{{ estimateDisplay }}</span>
    </button>

    <!-- 时间估算设置模态框 -->
    <Teleport to="body">
      <div v-if="showModal" class="modal-overlay teleport" :class="{ visible: isModalVisible }" @click="closeModal">
        <div class="modal-content teleport" @click.stop>
          <div class="modal-header teleport">
            <h3>设置时间估算</h3>
            <button class="close-btn teleport" @click="closeModal">
              ×
            </button>
          </div>

          <div class="modal-body teleport">
            <!-- 时间输入 -->
            <div class="time-input-section">
              <label>预计完成时间</label>
              <div class="time-inputs">
                <div class="time-input-group">
                  <label for="days-input">天</label>
                  <input
                    id="days-input"
                    v-model.number="editingDays"
                    type="number"
                    min="0"
                    max="365"
                    class="time-input"
                  >
                </div>
                <div class="time-input-group">
                  <label for="hours-input">小时</label>
                  <input
                    id="hours-input"
                    v-model.number="editingHours"
                    type="number"
                    min="0"
                    max="23"
                    class="time-input"
                  >
                </div>
                <div class="time-input-group">
                  <label for="minutes-input">分钟</label>
                  <input
                    id="minutes-input"
                    v-model.number="editingMinutes"
                    type="number"
                    min="0"
                    max="59"
                    class="time-input"
                  >
                </div>
              </div>
            </div>

            <!-- 快速选择 -->
            <div class="quick-estimates-section">
              <label>快速选择</label>
              <div class="quick-options">
                <button
                  v-for="estimate in quickEstimates"
                  :key="estimate.minutes"
                  class="quick-option"
                  :class="{ active: totalMinutes === estimate.minutes }"
                  @click="setQuickEstimate(estimate.minutes)"
                >
                  {{ estimate.label }}
                </button>
              </div>
            </div>

            <!-- 时间预览 -->
            <div class="time-preview">
              <label>时间预览:</label>
              <div class="preview-content">
                <svg class="icon" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M12,20A8,8 0 0,0 20,12A8,8 0 0,0 12,4A8,8 0 0,0 4,12A8,8 0 0,0 12,20M12,2A10,10 0 0,1 22,12A10,10 0 0,1 12,22C6.47,22 2,17.5 2,12A10,10 0 0,1 12,2M12.5,7V12.25L17,14.92L16.25,16.15L11,13V7H12.5Z" />
                </svg>
                <span>{{ totalMinutes > 0 ? formatTime(totalMinutes) : '未设置时间' }}</span>
                <span class="minutes-text">({{ totalMinutes }}分钟)</span>
              </div>
            </div>

            <!-- 时间统计 -->
            <div v-if="totalMinutes > 0" class="time-stats">
              <div class="stat-item">
                <span class="stat-label">总时间:</span>
                <span class="stat-value">{{ formatTime(totalMinutes) }}</span>
              </div>
              <div class="stat-item">
                <span class="stat-label">工作日:</span>
                <span class="stat-value">{{ Math.ceil(totalMinutes / 480) }}天</span>
              </div>
              <div class="stat-item">
                <span class="stat-label">总分钟:</span>
                <span class="stat-value">{{ totalMinutes }}分钟</span>
              </div>
            </div>
          </div>

          <div class="modal-footer teleport">
            <button class="btn-secondary teleport" @click="clearEstimate">
              清空
            </button>
            <button class="btn-secondary teleport" @click="closeModal">
              取消
            </button>
            <button class="btn-primary teleport" @click="saveEstimate">
              保存时间
            </button>
          </div>
        </div>
      </div>
    </Teleport>
  </div>
</template>

<style scoped lang="postcss">
.todo-estimate {
  position: relative;
}

.estimate-btn {
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

.estimate-btn:hover:not(.readonly) {
  background: var(--color-base-200);
  border-color: var(--color-primary);
}

.estimate-btn.hasEstimate {
  background: var(--color-warning);
  color: var(--color-warning-content);
  border-color: var(--color-warning);
}

.estimate-btn.readonly {
  cursor: default;
  opacity: 0.6;
}

.icon {
  width: 0.875rem;
  height: 0.875rem;
  flex-shrink: 0;
}

.estimate-text {
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  max-width: 5rem;
}

/* 模态框样式 - 全局样式，因为使用了Teleport */

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

.time-input-section {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.time-input-section > label {
  font-weight: 500;
  color: var(--color-base-content);
}

.time-inputs {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 1rem;
}

.time-input-group {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.time-input-group > label {
  font-size: 0.875rem;
  font-weight: 500;
  color: var(--color-base-content);
  text-align: center;
}

.time-input {
  padding: 0.75rem;
  border: 1px solid var(--color-base-300);
  border-radius: 0.5rem;
  text-align: center;
  font-size: 1.125rem;
  font-weight: 600;
  background: var(--color-base-100);
  color: var(--color-base-content);
}

.time-input:focus {
  outline: none;
  border-color: var(--color-primary);
  box-shadow: 0 0 0 3px rgba(var(--color-primary-rgb), 0.1);
}

.quick-estimates-section {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.quick-estimates-section > label {
  font-weight: 500;
  color: var(--color-base-content);
}

.quick-options {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 0.5rem;
}

.quick-option {
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

.quick-option:hover {
  background: var(--color-base-200);
  border-color: var(--color-primary);
}

.quick-option.active {
  background: var(--color-primary);
  color: var(--color-primary-content);
  border-color: var(--color-primary);
}

.time-preview {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  padding: 1rem;
  background: var(--color-base-200);
  border-radius: 0.5rem;
  border: 1px solid var(--color-base-300);
}

.time-preview > label {
  font-weight: 500;
  color: var(--color-base-content);
}

.preview-content {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  color: var(--color-base-content);
  font-weight: 500;
}

.minutes-text {
  font-size: 0.875rem;
  color: var(--color-base-content);
  opacity: 0.7;
}

.time-stats {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  padding: 1rem;
  background: var(--color-info);
  background-opacity: 0.1;
  border-radius: 0.5rem;
  border: 1px solid var(--color-info);
}

.stat-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.stat-label {
  font-weight: 500;
  color: var(--color-base-content);
}

.stat-value {
  font-weight: 600;
  color: var(--color-info);
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

  .time-inputs {
    grid-template-columns: 1fr;
    gap: 0.75rem;
  }

  .quick-options {
    grid-template-columns: 1fr;
  }

  .modal-footer {
    flex-direction: column;
    gap: 0.5rem;
  }

  .btn-secondary,
  .btn-primary {
    width: 100%;
  }

  .modal-footer {
    flex-direction: row;
    justify-content: space-between;
  }

  .modal-footer .btn-secondary:first-child {
    order: 3;
  }

  .modal-footer .btn-secondary:nth-child(2) {
    order: 1;
  }

  .modal-footer .btn-primary {
    order: 2;
    flex: 1;
    margin: 0 0.5rem;
  }
}
</style>
