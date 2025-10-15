import { invoke } from '@tauri-apps/api/core';

/**
 * 系统托盘相关功能
 */
export function useTray() {
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
