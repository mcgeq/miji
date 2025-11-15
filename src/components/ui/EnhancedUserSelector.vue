<script setup lang="ts">
import { useUserSearch } from '@/composables/useUserSearch';
import type { User } from '@/schema/user';

interface Props {
  selectedUser?: User | null;
  placeholder?: string;
  disabled?: boolean;
  showRecentUsers?: boolean;
  showSearchHistory?: boolean;
}

interface Emits {
  select: [user: User];
  clear: [];
}

const props = withDefaults(defineProps<Props>(), {
  placeholder: '输入完整邮箱地址搜索用户',
  disabled: false,
  showRecentUsers: true,
  showSearchHistory: true,
});

const emit = defineEmits<Emits>();

const {
  searchQuery,
  users,
  recentUsers,
  loading,
  error,
  selectedUser,
  searchHistory,
  selectUser,
  clearSelection,
  debouncedSearch,
  loadRecentUsers,
  clearSearchHistory,
  reset,
} = useUserSearch();

// 响应式状态
const showDropdown = ref(false);
const inputRef = ref<HTMLInputElement>();
const dropdownRef = ref<HTMLElement>();

// 当前显示的用户列表
const displayUsers = computed(() => {
  if (searchQuery.value.trim()) {
    return users.value;
  }
  if (props.showRecentUsers && recentUsers.value.length > 0) {
    return recentUsers.value;
  }
  return [];
});

// 监听搜索查询变化
watch(searchQuery, newQuery => {
  if (newQuery.trim()) {
    debouncedSearch();
    showDropdown.value = true;
  } else {
    showDropdown.value = !!displayUsers.value.length;
  }
});

// 监听外部选中用户变化
watch(() => props.selectedUser, newUser => {
  if (newUser) {
    selectUser(newUser);
    searchQuery.value = `${newUser.name} (${newUser.email})`;
    showDropdown.value = false;
  } else {
    clearSelection();
    searchQuery.value = '';
  }
}, { immediate: true });

// 选择用户
function handleUserSelect(user: User) {
  selectUser(user);
  searchQuery.value = `${user.name} (${user.email})`;
  showDropdown.value = false;
  emit('select', user);
}

// 清除选择
function handleClear() {
  clearSelection();
  searchQuery.value = '';
  showDropdown.value = false;
  emit('clear');
  inputRef.value?.focus();
}

// 处理输入框焦点
function handleInputFocus() {
  if (displayUsers.value.length > 0 || searchHistory.value.length > 0) {
    showDropdown.value = true;
  }
  // 加载最近用户
  if (props.showRecentUsers) {
    loadRecentUsers();
  }
}

// 处理输入框失焦
function handleInputBlur(event: FocusEvent) {
  // 如果焦点转移到下拉框内，不关闭
  if (dropdownRef.value?.contains(event.relatedTarget as Node)) {
    return;
  }
  // 延迟关闭下拉框，以便点击选择生效
  setTimeout(() => {
    showDropdown.value = false;
  }, 200);
}

// 处理键盘导航
const highlightedIndex = ref(-1);

function handleKeyDown(event: KeyboardEvent) {
  if (!showDropdown.value) return;

  const totalItems = displayUsers.value.length + (props.showSearchHistory ? searchHistory.value.length : 0);

  switch (event.key) {
    case 'ArrowDown':
      event.preventDefault();
      highlightedIndex.value = Math.min(highlightedIndex.value + 1, totalItems - 1);
      break;
    case 'ArrowUp':
      event.preventDefault();
      highlightedIndex.value = Math.max(highlightedIndex.value - 1, -1);
      break;
    case 'Enter':
      event.preventDefault();
      if (highlightedIndex.value >= 0) {
        if (highlightedIndex.value < displayUsers.value.length) {
          handleUserSelect(displayUsers.value[highlightedIndex.value]);
        } else {
          // 选择搜索历史
          const historyIndex = highlightedIndex.value - displayUsers.value.length;
          if (historyIndex < searchHistory.value.length) {
            searchQuery.value = searchHistory.value[historyIndex];
            debouncedSearch();
          }
        }
      }
      break;
    case 'Escape':
      showDropdown.value = false;
      highlightedIndex.value = -1;
      break;
  }
}

