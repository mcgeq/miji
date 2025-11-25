<script setup lang="ts">
import z from 'zod';
import BaseModal from '@/components/common/BaseModal.vue';
import BudgetAllocationEditor from '@/components/common/money/BudgetAllocationEditor.vue';
import { useBudgetForm } from '@/composables/useBudgetForm';
import { BudgetCreateSchema } from '@/schema/money';
import { useCategoryStore, useFamilyMemberStore } from '@/stores/money';
import { toast } from '@/utils/toast';
import BudgetFormFields from './BudgetFormFields.vue';
import type { Budget, BudgetCreate } from '@/schema/money';
import type { BudgetAllocationCreateRequest } from '@/types/budget-allocation';

interface Props {
  /** 家庭记账本序列号（必须） */
  familyLedgerSerialNum: string;
  /** 编辑模式下的预算数据 */
  budget?: Budget | null;
}

const props = defineProps<Props>();
const emit = defineEmits<{
  close: [];
  save: [budget: BudgetCreate, allocations: BudgetAllocationCreateRequest[]];
}>();

const categoryStore = useCategoryStore();
const familyMemberStore = useFamilyMemberStore();

// 使用共享的表单逻辑
const {
  form,
  colorNameMap,
  categoryError,
  isSubmitting,
  validationErrors,
  scopeTypes,
  isFormValid,
  handleCategoryValidation,
  handleRepeatPeriodValidation,
  handleRepeatPeriodChange,
  formatFormData,
} = useBudgetForm(props.budget);

// 成员预算分配配置（家庭预算特有）
const allocations = ref<BudgetAllocationCreateRequest[]>([]);
const showAllocationEditor = ref(false);
const editingAllocation = ref<BudgetAllocationCreateRequest | undefined>();

// 完整成员列表（用于显示已分配的成员名称）
const allMembers = computed(() =>
  familyMemberStore.members.map(m => ({
    serialNum: m.serialNum,
    name: m.name,
  })),
);

// 可用成员列表（只过滤"仅成员"分配，不过滤"成员+分类"组合）
const members = computed(() => {
  const allocatedMemberOnlyIds = new Set(
    allocations.value
      .filter(a => a.memberSerialNum && !a.categorySerialNum)
      .map(a => a.memberSerialNum),
  );

  if (editingAllocation.value?.memberSerialNum && !editingAllocation.value?.categorySerialNum) {
    allocatedMemberOnlyIds.delete(editingAllocation.value.memberSerialNum);
  }

  return familyMemberStore.members
    .filter(m => !allocatedMemberOnlyIds.has(m.serialNum))
    .map(m => ({
      serialNum: m.serialNum,
      name: m.name,
    }));
});

// 可用分类列表（只过滤"仅分类"分配，不过滤"成员+分类"组合）
const categories = computed(() => {
  const allocatedCategoryOnlyNames = new Set(
    allocations.value
      .filter(a => a.categorySerialNum && !a.memberSerialNum)
      .map(a => a.categorySerialNum),
  );

  if (editingAllocation.value?.categorySerialNum && !editingAllocation.value?.memberSerialNum) {
    allocatedCategoryOnlyNames.delete(editingAllocation.value.categorySerialNum);
  }

  return categoryStore.categories
    .filter(c => !allocatedCategoryOnlyNames.has(c.name))
    .map(c => ({
      serialNum: c.name,
      name: c.name,
    }));
});

// 已分配金额/百分比统计
const allocationsSummary = computed(() => {
  let totalFixed = 0;
  let totalPercentage = 0;

  allocations.value.forEach(alloc => {
    if (alloc.allocatedAmount !== undefined && alloc.allocatedAmount !== null) {
      const amount = Number(alloc.allocatedAmount);
      if (!Number.isNaN(amount)) {
        totalFixed += amount;
      }
    }
    if (alloc.percentage !== undefined && alloc.percentage !== null) {
      const percentage = Number(alloc.percentage);
      if (!Number.isNaN(percentage)) {
        totalPercentage += percentage;
      }
    }
  });

  return {
    totalFixed,
    totalPercentage,
    remainingFixed: Math.max(0, Number(form.amount) - totalFixed),
    remainingPercentage: Math.max(0, 100 - totalPercentage),
  };
});

