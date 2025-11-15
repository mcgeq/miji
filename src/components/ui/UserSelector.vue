<script setup lang="ts">
import { useUserSearch } from '@/composables/useUserSearch';
import type { User } from '@/schema/user';

interface Props {
  selectedUser?: User | null;
  placeholder?: string;
  disabled?: boolean;
}

interface Emits {
  select: [user: User];
  clear: [];
}

const props = withDefaults(defineProps<Props>(), {
  placeholder: '搜索用户姓名或邮箱',
  disabled: false,
});

const emit = defineEmits<Emits>();

const {
  searchQuery,
  filteredUsers,
  loading,
  error,
  selectedUser,
  selectUser,
  clearSelection,
  debouncedSearch,
  reset,
} = useUserSearch();

// 响应式状态
const showDropdown = ref(false);
const inputRef = ref<HTMLInputElement>();

// 监听搜索查询变化
watch(searchQuery, newQuery => {
  if (newQuery.trim()) {
    debouncedSearch();
    showDropdown.value = true;
  } else {
    showDropdown.value = false;
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
  if (searchQuery.value && !selectedUser.value) {
    showDropdown.value = true;
  }
}

// 处理输入框失焦
function handleInputBlur() {
  // 延迟关闭下拉框，以便点击选择生效
  setTimeout(() => {
    showDropdown.value = false;
  }, 200);
}

// 处理键盘导航
const highlightedIndex = ref(-1);

function handleKeyDown(event: KeyboardEvent) {
  if (!showDropdown.value || filteredUsers.value.length === 0) {
    return;
  }

  switch (event.key) {
    case 'ArrowDown':
      event.preventDefault();
      highlightedIndex.value = Math.min(
        highlightedIndex.value + 1,
        filteredUsers.value.length - 1,
      );
      break;
    case 'ArrowUp':
      event.preventDefault();
      highlightedIndex.value = Math.max(highlightedIndex.value - 1, -1);
      break;
    case 'Enter':
      event.preventDefault();
      if (highlightedIndex.value >= 0) {
        handleUserSelect(filteredUsers.value[highlightedIndex.value]);
      }
      break;
    case 'Escape':
      showDropdown.value = false;
      highlightedIndex.value = -1;
      break;
  }
}

// 重置高亮索引
watch(filteredUsers, () => {
  highlightedIndex.value = -1;
});

// 组件卸载时清理
onUnmounted(() => {
  reset();
});
</script>

<template>
  <div class="user-selector">
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
    <div v-if="showDropdown" class="dropdown">
      <!-- 加载状态 -->
      <div v-if="loading" class="dropdown-item loading-item">
        <LucideLoader2 class="w-4 h-4 animate-spin" />
        <span>搜索中...</span>
      </div>

      <!-- 用户列表 -->
      <div
        v-else-if="filteredUsers.length > 0"
        class="user-list"
      >
        <div
          v-for="(user, index) in filteredUsers"
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

          <div v-if="user.isVerified" class="verified-badge">
            <LucideShieldCheck class="w-4 h-4" />
          </div>
        </div>
      </div>

      <!-- 无结果 -->
      <div v-else class="dropdown-item no-results">
        <LucideUserX class="w-4 h-4" />
        <span>未找到用户</span>
      </div>
    </div>
  </div>
</template>

<style scoped>
.user-selector {
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
  max-height: 16rem;
  overflow-y: auto;
}

.dropdown-item {
  padding: 0.75rem;
  display: flex;
  align-items: center;
  gap: 0.5rem;
  color: #6b7280;
  font-size: 0.875rem;
}

.loading-item {
  justify-content: center;
}

.no-results {
  justify-content: center;
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
  width: 2rem;
  height: 2rem;
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
  font-size: 0.875rem;
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

.verified-badge {
  color: #10b981;
  flex-shrink: 0;
}
</style>
