<template>
  <div class="max-w-4xl mx-auto">
    <!-- 加载状态 -->
    <div v-if="loading" class="flex items-center justify-center py-16">
      <div
        class="animate-spin rounded-full h-10 w-10 border-b-2 border-orange-600 dark:border-orange-500"
      ></div>
      <span class="ml-3 text-gray-600 dark:text-gray-400 text-lg">加载中...</span>
    </div>

    <!-- 错误消息 -->
    <div
      v-else-if="errorMessage"
      class="p-5 bg-red-50 dark:bg-red-900/20 border-2 border-red-200 dark:border-red-800 rounded-xl flex items-center justify-between shadow-sm"
    >
      <span class="text-red-700 dark:text-red-300 font-medium">{{ errorMessage }}</span>
      <button
        @click="loadState"
        class="px-4 py-2 bg-red-600 hover:bg-red-700 text-white rounded-lg font-medium transition-colors shadow-md hover:shadow-lg"
      >
        重试
      </button>
    </div>

    <!-- 主内容 -->
    <div v-else-if="state" class="space-y-6">
      <!-- 状态卡片 -->
      <div
        class="bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-xl shadow-sm"
      >
        <div class="p-5">
          <!-- 状态头部 -->
          <div
            class="flex items-center justify-between pb-4 mb-4 border-b border-gray-200 dark:border-gray-700"
          >
            <div class="flex items-center gap-3">
              <div class="relative">
                <div
                  :class="[
                    'w-4 h-4 rounded-full transition-all duration-300',
                    state.isRunning 
                      ? 'bg-green-500 shadow-lg shadow-green-500/50' 
                      : 'bg-gray-400 dark:bg-gray-600'
                  ]"
                >
                  <div
                    v-if="state.isRunning"
                    class="absolute inset-0 rounded-full bg-green-500 animate-ping opacity-75"
                  ></div>
                </div>
              </div>
              <span class="text-xl font-bold text-gray-900 dark:text-white">
                {{ state.isRunning ? '🟢 运行中' : '⚫ 已停止' }}
              </span>
            </div>
          </div>

          <!-- 状态网格 -->
          <div class="grid grid-cols-2 gap-3">
            <div
              class="p-3 bg-gray-50 dark:bg-gray-700/50 rounded-lg border border-gray-200 dark:border-gray-600"
            >
              <div class="flex items-center justify-between">
                <span class="text-sm text-gray-500 dark:text-gray-400">上次扫描</span>
                <span class="text-xs text-orange-600 dark:text-orange-400">⏱️</span>
              </div>
              <div class="mt-2 text-lg font-semibold text-gray-900 dark:text-white">
                {{ displayTime }}
              </div>
            </div>

            <div
              class="p-3 bg-gray-50 dark:bg-gray-700/50 rounded-lg border border-gray-200 dark:border-gray-600"
            >
              <div class="flex items-center justify-between">
                <span class="text-sm text-gray-500 dark:text-gray-400">待处理</span>
                <span class="text-xs">⏳</span>
              </div>
              <div class="mt-2 text-lg font-semibold text-blue-600 dark:text-blue-400">
                {{ state.pendingTasks }}个
              </div>
            </div>

            <div
              class="p-3 bg-gray-50 dark:bg-gray-700/50 rounded-lg border border-gray-200 dark:border-gray-600"
            >
              <div class="flex items-center justify-between">
                <span class="text-sm text-gray-500 dark:text-gray-400">今日已执行</span>
                <span class="text-xs">✅</span>
              </div>
              <div class="mt-2 text-lg font-semibold text-green-600 dark:text-green-400">
                {{ state.executedToday }}个
              </div>
            </div>

            <div
              class="p-3 bg-gray-50 dark:bg-gray-700/50 rounded-lg border border-gray-200 dark:border-gray-600"
            >
              <div class="flex items-center justify-between">
                <span class="text-sm text-gray-500 dark:text-gray-400">今日失败</span>
                <span class="text-xs">❌</span>
              </div>
              <div class="mt-2 text-lg font-semibold text-red-600 dark:text-red-400">
                {{ state.failedToday }}个
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- 操作按钮区 -->
      <div class="flex justify-center gap-3">
        <button
          @click="toggle"
          :disabled="loading"
          :class="[
            'w-12 h-12 rounded-lg text-xl text-white transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center',
            state.isRunning 
              ? 'bg-red-600 hover:bg-red-700' 
              : 'bg-green-600 hover:bg-green-700'
          ]"
          :title="state.isRunning ? '停止调度器' : '启动调度器'"
        >
          {{ state.isRunning ? '⏸️' : '▶️' }}
        </button>

        <button
          @click="handleScan"
          :disabled="loading || !state.isRunning"
          class="w-12 h-12 bg-blue-600 hover:bg-blue-700 text-white text-xl rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center"
          title="立即扫描"
        >
          🔍
        </button>

        <button
          v-if="isDev"
          @click="handleTest"
          :disabled="loading"
          class="w-12 h-12 bg-gray-600 hover:bg-gray-700 text-white text-xl rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center"
          title="测试通知"
        >
          🧪
        </button>

        <button
          @click="loadState"
          :disabled="loading"
          class="w-12 h-12 bg-white dark:bg-gray-700 hover:bg-gray-50 dark:hover:bg-gray-600 text-gray-700 dark:text-white text-xl rounded-lg border border-gray-300 dark:border-gray-600 transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center"
          title="刷新状态"
        >
          🔄
        </button>
      </div>

      <!-- 扫描结果 -->
      <div
        v-if="scanResult !== null"
        class="p-4 bg-green-50 dark:bg-green-900/20 border border-green-200 dark:border-green-800 rounded-lg animate-fade-in"
      >
        <div class="flex items-center gap-2">
          <span class="text-green-600 dark:text-green-400 text-xl">✓</span>
          <span class="text-green-800 dark:text-green-300 font-medium">
            扫描完成，找到 <span class="font-semibold">{{ scanResult }}</span>个待发送提醒
          </span>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
  import { listen } from '@tauri-apps/api/event';
  import { onMounted, onUnmounted, ref } from 'vue';
  import { reminderSchedulerApi, type SchedulerState } from '@/api/reminderScheduler';
  import { toast } from '@/utils/toast';

  // 乐观初始状态：假设调度器已启动（与后端保持一致）
  const state = ref<SchedulerState | null>({
    isRunning: true,
    lastScanAt: undefined,
    pendingTasks: 0,
    executedToday: 0,
    failedToday: 0,
  });
  const loading = ref(false);
  const errorMessage = ref<string | null>(null);
  const scanResult = ref<number | null>(null);
  const isDev = import.meta.env.DEV;

  /**
   * 加载调度器状态
   */
  async function loadState() {
    loading.value = true;
    errorMessage.value = null;

    try {
      const result = await reminderSchedulerApi.getState();
      state.value = result;
    } catch (err) {
      errorMessage.value = err instanceof Error ? err.message : '加载状态失败';
      toast.error('加载调度器状态失败');
    } finally {
      loading.value = false;
    }
  }

  /**
   * 切换调度器状态
   */
  async function toggle() {
    if (!state.value) return;

    loading.value = true;
    errorMessage.value = null;

    try {
      if (state.value.isRunning) {
        await reminderSchedulerApi.stop();
        toast.success('调度器已停止');
      } else {
        await reminderSchedulerApi.start();
        toast.success('调度器已启动');
      }
      await loadState();
    } catch (err) {
      errorMessage.value = err instanceof Error ? err.message : '操作失败';
      toast.error(state.value.isRunning ? '停止调度器失败' : '启动调度器失败');
    } finally {
      loading.value = false;
    }
  }

  /**
   * 手动扫描
   */
  async function handleScan() {
    loading.value = true;
    errorMessage.value = null;
    scanResult.value = null;

    try {
      const count = await reminderSchedulerApi.scanNow();
      scanResult.value = count;

      if (count > 0) {
        toast.success(`扫描完成，已发送 ${count} 个提醒`);
      } else {
        toast.info('扫描完成，没有待发送的提醒');
      }

      await loadState();

      // 3秒后清除结果
      setTimeout(() => {
        scanResult.value = null;
      }, 3000);
    } catch (err) {
      errorMessage.value = err instanceof Error ? err.message : '扫描失败';
      toast.error('扫描提醒失败');
    } finally {
      loading.value = false;
    }
  }

  /**
   * 测试通知
   */
  async function handleTest() {
    loading.value = true;
    errorMessage.value = null;

    try {
      await reminderSchedulerApi.testNotification('测试通知', '这是一条来自提醒调度器的测试通知');
      toast.success('测试通知已发送');
    } catch (err) {
      errorMessage.value = err instanceof Error ? err.message : '测试失败';
      toast.error('发送测试通知失败');
    } finally {
      loading.value = false;
    }
  }

  /**
   * 格式化时间为 YYYY-MM-DD HH:mm:ss 格式
   */
  function formatTime(timeStr?: string): string {
    if (!timeStr) return '从未';

    try {
      const date = new Date(timeStr);
      const year = date.getFullYear();
      const month = String(date.getMonth() + 1).padStart(2, '0');
      const day = String(date.getDate()).padStart(2, '0');
      const hours = String(date.getHours()).padStart(2, '0');
      const minutes = String(date.getMinutes()).padStart(2, '0');
      const seconds = String(date.getSeconds()).padStart(2, '0');

      return `${year}-${month}-${day} ${hours}:${minutes}:${seconds}`;
    } catch {
      return timeStr;
    }
  }

  // 直接使用 computed 计算显示时间
  const displayTime = computed(() => formatTime(state.value?.lastScanAt));

  // 组件挂载时监听后端事件
  let unlistenReadyFn: (() => void) | null = null;
  let unlistenScanFn: (() => void) | null = null;
  let fallbackTimer: NodeJS.Timeout | null = null;

  onMounted(async () => {
    // 1. 监听后端调度器就绪事件
    try {
      unlistenReadyFn = await listen('scheduler-ready', () => {
        loadState();

        // 收到事件后清除兜底定时器
        if (fallbackTimer) {
          clearTimeout(fallbackTimer);
          fallbackTimer = null;
        }
      });
    } catch (err) {
      console.error('监听调度器就绪事件失败:', err);
    }

    // 2. 监听扫描完成事件（后端每次扫描后自动通知）
    try {
      unlistenScanFn = await listen('scheduler-scan-completed', () => {
        loadState();
      });
    } catch (err) {
      console.error('监听扫描完成事件失败:', err);
    }

    // 兜底机制：1.5秒后主动刷新状态（给后端足够初始化时间）
    fallbackTimer = setTimeout(() => {
      loadState();
    }, 1500);
  });

  // 清理监听器
  onUnmounted(() => {
    if (unlistenReadyFn) {
      unlistenReadyFn();
    }
    if (unlistenScanFn) {
      unlistenScanFn();
    }
    if (fallbackTimer) {
      clearTimeout(fallbackTimer);
    }
  });
</script>

<style scoped>
  /* 使用 Tailwind CSS */

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
    animation: fade-in 0.4s ease-out;
  }
</style>
