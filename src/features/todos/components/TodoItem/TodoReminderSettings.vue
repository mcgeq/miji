<script setup lang="ts">
import { Bell, Check, Settings } from 'lucide-vue-next';
import { Modal } from '@/components/ui';
import type { TodoUpdate } from '@/schema/todos';

type ReminderMethod = 'system' | 'email' | 'sms';
type ReminderMethods = Record<ReminderMethod, boolean>;
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
const ADVANCE_UNITS = ['minutes', 'hours', 'days'] as const;
type AdvanceUnit = typeof ADVANCE_UNITS[number];
const FREQUENCIES = ['once', 'daily', 'weekly', 'custom'] as const;
type Frequency = typeof FREQUENCIES[number];

const showModal = ref(false);
const isModalVisible = ref(false);

// 提醒设置状态
const reminderSettings = ref<{
  enabled: boolean;
  advanceValue: number;
  advanceUnit: AdvanceUnit;
  frequency: Frequency;
  methods: ReminderMethods;
  smartEnabled: boolean;
  locationBased: boolean;
  weatherDependent: boolean;
  priorityBoost: boolean;
}>({
  enabled: props.todo.reminderEnabled,
  advanceValue: props.todo.reminderAdvanceValue ?? 15,
  advanceUnit: (ADVANCE_UNITS as readonly string[]).includes(props.todo.reminderAdvanceUnit ?? '')
    ? (props.todo.reminderAdvanceUnit as AdvanceUnit)
    : 'minutes',
  frequency: (FREQUENCIES as readonly string[]).includes(props.todo.reminderFrequency ?? '')
    ? (props.todo.reminderFrequency as Frequency)
    : 'once',
  // 将桌面/移动合并为 system（系统），保存时再映射为 desktop/mobile
  methods: {
    system: props.todo.reminderMethods
      ? Boolean((props.todo.reminderMethods.desktop || props.todo.reminderMethods.mobile))
      : true,
    email: Boolean(props.todo.reminderMethods?.email ?? false),
    sms: Boolean(props.todo.reminderMethods?.sms ?? false),
  },
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

// 合并后的提醒方式选项（系统 + 邮件 + 短信）
const reminderMethods = [
  { key: 'system' as const, label: '系统' },
  { key: 'email' as const, label: '邮件' },
  { key: 'sms' as const, label: '短信' },
] as const;

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
    // 将 system 同步回 desktop/mobile，保持后端兼容
    reminderMethods: {
      desktop: reminderSettings.value.methods.system,
      mobile: reminderSettings.value.methods.system,
      email: reminderSettings.value.methods.email,
      sms: reminderSettings.value.methods.sms,
    },
    smartReminderEnabled: reminderSettings.value.smartEnabled,
    locationBasedReminder: reminderSettings.value.locationBased,
    weatherDependent: reminderSettings.value.weatherDependent,
    priorityBoostEnabled: reminderSettings.value.priorityBoost,
  };
  emit('update', update);
  closeModal();
}

function toggleMethod(method: ReminderMethod) {
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
    methods: { system: true, email: false, sms: false },
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
    <Modal
      :open="showModal"
      title="提醒设置"
      size="md"
      @close="closeModal"
      @confirm="saveSettings"
    >
      <template #footer>
        <div class="flex justify-center gap-3">
          <button
            class="flex items-center justify-center w-12 h-12 rounded-full border border-gray-300 hover:bg-gray-50 transition-colors"
            title="重置默认"
            @click="resetToDefaults"
          >
            <Settings :size="20" />
          </button>
          <button
            class="flex items-center justify-center w-12 h-12 rounded-full bg-blue-600 text-white hover:bg-blue-700 transition-colors"
            title="保存设置"
            @click="saveSettings(); closeModal()"
          >
            <Check :size="20" />
          </button>
        </div>
      </template>
      <div class="space-y-6">
        <!-- 基础提醒设置 -->
        <div class="space-y-4">
          <div class="flex items-center gap-3">
            <label class="relative inline-flex items-center cursor-pointer">
              <input
                v-model="reminderSettings.enabled"
                type="checkbox"
                class="sr-only peer"
              >
              <div class="w-11 h-6 bg-gray-200 peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-blue-300 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-blue-600" />
            </label>
            <span class="text-sm font-medium">启用提醒</span>
          </div>

          <div v-if="reminderSettings.enabled" class="space-y-4 pl-4 border-l-2 border-blue-600">
            <!-- 提前时间设置 -->
            <div class="space-y-2">
              <label class="block text-sm font-medium">提前提醒时间</label>
              <div class="flex gap-2">
                <input
                  v-model="reminderSettings.advanceValue"
                  type="number"
                  min="1"
                  max="999"
                  class="w-24 px-3 py-2 border border-gray-300 rounded-lg text-center"
                >
                <select v-model="reminderSettings.advanceUnit" class="flex-1 px-3 py-2 border border-gray-300 rounded-lg">
                  <option v-for="unit in advanceUnits" :key="unit.value" :value="unit.value">
                    {{ unit.label }}
                  </option>
                </select>
              </div>
            </div>

            <!-- 提醒频率 -->
            <div class="space-y-2">
              <label class="block text-sm font-medium">提醒频率</label>
              <select v-model="reminderSettings.frequency" class="w-full px-3 py-2 border border-gray-300 rounded-lg">
                <option v-for="option in frequencyOptions" :key="option.value" :value="option.value">
                  {{ option.label }}
                </option>
              </select>
            </div>

            <!-- 提醒方式（系统合并） -->
            <div class="space-y-2">
              <label class="block text-sm font-medium">提醒方式</label>
              <div class="flex gap-3">
                <label
                  v-for="method in reminderMethods"
                  :key="method.key"
                  class="flex items-center gap-2 px-3 py-2 border rounded-lg cursor-pointer transition-colors"
                  :class="reminderSettings.methods[method.key] ? 'bg-blue-50 border-blue-600' : 'border-gray-300 hover:border-blue-500'"
                >
                  <input
                    type="checkbox"
                    :checked="reminderSettings.methods[method.key]"
                    class="w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
                    @change="toggleMethod(method.key)"
                  >
                  <span class="text-sm">{{ method.label }}</span>
                </label>
              </div>
            </div>
          </div>
        </div>

        <!-- 智能提醒设置 -->
        <div class="space-y-4">
          <h4 class="text-sm font-semibold text-gray-700">
            智能提醒
          </h4>
          <div class="space-y-3">
            <div class="flex items-center gap-3">
              <label class="relative inline-flex items-center cursor-pointer">
                <input v-model="reminderSettings.smartEnabled" type="checkbox" class="sr-only peer">
                <div class="w-11 h-6 bg-gray-200 peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-blue-300 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-blue-600" />
              </label>
              <span class="text-sm font-medium">启用智能提醒</span>
            </div>

            <div v-if="reminderSettings.smartEnabled" class="space-y-3 pl-4 border-l-2 border-green-600">
              <label class="flex items-center gap-3 cursor-pointer">
                <input v-model="reminderSettings.locationBased" type="checkbox" class="w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500">
                <span class="text-sm">基于位置的提醒</span>
              </label>

              <label class="flex items-center gap-3 cursor-pointer">
                <input v-model="reminderSettings.weatherDependent" type="checkbox" class="w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500">
                <span class="text-sm">天气相关提醒</span>
              </label>

              <label class="flex items-center gap-3 cursor-pointer">
                <input v-model="reminderSettings.priorityBoost" type="checkbox" class="w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500">
                <span class="text-sm">高优先级增强提醒</span>
              </label>
            </div>
          </div>
        </div>
      </div>
    </Modal>
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
</style>
