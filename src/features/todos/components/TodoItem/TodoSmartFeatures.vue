<script setup lang="ts">
import { computed, ref } from 'vue';
import type { TodoUpdate } from '@/schema/todos';

const props = defineProps<{
  todo: {
    smartReminderEnabled: boolean;
    locationBasedReminder: boolean;
    weatherDependent: boolean;
    priorityBoostEnabled: boolean;
    timezone: string | null;
  };
  readonly?: boolean;
}>();

const emit = defineEmits<{
  update: [update: TodoUpdate];
}>();

const showModal = ref(false);
const isModalVisible = ref(false);

// 智能功能状态
const smartFeatures = ref({
  smartReminder: props.todo.smartReminderEnabled,
  locationBased: props.todo.locationBasedReminder,
  weatherDependent: props.todo.weatherDependent,
  priorityBoost: props.todo.priorityBoostEnabled,
  timezone: props.todo.timezone || Intl.DateTimeFormat().resolvedOptions().timeZone,
});

// 位置信息
const locationInfo = ref({
  latitude: null as number | null,
  longitude: null as number | null,
  address: '',
  radius: 100, // 米
});

// 天气信息
const weatherInfo = ref({
  condition: 'sunny', // sunny, cloudy, rainy, snowy
  temperature: 22,
  humidity: 60,
  windSpeed: 5,
});

// 计算属性
const hasSmartFeatures = computed(() =>
  smartFeatures.value.smartReminder ||
  smartFeatures.value.locationBased ||
  smartFeatures.value.weatherDependent ||
  smartFeatures.value.priorityBoost,
);

const smartFeatureCount = computed(() => {
  let count = 0;
  if (smartFeatures.value.smartReminder) count++;
  if (smartFeatures.value.locationBased) count++;
  if (smartFeatures.value.weatherDependent) count++;
  if (smartFeatures.value.priorityBoost) count++;
  return count;
});

// 时区选项
const timezones = [
  'Asia/Shanghai',
  'Asia/Tokyo',
  'America/New_York',
  'America/Los_Angeles',
  'Europe/London',
  'Europe/Paris',
  'Australia/Sydney',
];

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
  }, 200);
}

function saveSmartFeatures() {
  const update: TodoUpdate = {
    smartReminderEnabled: smartFeatures.value.smartReminder,
    locationBasedReminder: smartFeatures.value.locationBased,
    weatherDependent: smartFeatures.value.weatherDependent,
    priorityBoostEnabled: smartFeatures.value.priorityBoost,
    timezone: smartFeatures.value.timezone,
  };

  emit('update', update);
  closeModal();
}

function getCurrentLocation() {
  if (!navigator.geolocation) {
    console.warn('您的浏览器不支持地理位置功能');
    return;
  }

  navigator.geolocation.getCurrentPosition(
    position => {
      locationInfo.value.latitude = position.coords.latitude;
      locationInfo.value.longitude = position.coords.longitude;

      // 这里可以调用地理编码API获取地址
      // 目前使用模拟数据
      locationInfo.value.address = '当前位置 (模拟)';
    },
    error => {
      console.error('获取位置失败:', error);
      console.warn('获取位置失败');
    },
  );
}

function getCurrentWeather() {
  // 这里可以调用天气API获取实时天气
  // 目前使用模拟数据
  const conditions = ['sunny', 'cloudy', 'rainy', 'snowy'];
  weatherInfo.value.condition = conditions[Math.floor(Math.random() * conditions.length)];
  weatherInfo.value.temperature = Math.floor(Math.random() * 30) + 10;
  weatherInfo.value.humidity = Math.floor(Math.random() * 40) + 40;
  weatherInfo.value.windSpeed = Math.floor(Math.random() * 10) + 1;
}

function resetToDefaults() {
  smartFeatures.value = {
    smartReminder: false,
    locationBased: false,
    weatherDependent: false,
    priorityBoost: false,
    timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
  };
  locationInfo.value = {
    latitude: null,
    longitude: null,
    address: '',
    radius: 100,
  };
}
</script>

