<template>
  <div class="reminder-scheduler-settings">
    <div class="settings-header">
      <h3>提醒调度器</h3>
      <p class="description">管理系统提醒的自动扫描和发送</p>
    </div>

    <div v-if="loading" class="loading">
      <div class="spinner" />
      加载中...
    </div>

    <div v-else-if="errorMessage" class="error-message">
      {{ errorMessage }}
      <button @click="loadState" class="retry-btn">重试</button>
    </div>

    <div v-else-if="state" class="settings-content">
      <!-- 调度器状态 -->
      <div class="status-card">
        <div class="status-header">
          <div class="status-indicator" :class="{ active: state.isRunning }" />
          <span class="status-text"> {{ state.isRunning ? '运行中' : '已停止' }} </span>
        </div>

        <div class="status-info">
          <div class="info-item">
            <span class="label">上次扫描:</span>
            <span class="value">{{ formatTime(state.lastScanAt) }}</span>
          </div>
          <div class="info-item">
            <span class="label">待处理:</span>
            <span class="value">{{ state.pendingTasks }}个</span>
          </div>
          <div class="info-item">
            <span class="label">今日已执行:</span>
            <span class="value success">{{ state.executedToday }}个</span>
          </div>
          <div class="info-item">
            <span class="label">今日失败:</span>
            <span class="value error">{{ state.failedToday }}个</span>
          </div>
        </div>
      </div>

      <!-- 操作按钮 -->
      <div class="action-buttons">
        <button @click="toggle" :disabled="loading" class="btn-primary">
          {{ state.isRunning ? '停止调度器' : '启动调度器' }}
        </button>

        <button @click="handleScan" :disabled="loading || !state.isRunning" class="btn-secondary">
          立即扫描
        </button>

        <button @click="handleTest" :disabled="loading" class="btn-secondary">测试通知</button>

        <button @click="loadState" :disabled="loading" class="btn-text">刷新状态</button>
      </div>

      <!-- 扫描结果 -->
      <div v-if="scanResult !== null" class="scan-result">
        <div class="result-icon">✓</div>
        <span>扫描完成，找到 {{ scanResult }}个待发送提醒</span>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
  import { onMounted, ref } from 'vue';
  import { reminderSchedulerApi, type SchedulerState } from '@/api/reminderScheduler';
  import { toast } from '@/utils/toast';

  const state = ref<SchedulerState | null>(null);
  const loading = ref(false);
  const errorMessage = ref<string | null>(null);
  const scanResult = ref<number | null>(null);

  /**
   * 加载调度器状态
   */
  async function loadState() {
    loading.value = true;
    errorMessage.value = null;

    try {
      state.value = await reminderSchedulerApi.getState();
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
   * 格式化时间
   */
  function formatTime(timeStr?: string): string {
    if (!timeStr) return '从未';

    try {
      const date = new Date(timeStr);
      const now = new Date();
      const diff = now.getTime() - date.getTime();

      if (diff < 60000) return '刚刚';
      if (diff < 3600000) return `${Math.floor(diff / 60000)} 分钟前`;
      if (diff < 86400000) return `${Math.floor(diff / 3600000)} 小时前`;

      return date.toLocaleString('zh-CN', {
        month: '2-digit',
        day: '2-digit',
        hour: '2-digit',
        minute: '2-digit',
      });
    } catch {
      return timeStr;
    }
  }

  // 组件挂载时加载状态
  onMounted(() => {
    loadState();
  });
</script>

<style scoped>
  .reminder-scheduler-settings {
    padding: 24px;
    max-width: 800px;
  }

  .settings-header {
    margin-bottom: 24px;
  }

  .settings-header h3 {
    font-size: 20px;
    font-weight: 600;
    margin-bottom: 8px;
    color: var(--color-text-primary);
  }

  .description {
    font-size: 14px;
    color: var(--color-text-secondary);
  }

  /* 加载状态 */
  .loading {
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 48px;
    color: var(--color-text-secondary);
  }

  .spinner {
    width: 20px;
    height: 20px;
    border: 2px solid var(--color-border);
    border-top-color: var(--color-primary);
    border-radius: 50%;
    animation: spin 0.6s linear infinite;
    margin-right: 12px;
  }

  @keyframes spin {
    to {
      transform: rotate(360deg);
    }
  }

  /* 错误消息 */
  .error-message {
    padding: 16px;
    background: var(--color-error-bg);
    border: 1px solid var(--color-error-border);
    border-radius: 8px;
    color: var(--color-error);
    display: flex;
    align-items: center;
    justify-content: space-between;
  }

  .retry-btn {
    padding: 6px 12px;
    background: var(--color-error);
    color: white;
    border: none;
    border-radius: 4px;
    cursor: pointer;
    font-size: 14px;
  }

  /* 状态卡片 */
  .status-card {
    background: var(--color-bg-elevated);
    border: 1px solid var(--color-border);
    border-radius: 12px;
    padding: 20px;
    margin-bottom: 24px;
  }

  .status-header {
    display: flex;
    align-items: center;
    margin-bottom: 16px;
    padding-bottom: 16px;
    border-bottom: 1px solid var(--color-border);
  }

  .status-indicator {
    width: 12px;
    height: 12px;
    border-radius: 50%;
    background: var(--color-text-tertiary);
    margin-right: 12px;
  }

  .status-indicator.active {
    background: var(--color-success);
    box-shadow: 0 0 8px rgba(52, 211, 153, 0.4);
  }

  .status-text {
    font-size: 16px;
    font-weight: 500;
    color: var(--color-text-primary);
  }

  .status-info {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: 12px;
  }

  .info-item {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 8px 0;
  }

  .info-item .label {
    font-size: 14px;
    color: var(--color-text-secondary);
  }

  .info-item .value {
    font-size: 14px;
    font-weight: 500;
    color: var(--color-text-primary);
  }

  .info-item .value.success {
    color: var(--color-success);
  }

  .info-item .value.error {
    color: var(--color-error);
  }

  /* 操作按钮 */
  .action-buttons {
    display: flex;
    gap: 12px;
    margin-bottom: 24px;
  }

  .btn-primary,
  .btn-secondary,
  .btn-text {
    padding: 10px 20px;
    border-radius: 8px;
    font-size: 14px;
    font-weight: 500;
    cursor: pointer;
    transition: all 0.2s;
    border: none;
  }

  .btn-primary {
    background: var(--color-primary);
    color: white;
  }

  .btn-primary:hover:not(:disabled) {
    background: var(--color-primary-hover);
  }

  .btn-secondary {
    background: var(--color-bg-elevated);
    color: var(--color-text-primary);
    border: 1px solid var(--color-border);
  }

  .btn-secondary:hover:not(:disabled) {
    background: var(--color-bg-hover);
  }

  .btn-text {
    background: transparent;
    color: var(--color-primary);
  }

  .btn-text:hover:not(:disabled) {
    background: var(--color-bg-hover);
  }

  .btn-primary:disabled,
  .btn-secondary:disabled,
  .btn-text:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  /* 扫描结果 */
  .scan-result {
    display: flex;
    align-items: center;
    padding: 12px 16px;
    background: var(--color-success-bg);
    border: 1px solid var(--color-success-border);
    border-radius: 8px;
    color: var(--color-success);
    animation: fadeIn 0.3s;
  }

  .result-icon {
    width: 24px;
    height: 24px;
    display: flex;
    align-items: center;
    justify-content: center;
    background: var(--color-success);
    color: white;
    border-radius: 50%;
    margin-right: 12px;
    font-weight: bold;
  }

  @keyframes fadeIn {
    from {
      opacity: 0;
      transform: translateY(-10px);
    }
    to {
      opacity: 1;
      transform: translateY(0);
    }
  }
</style>