// 提交表单
async function onSubmit() {
  if (!isFormValid.value) {
    toast.error('请完整填写预算信息');
    return;
  }

  if (isSubmitting.value) return;
  isSubmitting.value = true;

  try {
    // 使用共享的格式化函数
    const budgetData = formatFormData() as BudgetCreate;

    // 验证预算数据
    BudgetCreateSchema.parse(budgetData);

    // 发送创建事件，包含预算数据和分配配置
    emit('save', budgetData, allocations.value);
    closeModal();
  } catch (err: unknown) {
    if (err instanceof z.ZodError) {
      console.error('Validation failed:', err.issues);
      toast.error('数据验证失败，请检查输入');
    } else {
      console.error('Unexpected error:', err);
      toast.error('创建预算失败');
    }
  } finally {
    isSubmitting.value = false;
  }
}

// 添加分配
function handleAddAllocation() {
  editingAllocation.value = undefined;
  showAllocationEditor.value = true;
}

// 编辑分配
function handleEditAllocation(index: number) {
  editingAllocation.value = allocations.value[index];
  showAllocationEditor.value = true;
}

// 删除分配
function handleDeleteAllocation(index: number) {
  allocations.value.splice(index, 1);
}

// 保存分配
function handleSaveAllocation(data: BudgetAllocationCreateRequest) {
  if (editingAllocation.value) {
    const index = allocations.value.indexOf(editingAllocation.value);
    if (index !== -1) {
      allocations.value[index] = data;
    }
  } else {
    allocations.value.push(data);
  }
  showAllocationEditor.value = false;
  editingAllocation.value = undefined;
}

function closeModal() {
  emit('close');
}

// 初始化
onMounted(async () => {
  await Promise.all([
    familyMemberStore.fetchMembers(),
    categoryStore.fetchCategories(),
  ]);

  // 编辑模式：填充表单
  if (props.budget) {
    Object.assign(form, {
      ...props.budget,
      startDate: props.budget.startDate?.split('T')[0],
      endDate: props.budget.endDate?.split('T')[0],
    });
  }
});
</script>

<template>
  <BaseModal
    :title="props.budget ? '编辑家庭预算' : '创建家庭预算'"
    size="md"
    :confirm-loading="isSubmitting"
    :confirm-disabled="!isFormValid"
    @close="closeModal"
    @confirm="onSubmit"
  >
    <form class="family-budget-form" @submit.prevent="onSubmit">
      <!-- 基本信息 -->
      <div class="form-section">
        <h3 class="section-title">
          📋 基本信息
        </h3>

        <!-- 使用共享的表单字段组件 -->
        <BudgetFormFields
          :form="form"
          :color-names="colorNameMap"
          :scope-types="scopeTypes"
          :category-error="categoryError"
          :repeat-period-error="validationErrors.repeatPeriod"
          :show-account-selector="false"
          :is-family-budget="true"
          @validate-category="handleCategoryValidation"
          @validate-repeat-period="handleRepeatPeriodValidation"
          @change-repeat-period="handleRepeatPeriodChange"
        />
      </div>

      <!-- 成员预算分配 -->
      <div class="form-section">
        <div class="section-header">
          <h3 class="section-title">
            👥 成员预算分配（可选）
          </h3>
          <button
            type="button"
            class="btn-add-allocation"
            @click="handleAddAllocation"
          >
            + 添加分配
          </button>
        </div>

        <!-- 分配统计 -->
        <div v-if="allocations.length > 0" class="allocations-summary">
          <div class="summary-item">
            <span class="label">已分配金额：</span>
            <span class="value">¥{{ allocationsSummary.totalFixed.toFixed(2) }}</span>
            <span class="remaining">(剩余: ¥{{ allocationsSummary.remainingFixed.toFixed(2) }})</span>
          </div>
          <div class="summary-item">
            <span class="label">已分配百分比：</span>
            <span class="value">{{ allocationsSummary.totalPercentage.toFixed(1) }}%</span>
            <span class="remaining">(剩余: {{ allocationsSummary.remainingPercentage.toFixed(1) }}%)</span>
          </div>
        </div>

        <!-- 分配列表 -->
        <div v-if="allocations.length > 0" class="allocations-list">
          <div
            v-for="(allocation, index) in allocations"
            :key="index"
            class="allocation-item"
          >
            <div class="allocation-info">
              <span v-if="allocation.memberSerialNum" class="member-name">
                {{ allMembers.find(m => m.serialNum === allocation.memberSerialNum)?.name || '未知成员' }}
              </span>
              <span v-if="allocation.categorySerialNum" class="category-name">
                · {{ allocation.categorySerialNum }}
              </span>
              <span class="amount">
                {{ allocation.allocatedAmount
                  ? `¥${Number(allocation.allocatedAmount).toFixed(2)}`
                  : `${Number(allocation.percentage).toFixed(1)}%`
                }}
              </span>
            </div>
            <div class="allocation-actions">
              <button
                type="button"
                class="btn-icon btn-edit"
                @click="handleEditAllocation(index)"
              >
                ✏️
              </button>
              <button
                type="button"
                class="btn-icon btn-delete"
                @click="handleDeleteAllocation(index)"
              >
                🗑️
              </button>
            </div>
          </div>
        </div>

        <div v-else class="empty-allocations">
          <p>暂无成员预算分配，点击"添加分配"开始配置</p>
        </div>
      </div>
    </form>
  </BaseModal>

  <!-- 分配编辑器模态框 -->
  <BudgetAllocationEditor
    v-if="showAllocationEditor"
    :is-edit="!!editingAllocation"
    :allocation="editingAllocation as any"
    :members="members"
    :categories="categories"
    :budget-total="form.amount"
    @submit="handleSaveAllocation"
    @cancel="showAllocationEditor = false"
  />
