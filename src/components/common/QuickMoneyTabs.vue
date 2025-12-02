<script setup lang="ts">
// Tab切换组件
type TabType = 'accounts' | 'transactions' | 'budgets' | 'reminders';

interface Props {
  activeTab: TabType;
}

defineProps<Props>();

const emit = defineEmits<{
  switch: [tab: TabType];
}>();
</script>

<template>
  <div class="flex gap-1 w-full border-b-2 border-gray-200 dark:border-gray-700 mb-3">
    <button
      class="flex-1 px-3 py-0.5 md:py-0.5 bg-transparent border-none cursor-pointer text-sm font-medium text-gray-700 dark:text-gray-300 opacity-60 hover:opacity-100 hover:bg-gray-100 dark:hover:bg-gray-700 transition-all relative rounded-t"
      :class="activeTab === 'accounts' ? 'opacity-100 text-gray-900 dark:text-white font-semibold after:content-[\'\'] after:absolute after:-bottom-0.5 after:left-0 after:right-0 after:h-0.5 after:bg-gray-900 dark:after:bg-white' : ''"
      @click="emit('switch', 'accounts')"
    >
      账户
    </button>
    <button
      class="flex-1 px-3 py-0.5 md:py-0.5 bg-transparent border-none cursor-pointer text-sm font-medium text-gray-700 dark:text-gray-300 opacity-60 hover:opacity-100 hover:bg-gray-100 dark:hover:bg-gray-700 transition-all relative rounded-t"
      :class="activeTab === 'transactions' ? 'opacity-100 text-gray-900 dark:text-white font-semibold after:content-[\'\'] after:absolute after:-bottom-0.5 after:left-0 after:right-0 after:h-0.5 after:bg-gray-900 dark:after:bg-white' : ''"
      @click="emit('switch', 'transactions')"
    >
      交易
    </button>
    <button
      class="flex-1 px-3 py-0.5 md:py-0.5 bg-transparent border-none cursor-pointer text-sm font-medium text-gray-700 dark:text-gray-300 opacity-60 hover:opacity-100 hover:bg-gray-100 dark:hover:bg-gray-700 transition-all relative rounded-t"
      :class="activeTab === 'budgets' ? 'opacity-100 text-gray-900 dark:text-white font-semibold after:content-[\'\'] after:absolute after:-bottom-0.5 after:left-0 after:right-0 after:h-0.5 after:bg-gray-900 dark:after:bg-white' : ''"
      @click="emit('switch', 'budgets')"
    >
      预算
    </button>
    <button
      class="flex-1 px-3 py-0.5 md:py-0.5 bg-transparent border-none cursor-pointer text-sm font-medium text-gray-700 dark:text-gray-300 opacity-60 hover:opacity-100 hover:bg-gray-100 dark:hover:bg-gray-700 transition-all relative rounded-t"
      :class="activeTab === 'reminders' ? 'opacity-100 text-gray-900 dark:text-white font-semibold after:content-[\'\'] after:absolute after:-bottom-0.5 after:left-0 after:right-0 after:h-0.5 after:bg-gray-900 dark:after:bg-white' : ''"
      @click="emit('switch', 'reminders')"
    >
      提醒
    </button>
  </div>
</template>
