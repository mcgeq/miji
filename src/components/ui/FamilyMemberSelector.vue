<script setup lang="ts">
import { computed, onUnmounted, ref, watch } from 'vue';
import { useFamilyMemberSearch } from '@/composables/useFamilyMemberSearch';
import type { FamilyMember } from '@/composables/useFamilyMemberSearch';

interface Props {
  selectedMember?: FamilyMember | null;
  placeholder?: string;
  disabled?: boolean;
  showRecentMembers?: boolean;
  showSearchHistory?: boolean;
}

interface Emits {
  select: [member: FamilyMember];
  clear: [];
}

const props = withDefaults(defineProps<Props>(), {
  placeholder: '搜索家庭成员姓名或邮箱',
  disabled: false,
  showRecentMembers: true,
  showSearchHistory: true,
});

const emit = defineEmits<Emits>();

const {
  searchQuery,
  members,
  recentMembers,
  loading,
  error,
  selectedMember,
  searchHistory,
  selectFamilyMember,
  clearSelection,
  debouncedSearch,
  loadRecentFamilyMembers,
  clearSearchHistory,
  reset,
} = useFamilyMemberSearch();

// 响应式状态
const showDropdown = ref(false);
const inputRef = ref<HTMLInputElement>();
const dropdownRef = ref<HTMLElement>();

// 当前显示的成员列表
const displayMembers = computed(() => {
  if (searchQuery.value.trim()) {
    return members.value;
  }
  if (props.showRecentMembers && recentMembers.value.length > 0) {
    return recentMembers.value;
  }
  return [];
});

// 监听搜索查询变化
watch(searchQuery, newQuery => {
  if (newQuery.trim()) {
    debouncedSearch();
    showDropdown.value = true;
  } else {
    showDropdown.value = !!displayMembers.value.length;
  }
});

// 监听外部选中成员变化
watch(() => props.selectedMember, newMember => {
  if (newMember) {
    selectFamilyMember(newMember);
    searchQuery.value = `${newMember.name} (${newMember.email || newMember.serialNum})`;
    showDropdown.value = false;
  } else {
    clearSelection();
    searchQuery.value = '';
  }
}, { immediate: true });

