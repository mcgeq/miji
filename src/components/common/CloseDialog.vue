<script setup lang="ts">
import { invoke } from '@tauri-apps/api/core';
import { listen } from '@tauri-apps/api/event';
import { toast } from '@/utils/toast';

const isVisible = ref(false);

// 监听来自Rust的关闭事件
onMounted(async () => {
  await listen('show-close-dialog', () => {
    isVisible.value = true;
  });
});

async function handleMinimizeToTray() {
  try {
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
  gap: 0.25rem;
  padding: 0.5rem 0.75rem;
  border-radius: 0.375rem;
  font-size: 0.75rem;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s ease;
  border: none;
  min-width: 2.5rem;
  height: 2.5rem;
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