<template>
  <div class="todo-smart-features">
    <!-- 智能功能显示按钮 -->
    <button
      class="todo-btn"
      :class="{
        'todo-btn--active': hasSmartFeatures,
        'todo-btn--readonly': readonly,
      }"
      :title="hasSmartFeatures ? `智能功能: ${smartFeatureCount}项已启用` : '设置智能功能'"
      @click="openModal"
    >
      <svg class="icon" viewBox="0 0 24 24" fill="currentColor">
        <path d="M12,2A10,10 0 0,1 22,12A10,10 0 0,1 12,22A10,10 0 0,1 2,12A10,10 0 0,1 12,2M12,4A8,8 0 0,0 4,12A8,8 0 0,0 12,20A8,8 0 0,0 20,12A8,8 0 0,0 12,4M12,6A6,6 0 0,1 18,12A6,6 0 0,1 12,18A6,6 0 0,1 6,12A6,6 0 0,1 12,6M12,8A4,4 0 0,0 8,12A4,4 0 0,0 12,16A4,4 0 0,0 16,12A4,4 0 0,0 12,8Z" />
      </svg>
      <span class="features-text">
        {{ hasSmartFeatures ? `智能${smartFeatureCount}` : '' }}
      </span>
      <div v-if="hasSmartFeatures" class="feature-indicators">
        <span v-if="smartFeatures.smartReminder" class="indicator" title="智能提醒">🧠</span>
        <span v-if="smartFeatures.locationBased" class="indicator" title="位置提醒">📍</span>
        <span v-if="smartFeatures.weatherDependent" class="indicator" title="天气提醒">🌤</span>
        <span v-if="smartFeatures.priorityBoost" class="indicator" title="优先级增强">⚡</span>
      </div>
    </button>

    <!-- 智能功能设置模态框 -->
    <Teleport to="body">
      <div v-if="showModal" class="modal-overlay teleport" :class="{ visible: isModalVisible }" @click="closeModal">
        <div class="modal-content teleport" @click.stop>
          <div class="modal-header teleport">
            <h3>智能功能设置</h3>
            <button class="close-btn teleport" @click="closeModal">
              ×
            </button>
          </div>

          <div class="modal-body teleport">
            <!-- 基础智能功能 -->
            <div class="section">
              <div class="setting-row">
                <label class="switch">
                  <input
                    v-model="smartFeatures.smartReminder"
                    type="checkbox"
                  >
                  <span class="slider" />
                </label>
                <div class="setting-info">
                  <span class="label">启用智能提醒</span>
                  <p class="description">
                    基于用户行为和学习习惯优化提醒时间
                  </p>
                </div>
              </div>
            </div>

            <!-- 位置相关功能 -->
            <div class="section">
              <div class="setting-row">
                <label class="switch">
                  <input
                    v-model="smartFeatures.locationBased"
                    type="checkbox"
                    :disabled="!smartFeatures.smartReminder"
                  >
                  <span class="slider" />
                </label>
                <div class="setting-info">
                  <span class="label">基于位置的提醒</span>
                  <p class="description">
                    当您到达特定位置时发送提醒
                  </p>
                </div>
              </div>

              <div v-if="smartFeatures.locationBased" class="location-settings">
                <div class="location-input-group">
                  <label>位置设置</label>
                  <div class="input-row">
                    <input
                      v-model="locationInfo.address"
                      type="text"
                      placeholder="输入地址或位置名称..."
                      class="location-input"
                    >
                    <button class="location-btn" @click="getCurrentLocation">
                      <svg class="icon" viewBox="0 0 24 24" fill="currentColor">
                        <path d="M12 2C8.13 2 5 5.13 5 9C5 14.25 12 22 12 22S19 14.25 19 9C19 5.13 15.87 2 12 2ZM12 11.5 hours" />
                      </svg>
                      获取当前位置
                    </button>
                  </div>
                </div>

                <div class="radius-setting">
                  <label>提醒半径: {{ locationInfo.radius }}米</label>
                  <input
                    v-model="locationInfo.radius"
                    type="range"
                    min="50"
                    max="1000"
                    step="50"
                    class="radius-slider"
                  >
                </div>
              </div>
            </div>

            <!-- 天气相关功能 -->
            <div class="section">
              <div class="setting-row">
                <label class="switch">
                  <input
                    v-model="smartFeatures.weatherDependent"
                    type="checkbox"
                    :disabled="!smartFeatures.smartReminder"
                  >
                  <span class="slider" />
                </label>
                <div class="setting-info">
                  <span class="label">天气相关提醒</span>
                  <p class="description">
                    根据天气条件调整提醒策略
                  </p>
                </div>
              </div>

              <div v-if="smartFeatures.weatherDependent" class="weather-settings">
                <div class="weather-info">
                  <button class="weather-btn" @click="getCurrentWeather">
                    <svg class="icon" viewBox="0 0 24 24" fill="currentColor">
                      <path d="M6.59,0.66C8.93,-1.15 11.47,1.06 12.04,4.5C12.47,4.5 12.89,4.62 13.27,4.84C13.79,5.15 14.2,5.59 14.44,6.13C14.82,5.97 15.24,5.9 15.68,5.9C17.15,5.9 18.4,6.82 18.83,8.14C19.35,8.14 19.8,8.35 20.12,8.7C20.59,9.21 20.59,10 20.12,10.5C19.8,10.85 19.35,11.06 18.83,11.06H5.5C4.67,11.06 4,10.39 4,9.56C4,8.73 4.67,8.06 5.5,8.06C5.5,6.58 6.59,0.66 6.59,0.66M13.5,12H15.5C16.33,12 17,12.67 17,13.5C17,14.33 16.33,15 15.5,15H13.5C12.67,15 12,14.33 12,13.5C12,12.67 12.67,12 13.5,12M9.5,12H11.5C12.33,12 13,12.67 13,13.5C13,14.33 12.33,15 11.5,15H9.5C8.67,15 8,14.33 8,13.5C8,12.67 8.67,12 9.5,12Z" />
                    </svg>
                    获取天气信息
                  </button>

                  <div v-if="weatherInfo.condition" class="weather-display">
                    <div class="weather-icon">
                      {{ weatherInfo.condition === 'sunny' ? '☀'
                        : weatherInfo.condition === 'cloudy' ? '☁'
                          : weatherInfo.condition === 'rainy' ? '🌧' : '❄' }}
                    </div>
                    <div class="weather-details">
                      <span class="temperature">{{ weatherInfo.temperature }}°C</span>
                      <span class="humidity">湿度: {{ weatherInfo.humidity }}%</span>
                      <span class="wind">风速: {{ weatherInfo.windSpeed }}m/s</span>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <!-- 优先级增强 -->
            <div class="section">
              <div class="setting-row">
                <label class="switch">
                  <input
                    v-model="smartFeatures.priorityBoost"
                    type="checkbox"
                    :disabled="!smartFeatures.smartReminder"
                  >
                  <span class="slider" />
                </label>
                <div class="setting-info">
                  <span class="label">优先级增强提醒</span>
                  <p class="description">
                    高优先级任务获得更多提醒和特殊处理
                  </p>
                </div>
              </div>
            </div>

            <!-- 时区设置 -->
            <div class="section">
              <div class="setting-row">
                <label>时区设置</label>
                <select v-model="smartFeatures.timezone" class="timezone-select">
                  <option v-for="tz in timezones" :key="tz" :value="tz">
                    {{ tz }}
                  </option>
                </select>
              </div>
            </div>

            <!-- 功能预览 -->
            <div v-if="hasSmartFeatures" class="features-preview">
              <h4>功能预览</h4>
              <div class="preview-grid">
                <div v-if="smartFeatures.smartReminder" class="preview-item">
                  <span class="preview-icon">🧠</span>
                  <span>智能提醒已启用</span>
                </div>
                <div v-if="smartFeatures.locationBased" class="preview-item">
                  <span class="preview-icon">📍</span>
                  <span>位置提醒已启用</span>
                </div>
                <div v-if="smartFeatures.weatherDependent" class="preview-item">
                  <span class="preview-icon">🌤</span>
                  <span>天气提醒已启用</span>
                </div>
                <div v-if="smartFeatures.priorityBoost" class="preview-item">
                  <span class="preview-icon">⚡</span>
                  <span>优先级增强已启用</span>
                </div>
              </div>
            </div>
          </div>

          <div class="modal-footer teleport">
            <button class="btn-secondary teleport" @click="resetToDefaults">
              重置默认
            </button>
            <button class="btn-primary teleport" @click="saveSmartFeatures">
              保存设置
            </button>
          </div>
        </div>
      </div>
    </Teleport>
  </div>