</template>

<style scoped>
.family-budget-form {
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
}

/* 表单区块 */
.form-section {
  padding: 1rem;
  background: var(--color-base-200);
  border-radius: 0.75rem;
}

.section-title {
  font-size: 1rem;
  font-weight: 600;
  color: var(--color-base-content);
  margin-bottom: 1rem;
}

.section-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1rem;
}

.btn-add-allocation {
  padding: 0.5rem 1rem;
  background: var(--color-primary);
  color: white;
  border: none;
  border-radius: 0.5rem;
  font-size: 0.875rem;
  cursor: pointer;
  transition: all 0.2s;
}

.btn-add-allocation:hover {
  background: var(--color-primary-focus);
  transform: translateY(-1px);
}

/* 分配统计 */
.allocations-summary {
  padding: 1rem;
  background: var(--color-base-100);
  border-radius: 0.5rem;
  margin-bottom: 1rem;
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.summary-item {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.875rem;
}

.summary-item .label {
  color: var(--color-base-content);
  opacity: 0.7;
}

.summary-item .value {
  font-weight: 600;
  color: var(--color-primary);
}

.summary-item .remaining {
  color: var(--color-base-content);
  opacity: 0.6;
  font-size: 0.75rem;
}

/* 分配列表 */
.allocations-list {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.allocation-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0.75rem;
  background: var(--color-base-100);
  border-radius: 0.5rem;
  border: 1px solid var(--color-base-300);
  transition: all 0.2s;
}

.allocation-item:hover {
  border-color: var(--color-primary);
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

.allocation-info {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  flex: 1;
}

.member-name {
  font-weight: 600;
  color: var(--color-base-content);
}

.category-name {
  color: var(--color-base-content);
  opacity: 0.7;
  font-size: 0.875rem;
}

.amount {
  margin-left: auto;
  font-weight: 600;
  color: var(--color-primary);
}

.allocation-actions {
  display: flex;
  gap: 0.5rem;
}

.btn-icon {
  padding: 0.25rem 0.5rem;
  border: none;
  background: transparent;
  cursor: pointer;
  font-size: 1rem;
  transition: transform 0.2s;
}

.btn-icon:hover {
  transform: scale(1.2);
}

.empty-allocations {
  padding: 2rem;
  text-align: center;
  color: var(--color-base-content);
  opacity: 0.6;
  font-size: 0.875rem;
}
</style>
