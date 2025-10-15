import { invoke } from '@tauri-apps/api/core';
import { isDesktop } from '@/utils/platform';

/**
 * 系统托盘相关功能
 * 仅在桌面端可用
 */
export function useTray() {
  // 检查是否为桌面端
  if (!isDesktop()) {
    console.warn('useTray: 系统托盘功能仅在桌面端可用');
    return {
      minimizeToTray: async () => {
        console.warn('系统托盘功能仅在桌面端可用');
      },
      restoreFromTray: async () => {
        console.warn('系统托盘功能仅在桌面端可用');
      },
      toggleWindowVisibility: async () => {
        console.warn('系统托盘功能仅在桌面端可用');
      },
    };
  }
  /**
   * 最小化到系统托盘
   */
  const minimizeToTray = async () => {
    try {
      await invoke('minimize_to_tray');
    } catch (error) {
      console.error('Failed to minimize to tray:', error);
    }
  };

  /**
   * 从系统托盘恢复窗口
   */
  const restoreFromTray = async () => {
    try {
      await invoke('restore_from_tray');
    } catch (error) {
      console.error('Failed to restore from tray:', error);
    }
  };

  /**
   * 切换窗口显示状态
   */
  const toggleWindowVisibility = async () => {
    try {
      await invoke('toggle_window_visibility');
    } catch (error) {
      console.error('Failed to toggle window visibility:', error);
    }
  };

  return {
    minimizeToTray,
    restoreFromTray,
    toggleWindowVisibility,
  };
}