</template>

<style scoped lang="postcss">
.todo-smart-features {
  position: relative;
}

/* 按钮样式现在使用全局 .todo-btn 样式 */

.icon {
  width: 0.875rem;
  height: 0.875rem;
  flex-shrink: 0;
}

.features-text {
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  max-width: 4rem;
}

.feature-indicators {
  display: flex;
  gap: 0.125rem;
  margin-left: 0.25rem;
}

.indicator {
  font-size: 0.625rem;
  line-height: 1;
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

.section {
  border: 1px solid var(--color-base-300);
  border-radius: 0.5rem;
  padding: 1rem;
}

.setting-row {
  display: flex;
  align-items: flex-start;
  gap: 1rem;
}

.setting-info {
  flex: 1;
}

.setting-info .label {
  font-weight: 500;
  color: var(--color-base-content);
  display: block;
  margin-bottom: 0.25rem;
}

.setting-info .description {
  font-size: 0.875rem;
  color: var(--color-base-content);
  opacity: 0.7;
  margin: 0;
}

/* 开关样式 */
.switch {
  position: relative;
  display: inline-block;
  width: 2.5rem;
  height: 1.25rem;
  flex-shrink: 0;
}

.switch input {
  opacity: 0;
  width: 0;
  height: 0;
}

.slider {
  position: absolute;
  cursor: pointer;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background-color: var(--color-base-300);
  transition: 0.2s;
  border-radius: 1.25rem;
}

.slider:before {
  position: absolute;
  content: "";
  height: 1rem;
  width: 1rem;
  left: 0.125rem;
  bottom: 0.125rem;
  background-color: white;
  transition: 0.2s;
  border-radius: 50%;
}

input:checked + .slider {
  background-color: var(--color-primary);
}

input:checked + .slider:before {
  transform: translateX(1.25rem);
}

input:disabled + .slider {
  opacity: 0.5;
  cursor: not-allowed;
}

/* 位置设置 */
.location-settings {
  margin-top: 1rem;
  padding-top: 1rem;
  border-top: 1px solid var(--color-base-300);
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.location-input-group {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.input-row {
  display: flex;
  gap: 0.5rem;
}

.location-input {
  flex: 1;
  padding: 0.5rem;
  border: 1px solid var(--color-base-300);
  border-radius: 0.375rem;
  background: var(--color-base-100);
  color: var(--color-base-content);
}

.location-btn {
  display: flex;
  align-items: center;
  gap: 0.25rem;
  padding: 0.5rem 0.75rem;
  border: 1px solid var(--color-info);
  border-radius: 0.375rem;
  background: var(--color-info);
  color: var(--color-info-content);
  cursor: pointer;
  font-size: 0.875rem;
}

.radius-setting {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.radius-slider {
  width: 100%;
}

/* 天气设置 */
.weather-settings {
  margin-top: 1rem;
  padding-top: 1rem;
  border-top: 1px solid var(--color-base-300);
}

.weather-btn {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.75rem 1rem;
  border: 1px solid var(--color-warning);
  border-radius: 0.5rem;
  background: var(--color-warning);
  color: var(--color-warning-content);
  cursor: pointer;
  font-weight: 500;
}

.weather-display {
  margin-top: 1rem;
  display: flex;
  align-items: center;
  gap: 1rem;
  padding: 1rem;
  background: var(--color-base-200);
  border-radius: 0.5rem;
}

.weather-icon {
  font-size: 2rem;
}

.weather-details {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.temperature {
  font-size: 1.25rem;
  font-weight: 600;
}

.humidity,
.wind {
  font-size: 0.875rem;
  opacity: 0.7;
}

/* 时区选择 */
.timezone-select {
  padding: 0.5rem;
  border: 1px solid var(--color-base-300);
  border-radius: 0.375rem;
  background: var(--color-base-100);
  color: var(--color-base-content);
}

/* 功能预览 */
.features-preview {
  padding: 1rem;
  background: var(--color-base-200);
  border-radius: 0.5rem;
  border: 1px solid var(--color-base-300);
}

.features-preview h4 {
  margin: 0 0 1rem 0;
  font-size: 1rem;
  font-weight: 600;
}

.preview-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 0.75rem;
}

.preview-item {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.5rem;
  background: var(--color-base-100);
  border-radius: 0.375rem;
  font-size: 0.875rem;
}

.preview-icon {
  font-size: 1rem;
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

  .preview-grid {
    grid-template-columns: 1fr;
  }

  .input-row {
    flex-direction: column;
  }

  .weather-display {
    flex-direction: column;
    text-align: center;
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
