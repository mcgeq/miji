<script setup lang="ts">
import { Bell, Check, Settings, X } from 'lucide-vue-next';
import type { TodoUpdate } from '@/schema/todos';

const props = defineProps<{
  todo: {
    reminderEnabled: boolean;
    reminderAdvanceValue: number | null;
    reminderAdvanceUnit: string | null;
    reminderFrequency: string | null;
    reminderMethods: any;
    smartReminderEnabled: boolean;
    locationBasedReminder: boolean;
    weatherDependent: boolean;
    priorityBoostEnabled: boolean;
  };
}>();

const emit = defineEmits<{
  update: [update: TodoUpdate];
}>();

const showModal = ref(false);
const isModalVisible = ref(false);

// 提醒设置状态
const reminderSettings = ref({
  enabled: props.todo.reminderEnabled,
  advanceValue: props.todo.reminderAdvanceValue || 15,
  advanceUnit: props.todo.reminderAdvanceUnit || 'minutes',
  frequency: props.todo.reminderFrequency || 'once',
  methods: props.todo.reminderMethods || { desktop: true, mobile: false, email: false },
  smartEnabled: props.todo.smartReminderEnabled,
  locationBased: props.todo.locationBasedReminder,
  weatherDependent: props.todo.weatherDependent,
  priorityBoost: props.todo.priorityBoostEnabled,
});

// 预设选项
const advanceUnits = [
  { value: 'minutes', label: '分钟' },
  { value: 'hours', label: '小时' },
  { value: 'days', label: '天' },
];

const frequencyOptions = [
  { value: 'once', label: '仅一次' },
  { value: 'daily', label: '每天' },
  { value: 'weekly', label: '每周' },
  { value: 'custom', label: '自定义' },
];

const reminderMethods = [
  { key: 'desktop', label: '桌面通知' },
  { key: 'mobile', label: '移动推送' },
  { key: 'email', label: '邮件提醒' },
  { key: 'sms', label: '短信提醒' },
];

// 计算属性
// hasAdvancedSettings 变量暂时未使用，如需要显示高级设置状态可以重新添加

// 方法
function openModal() {
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

function saveSettings() {
  const update: TodoUpdate = {
    reminderEnabled: reminderSettings.value.enabled,
    reminderAdvanceValue: reminderSettings.value.advanceValue,
    reminderAdvanceUnit: reminderSettings.value.advanceUnit,
    reminderFrequency: reminderSettings.value.frequency,
    reminderMethods: reminderSettings.value.methods,
    smartReminderEnabled: reminderSettings.value.smartEnabled,
    locationBasedReminder: reminderSettings.value.locationBased,
    weatherDependent: reminderSettings.value.weatherDependent,
    priorityBoostEnabled: reminderSettings.value.priorityBoost,
  };
  emit('update', update);
  closeModal();
}

function toggleMethod(method: string) {
  reminderSettings.value.methods = {
    ...reminderSettings.value.methods,
    [method]: !reminderSettings.value.methods[method],
  };
}

function resetToDefaults() {
  reminderSettings.value = {
    enabled: false,
    advanceValue: 15,
    advanceUnit: 'minutes',
    frequency: 'once',
    methods: { desktop: true, mobile: false, email: false, sms: false },
    smartEnabled: false,
    locationBased: false,
    weatherDependent: false,
    priorityBoost: false,
  };
}
</script>

<template>
  <div class="reminder-settings">
    <!-- 提醒开关按钮 -->
    <button
      class="todo-btn"
      :class="{ 'todo-btn--active': todo.reminderEnabled }"
      :title="todo.reminderEnabled ? '编辑提醒设置' : '设置提醒'"
      @click="openModal"
    >
      <Bell class="icon" :size="14" />
      <span v-if="todo.reminderEnabled && todo.reminderAdvanceValue" class="advance-info">
        {{ todo.reminderAdvanceValue }}{{ todo.reminderAdvanceUnit === 'minutes' ? '分钟' : todo.reminderAdvanceUnit === 'hours' ? '小时' : '天' }}前
      </span>
    </button>

    <!-- 提醒设置模态框 -->
    <Teleport to="body">
      <div v-if="showModal" class="modal-overlay teleport" :class="{ visible: isModalVisible }" @click="closeModal">
        <div class="modal-content teleport" @click.stop>
          <div class="modal-header teleport">
            <h3>提醒设置</h3>
            <button class="close-btn teleport" @click="closeModal">
              <X :size="20" />
            </button>
          </div>

          <div class="modal-body teleport">
            <!-- 基础提醒设置 -->
            <div class="section">
              <div class="setting-row">
                <label class="switch">
                  <input
                    v-model="reminderSettings.enabled"
                    type="checkbox"
                  >
                  <span class="slider" />
                </label>
                <span class="label">启用提醒</span>
              </div>

              <div v-if="reminderSettings.enabled" class="settings-group">
                <!-- 提前时间设置 -->
                <div class="setting-row">
                  <label>提前提醒时间</label>
                  <div class="input-group">
                    <input
                      v-model="reminderSettings.advanceValue"
                      type="number"
                      min="1"
                      max="999"
                      class="number-input"
                    >
                    <select v-model="reminderSettings.advanceUnit" class="unit-select">
                      <option v-for="unit in advanceUnits" :key="unit.value" :value="unit.value">
                        {{ unit.label }}
                      </option>
                    </select>
                  </div>
                </div>

                <!-- 提醒频率 -->
                <div class="setting-row">
                  <label>提醒频率</label>
                  <select v-model="reminderSettings.frequency" class="select-input">
                    <option v-for="option in frequencyOptions" :key="option.value" :value="option.value">
                      {{ option.label }}
                    </option>
                  </select>
                </div>

                <!-- 提醒方式 -->
                <div class="setting-row">
                  <label>提醒方式</label>
                  <div class="methods-grid">
                    <label
                      v-for="method in reminderMethods"
                      :key="method.key"
                      class="method-option"
                    >
                      <input
                        type="checkbox"
                        :checked="reminderSettings.methods[method.key]"
                        @change="toggleMethod(method.key)"
                      >
                      <span>{{ method.label }}</span>
                    </label>
                  </div>
                </div>
              </div>
            </div>

            <!-- 智能提醒设置 -->
            <div class="section">
              <h4>智能提醒</h4>
              <div class="settings-group">
                <div class="setting-row">
                  <label class="switch">
                    <input v-model="reminderSettings.smartEnabled" type="checkbox">
                    <span class="slider" />
                  </label>
                  <span class="label">启用智能提醒</span>
                </div>

                <div v-if="reminderSettings.smartEnabled" class="smart-settings">
                  <div class="setting-row">
                    <label class="switch">
                      <input v-model="reminderSettings.locationBased" type="checkbox">
                      <span class="slider" />
                    </label>
                    <span class="label">基于位置的提醒</span>
                  </div>

                  <div class="setting-row">
                    <label class="switch">
                      <input v-model="reminderSettings.weatherDependent" type="checkbox">
                      <span class="slider" />
                    </label>
                    <span class="label">天气相关提醒</span>
                  </div>

                  <div class="setting-row">
                    <label class="switch">
                      <input v-model="reminderSettings.priorityBoost" type="checkbox">
                      <span class="slider" />
                    </label>
                    <span class="label">高优先级增强提醒</span>
                  </div>
                </div>
              </div>
            </div>

            <div class="modal-footer teleport">
              <button class="btn-icon btn-secondary teleport" title="重置默认" @click="resetToDefaults">
                <Settings :size="20" />
              </button>
              <button class="btn-icon btn-secondary teleport" title="取消" @click="closeModal">
                <X :size="20" />
              </button>
              <button class="btn-icon btn-primary teleport" title="保存设置" @click="saveSettings">
                <Check :size="20" />
              </button>
            </div>
          </div>
        </div>
      </div>
    </Teleport>
  </div>
</template>

<style scoped lang="postcss">
.reminder-settings {
  position: relative;
}

/* 按钮样式现在使用全局 .todo-btn 样式 */

.icon {
  width: 1rem;
  height: 1rem;
}

.advance-info {
  font-size: 0.7rem;
  opacity: 0.9;
}

/* 模态框样式 - 全局样式，因为使用了Teleport */

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
}

