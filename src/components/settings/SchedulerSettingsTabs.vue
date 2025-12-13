<template>
  <div class="max-w-[1000px] mx-auto">
    <div class="mb-6">
      <h3 class="text-2xl font-semibold mb-2 text-gray-900 dark:text-white">⚙️ 定时任务配置</h3>
      <p class="text-sm text-gray-500 dark:text-gray-400 m-0">根据模块管理自动任务和提醒</p>
    </div>

    <!-- Tab 导航 -->
    <div
      class="flex justify-center gap-2 mb-6 border-b-2 border-gray-200 dark:border-gray-700 pb-0"
    >
      <Tooltip v-for="tab in tabs" :key="tab.key" :content="tab.label" placement="bottom">
        <button
          :class="[
            'flex items-center justify-center w-14 h-14 bg-transparent border-none border-b-3 border-b-transparent text-gray-500 dark:text-gray-400 font-medium cursor-pointer transition-all relative -bottom-0.5 rounded-t-lg',
            'hover:text-gray-900 hover:dark:text-white hover:bg-gray-50 hover:dark:bg-gray-800',
            activeTab === tab.key && 'text-blue-600 dark:text-blue-400 !border-b-blue-600 dark:!border-b-blue-400 bg-gray-50 dark:bg-gray-800'
          ]"
          @click="activeTab = tab.key"
        >
          <span class="text-2xl">{{ tab.icon }}</span>
        </button>
      </Tooltip>
    </div>

    <!-- 加载状态 -->
    <div v-if="loading" class="flex items-center justify-center py-12">
      <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
      <span class="ml-3 text-gray-600 dark:text-gray-400">加载配置中...</span>
    </div>

    <!-- Tab 内容 -->
    <div v-else class="min-h-[400px]">
      <!-- 财务/待办模块 -->
      <div v-if="activeTab !== 'reminder'" class="animate-fade-in space-y-4">
        <div
          v-for="config in filteredConfigs"
          :key="config.serialNum"
          class="p-5 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-xl hover:shadow-lg transition-all"
        >
          <!-- 任务标题 -->
          <div class="flex items-center justify-between mb-4">
            <div class="flex items-center gap-3">
              <!-- Toggle -->
              <label class="relative inline-block w-12 h-7 cursor-pointer">
                <input
                  v-model="config.enabled"
                  type="checkbox"
                  class="sr-only peer"
                  @change="updateConfig(config)"
                />
                <div
                  class="absolute inset-0 bg-gray-200 dark:bg-gray-700 rounded-full transition-colors peer-checked:bg-blue-600 dark:peer-checked:bg-blue-500"
                ></div>
                <div
                  class="absolute top-1 left-1 w-5 h-5 bg-white rounded-full transition-transform peer-checked:translate-x-5"
                ></div>
              </label>

              <!-- 任务信息 -->
              <div>
                <div class="flex items-center gap-2">
                  <span class="text-xl">{{ TASK_TYPE_ICONS[config.taskType] }}</span>
                  <span class="font-medium text-lg text-gray-900 dark:text-white"
                    >{{ TASK_TYPE_LABELS[config.taskType] }}</span
                  >
                  <span
                    v-if="config.platform"
                    class="px-2 py-1 text-xs bg-gray-100 dark:bg-gray-700 text-gray-600 dark:text-gray-300 rounded"
                    >{{ config.platform }}</span
                  >
                  <span
                    v-if="config.isDefault"
                    class="px-2 py-1 text-xs bg-green-100 dark:bg-green-900 text-green-600 dark:text-green-300 rounded"
                    >默认</span
                  >
                </div>
                <p class="text-sm text-gray-500 dark:text-gray-400 mt-1">
                  {{ TASK_TYPE_DESCRIPTIONS[config.taskType] }}
                </p>
              </div>
            </div>

            <!-- 重置按钮 -->
            <button
              class="px-3 py-1 text-sm text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-white hover:bg-gray-100 dark:hover:bg-gray-700 rounded transition-colors"
              title="重置为默认配置"
              @click="resetConfig(config.taskType)"
            >
              🔄 重置
            </button>
          </div>

          <!-- 配置详情 -->
          <div v-if="config.enabled" class="space-y-4 pl-14">
            <!-- 执行间隔 -->
            <div>
              <label class="text-sm font-medium text-gray-700 dark:text-gray-300 block mb-2">
                执行间隔
              </label>
              <div class="flex items-center gap-3">
                <input
                  v-model.number="config.intervalSeconds"
                  type="range"
                  :min="getIntervalRange(config.taskType).min"
                  :max="getIntervalRange(config.taskType).max"
                  :step="getIntervalRange(config.taskType).step"
                  class="flex-1 h-2 bg-gray-200 dark:bg-gray-700 rounded-lg appearance-none cursor-pointer range-slider"
                  @change="updateConfig(config)"
                />
                <span
                  class="min-w-24 text-sm text-gray-600 dark:text-gray-400 font-medium text-right"
                  >{{ formatInterval(config.intervalSeconds) }}</span
                >
              </div>
              <div class="flex justify-between text-xs text-gray-400 mt-1">
                <span>{{ formatInterval(getIntervalRange(config.taskType).min) }}</span>
                <span>{{ formatInterval(getIntervalRange(config.taskType).max) }}</span>
              </div>
            </div>

            <!-- 活动时段 -->
            <div>
              <div class="flex items-center gap-2 mb-2">
                <input
                  v-model="activeHoursEnabled[config.taskType]"
                  type="checkbox"
                  class="w-4 h-4 rounded border-gray-300 dark:border-gray-600 text-blue-600 focus:ring-2 focus:ring-blue-500 cursor-pointer"
                  @change="toggleActiveHours(config)"
                />
                <label class="text-sm font-medium text-gray-700 dark:text-gray-300">
                  限制活动时段
                </label>
              </div>
              <div v-if="activeHoursEnabled[config.taskType]" class="flex items-center gap-2 ml-6">
                <input
                  v-model="config.activeHoursStart"
                  type="time"
                  class="px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg text-sm bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  @change="updateConfig(config)"
                />
                <span class="text-gray-500 dark:text-gray-400">至</span>
                <input
                  v-model="config.activeHoursEnd"
                  type="time"
                  class="px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg text-sm bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  @change="updateConfig(config)"
                />
              </div>
            </div>

            <!-- 移动端优化 -->
            <div v-if="isMobile">
              <h4
                class="text-sm font-medium text-gray-700 dark:text-gray-300 mb-3 flex items-center gap-2"
              >
                📱 移动端优化
              </h4>
              <div class="space-y-2">
                <div class="flex items-center gap-3">
                  <label class="text-sm text-gray-600 dark:text-gray-400 flex-1">
                    电量低于时暂停任务
                  </label>
                  <input
                    v-model.number="config.batteryThreshold"
                    type="number"
                    :min="10"
                    :max="100"
                    :step="5"
                    class="w-20 px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg text-sm bg-white dark:bg-gray-700 text-gray-900 dark:text-white"
                    @change="updateConfig(config)"
                  />
                  <span class="text-sm text-gray-500 dark:text-gray-400">%</span>
                </div>
                <div class="flex items-center gap-2">
                  <input
                    v-model="config.networkRequired"
                    type="checkbox"
                    class="w-4 h-4 rounded border-gray-300 dark:border-gray-600 text-blue-600 cursor-pointer"
                    @change="updateConfig(config)"
                  />
                  <label class="text-sm text-gray-600 dark:text-gray-400">需要网络连接</label>
                </div>
                <div v-if="config.networkRequired" class="flex items-center gap-2 ml-6">
                  <input
                    v-model="config.wifiOnly"
                    type="checkbox"
                    class="w-4 h-4 rounded border-gray-300 dark:border-gray-600 text-blue-600 cursor-pointer"
                    @change="updateConfig(config)"
                  />
                  <label class="text-sm text-gray-600 dark:text-gray-400">
                    仅 Wi-Fi 连接时执行
                  </label>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- 提醒调度器 -->
      <div v-else class="animate-fade-in">
        <ReminderSchedulerSettings />
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
  import { computed, onMounted, ref } from 'vue';
  import { schedulerApi } from '@/api/scheduler';
  import Tooltip from '@/components/ui/Tooltip.vue';
  import {
    formatInterval,
    isMobilePlatform,
    type SchedulerConfig,
    SchedulerTaskType,
    TASK_INTERVAL_RANGES,
    TASK_TYPE_DESCRIPTIONS,
    TASK_TYPE_ICONS,
    TASK_TYPE_LABELS,
  } from '@/types/scheduler';
  import { toast } from '@/utils/toast';
  import ReminderSchedulerSettings from './ReminderSchedulerSettings.vue';

  interface Tab {
    key: string;
    label: string;
    icon: string;
    taskTypes: SchedulerTaskType[];
  }

  const tabs: Tab[] = [
    {
      key: 'finance',
      label: '财务模块',
      icon: '💰',
      taskTypes: [SchedulerTaskType.TransactionProcess, SchedulerTaskType.BudgetAutoCreate],
    },
    {
      key: 'todo',
      label: '待办模块',
      icon: '✅',
      taskTypes: [SchedulerTaskType.TodoAutoCreate],
    },
    {
      key: 'health',
      label: '健康模块',
      icon: '❤️',
      taskTypes: [SchedulerTaskType.PeriodReminderCheck],
    },
    { key: 'reminder', label: '提醒调度器', icon: '🔔', taskTypes: [] },
  ];

  const activeTab = ref('finance');
  const configs = ref<SchedulerConfig[]>([]);
  const loading = ref(false);
  const activeHoursEnabled = ref<Record<string, boolean>>({});
  const isMobile = computed(() => isMobilePlatform());

  // 按模块筛选配置
  const filteredConfigs = computed(() => {
    const currentTab = tabs.find(t => t.key === activeTab.value);
    if (!currentTab || currentTab.taskTypes.length === 0) return [];
    return configs.value.filter(c => currentTab.taskTypes.includes(c.taskType));
  });

  // 加载配置
  async function loadConfigs() {
    loading.value = true;
    try {
      const loadedConfigs = await schedulerApi.list();
      configs.value = loadedConfigs;

      // 初始化活动时段开关
      loadedConfigs.forEach(config => {
        activeHoursEnabled.value[config.taskType] = !!(
          config.activeHoursStart && config.activeHoursEnd
        );
      });
    } catch (err) {
      console.error('加载配置失败:', err);
      toast.error('加载配置失败');
    } finally {
      loading.value = false;
    }
  }

  // 获取间隔范围
  function getIntervalRange(taskType: SchedulerTaskType) {
    return TASK_INTERVAL_RANGES[taskType];
  }

  // 切换活动时段
  function toggleActiveHours(config: SchedulerConfig) {
    if (!activeHoursEnabled.value[config.taskType]) {
      config.activeHoursStart = undefined;
      config.activeHoursEnd = undefined;
    } else {
      config.activeHoursStart = '08:00';
      config.activeHoursEnd = '22:00';
    }
    updateConfig(config);
  }

  // 更新单个配置
  async function updateConfig(config: SchedulerConfig) {
    try {
      await schedulerApi.update({
        serialNum: config.serialNum,
        enabled: config.enabled,
        intervalSeconds: config.intervalSeconds,
        maxRetryCount: config.maxRetryCount,
        retryDelaySeconds: config.retryDelaySeconds,
        batteryThreshold: config.batteryThreshold,
        networkRequired: config.networkRequired,
        wifiOnly: config.wifiOnly,
        activeHoursStart: config.activeHoursStart,
        activeHoursEnd: config.activeHoursEnd,
      });
      toast.success(`${TASK_TYPE_LABELS[config.taskType]} 配置已更新`);
    } catch (err) {
      toast.error(`更新失败: ${err instanceof Error ? err.message : '未知错误'}`);
    }
  }

  // 重置配置
  async function resetConfig(taskType: SchedulerTaskType) {
    try {
      await schedulerApi.reset(taskType);
      toast.success(`${TASK_TYPE_LABELS[taskType]} 已重置为默认配置`);
      await loadConfigs();
    } catch (err) {
      toast.error('重置失败');
    }
  }

  onMounted(() => {
    loadConfigs();
  });
</script>

<style scoped>
  /* 使用 Tailwind CSS 4 */

  /* 自定义动画 */
  @keyframes fade-in {
    from {
      opacity: 0;
      transform: translateY(-10px);
    }
    to {
      opacity: 1;
      transform: translateY(0);
    }
  }

  .animate-fade-in {
    animation: fade-in 0.3s ease-out;
  }

  /* Range Slider 样式 */
  .range-slider::-webkit-slider-thumb {
    appearance: none;
    width: 1rem;
    height: 1rem;
    border-radius: 9999px;
    background-color: rgb(37 99 235);
    cursor: pointer;
  }

  .range-slider::-moz-range-thumb {
    width: 1rem;
    height: 1rem;
    border-radius: 9999px;
    background-color: rgb(37 99 235);
    cursor: pointer;
    border: 0;
  }
</style>
