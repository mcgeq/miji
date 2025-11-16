<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import BudgetAlertPanel from '@/components/common/money/BudgetAlertPanel.vue';
import BudgetAllocationCard from '@/components/common/money/BudgetAllocationCard.vue';
import BudgetAllocationEditor from '@/components/common/money/BudgetAllocationEditor.vue';
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
const budgetSerialNum = computed(() => route.query.budgetId as string || '');

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
      result = result.filter(a => !a.isWarning && !a.isExceeded);
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
      await budgetAllocationStore.updateAllocation(
        editingAllocation.value.serialNum,
        data,
      );
    } else {
      // 创建
      await budgetAllocationStore.createAllocation(
        budgetSerialNum.value,
        data,
      );
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
  const allocation = allocations.value.find(
    a => a.budgetSerialNum === alert.budgetSerialNum,
  );
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
</script>

<template>
  <div class="budget-allocations-page">
    <!-- 页面头部 -->
    <div class="page-header">
      <div class="header-content">
        <h1 class="page-title">
          预算分配管理
        </h1>
        <p class="page-description">
          家庭预算分配、超支控制和智能预警
        </p>
      </div>
      <div class="header-actions">
        <button class="btn-create" @click="showEditor = true">
          <span class="icon">➕</span>
          <span>创建分配</span>
        </button>
      </div>
    </div>

    <!-- 预警面板 -->
    <BudgetAlertPanel
      v-if="alerts.length > 0"
      class="alerts-container"
      :alerts="alerts"
      :show-clear-button="true"
      :show-stats="true"
      @view="handleViewAlert"
      @clear="handleClearAlerts"
    />

    <!-- 统计信息 -->
    <div class="stats-section">
      <div class="stat-card">
        <div class="stat-value">
          ¥{{ statistics.totalAllocated.toFixed(2) }}
        </div>
        <div class="stat-label">
          总分配
        </div>
      </div>
      <div class="stat-card">
        <div class="stat-value">
          ¥{{ statistics.totalUsed.toFixed(2) }}
        </div>
        <div class="stat-label">
          已使用
        </div>
      </div>
      <div class="stat-card">
        <div class="stat-value">
          {{ statistics.overallUsageRate.toFixed(1) }}%
        </div>
        <div class="stat-label">
          使用率
        </div>
      </div>
      <div class="stat-card exceeded">
        <div class="stat-value">
          {{ statistics.exceeded }}
        </div>
        <div class="stat-label">
          超支数
        </div>
      </div>
      <div class="stat-card warning">
        <div class="stat-value">
          {{ statistics.warning }}
        </div>
        <div class="stat-label">
          预警数
        </div>
      </div>
    </div>

    <!-- 筛选和排序 -->
    <div class="filters-section">
      <div class="section-header">
        <h2>分配列表</h2>
        <span class="count">共 {{ filteredAllocations.length }} 项</span>
      </div>
      <div class="filters">
        <select v-model="filter.status" class="filter-select">
          <option value="">
            全部状态
          </option>
          <option value="ACTIVE">
            活动中
          </option>
          <option value="PAUSED">
            已暂停
          </option>
          <option value="COMPLETED">
            已完成
          </option>
        </select>
        <select v-model="filter.alertStatus" class="filter-select">
          <option value="">
            全部预警
          </option>
          <option value="exceeded">
            已超支
          </option>
          <option value="warning">
            预警中
          </option>
          <option value="normal">
            正常
          </option>
        </select>
      </div>
    </div>

    <!-- 加载状态 -->
    <div v-if="loading" class="loading-container">
      <div class="loading-spinner" />
      <div class="loading-text">
        加载中...
      </div>
    </div>

    <!-- 错误状态 -->
    <div v-else-if="error" class="error-container">
      <div class="error-icon">
        ⚠️
      </div>
      <div class="error-message">
        {{ error }}
      </div>
      <button class="btn-retry" @click="loadData">
        重试
      </button>
    </div>

    <!-- 空状态 -->
    <div v-else-if="filteredAllocations.length === 0" class="empty-container">
      <div class="empty-icon">
        📊
      </div>
      <div class="empty-text">
        暂无预算分配
      </div>
      <div class="empty-subtitle">
        点击"创建分配"开始管理家庭预算
      </div>
      <button class="btn-create-empty" @click="showEditor = true">
        创建第一个分配
      </button>
    </div>

    <!-- 分配列表 -->
    <div v-else class="allocations-grid">
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
    <div v-if="showEditor" class="modal-overlay" @click.self="handleCancelEdit">
      <div class="modal-content">
        <div class="modal-header">
          <h3>{{ editingAllocation ? '编辑分配' : '创建分配' }}</h3>
          <button class="modal-close" @click="handleCancelEdit">
            ✕
          </button>
        </div>
        <div class="modal-body">
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
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.budget-allocations-page {
  max-width: 1400px;
  margin: 0 auto;
  padding: 24px;
}

/* 页面头部 */
.page-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 24px;
  padding-bottom: 20px;
  border-bottom: 1px solid var(--color-base-300);
}

.header-content {
  flex: 1;
}

.page-title {
  margin: 0 0 8px 0;
  font-size: 28px;
  font-weight: 700;
  color: var(--color-base-content);
}

.page-description {
  margin: 0;
  font-size: 14px;
  color: var(--color-neutral);
}

.header-actions {
  display: flex;
  gap: 12px;
}

.btn-create {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 10px 20px;
  background-color: var(--color-primary);
  color: var(--color-primary-content);
  border: none;
  border-radius: 8px;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
}

