/**
 * 通知权限管理 Composable
 * @module composables/useNotificationPermission
 * @description 管理通知权限的请求、检查和状态
 */

import { invoke } from '@tauri-apps/api/core';
import type { NotificationPermission } from '@/types/notification';

/**
 * 通知权限管理
 */
export function useNotificationPermission() {
  // ==================== 状态 ====================

  const permission = ref<NotificationPermission>({
    granted: false,
    supported: true,
    requesting: false,
  });

  const checking = ref(false);
  const error = ref<string | null>(null);

  // ==================== 计算属性 ====================

  /**
   * 是否已授予权限
   */
  const hasPermission = computed(() => permission.value.granted);

  /**
   * 是否支持通知
   */
  const isSupported = computed(() => permission.value.supported);

  /**
   * 是否正在处理
   */
  const isProcessing = computed(() => permission.value.requesting || checking.value);

  /**
   * 权限状态文本
   */
  const statusText = computed(() => {
    if (!permission.value.supported) {
      return '当前设备不支持通知';
    }
    if (permission.value.granted) {
      return '通知权限已授予';
    }
    return '通知权限未授予';
  });

  /**
   * 权限状态颜色
   */
  const statusColor = computed(() => {
    if (!permission.value.supported) {
      return 'gray';
    }
    if (permission.value.granted) {
      return 'green';
    }
    return 'orange';
  });

  // ==================== 方法 ====================

  /**
   * 检查通知权限
   */
  async function checkPermission(): Promise<boolean> {
    checking.value = true;
    error.value = null;

    try {
      const granted = await invoke<boolean>('check_notification_permission');
      permission.value.granted = granted;
      console.log('✅ 通知权限检查完成:', granted);
      return granted;
    } catch (err) {
      console.error('❌ 检查通知权限失败:', err);
      error.value = err instanceof Error ? err.message : String(err);
      permission.value.supported = false;
      return false;
    } finally {
      checking.value = false;
    }
  }

  /**
   * 请求通知权限
   */
  async function requestPermission(): Promise<boolean> {
    if (permission.value.granted) {
      console.log('✅ 已有通知权限，无需重复请求');
      return true;
    }

    permission.value.requesting = true;
    error.value = null;

    try {
      const granted = await invoke<boolean>('request_notification_permission');
      permission.value.granted = granted;

      if (granted) {
        console.log('✅ 通知权限请求成功');
      } else {
        console.warn('⚠️ 用户拒绝了通知权限');
      }

      return granted;
    } catch (err) {
      console.error('❌ 请求通知权限失败:', err);
      error.value = err instanceof Error ? err.message : String(err);
      return false;
    } finally {
      permission.value.requesting = false;
    }
  }

  /**
   * 打开系统通知设置
   */
  async function openSettings(): Promise<void> {
    try {
      await invoke('open_notification_settings');
      console.log('✅ 已打开系统通知设置');
    } catch (err) {
      console.error('❌ 打开系统设置失败:', err);
      error.value = err instanceof Error ? err.message : String(err);

      // 桌面端可能不支持，给出友好提示
      if (String(err).includes('桌面端不支持')) {
        error.value = '桌面端请在系统设置中手动配置通知权限';
      }
    }
  }

  /**
   * 重置错误状态
   */
  function clearError(): void {
    error.value = null;
  }

  // ==================== 生命周期 ====================

  /**
   * 组件挂载时自动检查权限
   */
  onMounted(async () => {
    await checkPermission();
  });

  // ==================== 返回 ====================

  return {
    // 状态
    permission,
    checking,
    error,

    // 计算属性
    hasPermission,
    isSupported,
    isProcessing,
    statusText,
    statusColor,

    // 方法
    checkPermission,
    requestPermission,
    openSettings,
    clearError,
  };
}

/**
 * 使用示例:
 *
 * ```vue
 * <script setup lang="ts">
 * import { useNotificationPermission } from '@/composables/useNotificationPermission';
 *
 * const {
 *   hasPermission,
 *   statusText,
 *   statusColor,
 *   requestPermission,
 *   openSettings,
 * } = useNotificationPermission();
 * </script>
 *
 * <template>
 *   <div>
 *     <Badge :color="statusColor">{{ statusText }}</Badge>
 *     <Button v-if="!hasPermission" @click="requestPermission">
 *       授予权限
 *     </Button>
 *     <Button @click="openSettings">打开设置</Button>
 *   </div>
 * </template>
 * ```
 */
