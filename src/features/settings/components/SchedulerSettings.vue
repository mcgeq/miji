<script setup lang="ts">
  import { Save, Trash2 } from 'lucide-vue-next';
  import { schedulerApi } from '@/api/scheduler';
  import {
    formatInterval,
    isMobilePlatform,
    type SchedulerConfig,
    type SchedulerTaskType,
    TASK_INTERVAL_RANGES,
    TASK_TYPE_DESCRIPTIONS,
    TASK_TYPE_ICONS,
    TASK_TYPE_LABELS,
  } from '@/types/scheduler';
  import { toast } from '@/utils/toast';

  // 状态
  const configs = ref<SchedulerConfig[]>([]);
  const loading = ref(false);
  const saving = ref(false);
  const error = ref<string | null>(null);
  const activeHoursEnabled = ref<Record<string, boolean>>({});
  const lastUpdateTime = ref<string>('');

  // 是否为移动端
  const isMobile = computed(() => isMobilePlatform());

  // 加载配置
  async function loadConfigs() {
    loading.value = true;
    error.value = null;

    try {
      const loadedConfigs = await schedulerApi.list();
      configs.value = loadedConfigs;

      // 初始化活动时段开关状态
      loadedConfigs.forEach(config => {
        activeHoursEnabled.value[config.taskType] = !!(
          config.activeHoursStart && config.activeHoursEnd
        );
      });

      lastUpdateTime.value = new Date().toLocaleString('zh-CN');
    } catch (err) {
      error.value = err instanceof Error ? err.message : '加载配置失败';
      console.error('加载配置失败:', err);
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
      lastUpdateTime.value = new Date().toLocaleString('zh-CN');
    } catch (err) {
      toast.error(`更新失败: ${err instanceof Error ? err.message : '未知错误'}`);
      console.error('更新配置失败:', err);
    }
  }

  // 保存所有配置
  async function saveAllConfigs() {
    saving.value = true;

    try {
      await Promise.all(
        configs.value.map(config =>
          schedulerApi.update({
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
          }),
        ),
      );

      toast.success('所有配置已保存');
      lastUpdateTime.value = new Date().toLocaleString('zh-CN');
    } catch (err) {
      toast.error(`保存失败: ${err instanceof Error ? err.message : '未知错误'}`);
      console.error('保存配置失败:', err);
    } finally {
      saving.value = false;
    }
  }

  // 重置配置
  async function resetConfig(taskType: SchedulerTaskType) {
    try {
      await schedulerApi.reset(taskType);
      toast.success(`${TASK_TYPE_LABELS[taskType]} 已重置为默认配置`);
      await loadConfigs();
    } catch (err) {
      toast.error(`重置失败: ${err instanceof Error ? err.message : '未知错误'}`);
      console.error('重置配置失败:', err);
    }
  }

  // 清除缓存
  async function clearCache() {
    try {
      await schedulerApi.clearCache();
      toast.success('缓存已清除');
    } catch (err) {
      toast.error(`清除缓存失败: ${err instanceof Error ? err.message : '未知错误'}`);
      console.error('清除缓存失败:', err);
    }
  }

  // 组件挂载时加载配置
  onMounted(() => {
    loadConfigs();
  });
</script>

