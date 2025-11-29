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
  <div class="relative w-full">
    <!-- 输入框 -->
    <div class="relative flex items-center">
      <input
        ref="inputRef"
        v-model="searchQuery"
        type="text"
        class="w-full pr-10 pl-3 py-2 border rounded-md text-sm transition-all duration-200"
        :class="[
          selectedMember ? 'bg-sky-50 dark:bg-sky-950/30 border-sky-500 dark:border-sky-500' : '',
          error ? 'border-red-500 dark:border-red-500' : 'border-gray-300 dark:border-gray-600',
          disabled ? 'bg-gray-50 dark:bg-gray-900 text-gray-500 dark:text-gray-500 cursor-not-allowed' : 'bg-white dark:bg-gray-800 text-gray-900 dark:text-white',
          !disabled && !error && !selectedMember ? 'focus:outline-none focus:border-blue-500 focus:ring-3 focus:ring-blue-500/10' : '',
        ]"
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
        class="absolute right-2 p-1 text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-200 transition-colors z-10"
        @click="handleClear"
      >
        <LucideX class="w-4 h-4" />
      </button>

      <!-- 搜索图标 -->
      <LucideSearch
        v-else-if="!loading"
        class="absolute right-3 w-4 h-4 text-gray-500 dark:text-gray-400 pointer-events-none"
      />

      <!-- 加载状态 -->
      <div v-else class="absolute right-3 text-gray-500 dark:text-gray-400 pointer-events-none">
        <LucideLoader2 class="w-4 h-4 animate-spin" />
      </div>
    </div>

    <!-- 错误提示 -->
    <div v-if="error" class="mt-1 text-xs text-red-600 dark:text-red-400 whitespace-pre-line">
      {{ error }}
    </div>

    <!-- 下拉列表 -->
    <div
      v-if="showDropdown"
      ref="dropdownRef"
      class="absolute top-full left-0 right-0 z-50 mt-1 bg-white dark:bg-gray-800 border border-gray-300 dark:border-gray-700 rounded-lg shadow-xl max-h-80 overflow-y-auto"
      tabindex="-1"
    >
      <!-- 搜索历史 -->
      <div
        v-if="!searchQuery.trim() && props.showSearchHistory && searchHistory.length > 0"
        class="border-b border-gray-100 dark:border-gray-700"
      >
        <div class="p-2 px-3 flex items-center justify-between bg-gray-50 dark:bg-gray-800/50">
          <span class="text-xs font-semibold text-gray-600 dark:text-gray-400 uppercase tracking-wider">搜索历史</span>
          <button
            type="button"
            class="p-0.5 text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-200 transition-colors"
            @click="clearSearchHistory"
          >
            <LucideX class="w-3 h-3" />
          </button>
        </div>
        <div
          v-for="(historyItem, index) in searchHistory.slice(0, 5)"
          :key="`history-${index}`"
          class="py-2 px-3 flex items-center gap-2 cursor-pointer transition-colors text-sm text-gray-600 dark:text-gray-400"
          :class="[
            index + displayMembers.length === highlightedIndex ? 'bg-gray-100 dark:bg-gray-700/50' : 'hover:bg-gray-50 dark:hover:bg-gray-700/30',
          ]"
          @click="searchQuery = historyItem; debouncedSearch()"
        >
          <LucideHistory class="w-4 h-4" />
          <span>{{ historyItem }}</span>
        </div>
      </div>

      <!-- 最近成员 -->
      <div
        v-if="!searchQuery.trim() && props.showRecentMembers && recentMembers.length > 0"
        class="border-b border-gray-100 dark:border-gray-700"
      >
        <div class="p-2 px-3 bg-gray-50 dark:bg-gray-800/50">
          <span class="text-xs font-semibold text-gray-600 dark:text-gray-400 uppercase tracking-wider">最近成员</span>
        </div>
      </div>

      <!-- 加载状态 -->
      <div v-if="loading" class="p-3 flex items-center justify-center gap-2 text-gray-600 dark:text-gray-400 text-sm">
        <LucideLoader2 class="w-4 h-4 animate-spin" />
        <span>搜索中...</span>
      </div>

      <!-- 成员列表 -->
      <div v-else-if="displayMembers.length > 0" class="max-h-60 overflow-y-auto">
        <div
          v-for="(member, index) in displayMembers"
          :key="member.serialNum"
          class="p-3 flex items-center gap-3 cursor-pointer transition-colors border-b border-gray-100 dark:border-gray-700 last:border-b-0"
          :class="[
            index === highlightedIndex ? 'bg-gray-50 dark:bg-gray-700/50' : 'hover:bg-gray-50 dark:hover:bg-gray-700/50',
          ]"
          @click="handleMemberSelect(member)"
          @mouseenter="highlightedIndex = index"
        >
          <div class="w-10 h-10 rounded-full overflow-hidden shrink-0">
            <img
              v-if="member.avatarUrl"
              :src="member.avatarUrl"
              :alt="member.name"
              class="w-full h-full object-cover"
            >
            <div
              v-else
              class="w-full h-full flex items-center justify-center text-white font-semibold text-base"
              :style="{ backgroundColor: member.color || '#e5e7eb' }"
            >
              {{ member.name.charAt(0).toUpperCase() }}
            </div>
          </div>

          <div class="flex-1 min-w-0">
            <div class="font-medium text-gray-900 dark:text-white whitespace-nowrap overflow-hidden text-ellipsis flex items-center gap-2">
              {{ member.name }}
              <span v-if="member.isPrimary" class="bg-amber-100 dark:bg-amber-900/30 text-amber-700 dark:text-amber-400 text-[10px] font-semibold px-1.5 py-0.5 rounded">主要</span>
            </div>
            <div class="text-xs text-gray-600 dark:text-gray-400 whitespace-nowrap overflow-hidden text-ellipsis">
              <span v-if="member.email" class="member-email">{{ member.email }}</span>
              <span v-else-if="member.phone" class="member-phone">{{ member.phone }}</span>
              <span v-else class="member-id">ID: {{ member.serialNum.slice(-8) }}</span>
            </div>
          </div>

          <div class="flex items-center gap-2 shrink-0">
            <div
              class="text-[10px] font-medium px-1.5 py-0.5 rounded uppercase tracking-wider" :class="[
                member.role === 'Owner' ? 'bg-red-50 dark:bg-red-950/30 text-red-600 dark:text-red-400' : '',
                member.role === 'Admin' ? 'bg-blue-50 dark:bg-blue-950/30 text-blue-600 dark:text-blue-400' : '',
                member.role === 'Member' ? 'bg-green-50 dark:bg-green-950/30 text-green-600 dark:text-green-400' : '',
                member.role === 'Viewer' ? 'bg-slate-50 dark:bg-slate-900/30 text-slate-600 dark:text-slate-400' : '',
              ]"
            >
              {{ member.role }}
            </div>
            <div v-if="member.status === 'Active'" class="text-green-500 dark:text-green-400" title="活跃">
              <LucideCircle class="w-2 h-2 fill-current" />
            </div>
          </div>
        </div>
      </div>

      <!-- 无结果 -->
      <div v-else-if="searchQuery.trim()" class="p-3 flex items-center justify-center gap-2 text-gray-600 dark:text-gray-400 text-sm">
        <LucideUserX class="w-4 h-4" />
        <span>未找到成员</span>
      </div>

      <!-- 空状态提示 -->
      <div v-else class="p-3 flex items-center justify-center gap-2 text-gray-600 dark:text-gray-400 text-sm">
        <LucideUsers class="w-4 h-4" />
        <span>输入姓名或邮箱开始搜索</span>
      </div>
    </div>
  </div>
</template>
