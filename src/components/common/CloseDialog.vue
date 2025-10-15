<script setup lang="ts">
import { invoke } from '@tauri-apps/api/core';
import { listen } from '@tauri-apps/api/event';
import { toast } from '@/utils/toast';

const isVisible = ref(false);
const rememberChoice = ref(false);

// 监听来自Rust的关闭事件
onMounted(async () => {
  // 监听检查认证页面事件
  await listen('check-auth-page', () => {
    const currentPath = window.location.hash;

    // 检查是否为登录或注册页面
    const isAuthPage = currentPath.includes('/auth/login') || currentPath.includes('/auth/register');

    if (isAuthPage) {
      // 在登录/注册页面，直接关闭应用
      invoke('close_app');
    } else {
      // 不在登录/注册页面，检查用户偏好并处理
      handleCloseWithPreference();
    }
  });

  // 监听显示关闭对话框事件（保留兼容性）
  await listen('show-close-dialog', async () => {
    await handleCloseWithPreference();
  });
});

async function handleCloseWithPreference() {
  // 检查用户的关闭行为偏好
  try {
    const preference = await invoke('get_close_behavior_preference');

    if (preference === 'close') {
      // 用户偏好直接关闭
      await invoke('close_app');
      return;
    } else if (preference === 'minimize') {
      // 用户偏好最小化到托盘
      await invoke('minimize_to_tray');
      toast.info('应用已最小化到系统托盘');
      return;
    }
  } catch (error) {
    console.error('Failed to get close behavior preference:', error);
  }

  // 显示关闭对话框
  isVisible.value = true;
}

async function handleMinimizeToTray() {
  try {
    // 如果用户选择记住选择，保存偏好设置
    if (rememberChoice.value) {
      await invoke('set_close_behavior_preference', { preference: 'minimize' });
    }

    await invoke('minimize_to_tray');
    toast.info('应用已最小化到系统托盘');
    isVisible.value = false;
  } catch (error) {
    console.error('Failed to minimize to tray:', error);
    toast.error('最小化到托盘失败');
  }
}

async function handleCloseApp() {
  try {
    // 如果用户选择记住选择，保存偏好设置
    if (rememberChoice.value) {
      await invoke('set_close_behavior_preference', { preference: 'close' });
    }

    await invoke('close_app');
  } catch (error) {
    console.error('Failed to close app:', error);
    toast.error('关闭应用失败');
  }
}

function handleCancel() {
  isVisible.value = false;
}
</script>

<template>
  <div v-if="isVisible" class="dialog-overlay" @click="handleCancel">
    <div class="dialog-content" @click.stop>
      <div class="dialog-body">
        <div class="dialog-message">
          <p>选择关闭应用的方式：</p>
        </div>

        <div class="remember-choice">
          <label class="checkbox-label">
            <input
              v-model="rememberChoice"
              type="checkbox"
              class="checkbox-input"
            >
            <span class="checkbox-text">记住我的选择</span>
          </label>
        </div>

        <div class="dialog-actions">
          <button class="action-btn minimize-btn" title="最小化到托盘" @click="handleMinimizeToTray">
            <LucideMinimize2 :size="16" />
          </button>

          <button class="action-btn close-app-btn" title="关闭应用" @click="handleCloseApp">
            <LucideX :size="16" />
          </button>

          <button class="action-btn cancel-btn" title="取消" @click="handleCancel">
            <LucideX :size="16" />
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.dialog-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background-color: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 9999;
}

.dialog-content {
  background: var(--color-base-200);
  border-radius: 0.75rem;
  box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04);
  max-width: 400px;
  max-height: 90vh;
  overflow: hidden;
}

.dialog-header {
  display: flex;
  align-items: flex-start;
  justify-content: flex-end;
  padding: 1rem 1rem 0 1rem;
  position: relative;
}

.header-close-btn {
  background: none;
  border: none;
  padding: 0.5rem;
  border-radius: 0.375rem;
  cursor: pointer;
  color: var(--color-base-500);
  transition: all 0.2s ease;
  display: flex;
  align-items: center;
  justify-content: center;
}

.header-close-btn:hover {
  background-color: var(--color-base-100);
  color: var(--color-base-700);
}

.dialog-body {
  padding: 1.5rem;
}

.dialog-message {
  margin-bottom: 1rem;
  text-align: center;
}

.dialog-message p {
  margin: 0;
  color: var(--color-base-700);
  font-size: 0.875rem;
}

.remember-choice {
  margin-bottom: 1.5rem;
  display: flex;
  justify-content: center;
}

.checkbox-label {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  cursor: pointer;
  font-size: 0.875rem;
  color: var(--color-base-600);
}

.checkbox-input {
  width: 1rem;
  height: 1rem;
  accent-color: var(--color-primary-500);
}

.checkbox-text {
  user-select: none;
}

.dialog-actions {
  display: flex;
  flex-direction: row;
  gap: 0.5rem;
  justify-content: center;
  align-items: center;
}

.action-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  padding: 0.75rem 1rem;
  border-radius: 0.375rem;
  font-size: 0.875rem;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s ease;
  border: none;
  min-width: 5rem;
  height: 2.75rem;
}

.minimize-btn {
  background-color: var(--color-primary-500, #3b82f6);
  color: white;
}

.minimize-btn:hover {
  background-color: var(--color-primary-600, #2563eb);
}

.close-app-btn {
  background-color: var(--color-error-500, #ef4444);
  color: white;
}

.close-app-btn:hover {
  background-color: var(--color-error-600, #dc2626);
}

.cancel-btn {
  background-color: var(--color-base-300, #e5e7eb);
  color: var(--color-base-700, #374151);
}

.cancel-btn:hover {
  background-color: var(--color-base-300, #d1d5db);
}

@media (max-width: 480px) {
  .dialog-actions {
    flex-direction: column;
    gap: 0.5rem;
  }

  .action-btn {
    width: 100%;
  }
}
</style>