<template>
  <div class="max-w-4xl mx-auto p-6">
    <!-- 标题和说明 -->
    <div class="mb-6">
      <h2 class="text-2xl font-bold">⚙️ 定时任务配置</h2>
      <p class="text-sm text-gray-500 mt-2">
        调整通知检查频率和任务执行策略，优化系统性能和电池续航
      </p>
    </div>

    <!-- 加载状态 -->
    <div v-if="loading" class="flex items-center justify-center py-12">
      <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary"></div>
      <span class="ml-3 text-gray-600">加载配置中...</span>
    </div>

    <!-- 错误提示 -->
    <div v-else-if="error" class="bg-red-50 border border-red-200 rounded-lg p-4">
      <p class="text-red-800">{{ error }}</p>
      <button
        @click="loadConfigs"
        class="mt-2 px-4 py-2 bg-red-600 text-white rounded hover:bg-red-700"
      >
        重试
      </button>
    </div>

    <!-- 配置列表 -->
    <div v-else class="space-y-4 mt-6">
      <div
        v-for="config in configs"
        :key="config.serialNum"
        class="border rounded-lg p-4 hover:shadow-lg transition-all duration-200"
      >
        <!-- 任务标题行 -->
        <div class="flex items-center justify-between mb-4">
          <div class="flex items-center gap-3">
            <!-- 启用开关 -->
            <label class="relative inline-flex items-center cursor-pointer">
              <input
                type="checkbox"
                v-model="config.enabled"
                @change="updateConfig(config)"
                class="sr-only peer"
              />
              <div
                class="w-11 h-6 bg-gray-200 peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-blue-300 rounded-full peer peer-checked:after:translate-x-full rtl:peer-checked:after:-translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:start-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-blue-600"
              ></div>
            </label>

            <!-- 任务信息 -->
            <div>
              <div class="flex items-center gap-2">
                <span class="text-xl">{{ TASK_TYPE_ICONS[config.taskType] }}</span>
                <span class="font-medium text-lg">{{ TASK_TYPE_LABELS[config.taskType] }}</span>
                <span
                  v-if="config.platform"
                  class="px-2 py-1 text-xs bg-gray-100 text-gray-600 rounded"
                >
                  {{ config.platform }}
                </span>
                <span
                  v-if="config.isDefault"
                  class="px-2 py-1 text-xs bg-green-100 text-green-600 rounded"
                >
                  默认
                </span>
              </div>
              <p class="text-sm text-gray-500 mt-1">
                {{ TASK_TYPE_DESCRIPTIONS[config.taskType] }}
              </p>
            </div>
          </div>

          <!-- 重置按钮 -->
          <button
            @click="resetConfig(config.taskType)"
            class="px-3 py-1 text-sm text-gray-600 hover:text-gray-900 hover:bg-gray-100 rounded transition-colors"
            title="重置为默认配置"
          >
            🔄 重置
          </button>
        </div>

        <!-- 配置详情（仅在启用时显示） -->
        <div v-if="config.enabled" class="space-y-4 pl-14">
          <!-- 执行间隔 -->
          <div class="config-item">
            <label class="text-sm font-medium text-gray-700 block mb-2">执行间隔</label>
            <div class="flex items-center gap-3">
              <input
                type="range"
                v-model.number="config.intervalSeconds"
                :min="getIntervalRange(config.taskType).min"
                :max="getIntervalRange(config.taskType).max"
                :step="getIntervalRange(config.taskType).step"
                @change="updateConfig(config)"
                class="flex-1 h-2 bg-gray-200 rounded-lg appearance-none cursor-pointer"
              />
              <span class="min-w-24 text-sm text-gray-600 font-medium text-right">
                {{ formatInterval(config.intervalSeconds) }}
              </span>
            </div>
            <div class="flex justify-between text-xs text-gray-400 mt-1">
              <span>{{ formatInterval(getIntervalRange(config.taskType).min) }}</span>
              <span>{{ formatInterval(getIntervalRange(config.taskType).max) }}</span>
            </div>
          </div>

          <!-- 活动时段 -->
          <div class="config-item">
            <div class="flex items-center gap-2 mb-2">
              <input
                type="checkbox"
                v-model="activeHoursEnabled[config.taskType]"
                @change="toggleActiveHours(config)"
                class="w-4 h-4 text-blue-600 bg-gray-100 border-gray-300 rounded focus:ring-blue-500"
              />
              <label class="text-sm font-medium text-gray-700">限制活动时段</label>
            </div>
            <div v-if="activeHoursEnabled[config.taskType]" class="flex items-center gap-2 ml-6">
              <input
                type="time"
                v-model="config.activeHoursStart"
                @change="updateConfig(config)"
                class="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              />
              <span class="text-gray-500">至</span>
              <input
                type="time"
                v-model="config.activeHoursEnd"
                @change="updateConfig(config)"
                class="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              />
            </div>
          </div>

          <!-- 移动端优化（仅移动端显示） -->
          <div v-if="isMobile" class="config-item">
            <h4 class="text-sm font-medium text-gray-700 mb-3 flex items-center gap-2">
              📱 移动端优化
            </h4>

            <!-- 电量阈值 -->
            <div class="flex items-center gap-3 mb-3">
              <label class="text-sm text-gray-600 flex-1">电量低于时暂停任务</label>
              <input
                type="number"
                v-model.number="config.batteryThreshold"
                :min="10"
                :max="100"
                :step="5"
                @change="updateConfig(config)"
                class="w-20 px-3 py-2 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              />
              <span class="text-sm text-gray-500">%</span>
            </div>

            <!-- 网络要求 -->
            <div class="flex items-center gap-2 mb-2">
              <input
                type="checkbox"
                v-model="config.networkRequired"
                @change="updateConfig(config)"
                class="w-4 h-4 text-blue-600 bg-gray-100 border-gray-300 rounded focus:ring-blue-500"
              />
              <label class="text-sm text-gray-600">需要网络连接</label>
            </div>

            <!-- 仅Wi-Fi -->
            <div v-if="config.networkRequired" class="flex items-center gap-2 ml-6">
              <input
                type="checkbox"
                v-model="config.wifiOnly"
                @change="updateConfig(config)"
                class="w-4 h-4 text-blue-600 bg-gray-100 border-gray-300 rounded focus:ring-blue-500"
              />
              <label class="text-sm text-gray-600">仅 Wi-Fi 连接时执行</label>
            </div>
          </div>

          <!-- 重试策略 -->
          <div class="config-item">
            <h4 class="text-sm font-medium text-gray-700 mb-3 flex items-center gap-2">
              🔄 重试策略
            </h4>
            <div class="grid grid-cols-2 gap-3">
              <div>
                <label class="text-xs text-gray-600 block mb-1">最大重试次数</label>
                <input
                  type="number"
                  v-model.number="config.maxRetryCount"
                  :min="0"
                  :max="10"
                  @change="updateConfig(config)"
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                />
              </div>
              <div>
                <label class="text-xs text-gray-600 block mb-1">重试延迟（秒）</label>
                <input
                  type="number"
                  v-model.number="config.retryDelaySeconds"
                  :min="10"
                  :max="600"
                  :step="10"
                  @change="updateConfig(config)"
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                />
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- 底部操作栏 -->
    <div v-if="!loading && !error" class="mt-6 pt-4 border-t">
      <div class="flex flex-col items-center gap-4">
        <!-- 最后更新时间 -->
        <div class="text-sm text-gray-500">
          <span>最后更新: {{ lastUpdateTime }}</span>
        </div>

        <!-- 按钮组 -->
        <div class="flex gap-3">
          <button
            @click="clearCache"
            :disabled="saving"
            title="清除配置缓存"
            class="p-2.5 text-gray-700 bg-gray-100 rounded-lg hover:bg-gray-200 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
          >
            <Trash2 class="w-5 h-5" />
          </button>
          <button
            @click="saveAllConfigs"
            :disabled="saving"
            :title="saving ? '保存中...' : '保存所有配置更改'"
            class="p-2.5 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
          >
            <Save class="w-5 h-5" :class="{ 'animate-pulse': saving }" />
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
  /* 自定义滑块样式 - 这些伪元素无法用 Tailwind utility classes */
  input[type="range"]::-webkit-slider-thumb {
    appearance: none;
    width: 1rem;
    height: 1rem;
    border-radius: 9999px;
    background-color: rgb(37 99 235);
    cursor: pointer;
  }

  input[type="range"]::-moz-range-thumb {
    width: 1rem;
    height: 1rem;
    border-radius: 9999px;
    background-color: rgb(37 99 235);
    cursor: pointer;
    border: 0;
  }
</style>