// 重置高亮索引
watch([displayUsers, searchHistory], () => {
  highlightedIndex.value = -1;
});

// 组件卸载时清理
onUnmounted(() => {
  reset();
});
</script>

<template>
  <div class="enhanced-user-selector">
    <!-- 输入框 -->
    <div class="input-container">
      <input
        ref="inputRef"
        v-model="searchQuery"
        type="text"
        class="user-input"
        :class="{
          'has-selection': selectedUser,
          'is-error': error,
        }"
        :placeholder="placeholder"
        :disabled="disabled"
        @focus="handleInputFocus"
        @blur="handleInputBlur"
        @keydown="handleKeyDown"
      >

      <!-- 清除按钮 -->
      <button
        v-if="selectedUser && !disabled"
        type="button"
        class="clear-btn"
        @click="handleClear"
      >
        <LucideX class="w-4 h-4" />
      </button>

      <!-- 搜索图标 -->
      <LucideSearch
        v-else-if="!loading"
        class="search-icon"
      />

      <!-- 加载状态 -->
      <div v-else class="loading-icon">
        <LucideLoader2 class="w-4 h-4 animate-spin" />
      </div>
    </div>

    <!-- 错误提示 -->
    <div v-if="error" class="error-message">
      {{ error }}
    </div>

    <!-- 下拉列表 -->
    <div
      v-if="showDropdown"
      ref="dropdownRef"
      class="dropdown"
      tabindex="-1"
    >
      <!-- 搜索历史 -->
      <div
        v-if="!searchQuery.trim() && props.showSearchHistory && searchHistory.length > 0"
        class="dropdown-section"
      >
        <div class="section-header">
          <span class="section-title">搜索历史</span>
          <button
            type="button"
            class="clear-history-btn"
            @click="clearSearchHistory"
          >
            <LucideX class="w-3 h-3" />
          </button>
        </div>
        <div
          v-for="(historyItem, index) in searchHistory.slice(0, 5)"
          :key="`history-${index}`"
          class="history-item"
          :class="{ highlighted: index + displayUsers.length === highlightedIndex }"
          @click="searchQuery = historyItem; debouncedSearch()"
        >
          <LucideHistory class="w-4 h-4" />
          <span>{{ historyItem }}</span>
        </div>
      </div>

      <!-- 最近用户 -->
      <div
        v-if="!searchQuery.trim() && props.showRecentUsers && recentUsers.length > 0"
        class="dropdown-section"
      >
        <div class="section-header">
          <span class="section-title">最近用户</span>
        </div>
      </div>

      <!-- 加载状态 -->
      <div v-if="loading" class="dropdown-item loading-item">
        <LucideLoader2 class="w-4 h-4 animate-spin" />
        <span>搜索中...</span>
      </div>

      <!-- 用户列表 -->
      <div v-else-if="displayUsers.length > 0" class="user-list">
        <div
          v-for="(user, index) in displayUsers"
          :key="user.serialNum"
          class="user-item"
          :class="{ highlighted: index === highlightedIndex }"
          @click="handleUserSelect(user)"
          @mouseenter="highlightedIndex = index"
        >
          <div class="user-avatar">
            <img
              v-if="user.avatarUrl"
              :src="user.avatarUrl"
              :alt="user.name"
              class="avatar-image"
            >
            <div v-else class="avatar-placeholder">
              {{ user.name.charAt(0).toUpperCase() }}
            </div>
          </div>

          <div class="user-info">
            <div class="user-name">
              {{ user.name }}
            </div>
            <div class="user-email">
              {{ user.email }}
            </div>
          </div>

          <div class="user-badges">
            <div v-if="user.isVerified" class="verified-badge" title="已验证用户">
              <LucideShieldCheck class="w-4 h-4" />
            </div>
            <div v-if="user.lastActiveAt" class="active-badge" title="最近活跃">
              <LucideCircle class="w-2 h-2 fill-current" />
            </div>
          </div>
        </div>
      </div>

      <!-- 无结果 -->
      <div v-else-if="searchQuery.trim()" class="dropdown-item no-results">
        <LucideUserX class="w-4 h-4" />
        <span>未找到用户</span>
      </div>

      <!-- 空状态提示 -->
      <div v-else class="dropdown-item empty-state">
        <LucideUsers class="w-4 h-4" />
        <span>输入邮箱地址开始搜索</span>
      </div>
    </div>
  </div>