.section {
  margin-bottom: 1.5rem;
}

.section h4 {
  margin: 0 0 1rem 0;
  font-size: 1rem;
  font-weight: 600;
  color: var(--color-base-content);
}

.setting-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0.75rem 0;
  border-bottom: 1px solid var(--color-base-200);
}

.setting-row:last-child {
  border-bottom: none;
}

.setting-row label {
  font-weight: 500;
  color: var(--color-base-content);
}

.settings-group {
  margin-top: 0.5rem;
  padding-left: 1rem;
  border-left: 2px solid var(--color-primary);
}

.smart-settings {
  margin-top: 0.5rem;
}

/* 开关样式 */
.switch {
  position: relative;
  display: inline-block;
  width: 2.5rem;
  height: 1.25rem;
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

/* 输入框样式 */
.input-group {
  display: flex;
  gap: 0.5rem;
}

.number-input {
  width: 4rem;
  padding: 0.5rem;
  border: 1px solid var(--color-base-300);
  border-radius: 0.375rem;
  text-align: center;
}

.unit-select,
.select-input {
  padding: 0.5rem;
  border: 1px solid var(--color-base-300);
  border-radius: 0.375rem;
  background: var(--color-base-100);
  color: var(--color-base-content);
}

/* 提醒方式网格 */
.methods-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0.5rem;
  margin-top: 0.5rem;
}

.method-option {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.5rem;
  border: 1px solid var(--color-base-300);
  border-radius: 0.375rem;
  cursor: pointer;
  transition: all 0.2s ease;
}

.method-option:hover {
  background: var(--color-base-200);
}

.method-option input[type="checkbox"] {
  margin: 0;
}

/* 模态框底部样式已移至全局buttons.css */

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

/* 圆形图标按钮样式已移至全局buttons.css */

/* 响应式设计 */
@media (max-width: 768px) {
  .modal-content {
    width: 95%;
    margin: 1rem;
  }
  .methods-grid {
    grid-template-columns: 1fr;
  }
  .modal-footer {
    flex-direction: row;
    gap: 1.5rem;
    justify-content: center;
  }
  .btn-icon {
    width: 2.5rem !important;
    height: 2.5rem !important;
  }
}
</style>
