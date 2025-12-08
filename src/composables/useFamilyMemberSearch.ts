import { debounce } from 'es-toolkit';
import { computed, ref } from 'vue';
import { invokeCommand } from '@/types/api';
import { userPreferences } from '@/utils/userPreferences';

// 家庭成员接口定义
export interface FamilyMember {
  serialNum: string;
  name: string;
  role: string;
  isPrimary: boolean;
  permissions: string;
  userId?: string;
  avatarUrl?: string;
  color?: string;
  totalPaid: number;
  totalOwed: number;
  balance: number;
  status: string;
  email?: string;
  phone?: string;
  createdAt: string;
  updatedAt?: string;
}

interface FamilyMemberSearchResponse {
  members: FamilyMember[];
  total: number;
  hasMore: boolean;
}

// 搜索结果缓存
const searchCache = new Map<string, { members: FamilyMember[]; timestamp: number }>();
const CACHE_DURATION = 5 * 60 * 1000; // 5分钟缓存

/**
 * 家庭成员搜索组合函数
 * 专门用于家庭记账本中的成员搜索和管理
 */
export function useFamilyMemberSearch() {
  // 状态
  const searchQuery = ref('');
  const members = ref<FamilyMember[]>([]);
  const recentMembers = ref<FamilyMember[]>([]);
  const loading = ref(false);
  const error = ref<string | null>(null);
  const selectedMember = ref<FamilyMember | null>(null);
  const searchHistory = ref<string[]>(
    JSON.parse(localStorage.getItem('familyMemberSearchHistory') || '[]'),
  );

  // 计算属性：过滤成员列表
  const filteredMembers = computed(() => {
    if (!searchQuery.value.trim()) return members.value;

    const query = searchQuery.value.toLowerCase();
    return members.value.filter(
      member =>
        member.name.toLowerCase().includes(query) ||
        member.email?.toLowerCase().includes(query) ||
        member.phone?.includes(query),
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
    localStorage.setItem('familyMemberSearchHistory', JSON.stringify(history));
  }

  /**
   * 使用搜索 API 获取结果
   */
  async function fetchWithSearchApi(searchTerm: string): Promise<FamilyMember[]> {
    const result = await invokeCommand<FamilyMemberSearchResponse>('search_family_members', {
      query: searchTerm.includes('@') ? { email: searchTerm } : { keyword: searchTerm },
      limit: 20,
    });
    return result.members || [];
  }

  /**
   * 使用列表 API + 前端过滤获取结果（降级方案）
   */
  async function fetchWithListApi(searchTerm: string): Promise<FamilyMember[]> {
    const allMembers = await invokeCommand<FamilyMember[]>('family_member_list');
    const queryLower = searchTerm.toLowerCase();
    return allMembers
      .filter(
        member =>
          member.name.toLowerCase().includes(queryLower) ||
          member.email?.toLowerCase().includes(queryLower) ||
          member.phone?.includes(searchTerm),
      )
      .slice(0, 20);
  }

  /**
   * 执行搜索并处理降级
   */
  async function executeSearch(searchTerm: string): Promise<FamilyMember[]> {
    try {
      return await fetchWithSearchApi(searchTerm);
    } catch {
      // 如果搜索API不可用，降级到列表API然后在前端过滤
      try {
        return await fetchWithListApi(searchTerm);
      } catch {
        error.value = '搜索功能暂不可用，请稍后重试。';
        return [];
      }
    }
  }

  /**
   * 搜索家庭成员
   */
  async function searchFamilyMembers(query?: string): Promise<void> {
    loading.value = true;
    error.value = null;

    try {
      const searchTerm = query || searchQuery.value.trim();

      if (!searchTerm) {
        members.value = recentMembers.value;
        return;
      }

      // 检查缓存
      const cacheKey = `search_${searchTerm}`;
      const cached = searchCache.get(cacheKey);
      if (cached && isCacheValid(cached.timestamp)) {
        members.value = cached.members;
        return;
      }

      // 保存搜索历史
      saveSearchHistory(searchTerm);

      // 执行搜索
      const searchResults = await executeSearch(searchTerm);
      members.value = searchResults;

      // 缓存结果
      if (searchResults.length > 0) {
        searchCache.set(cacheKey, {
          members: searchResults,
          timestamp: Date.now(),
        });
      }
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : '搜索家庭成员失败';
      error.value = message;
      members.value = [];
    } finally {
      loading.value = false;
    }
  }

  /**
   * 根据ID获取家庭成员
   */
  async function getFamilyMemberById(serialNum: string): Promise<FamilyMember | null> {
    try {
      loading.value = true;
      error.value = null;

      const member = await invokeCommand<FamilyMember>('family_member_get', {
        serial_num: serialNum,
      });
      return member;
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : '获取家庭成员信息失败';
      error.value = message;
      return null;
    } finally {
      loading.value = false;
    }
  }

  /**
   * 选择家庭成员
   */
  function selectFamilyMember(member: FamilyMember) {
    selectedMember.value = member;
    // 记录选择历史
    userPreferences.addRecentSelection(member.serialNum);
  }

  /**
   * 清除选择
   */
  function clearSelection() {
    selectedMember.value = null;
  }

  /**
   * 重置搜索状态
   */
  function reset() {
    searchQuery.value = '';
    members.value = [];
    error.value = null;
    selectedMember.value = null;
    loading.value = false;
  }

  /**
   * 设置搜索查询
   */
  function setSearchQuery(query: string): void {
    searchQuery.value = query;
  }

  /**
   * 加载最近创建的家庭成员
   */
  async function loadRecentFamilyMembers(): Promise<void> {
    try {
      const result = await invokeCommand<FamilyMember[]>('list_recent_family_members', {
        limit: 10,
        days_back: 30,
      });
      recentMembers.value = result || [];
      if (!searchQuery.value.trim()) {
        members.value = recentMembers.value;
      }
    } catch {
      // 如果 API 不存在，静默失败
      recentMembers.value = [];
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
    localStorage.removeItem('familyMemberSearchHistory');
  }

  /**
   * 防抖搜索 - 使用 es-toolkit 的 debounce
   */
  const debouncedSearch = debounce(searchFamilyMembers, 300);

  return {
    // 状态
    searchQuery,
    members,
    recentMembers,
    filteredMembers,
    loading,
    error,
    selectedMember,
    searchHistory,

    // 方法
    searchFamilyMembers,
    loadRecentFamilyMembers,
    getFamilyMemberById,
    selectFamilyMember,
    clearSelection,
    reset,
    setSearchQuery,
    debouncedSearch,
    clearSearchCache,
    clearSearchHistory,
  };
}