// 选择成员
function handleMemberSelect(member: FamilyMember) {
  selectFamilyMember(member);
  searchQuery.value = `${member.name} (${member.email || member.serialNum})`;
  showDropdown.value = false;
  emit('select', member);
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
  if (displayMembers.value.length > 0 || searchHistory.value.length > 0) {
    showDropdown.value = true;
  }
  // 加载最近成员
  if (props.showRecentMembers) {
    loadRecentFamilyMembers();
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

  const totalItems = displayMembers.value.length + (props.showSearchHistory ? searchHistory.value.length : 0);

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
        if (highlightedIndex.value < displayMembers.value.length) {
          handleMemberSelect(displayMembers.value[highlightedIndex.value]);
        } else {
          // 选择搜索历史
          const historyIndex = highlightedIndex.value - displayMembers.value.length;
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
watch([displayMembers, searchHistory], () => {
  highlightedIndex.value = -1;
});

// 组件卸载时清理
onUnmounted(() => {
  reset();
});
</script>

<template>
  <div class="family-member-selector">
    <!-- 输入框 -->
    <div class="input-container">
      <input
        ref="inputRef"
        v-model="searchQuery"
        type="text"
        class="member-input"
        :class="{
          'has-selection': selectedMember,
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
        v-if="selectedMember && !disabled"
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
          :class="{ highlighted: index + displayMembers.length === highlightedIndex }"
          @click="searchQuery = historyItem; debouncedSearch()"
        >
          <LucideHistory class="w-4 h-4" />
          <span>{{ historyItem }}</span>
        </div>
      </div>

      <!-- 最近成员 -->
      <div
        v-if="!searchQuery.trim() && props.showRecentMembers && recentMembers.length > 0"
        class="dropdown-section"
      >
        <div class="section-header">
          <span class="section-title">最近成员</span>
        </div>
      </div>

      <!-- 加载状态 -->
      <div v-if="loading" class="dropdown-item loading-item">
        <LucideLoader2 class="w-4 h-4 animate-spin" />
        <span>搜索中...</span>
      </div>

      <!-- 成员列表 -->
      <div v-else-if="displayMembers.length > 0" class="member-list">
        <div
          v-for="(member, index) in displayMembers"
          :key="member.serialNum"
          class="member-item"
          :class="{ highlighted: index === highlightedIndex }"
          @click="handleMemberSelect(member)"
          @mouseenter="highlightedIndex = index"
        >
          <div class="member-avatar">
            <img
              v-if="member.avatarUrl"
              :src="member.avatarUrl"
              :alt="member.name"
              class="avatar-image"
            >
            <div
              v-else
              class="avatar-placeholder"
              :style="{ backgroundColor: member.color || '#e5e7eb' }"
            >
              {{ member.name.charAt(0).toUpperCase() }}
            </div>
          </div>

          <div class="member-info">
            <div class="member-name">
              {{ member.name }}
              <span v-if="member.isPrimary" class="primary-badge">主要</span>
            </div>
            <div class="member-details">
              <span v-if="member.email" class="member-email">{{ member.email }}</span>
              <span v-else-if="member.phone" class="member-phone">{{ member.phone }}</span>
              <span v-else class="member-id">ID: {{ member.serialNum.slice(-8) }}</span>
            </div>
          </div>

          <div class="member-badges">
            <div class="role-badge" :class="`role-${member.role.toLowerCase()}`">
              {{ member.role }}
            </div>
            <div v-if="member.status === 'Active'" class="status-active" title="活跃">
              <LucideCircle class="w-2 h-2 fill-current" />
            </div>
          </div>
        </div>
      </div>

      <!-- 无结果 -->
      <div v-else-if="searchQuery.trim()" class="dropdown-item no-results">
        <LucideUserX class="w-4 h-4" />
        <span>未找到成员</span>
      </div>

      <!-- 空状态提示 -->
      <div v-else class="dropdown-item empty-state">
        <LucideUsers class="w-4 h-4" />
        <span>输入姓名或邮箱开始搜索</span>
      </div>
    </div>
  </div>
</template>

<style scoped>
.family-member-selector {
  position: relative;
  width: 100%;
}

.input-container {
  position: relative;
  display: flex;
  align-items: center;
}

.member-input {
  width: 100%;
  padding: 0.5rem 2.5rem 0.5rem 0.75rem;
  border: 1px solid #d1d5db;
  border-radius: 0.375rem;
  font-size: 0.875rem;
  transition: all 0.2s;
}

.member-input:focus {
  outline: none;
  border-color: #3b82f6;
  box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
}

.member-input.has-selection {
  background-color: #f0f9ff;
  border-color: #0ea5e9;
}

.member-input.is-error {
  border-color: #ef4444;
}

.member-input:disabled {
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

.member-list {
  max-height: 15rem;
  overflow-y: auto;
}

.member-item {
  padding: 0.75rem;
  display: flex;
  align-items: center;
  gap: 0.75rem;
  cursor: pointer;
  transition: background-color 0.2s;
  border-bottom: 1px solid #f3f4f6;
}

.member-item:last-child {
  border-bottom: none;
}

.member-item:hover,
.member-item.highlighted {
  background-color: #f9fafb;
}

.member-avatar {
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
  color: white;
  font-weight: 600;
  font-size: 1rem;
}

.member-info {
  flex: 1;
  min-width: 0;
}

.member-name {
  font-weight: 500;
  color: #1f2937;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.primary-badge {
  background-color: #fef3c7;
  color: #d97706;
  font-size: 0.625rem;
  font-weight: 600;
  padding: 0.125rem 0.375rem;
  border-radius: 0.25rem;
}

.member-details {
  font-size: 0.75rem;
  color: #6b7280;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.member-badges {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  flex-shrink: 0;
}

.role-badge {
  font-size: 0.625rem;
  font-weight: 500;
  padding: 0.125rem 0.375rem;
  border-radius: 0.25rem;
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.role-owner {
  background-color: #fef2f2;
  color: #dc2626;
}

.role-admin {
  background-color: #f0f9ff;
  color: #2563eb;
}

.role-member {
  background-color: #f0fdf4;
  color: #16a34a;
}

.role-viewer {
  background-color: #f8fafc;
  color: #64748b;
}

.status-active {
  color: #22c55e;
}
</style>
