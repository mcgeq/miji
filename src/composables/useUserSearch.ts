import { debounce } from 'es-toolkit';
import { computed, ref } from 'vue';
import type { User } from '@/schema/user';
import { invokeCommand } from '@/types/api';

// 搜索结果缓存
const searchCache = new Map<string, { users: User[]; timestamp: number }>();
const CACHE_DURATION = 5 * 60 * 1000; // 5分钟缓存

/**
 * 增强的用户搜索组合函数
 * 提供用户搜索、列表、选择、缓存等功能
 */
export function useUserSearch() {
  // 状态
  const searchQuery = ref('');
  const users = ref<User[]>([]);
  const recentUsers = ref<User[]>([]);
  const loading = ref(false);
  const error = ref<string | null>(null);
  const selectedUser = ref<User | null>(null);
  const searchHistory = ref<string[]>(
    JSON.parse(localStorage.getItem('userSearchHistory') || '[]'),
  );

  // 计算属性：过滤用户列表
  const filteredUsers = computed(() => {
    if (!searchQuery.value.trim()) return users.value;

    const query = searchQuery.value.toLowerCase();
    return users.value.filter(
      user => user.name.toLowerCase().includes(query) || user.email.toLowerCase().includes(query),
    );
  });

  /**
   * 检查缓存是否有效
   */
  function isCacheValid(timestamp: number): boolean {
    return Date.now() - timestamp < CACHE_DURATION;
  }

  /**
   * 保存搜索历史
   */
  function saveSearchHistory(query: string) {
    const history = searchHistory.value;
    const index = history.indexOf(query);
    if (index > -1) {
      history.splice(index, 1);
    }
    history.unshift(query);
    if (history.length > 10) {
      history.splice(10);
    }
    searchHistory.value = history;
    localStorage.setItem('userSearchHistory', JSON.stringify(history));
  }

  /**
   * 增强的用户搜索函数
   */
  async function searchUsers(query?: string): Promise<void> {
    loading.value = true;
    error.value = null;

    try {
      const searchTerm = query || searchQuery.value.trim();

      if (!searchTerm) {
        users.value = recentUsers.value;
        return;
      }

      // 检查缓存
      const cacheKey = `search_${searchTerm}`;
      const cached = searchCache.get(cacheKey);
      if (cached && isCacheValid(cached.timestamp)) {
        users.value = cached.users;
        return;
      }

      // 保存搜索历史
      saveSearchHistory(searchTerm);

      let searchResults: User[] = [];

      // 使用统一的搜索API
      try {
        const result = await invokeCommand<{ users: User[]; total: number; hasMore: boolean }>(
          'search_users',
          {
            query: searchTerm.includes('@') ? { email: searchTerm } : { keyword: searchTerm },
            limit: 20,
          },
        );
        searchResults = result.users || [];
      } catch (_err: any) {
        // 如果新API不存在，根据搜索类型降级
        if (searchTerm.includes('@')) {
          try {
            // 降级到邮箱精确查找
            const user = await invokeCommand<User>('get_user_with_email', {
              email: searchTerm,
            });
            searchResults = user ? [user] : [];
          } catch {
            searchResults = [];
          }
        } else {
          // 姓名搜索失败
          searchResults = [];
          error.value = '搜索功能暂不可用，请稍后重试。';
        }
      }

      users.value = searchResults;

      // 缓存结果
      if (searchResults.length > 0) {
        searchCache.set(cacheKey, {
          users: searchResults,
          timestamp: Date.now(),
        });
      }
    } catch (err: any) {
      error.value = err.message || '搜索用户失败';
      users.value = [];
    } finally {
      loading.value = false;
    }
  }

  /**
   * 根据ID获取用户
   */
  async function getUserById(serialNum: string): Promise<User | null> {
    try {
      loading.value = true;
      error.value = null;

      const user = await invokeCommand<User>('get_user', { serial_num: serialNum });
      return user;
    } catch (err: any) {
      error.value = err.message || '获取用户信息失败';
      return null;
    } finally {
      loading.value = false;
    }
  }

  /**
   * 选择用户
   */
  function selectUser(user: User): void {
    selectedUser.value = user;
  }

  /**
   * 清除选择
   */
  function clearSelection(): void {
    selectedUser.value = null;
  }

  /**
   * 重置状态
   */
  function reset(): void {
    searchQuery.value = '';
    users.value = [];
    selectedUser.value = null;
    error.value = null;
    loading.value = false;
  }

  /**
   * 设置搜索查询
   */
  function setSearchQuery(query: string): void {
    searchQuery.value = query;
  }

  /**
   * 加载最近活跃用户
   */
  async function loadRecentUsers(): Promise<void> {
    try {
      const result = await invokeCommand<User[]>('list_recent_users', {
        limit: 10,
        days_back: 30,
      });
      recentUsers.value = result || [];
      if (!searchQuery.value.trim()) {
        users.value = recentUsers.value;
      }
    } catch {
      // 如果 API 不存在，静默失败
      recentUsers.value = [];
    }
  }

  /**
   * 清空搜索缓存
   */
  function clearSearchCache(): void {
    searchCache.clear();
  }

  /**
   * 清空搜索历史
   */
  function clearSearchHistory(): void {
    searchHistory.value = [];
    localStorage.removeItem('userSearchHistory');
  }

  /**
   * 防抖搜索 - 使用 es-toolkit 的 debounce
   */
  const debouncedSearch = debounce(searchUsers, 300);

  return {
    // 状态
    searchQuery,
    users,
    recentUsers,
    filteredUsers,
    loading,
    error,
    selectedUser,
    searchHistory,

    // 方法
    searchUsers,
    loadRecentUsers,
    getUserById,
    selectUser,
    clearSelection,
    reset,
    setSearchQuery,
    debouncedSearch,
    clearSearchCache,
    clearSearchHistory,
  };
}
