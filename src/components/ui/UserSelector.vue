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
  watch(
    () => props.selectedUser,
    newUser => {
      if (newUser) {
        selectUser(newUser);
        searchQuery.value = `${newUser.name} (${newUser.email})`;
        showDropdown.value = false;
      } else {
        clearSelection();
        searchQuery.value = '';
      }
    },
    { immediate: true },
  );

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
  <div class="relative w-full">
    <!-- 输入框 -->
    <div class="relative flex items-center">
      <input
        ref="inputRef"
        v-model="searchQuery"
        type="text"
        class="w-full pr-10 pl-3 py-2 border rounded-md text-sm transition-all duration-200"
        :class="[
          selectedUser ? 'bg-sky-50 dark:bg-sky-950/30 border-sky-500 dark:border-sky-500' : '',
          error ? 'border-red-500 dark:border-red-500' : 'border-gray-300 dark:border-gray-600',
          disabled ? 'bg-gray-50 dark:bg-gray-900 text-gray-500 dark:text-gray-500 cursor-not-allowed' : 'bg-white dark:bg-gray-800 text-gray-900 dark:text-white',
          !disabled && !error && !selectedUser ? 'focus:outline-none focus:border-blue-500 focus:ring-3 focus:ring-blue-500/10' : '',
        ]"
        :placeholder="placeholder"
        :disabled="disabled"
        @focus="handleInputFocus"
        @blur="handleInputBlur"
        @keydown="handleKeyDown"
      />

      <!-- 清除按钮 -->
      <button
        v-if="selectedUser && !disabled"
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
    <div v-if="error" class="mt-1 text-xs text-red-600 dark:text-red-400">{{ error }}</div>

    <!-- 下拉列表 -->
    <div
      v-if="showDropdown"
      class="absolute top-full left-0 right-0 z-50 mt-1 bg-white dark:bg-gray-800 border border-gray-300 dark:border-gray-700 rounded-lg shadow-xl max-h-64 overflow-y-auto"
    >
      <!-- 加载状态 -->
      <div
        v-if="loading"
        class="p-3 flex items-center justify-center gap-2 text-gray-600 dark:text-gray-400 text-sm"
      >
        <LucideLoader2 class="w-4 h-4 animate-spin" />
        <span>搜索中...</span>
      </div>

      <!-- 用户列表 -->
      <div v-else-if="filteredUsers.length > 0" class="max-h-60 overflow-y-auto">
        <div
          v-for="(user, index) in filteredUsers"
          :key="user.serialNum"
          class="p-3 flex items-center gap-3 cursor-pointer transition-colors border-b border-gray-100 dark:border-gray-700 last:border-b-0"
          :class="[
            index === highlightedIndex ? 'bg-gray-50 dark:bg-gray-700/50' : 'hover:bg-gray-50 dark:hover:bg-gray-700/50',
          ]"
          @click="handleUserSelect(user)"
          @mouseenter="highlightedIndex = index"
        >
          <div class="w-8 h-8 rounded-full overflow-hidden shrink-0">
            <img
              v-if="user.avatarUrl"
              :src="user.avatarUrl"
              :alt="user.name"
              class="w-full h-full object-cover"
            />
            <div
              v-else
              class="w-full h-full bg-gray-200 dark:bg-gray-700 flex items-center justify-center text-gray-600 dark:text-gray-400 font-semibold text-sm"
            >
              {{ user.name.charAt(0).toUpperCase() }}
            </div>
          </div>

          <div class="flex-1 min-w-0">
            <div
              class="font-medium text-gray-900 dark:text-white whitespace-nowrap overflow-hidden text-ellipsis"
            >
              {{ user.name }}
            </div>
            <div
              class="text-xs text-gray-600 dark:text-gray-400 whitespace-nowrap overflow-hidden text-ellipsis"
            >
              {{ user.email }}
            </div>
          </div>

          <div v-if="user.isVerified" class="text-green-500 dark:text-green-400 shrink-0">
            <LucideShieldCheck class="w-4 h-4" />
          </div>
        </div>
      </div>

      <!-- 无结果 -->
      <div
        v-else
        class="p-3 flex items-center justify-center gap-2 text-gray-600 dark:text-gray-400 text-sm"
      >
        <LucideUserX class="w-4 h-4" />
        <span>未找到用户</span>
      </div>
    </div>
  </div>
</template>
