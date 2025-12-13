<script setup lang="ts">
  import { useRoute } from 'vue-router';
  import BudgetAlertPanel from '@/components/common/money/BudgetAlertPanel.vue';
  import BudgetAllocationCard from '@/components/common/money/BudgetAllocationCard.vue';
  import BudgetAllocationEditor from '@/components/common/money/BudgetAllocationEditor.vue';
  import Button from '@/components/ui/Button.vue';
  import Modal from '@/components/ui/Modal.vue';
  import Select from '@/components/ui/Select.vue';
  import Spinner from '@/components/ui/Spinner.vue';
  import type { SelectOption } from '@/components/ui/types';
  import { useBudgetStore, useCategoryStore, useFamilyMemberStore } from '@/stores/money';
  import { useBudgetAllocationStore } from '@/stores/money/budget-allocation-store';
  import type {
    BudgetAlertResponse,
    BudgetAllocationCreateRequest,
    BudgetAllocationResponse,
  } from '@/types/budget-allocation';

  // Route
  const route = useRoute();

  // Stores
  const budgetAllocationStore = useBudgetAllocationStore();
  const budgetStore = useBudgetStore();
  const categoryStore = useCategoryStore();
  const familyMemberStore = useFamilyMemberStore();

  // State
  const showEditor = ref(false);
  const editingAllocation = ref<BudgetAllocationResponse | undefined>(undefined);
  const submitting = ref(false);
  const filter = ref({
    status: '' as string,
    alertStatus: '' as string,
  });

  // 从路由参数获取预算ID
  const budgetSerialNum = computed(() => (route.query.budgetId as string) || '');

  // 当前预算信息
  const currentBudget = computed(() => {
    if (!budgetSerialNum.value) return null;
    return budgetStore.budgets.find(b => b.serialNum === budgetSerialNum.value);
  });

  // 预算总金额
  const budgetTotal = computed(() => currentBudget.value?.amount || 0);

  // 成员列表（转换为组件需要的格式）
  const members = computed(() => {
    return familyMemberStore.members.map(m => ({
      serialNum: m.serialNum,
      name: m.name,
    }));
  });

  // 分类列表（转换为组件需要的格式）
  const categories = computed(() => {
    return categoryStore.categories.map(c => ({
      serialNum: c.name, // 使用name作为serialNum
      name: c.name,
    }));
  });

  // Computed
  const allocations = computed(() => budgetAllocationStore.allocationsByPriority);
  const alerts = computed(() => budgetAllocationStore.alerts);
  const statistics = computed(() => budgetAllocationStore.statistics);
  const loading = computed(() => budgetAllocationStore.loading);
  const error = computed(() => budgetAllocationStore.error);

  const filteredAllocations = computed(() => {
    let result = allocations.value;

    // 状态筛选
    if (filter.value.status) {
      result = result.filter(a => a.status === filter.value.status);
    }

    // 预警状态筛选
    if (filter.value.alertStatus) {
      if (filter.value.alertStatus === 'exceeded') {
        result = result.filter(a => a.isExceeded);
      } else if (filter.value.alertStatus === 'warning') {
        result = result.filter(a => a.isWarning && !a.isExceeded);
      } else if (filter.value.alertStatus === 'normal') {
        result = result.filter(a => !(a.isWarning || a.isExceeded));
      }
    }

    return result;
  });

  // Methods
  async function loadData() {
    if (!budgetSerialNum.value) {
      budgetAllocationStore.error = '请先选择一个预算';
      return;
    }

    try {
      // 并行加载所有数据
      await Promise.all([
        budgetAllocationStore.fetchAllocations(budgetSerialNum.value),
        budgetAllocationStore.checkAlerts(budgetSerialNum.value),
        budgetStore.fetchBudgetsPaged({
          currentPage: 1,
          pageSize: 100,
          sortOptions: { desc: true },
          filter: {},
        }),
        categoryStore.fetchCategories(),
        familyMemberStore.fetchMembers(),
      ]);
    } catch (err) {
      console.error('加载数据失败:', err);
    }
  }

  function handleEdit(allocation: BudgetAllocationResponse) {
    editingAllocation.value = allocation;
    showEditor.value = true;
  }

  async function handleDelete(allocation: BudgetAllocationResponse) {
    try {
      await budgetAllocationStore.deleteAllocation(allocation.serialNum);
      await loadData();
    } catch (err) {
      console.error('删除失败:', err);
    }
  }

  async function handleSubmit(data: BudgetAllocationCreateRequest) {
    submitting.value = true;

    try {
      if (editingAllocation.value) {
        // 更新
        await budgetAllocationStore.updateAllocation(editingAllocation.value.serialNum, data);
      } else {
        // 创建
        await budgetAllocationStore.createAllocation(budgetSerialNum.value, data);
      }

      // 关闭编辑器
      handleCancelEdit();

      // 重新加载
      await loadData();
    } catch (err) {
      console.error('提交失败:', err);
    } finally {
      submitting.value = false;
    }
  }

  function handleCancelEdit() {
    showEditor.value = false;
    editingAllocation.value = undefined;
  }

  function handleViewAlert(alert: BudgetAlertResponse) {
    // 跳转到对应的分配
    const allocation = allocations.value.find(a => a.budgetSerialNum === alert.budgetSerialNum);
    if (allocation) {
      handleEdit(allocation);
    }
  }

  function handleClearAlerts() {
    budgetAllocationStore.clearAlerts();
  }

  // Lifecycle
  onMounted(() => {
    loadData();
  });

  // 监听预算ID变化
  watch(budgetSerialNum, newId => {
    if (newId) {
      loadData();
    }
  });

  // 状态选项
  const statusOptions: SelectOption[] = [
    { value: '', label: '全部状态' },
    { value: 'ACTIVE', label: '活动中' },
    { value: 'PAUSED', label: '已暂停' },
    { value: 'COMPLETED', label: '已完成' },
  ];

  // 预警状态选项
  const alertStatusOptions: SelectOption[] = [
    { value: '', label: '全部预警' },
    { value: 'exceeded', label: '已超支' },
    { value: 'warning', label: '预警中' },
    { value: 'normal', label: '正常' },
  ];