</template>

<style scoped>
.enhanced-user-selector {
  position: relative;
  width: 100%;
}

.input-container {
  position: relative;
  display: flex;
  align-items: center;
}

.user-input {
  width: 100%;
  padding: 0.5rem 2.5rem 0.5rem 0.75rem;
  border: 1px solid #d1d5db;
  border-radius: 0.375rem;
  font-size: 0.875rem;
  transition: all 0.2s;
}

.user-input:focus {
  outline: none;
  border-color: #3b82f6;
  box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
}

.user-input.has-selection {
  background-color: #f0f9ff;
  border-color: #0ea5e9;
}

.user-input.is-error {
  border-color: #ef4444;
}

.user-input:disabled {
  background-color: #f9fafb;
  color: #6b7280;
  cursor: not-allowed;
}

.clear-btn {
  position: absolute;
  right: 0.5rem;
  padding: 0.25rem;
  color: #6b7280;
  transition: color 0.2s;
  z-index: 1;
}

.clear-btn:hover {
  color: #374151;
}

.search-icon, .loading-icon {
  position: absolute;
  right: 0.75rem;
  color: #6b7280;
  pointer-events: none;
}

.error-message {
  margin-top: 0.25rem;
  font-size: 0.75rem;
  color: #ef4444;
  white-space: pre-line;
}

.dropdown {
  position: absolute;
  top: 100%;
  left: 0;
  right: 0;
  z-index: 50;
  margin-top: 0.25rem;
  background: white;
  border: 1px solid #d1d5db;
  border-radius: 0.5rem;
  box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1);
  max-height: 20rem;
  overflow-y: auto;
}

.dropdown-section {
  border-bottom: 1px solid #f3f4f6;
}

.dropdown-section:last-child {
  border-bottom: none;
}

.section-header {
  padding: 0.5rem 0.75rem;
  display: flex;
  align-items: center;
  justify-content: space-between;
  background-color: #f9fafb;
}

.section-title {
  font-size: 0.75rem;
  font-weight: 600;
  color: #6b7280;
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.clear-history-btn {
  padding: 0.125rem;
  color: #6b7280;
  transition: color 0.2s;
}

.clear-history-btn:hover {
  color: #374151;
}

.dropdown-item {
  padding: 0.75rem;
  display: flex;
  align-items: center;
  gap: 0.5rem;
  color: #6b7280;
  font-size: 0.875rem;
}

.loading-item, .no-results, .empty-state {
  justify-content: center;
}

.history-item {
  padding: 0.5rem 0.75rem;
  display: flex;
  align-items: center;
  gap: 0.5rem;
  cursor: pointer;
  transition: background-color 0.2s;
  font-size: 0.875rem;
  color: #6b7280;
}

.history-item:hover,
.history-item.highlighted {
  background-color: #f3f4f6;
}

.user-list {
  max-height: 15rem;
  overflow-y: auto;
}

.user-item {
  padding: 0.75rem;
  display: flex;
  align-items: center;
  gap: 0.75rem;
  cursor: pointer;
  transition: background-color 0.2s;
  border-bottom: 1px solid #f3f4f6;
}

.user-item:last-child {
  border-bottom: none;
}

.user-item:hover,
.user-item.highlighted {
  background-color: #f9fafb;
}

.user-avatar {
  width: 2.5rem;
  height: 2.5rem;
  border-radius: 50%;
  overflow: hidden;
  flex-shrink: 0;
}

.avatar-image {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.avatar-placeholder {
  width: 100%;
  height: 100%;
  background-color: #e5e7eb;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #6b7280;
  font-weight: 600;
  font-size: 1rem;
}

.user-info {
  flex: 1;
  min-width: 0;
}

.user-name {
  font-weight: 500;
  color: #1f2937;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.user-email {
  font-size: 0.75rem;
  color: #6b7280;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.user-badges {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  flex-shrink: 0;
}

.verified-badge {
  color: #10b981;
}

.active-badge {
  color: #22c55e;
}
</style>
