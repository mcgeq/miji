/**
 * 用户偏好管理工具
 * 管理搜索历史、最近选择等本地偏好设置
 */

interface UserSearchPreferences {
  searchHistory: string[];
  recentSelections: string[]; // 用户ID列表
  maxHistoryItems: number;
  maxRecentItems: number;
  cacheEnabled: boolean;
  cacheDuration: number; // 毫秒
}

const DEFAULT_PREFERENCES: UserSearchPreferences = {
  searchHistory: [],
  recentSelections: [],
  maxHistoryItems: 10,
  maxRecentItems: 8,
  cacheEnabled: true,
  cacheDuration: 5 * 60 * 1000, // 5分钟
};

const STORAGE_KEYS = {
  SEARCH_HISTORY: 'user_search_history',
  RECENT_SELECTIONS: 'user_recent_selections',
  PREFERENCES: 'user_search_preferences',
} as const;

/**
 * 用户偏好管理器
 */
export class UserPreferencesManager {
  private preferences: UserSearchPreferences;

  constructor() {
    this.preferences = this.loadPreferences();
  }

  /**
   * 加载偏好设置
   */
  private loadPreferences(): UserSearchPreferences {
    try {
      const stored = localStorage.getItem(STORAGE_KEYS.PREFERENCES);
      if (stored) {
        const parsed = JSON.parse(stored);
        return { ...DEFAULT_PREFERENCES, ...parsed };
      }
    } catch (error) {
      console.warn('Failed to load user preferences:', error);
    }
    return { ...DEFAULT_PREFERENCES };
  }

  /**
   * 保存偏好设置
   */
  private savePreferences(): void {
    try {
      localStorage.setItem(STORAGE_KEYS.PREFERENCES, JSON.stringify(this.preferences));
    } catch (error) {
      console.warn('Failed to save user preferences:', error);
    }
  }

  /**
   * 获取搜索历史
   */
  getSearchHistory(): string[] {
    try {
      const stored = localStorage.getItem(STORAGE_KEYS.SEARCH_HISTORY);
      return stored ? JSON.parse(stored) : [];
    } catch {
      return [];
    }
  }

  /**
   * 添加搜索历史
   */
  addSearchHistory(query: string): void {
    if (!query.trim()) return;

    const history = this.getSearchHistory();
    const index = history.indexOf(query);

    // 如果已存在，移动到顶部
    if (index > -1) {
      history.splice(index, 1);
    }

    history.unshift(query);

    // 限制历史记录数量
    if (history.length > this.preferences.maxHistoryItems) {
      history.splice(this.preferences.maxHistoryItems);
    }

    try {
      localStorage.setItem(STORAGE_KEYS.SEARCH_HISTORY, JSON.stringify(history));
    } catch (error) {
      console.warn('Failed to save search history:', error);
    }
  }

  /**
   * 清空搜索历史
   */
  clearSearchHistory(): void {
    try {
      localStorage.removeItem(STORAGE_KEYS.SEARCH_HISTORY);
    } catch (error) {
      console.warn('Failed to clear search history:', error);
    }
  }

  /**
   * 获取最近选择的用户
   */
  getRecentSelections(): string[] {
    try {
      const stored = localStorage.getItem(STORAGE_KEYS.RECENT_SELECTIONS);
      return stored ? JSON.parse(stored) : [];
    } catch {
      return [];
    }
  }

  /**
   * 添加最近选择
   */
  addRecentSelection(userId: string): void {
    if (!userId) return;

    const recent = this.getRecentSelections();
    const index = recent.indexOf(userId);

    // 如果已存在，移动到顶部
    if (index > -1) {
      recent.splice(index, 1);
    }

    recent.unshift(userId);

    // 限制最近选择数量
    if (recent.length > this.preferences.maxRecentItems) {
      recent.splice(this.preferences.maxRecentItems);
    }

    try {
      localStorage.setItem(STORAGE_KEYS.RECENT_SELECTIONS, JSON.stringify(recent));
    } catch (error) {
      console.warn('Failed to save recent selections:', error);
    }
  }

  /**
   * 清空最近选择
   */
  clearRecentSelections(): void {
    try {
      localStorage.removeItem(STORAGE_KEYS.RECENT_SELECTIONS);
    } catch (error) {
      console.warn('Failed to clear recent selections:', error);
    }
  }

  /**
   * 更新偏好设置
   */
  updatePreferences(updates: Partial<UserSearchPreferences>): void {
    this.preferences = { ...this.preferences, ...updates };
    this.savePreferences();
  }

  /**
   * 获取偏好设置
   */
  getPreferences(): UserSearchPreferences {
    return { ...this.preferences };
  }

  /**
   * 重置所有偏好设置
   */
  resetAll(): void {
    this.clearSearchHistory();
    this.clearRecentSelections();
    this.preferences = { ...DEFAULT_PREFERENCES };
    this.savePreferences();
  }
}

// 单例实例
export const userPreferences = new UserPreferencesManager();

// 导出常用方法
export const {
  getSearchHistory,
  addSearchHistory,
  clearSearchHistory,
  getRecentSelections,
  addRecentSelection,
  clearRecentSelections,
  updatePreferences,
  getPreferences,
  resetAll,
} = userPreferences;