</script>

<template>
  <div class="max-w-7xl mx-auto p-4 sm:p-6 lg:p-8">
    <!-- 页面头部 -->
    <div
      class="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-4 pb-5 sm:pb-6 mb-6 border-b border-gray-200 dark:border-gray-700"
    >
      <div class="flex-1 min-w-0">
        <h1 class="text-2xl sm:text-3xl font-bold text-gray-900 dark:text-white mb-2 truncate">
          预算分配管理
        </h1>
        <p class="text-sm text-gray-600 dark:text-gray-400">家庭预算分配、超支控制和智能预警</p>
      </div>
      <div class="flex items-center gap-3 shrink-0">
        <Button variant="primary" size="md" class="w-full sm:w-auto" @click="showEditor = true">
          <span class="hidden sm:inline">➕ 创建分配</span>
          <span class="sm:hidden">➕ 创建</span>
        </Button>
      </div>
    </div>

    <!-- 预警面板 -->
    <BudgetAlertPanel
      v-if="alerts.length > 0"
      class="mb-6"
      :alerts="alerts"
      :show-clear-button="true"
      :show-stats="true"
      @view="handleViewAlert"
      @clear="handleClearAlerts"
    />

    <!-- 统计信息 -->
    <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-5 gap-3 sm:gap-4 mb-6">
      <!-- 总分配 -->
      <div
        class="bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-xl p-4 sm:p-5 text-center transition-all hover:-translate-y-0.5 hover:shadow-lg"
      >
        <div class="text-2xl sm:text-3xl font-bold text-gray-900 dark:text-white mb-2">
          ¥{{ statistics.totalAllocated.toFixed(2) }}
        </div>
        <div class="text-xs uppercase tracking-wider text-gray-500 dark:text-gray-400">总分配</div>
      </div>

      <!-- 已使用 -->
      <div
        class="bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-xl p-4 sm:p-5 text-center transition-all hover:-translate-y-0.5 hover:shadow-lg"
      >
        <div class="text-2xl sm:text-3xl font-bold text-gray-900 dark:text-white mb-2">
          ¥{{ statistics.totalUsed.toFixed(2) }}
        </div>
        <div class="text-xs uppercase tracking-wider text-gray-500 dark:text-gray-400">已使用</div>
      </div>

      <!-- 使用率 -->
      <div
        class="bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-xl p-4 sm:p-5 text-center transition-all hover:-translate-y-0.5 hover:shadow-lg"
      >
        <div class="text-2xl sm:text-3xl font-bold text-gray-900 dark:text-white mb-2">
          {{ statistics.overallUsageRate.toFixed(1) }}%
        </div>
        <div class="text-xs uppercase tracking-wider text-gray-500 dark:text-gray-400">使用率</div>
      </div>

      <!-- 超支数 -->
      <div
        class="bg-white dark:bg-gray-800 border-l-4 border-l-red-500 border-r border-r-gray-200 dark:border-r-gray-700 border-t border-t-gray-200 dark:border-t-gray-700 border-b border-b-gray-200 dark:border-b-gray-700 rounded-xl p-4 sm:p-5 text-center transition-all hover:-translate-y-0.5 hover:shadow-lg"
      >
        <div class="text-2xl sm:text-3xl font-bold text-red-600 dark:text-red-400 mb-2">
          {{ statistics.exceeded }}
        </div>
        <div class="text-xs uppercase tracking-wider text-gray-500 dark:text-gray-400">超支数</div>
      </div>

      <!-- 预警数 -->
      <div
        class="bg-white dark:bg-gray-800 border-l-4 border-l-yellow-500 border-r border-r-gray-200 dark:border-r-gray-700 border-t border-t-gray-200 dark:border-t-gray-700 border-b border-b-gray-200 dark:border-b-gray-700 rounded-xl p-4 sm:p-5 text-center transition-all hover:-translate-y-0.5 hover:shadow-lg"
      >
        <div class="text-2xl sm:text-3xl font-bold text-yellow-600 dark:text-yellow-400 mb-2">
          {{ statistics.warning }}
        </div>
        <div class="text-xs uppercase tracking-wider text-gray-500 dark:text-gray-400">预警数</div>
      </div>
    </div>

    <!-- 筛选和排序 -->
    <div class="mb-5">
      <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 mb-3">
        <h2 class="text-lg sm:text-xl font-semibold text-gray-900 dark:text-white">分配列表</h2>
        <span class="text-sm text-gray-600 dark:text-gray-400">
          共 {{ filteredAllocations.length }}项
        </span>
      </div>
      <div class="flex flex-col sm:flex-row gap-3">
        <Select
          v-model="filter.status"
          :options="statusOptions"
          placeholder="全部状态"
          size="md"
          class="w-full sm:w-48"
        />
        <Select
          v-model="filter.alertStatus"
          :options="alertStatusOptions"
          placeholder="全部预警"
          size="md"
          class="w-full sm:w-48"
        />
      </div>
    </div>

    <!-- 加载状态 -->
    <div v-if="loading" class="flex flex-col items-center justify-center py-16 sm:py-20">
      <Spinner size="lg" variant="spin" color="primary" />
      <div class="mt-4 text-sm text-gray-600 dark:text-gray-400">加载中...</div>
    </div>

    <!-- 错误状态 -->
    <div
      v-else-if="error"
      class="flex flex-col items-center justify-center py-16 sm:py-20 px-4 bg-red-50 dark:bg-red-900/10 border border-red-200 dark:border-red-800 rounded-xl"
    >
      <div class="text-5xl sm:text-6xl mb-4">⚠️</div>
      <div class="text-base sm:text-lg text-red-600 dark:text-red-400 mb-4 text-center">
        {{ error }}
      </div>
      <Button variant="danger" size="md" @click="loadData">重试</Button>
    </div>

    <!-- 空状态 -->
    <div
      v-else-if="filteredAllocations.length === 0"
      class="flex flex-col items-center justify-center py-16 sm:py-20 px-4 bg-gray-50 dark:bg-gray-800/50 border-2 border-dashed border-gray-300 dark:border-gray-700 rounded-xl text-center"
    >
      <div class="text-5xl sm:text-6xl mb-4 opacity-50">📊</div>
      <div class="text-lg font-semibold text-gray-900 dark:text-white mb-2">暂无预算分配</div>
      <div class="text-sm text-gray-600 dark:text-gray-400 mb-6">
        点击"创建分配"开始管理家庭预算
      </div>
      <Button variant="primary" size="md" @click="showEditor = true">创建第一个分配</Button>
    </div>

    <!-- 分配列表 -->
    <div v-else class="grid grid-cols-1 lg:grid-cols-2 xl:grid-cols-3 gap-4">
      <BudgetAllocationCard
        v-for="allocation in filteredAllocations"
        :key="allocation.serialNum"
        :allocation="allocation"
        :show-actions="true"
        @edit="handleEdit"
        @delete="handleDelete"
      />
    </div>

    <!-- 编辑器模态框 -->
    <Modal
      :open="showEditor"
      :title="editingAllocation ? '编辑分配' : '创建分配'"
      size="lg"
      :show-footer="false"
      @close="handleCancelEdit"
    >
      <BudgetAllocationEditor
        :is-edit="!!editingAllocation"
        :allocation="editingAllocation"
        :members="members"
        :categories="categories"
        :budget-total="budgetTotal"
        :loading="submitting"
        @submit="handleSubmit"
        @cancel="handleCancelEdit"
      />
    </Modal>
  </div>
</template>
