/**
 * 首次启动检测 Composable
 * @module composables/useFirstLaunch
 */

const FIRST_LAUNCH_KEY = 'app.first_launch_completed';
const NOTIFICATION_PERMISSION_ASKED_KEY = 'notification.permission_asked';

/**
 * 首次启动检测
 */
export function useFirstLaunch() {
  // ==================== 状态 ====================

  const isFirstLaunch = ref(false);
  const isPermissionAsked = ref(false);
  const loading = ref(true);
  const error = ref<string | null>(null);

  // ==================== 方法 ====================

  /**
   * 检查是否首次启动
   */
  async function checkFirstLaunch(): Promise<boolean> {
    loading.value = true;
    error.value = null;

    try {
      // 使用 localStorage 检查是否完成过首次启动
      const completed = localStorage.getItem(FIRST_LAUNCH_KEY) === 'true';
      isFirstLaunch.value = !completed;

      console.log('✅ 首次启动检测:', isFirstLaunch.value ? '是' : '否');
      return isFirstLaunch.value;
    } catch (err) {
      error.value = err instanceof Error ? err.message : '检查首次启动失败';
      console.error('❌ 检查首次启动失败:', err);
      return false;
    } finally {
      loading.value = false;
    }
  }

  /**
   * 标记首次启动已完成
   */
  async function markFirstLaunchCompleted(): Promise<void> {
    try {
      localStorage.setItem(FIRST_LAUNCH_KEY, 'true');
      isFirstLaunch.value = false;
      console.log('✅ 已标记首次启动完成');
    } catch (err) {
      error.value = err instanceof Error ? err.message : '标记首次启动失败';
      console.error('❌ 标记首次启动失败:', err);
      throw err;
    }
  }

  /**
   * 检查是否已请求过通知权限
   */
  async function checkPermissionAsked(): Promise<boolean> {
    try {
      const asked = localStorage.getItem(NOTIFICATION_PERMISSION_ASKED_KEY) === 'true';
      isPermissionAsked.value = asked;

      console.log('✅ 通知权限请求检测:', isPermissionAsked.value ? '已请求' : '未请求');
      return isPermissionAsked.value;
    } catch (err) {
      console.error('❌ 检查权限请求状态失败:', err);
      return false;
    }
  }

  /**
   * 标记已请求过通知权限
   */
  async function markPermissionAsked(): Promise<void> {
    try {
      localStorage.setItem(NOTIFICATION_PERMISSION_ASKED_KEY, 'true');
      isPermissionAsked.value = true;
      console.log('✅ 已标记通知权限请求');
    } catch (err) {
      console.error('❌ 标记权限请求状态失败:', err);
      throw err;
    }
  }

  /**
   * 重置首次启动状态（用于测试）
   */
  async function resetFirstLaunch(): Promise<void> {
    try {
      localStorage.removeItem(FIRST_LAUNCH_KEY);
      localStorage.removeItem(NOTIFICATION_PERMISSION_ASKED_KEY);

      isFirstLaunch.value = true;
      isPermissionAsked.value = false;
      console.log('✅ 已重置首次启动状态');
    } catch (err) {
      error.value = err instanceof Error ? err.message : '重置首次启动失败';
      console.error('❌ 重置首次启动失败:', err);
      throw err;
    }
  }

  /**
   * 清空错误
   */
  function clearError() {
    error.value = null;
  }

  // ==================== 生命周期 ====================

  onMounted(async () => {
    await checkFirstLaunch();
    await checkPermissionAsked();
  });

  // ==================== 返回 ====================

  return {
    // 状态
    isFirstLaunch,
    isPermissionAsked,
    loading,
    error,

    // 方法
    checkFirstLaunch,
    markFirstLaunchCompleted,
    checkPermissionAsked,
    markPermissionAsked,
    resetFirstLaunch,
    clearError,
  };
}

/**
 * 使用示例:
 *
 * ```vue
 * <script setup lang="ts">
 * import { useFirstLaunch } from '@/composables/useFirstLaunch';
 * import { useNotificationPermission } from '@/composables/useNotificationPermission';
 *
 * const firstLaunch = useFirstLaunch();
 * const permission = useNotificationPermission();
 *
 * // 在适当的时机显示权限引导
 * watch(
 *   () => firstLaunch.isFirstLaunch.value,
 *   async (isFirst) => {
 *     if (isFirst && !permission.hasPermission.value) {
 *       // 显示权限引导对话框
 *       showPermissionDialog.value = true;
 *     }
 *   }
 * );
 *
 * // 用户完成引导后
 * async function handleGuideComplete() {
 *   await firstLaunch.markFirstLaunchCompleted();
 *   await firstLaunch.markPermissionAsked();
 * }
 * </script>
 * ```
 */