.btn-create:hover {
  background-color: var(--color-primary-hover);
  transform: translateY(-1px);
  box-shadow: var(--shadow-md);
}

.btn-create .icon {
  font-size: 16px;
}

/* 预警容器 */
.alerts-container {
  margin-bottom: 24px;
}

/* 统计信息 */
.stats-section {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 16px;
  margin-bottom: 24px;
}

.stat-card {
  background: var(--color-base-100);
  border: 1px solid var(--color-base-300);
  border-radius: 12px;
  padding: 20px;
  text-align: center;
  transition: all 0.2s;
}

.stat-card:hover {
  transform: translateY(-2px);
  box-shadow: var(--shadow-md);
}

.stat-card.exceeded {
  border-left: 4px solid var(--color-error);
}

.stat-card.warning {
  border-left: 4px solid var(--color-warning);
}

.stat-value {
  font-size: 32px;
  font-weight: 700;
  color: var(--color-base-content);
  margin-bottom: 8px;
}

.stat-card.exceeded .stat-value {
  color: var(--color-error);
}

.stat-card.warning .stat-value {
  color: var(--color-warning);
}

.stat-label {
  font-size: 12px;
  color: var(--color-neutral);
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

/* 筛选区域 */
.filters-section {
  margin-bottom: 20px;
}

.section-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 12px;
}

.section-header h2 {
  margin: 0;
  font-size: 20px;
  font-weight: 600;
  color: var(--color-base-content);
}

.count {
  font-size: 14px;
  color: var(--color-neutral);
}

.filters {
  display: flex;
  gap: 12px;
  flex-wrap: wrap;
}

.filter-select {
  padding: 8px 12px;
  background: var(--color-base-100);
  border: 1px solid var(--color-base-300);
  border-radius: 6px;
  font-size: 14px;
  color: var(--color-base-content);
  cursor: pointer;
  transition: border-color 0.2s;
}

.filter-select:hover {
  border-color: var(--color-neutral);
}

.filter-select:focus {
  outline: none;
  border-color: var(--color-primary);
}

/* 加载状态 */
.loading-container {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 64px 24px;
}

.loading-spinner {
  width: 48px;
  height: 48px;
  border: 4px solid var(--color-base-300);
  border-top-color: var(--color-primary);
  border-radius: 50%;
  animation: spin 1s linear infinite;
}

@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}

.loading-text {
  margin-top: 16px;
  font-size: 14px;
  color: var(--color-neutral);
}

/* 错误状态 */
.error-container {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 64px 24px;
  background: color-mix(in oklch, var(--color-error) 10%, var(--color-base-100));
  border: 1px solid var(--color-error);
  border-radius: 12px;
}

.error-icon {
  font-size: 48px;
  margin-bottom: 16px;
}

.error-message {
  font-size: 16px;
  color: var(--color-error);
  margin-bottom: 16px;
}

.btn-retry {
  padding: 8px 16px;
  background: var(--color-error);
  color: white;
  border: none;
  border-radius: 6px;
  cursor: pointer;
  transition: all 0.2s;
}

.btn-retry:hover {
  background: var(--color-error-hover);
}

/* 空状态 */
.empty-container {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 64px 24px;
  background: var(--color-base-100);
  border: 2px dashed var(--color-base-300);
  border-radius: 12px;
  text-align: center;
}

.empty-icon {
  font-size: 64px;
  margin-bottom: 16px;
  opacity: 0.5;
}

.empty-text {
  font-size: 18px;
  font-weight: 600;
  color: var(--color-base-content);
  margin-bottom: 8px;
}

.empty-subtitle {
  font-size: 14px;
  color: var(--color-neutral);
  margin-bottom: 24px;
}

.btn-create-empty {
  padding: 12px 24px;
  background: var(--color-primary);
  color: var(--color-primary-content);
  border: none;
  border-radius: 8px;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
}

.btn-create-empty:hover {
  background: var(--color-primary-hover);
}

/* 分配列表网格 */
.allocations-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(360px, 1fr));
  gap: 16px;
}

/* 模态框 */
.modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background-color: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
  padding: 20px;
}

.modal-content {
  background: var(--color-base-100);
  border-radius: 12px;
  max-width: 640px;
  width: 100%;
  max-height: 90vh;
  overflow-y: auto;
  box-shadow: var(--shadow-lg);
}

.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 20px 24px;
  border-bottom: 1px solid var(--color-base-300);
  position: sticky;
  top: 0;
  background: var(--color-base-100);
  z-index: 10;
}

.modal-header h3 {
  margin: 0;
  font-size: 20px;
  font-weight: 600;
  color: var(--color-base-content);
}

.modal-close {
  width: 32px;
  height: 32px;
  border: none;
  background: transparent;
  font-size: 20px;
  color: var(--color-neutral);
  cursor: pointer;
  border-radius: 6px;
  transition: all 0.2s;
  display: flex;
  align-items: center;
  justify-content: center;
}

.modal-close:hover {
  background-color: var(--color-base-200);
  color: var(--color-base-content);
}

.modal-body {
  padding: 24px;
}

/* 响应式 */
@media (max-width: 768px) {
  .budget-allocations-page {
    padding: 16px;
  }

  .page-header {
    flex-direction: column;
    gap: 16px;
  }

  .stats-section {
    grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
  }

  .allocations-grid {
    grid-template-columns: 1fr;
  }

  .modal-overlay {
    padding: 0;
  }

  .modal-content {
    max-height: 100vh;
    border-radius: 0;
  }
}
</style>
