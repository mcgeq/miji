<script setup lang="ts">
  import { Brain, Check, Cloud, MapPin, Settings } from 'lucide-vue-next';
  import { Modal, TodoButton } from '@/components/ui';
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
  const hasSmartFeatures = computed(
    () =>
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
  }

  function closeModal() {
    showModal.value = false;
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
  <div class="relative">
    <!-- 智能功能显示按钮 -->
    <TodoButton
      :icon="Brain"
      :active="hasSmartFeatures"
      :readonly="props.readonly"
      :title="hasSmartFeatures ? `智能功能: ${smartFeatureCount}项已启用` : '设置智能功能'"
      @click="openModal"
    >
      <template v-if="hasSmartFeatures">
        <span class="whitespace-nowrap text-ellipsis max-w-16 inline-flex items-center gap-1">
          智能{{ smartFeatureCount }}
          <span v-if="smartFeatures.smartReminder" class="text-[10px]" title="智能提醒">🧠</span>
          <span v-if="smartFeatures.locationBased" class="text-[10px]" title="位置提醒">📍</span>
          <span
            v-if="smartFeatures.weatherDependent"
            class="text-[10px] leading-none"
            title="天气提醒"
            >🌤</span
          >
          <span
            v-if="smartFeatures.priorityBoost"
            class="text-[10px] leading-none"
            title="优先级增强"
            >⚡</span
          >
        </span>
      </template>
    </TodoButton>

    <!-- 智能功能设置模态框 -->
    <Modal
      :open="showModal"
      title="智能功能设置"
      size="lg"
      :show-footer="false"
      @close="closeModal"
    >
      <div class="space-y-6">
        <!-- 基础智能功能 -->
        <div class="border border-gray-200 dark:border-gray-700 rounded-lg p-4">
          <div class="flex items-start gap-4">
            <label class="relative inline-flex items-center cursor-pointer shrink-0 mt-1">
              <input v-model="smartFeatures.smartReminder" type="checkbox" class="sr-only peer" />
              <div
                class="w-11 h-6 bg-gray-200 dark:bg-gray-700 peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-blue-300 dark:peer-focus:ring-blue-800 rounded-full peer peer-checked:after:translate-x-full rtl:peer-checked:after:-translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-0.5 after:start-0.5 after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-blue-600"
              />
            </label>
            <div class="flex-1">
              <span class="block font-medium text-gray-900 dark:text-white">启用智能提醒</span>
              <p class="text-sm text-gray-500 dark:text-gray-400 mt-1">
                基于用户行为和学习习惯优化提醒时间
              </p>
            </div>
          </div>
        </div>

        <!-- 位置相关功能 -->
        <div class="border border-gray-200 dark:border-gray-700 rounded-lg p-4">
          <div class="flex items-start gap-4">
            <label class="relative inline-flex items-center cursor-pointer shrink-0 mt-1">
              <input
                v-model="smartFeatures.locationBased"
                type="checkbox"
                :disabled="!smartFeatures.smartReminder"
                class="sr-only peer"
              />
              <div
                class="w-11 h-6 bg-gray-200 dark:bg-gray-700 peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-blue-300 dark:peer-focus:ring-blue-800 rounded-full peer peer-checked:after:translate-x-full rtl:peer-checked:after:-translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-0.5 after:start-0.5 after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-blue-600 disabled:opacity-50 disabled:cursor-not-allowed"
              />
            </label>
            <div class="flex-1">
              <span class="block font-medium text-gray-900 dark:text-white">基于位置的提醒</span>
              <p class="text-sm text-gray-500 dark:text-gray-400 mt-1">
                当您到达特定位置时发送提醒
              </p>
            </div>
          </div>

          <div
            v-if="smartFeatures.locationBased"
            class="mt-4 pt-4 border-t border-gray-200 dark:border-gray-700 space-y-4"
          >
            <div class="flex flex-col gap-2">
              <label class="text-sm font-medium text-gray-900 dark:text-white">位置设置</label>
              <div class="flex flex-col sm:flex-row gap-2">
                <input
                  v-model="locationInfo.address"
                  type="text"
                  placeholder="输入地址或位置名称..."
                  class="flex-1 px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                />
                <button
                  class="flex items-center justify-center gap-1 px-3 py-2 border border-blue-500 rounded-md bg-blue-500 text-white hover:bg-blue-600 transition-colors text-sm whitespace-nowrap"
                  @click="getCurrentLocation"
                >
                  <MapPin :size="16" />
                  获取当前位置
                </button>
              </div>
            </div>

            <div class="flex flex-col gap-2">
              <label class="text-sm font-medium text-gray-900 dark:text-white">
                提醒半径: {{ locationInfo.radius }}米
              </label>
              <input
                v-model="locationInfo.radius"
                type="range"
                min="50"
                max="1000"
                step="50"
                class="w-full h-2 bg-gray-200 rounded-lg appearance-none cursor-pointer dark:bg-gray-700"
              />
            </div>
          </div>
        </div>

        <!-- 天气相关功能 -->
        <div class="border border-gray-200 dark:border-gray-700 rounded-lg p-4">
          <div class="flex items-start gap-4">
            <label class="relative inline-flex items-center cursor-pointer shrink-0 mt-1">
              <input
                v-model="smartFeatures.weatherDependent"
                type="checkbox"
                :disabled="!smartFeatures.smartReminder"
                class="sr-only peer"
              />
              <div
                class="w-11 h-6 bg-gray-200 dark:bg-gray-700 peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-blue-300 dark:peer-focus:ring-blue-800 rounded-full peer peer-checked:after:translate-x-full rtl:peer-checked:after:-translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-0.5 after:start-0.5 after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-blue-600 disabled:opacity-50 disabled:cursor-not-allowed"
              />
            </label>
            <div class="flex-1">
              <span class="block font-medium text-gray-900 dark:text-white">天气相关提醒</span>
              <p class="text-sm text-gray-500 dark:text-gray-400 mt-1">根据天气条件调整提醒策略</p>
            </div>
          </div>

          <div
            v-if="smartFeatures.weatherDependent"
            class="mt-4 pt-4 border-t border-gray-200 dark:border-gray-700"
          >
            <button
              class="flex items-center gap-2 px-4 py-3 border border-amber-500 rounded-lg bg-amber-500 text-white hover:bg-amber-600 transition-colors font-medium"
              @click="getCurrentWeather"
            >
              <Cloud :size="16" />
              获取天气信息
            </button>

            <div
              v-if="weatherInfo.condition"
              class="mt-4 flex flex-col sm:flex-row items-center sm:items-start gap-4 p-4 bg-gray-100 dark:bg-gray-800 rounded-lg text-center sm:text-left"
            >
              <div class="text-4xl">
                {{ weatherInfo.condition === 'sunny' ? '☀'
                  : weatherInfo.condition === 'cloudy' ? '☁'
                    : weatherInfo.condition === 'rainy' ? '🌧' : '❄' }}
              </div>
              <div class="flex flex-col gap-1">
                <span class="text-xl font-semibold text-gray-900 dark:text-white"
                  >{{ weatherInfo.temperature }}°C</span
                >
                <span class="text-sm text-gray-500 dark:text-gray-400"
                  >湿度: {{ weatherInfo.humidity }}%</span
                >
                <span class="text-sm text-gray-500 dark:text-gray-400"
                  >风速: {{ weatherInfo.windSpeed }}m/s</span
                >
              </div>
            </div>
          </div>
        </div>

        <!-- 优先级增强 -->
        <div class="border border-gray-200 dark:border-gray-700 rounded-lg p-4">
          <div class="flex items-start gap-4">
            <label class="relative inline-flex items-center cursor-pointer shrink-0 mt-1">
              <input
                v-model="smartFeatures.priorityBoost"
                type="checkbox"
                :disabled="!smartFeatures.smartReminder"
                class="sr-only peer"
              />
              <div
                class="w-11 h-6 bg-gray-200 dark:bg-gray-700 peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-blue-300 dark:peer-focus:ring-blue-800 rounded-full peer peer-checked:after:translate-x-full rtl:peer-checked:after:-translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-0.5 after:start-0.5 after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-blue-600 disabled:opacity-50 disabled:cursor-not-allowed"
              />
            </label>
            <div class="flex-1">
              <span class="block font-medium text-gray-900 dark:text-white">优先级增强提醒</span>
              <p class="text-sm text-gray-500 dark:text-gray-400 mt-1">
                高优先级任务获得更多提醒和特殊处理
              </p>
            </div>
          </div>
        </div>

        <!-- 时区设置 -->
        <div class="border border-gray-200 dark:border-gray-700 rounded-lg p-4">
          <div class="flex items-center justify-between gap-4">
            <label class="font-medium text-gray-900 dark:text-white">时区设置</label>
            <select
              v-model="smartFeatures.timezone"
              class="px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            >
              <option v-for="tz in timezones" :key="tz" :value="tz">{{ tz }}</option>
            </select>
          </div>
        </div>

        <!-- 功能预览 -->
        <div
          v-if="hasSmartFeatures"
          class="p-4 bg-gray-100 dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-700"
        >
          <h4 class="mb-4 text-base font-semibold text-gray-900 dark:text-white">功能预览</h4>
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div
              v-if="smartFeatures.smartReminder"
              class="flex items-center gap-2 p-2 bg-white dark:bg-gray-900 rounded-md text-sm"
            >
              <span class="text-base">🧠</span>
              <span class="text-gray-900 dark:text-white">智能提醒已启用</span>
            </div>
            <div
              v-if="smartFeatures.locationBased"
              class="flex items-center gap-2 p-2 bg-white dark:bg-gray-900 rounded-md text-sm"
            >
              <span class="text-base">📍</span>
              <span class="text-gray-900 dark:text-white">位置提醒已启用</span>
            </div>
            <div
              v-if="smartFeatures.weatherDependent"
              class="flex items-center gap-2 p-2 bg-white dark:bg-gray-900 rounded-md text-sm"
            >
              <span class="text-base">🌤</span>
              <span class="text-gray-900 dark:text-white">天气提醒已启用</span>
            </div>
            <div
              v-if="smartFeatures.priorityBoost"
              class="flex items-center gap-2 p-2 bg-white dark:bg-gray-900 rounded-md text-sm"
            >
              <span class="text-base">⚡</span>
              <span class="text-gray-900 dark:text-white">优先级增强已启用</span>
            </div>
          </div>
        </div>
      </div>

      <!-- 自定义footer -->
      <template #footer>
        <div class="flex justify-center gap-3">
          <button
            class="flex items-center justify-center w-12 h-12 rounded-full border border-gray-300 dark:border-gray-600 hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors"
            title="重置默认"
            @click="resetToDefaults"
          >
            <Settings :size="20" />
          </button>
          <button
            class="flex items-center justify-center w-12 h-12 rounded-full bg-blue-600 text-white hover:bg-blue-700 transition-colors"
            title="保存设置"
            @click="saveSmartFeatures"
          >
            <Check :size="20" />
          </button>
        </div>
      </template>
    </Modal>
  </div>
</template>

<style scoped>
  /* 所有样式已使用 Tailwind CSS 4 */
</style>
