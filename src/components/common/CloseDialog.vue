<script setup lang="ts">
import { invoke } from '@tauri-apps/api/core';
import { listen } from '@tauri-apps/api/event';
import { Checkbox } from '@/components/ui';
import { isDesktop } from '@/utils/platform';
import { toast } from '@/utils/toast';

const isVisible = ref(false);
const rememberChoice = ref(false);

// 平台检测
const isDesktopPlatform = ref(isDesktop());
const isMobile = ref(!isDesktop());

// 监听来自Rust的关闭事件
onMounted(async () => {
  // 监听检查认证页面事件
  await listen('check-auth-page', () => {
    const currentPath = window.location.hash;

    // 检查是否为登录或注册页面
    const isAuthPage = currentPath.includes('/auth/login') || currentPath.includes('/auth/register');

    if (isAuthPage || isMobile.value) {
      // 在登录/注册页面或移动端，直接关闭应用
      invoke('close_app');
    } else {
      // 不在登录/注册页面且非移动端，检查用户偏好并处理
      handleCloseWithPreference();
    }
  });

  // 监听显示关闭对话框事件（保留兼容性）
  await listen('show-close-dialog', async () => {
    if (isMobile.value) {
      // 移动端直接关闭应用
      await invoke('close_app');
    } else {
      await handleCloseWithPreference();
    }
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
      // 发送事件通知设置界面更新
      window.dispatchEvent(new CustomEvent('close-preference-changed', {
        detail: { preference: 'minimize' },
      }));
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
      // 发送事件通知设置界面更新
      window.dispatchEvent(new CustomEvent('close-preference-changed', {
        detail: { preference: 'close' },
      }));
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
  <!-- 使用 Transition 和现代化的对话框设计 -->
  <Teleport to="body">
    <Transition
      enter-active-class="duration-200 ease-out"
      enter-from-class="opacity-0"
      leave-active-class="duration-150 ease-in"
      leave-to-class="opacity-0"
    >
      <div v-if="isVisible" class="fixed inset-0 bg-black/60 backdrop-blur-sm z-[999999] flex items-center justify-center p-4" @click="handleCancel">
        <Transition
          enter-active-class="duration-200 ease-out"
          enter-from-class="opacity-0 scale-95"
          leave-active-class="duration-150 ease-in"
          leave-to-class="opacity-0 scale-95"
        >
          <div
            v-if="isVisible"
            class="bg-white dark:bg-gray-800 rounded-2xl shadow-2xl max-w-sm w-full overflow-hidden"
            @click.stop
          >
            <!-- 标题区 -->
            <div class="px-6 pt-6 pb-4 text-center">
              <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-2">
                关闭应用
              </h3>
              <p class="text-sm text-gray-600 dark:text-gray-400">
                选择您希望的操作
              </p>
            </div>

            <!-- 内容区 -->
            <div class="px-6 pb-6">
              <!-- 记住选择 -->
              <div class="mb-6 flex justify-center">
                <Checkbox
                  v-model="rememberChoice"
                  label="记住我的选择"
                />
              </div>

              <!-- 操作按钮 -->
              <div class="flex items-center justify-center gap-3">
                <!-- 最小化到托盘 -->
                <button
                  v-if="isDesktopPlatform"
                  class="flex items-center justify-center w-14 h-14 rounded-full bg-blue-600 hover:bg-blue-700 text-white transition-all hover:scale-110 active:scale-95"
                  title="最小化到托盘"
                  @click="handleMinimizeToTray"
                >
                  <LucideMinimize2 :size="22" />
                </button>

                <!-- 完全关闭 -->
                <button
                  class="flex items-center justify-center w-14 h-14 rounded-full bg-red-600 hover:bg-red-700 text-white transition-all hover:scale-110 active:scale-95"
                  title="完全关闭应用"
                  @click="handleCloseApp"
                >
                  <LucideCheckCheck :size="22" />
                </button>

                <!-- 取消 -->
                <button
                  class="flex items-center justify-center w-14 h-14 rounded-full bg-gray-100 hover:bg-gray-200 dark:bg-gray-700 dark:hover:bg-gray-600 text-gray-900 dark:text-white transition-all hover:scale-110 active:scale-95"
                  title="取消"
                  @click="handleCancel"
                >
                  <LucideX :size="22" />
                </button>
              </div>
            </div>
          </div>
        </Transition>
      </div>
    </Transition>
  </Teleport>
</template>
