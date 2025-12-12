<script setup lang="ts">
  import QuickMoneyActions from '@/components/common/QuickMoneyActions.vue';
  import TodayPeriod from '@/components/common/TodayPeriod.vue';
  import type TodayTodos from '@/components/common/TodayTodos.vue';
  import { useAccountStore } from '@/stores/money';

  // Tab 类型定义
  type TabType = 'money' | 'period' | 'todos' | 'stats';

  // TodayTodos 组件暴露的方法接口
  interface TodayTodosExposed {
    openModal: () => void;
    getTodoCount: () => number;
  }

  // 当前激活的tab
  const activeTab = ref<TabType>('money');

  // Account store
  const accountStore = useAccountStore();

  // Tab配置
  const tabs = [
    { id: 'money' as TabType, label: '财务' },
    { id: 'period' as TabType, label: '经期' },
    { id: 'todos' as TabType, label: '待办' },
    { id: 'stats' as TabType, label: '统计' },
  ];

  // 切换tab
  function switchTab(tab: TabType) {
    activeTab.value = tab;
  }

  // 切换全局金额可见性
  function toggleGlobalAmountVisibility() {
    accountStore.toggleGlobalAmountHidden();
  }

  // 添加待办任务（从TodayTodos组件调用）
  const todayTodosRef = ref<InstanceType<typeof TodayTodos> & TodayTodosExposed>();

  function openTodoModal() {
    if (todayTodosRef.value) {
      todayTodosRef.value.openModal();
    }
  }

  // 获取待办任务数量
  const todoCount = computed(() => {
    return todayTodosRef.value?.getTodoCount?.() || 0;
  });
</script>

<template>
  <div class="flex flex-col w-full h-full min-h-0 overflow-hidden">
    <!-- Tab导航 -->
    <div
      class="flex items-center justify-center gap-2 md:gap-2 p-2 md:p-3 bg-gradient-to-br from-gray-50 to-gray-100 dark:from-gray-800 dark:to-gray-900 border-b border-gray-200/50 dark:border-gray-700/50 backdrop-blur-xl shadow-sm shrink-0 overflow-x-auto scrollbar-none"
    >
      <button
        v-for="tab in tabs"
        :key="tab.id"
        class="flex flex-col items-center justify-center gap-0.5 md:gap-1 px-3 py-2 md:px-5 md:py-3 min-w-10 md:min-w-14 shrink-0 bg-transparent border-none rounded-2xl cursor-pointer transition-all duration-300 text-gray-700 dark:text-gray-300 font-medium text-center backdrop-blur-sm relative"
        :class="activeTab === tab.id
          ? 'opacity-100 text-blue-600 dark:text-blue-400 bg-gradient-to-br from-blue-50 to-blue-100/50 dark:from-blue-900/20 dark:to-blue-800/10 font-semibold shadow-lg shadow-blue-500/20 -translate-y-0.5 border border-blue-200/50 dark:border-blue-700/50'
          : 'opacity-70 hover:opacity-100 hover:bg-blue-50/50 dark:hover:bg-blue-900/10 hover:-translate-y-0.5 hover:shadow-md hover:shadow-blue-500/10 hover:text-blue-600 dark:hover:text-blue-400'"
        @click="switchTab(tab.id)"
      >
        <span class="text-xs md:text-sm font-medium whitespace-nowrap leading-tight tracking-wide"
          >{{ tab.label }}</span
        >
        <!-- Active indicator -->
        <span
          v-if="activeTab === tab.id"
          class="absolute -bottom-1 left-1/2 -translate-x-1/2 w-8 h-0.5 bg-gradient-to-r from-blue-600 to-blue-400 rounded-full shadow-sm shadow-blue-500/30"
        />
      </button>

      <!-- 待办任务操作区域 - 只在待办tab激活时显示 -->
      <div v-if="activeTab === 'todos'" class="flex items-center gap-2 shrink-0 ml-2">
        <button
          class="flex items-center justify-center w-8 h-8 rounded-full bg-blue-600 hover:bg-blue-700 border-2 border-blue-500 cursor-pointer transition-all duration-300 text-white shadow-lg shadow-blue-500/30 hover:scale-110 hover:shadow-xl hover:shadow-blue-500/40 active:scale-95"
          aria-label="Add Todo"
          @click="openTodoModal"
        >
          <LucidePlus class="w-5 h-5 transition-transform duration-300" />
        </button>
        <span
          class="text-sm font-semibold text-blue-600 dark:text-blue-400 px-2 py-1 bg-blue-50 dark:bg-blue-900/30 rounded-lg border border-blue-200/50 dark:border-blue-700/50"
          >{{ todoCount }}</span
        >
      </div>
    </div>

    <!-- Tab内容 -->
    <div class="flex-1 overflow-hidden relative min-h-0">
      <div v-if="activeTab === 'money'" class="w-full h-full p-0.5 overflow-hidden flex flex-col">
        <QuickMoneyActions
          :show-amount-toggle="true"
          @toggle-amount-visibility="toggleGlobalAmountVisibility"
        />
      </div>
      <div v-if="activeTab === 'period'" class="w-full h-full p-0.5 overflow-hidden flex flex-col">
        <TodayPeriod />
      </div>
      <div
        v-if="activeTab === 'todos'"
        class="w-full h-full p-0.5 overflow-y-auto flex flex-col scrollbar-none"
      >
        <TodayTodos ref="todayTodosRef" />
      </div>
      <div v-if="activeTab === 'stats'" class="w-full h-full p-0.5 overflow-hidden flex flex-col">
        <div
          class="flex flex-col items-center justify-center h-full gap-4 text-gray-600 dark:text-gray-400 opacity-60 text-center"
        >
          <LucideBarChart3 class="w-12 h-12 opacity-50" />
          <h3 class="m-0 text-xl font-semibold">统计面板</h3>
          <p class="m-0 text-sm opacity-70">这里将显示数据统计信息</p>
        </div>
      </div>
    </div>
  </div>
</template>
