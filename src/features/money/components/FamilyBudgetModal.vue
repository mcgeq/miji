<script setup lang="ts">
import z from 'zod';
import BudgetAllocationEditor from '@/components/common/money/BudgetAllocationEditor.vue';
import { Button, Modal } from '@/components/ui';
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
  <Modal
    :open="true"
    :title="props.budget ? '编辑家庭预算' : '创建家庭预算'"
    size="md"
    :confirm-loading="isSubmitting"
    :confirm-disabled="!isFormValid"
    @close="closeModal"
    @confirm="onSubmit"
  >
    <form class="flex flex-col gap-6" @submit.prevent="onSubmit">
      <!-- 基本信息 -->
      <div class="p-4 bg-gray-50 dark:bg-gray-900/50 rounded-xl">
        <h3 class="text-base font-semibold text-gray-900 dark:text-white mb-4">
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
      <div class="p-4 bg-gray-50 dark:bg-gray-900/50 rounded-xl">
        <div class="flex justify-between items-center mb-4">
          <h3 class="text-base font-semibold text-gray-900 dark:text-white">
            👥 成员预算分配（可选）
          </h3>
          <Button
            type="button"
            variant="primary"
            size="sm"
            @click="handleAddAllocation"
          >
            + 添加分配
          </Button>
        </div>

        <!-- 分配统计 -->
        <div v-if="allocations.length > 0" class="p-4 bg-white dark:bg-gray-800 rounded-lg mb-4 flex flex-col gap-2">
          <div class="flex items-center gap-2 text-sm">
            <span class="text-gray-600 dark:text-gray-400">已分配金额：</span>
            <span class="font-semibold text-blue-600 dark:text-blue-400">¥{{ allocationsSummary.totalFixed.toFixed(2) }}</span>
            <span class="text-gray-500 dark:text-gray-500 text-xs">(剩余: ¥{{ allocationsSummary.remainingFixed.toFixed(2) }})</span>
          </div>
          <div class="flex items-center gap-2 text-sm">
            <span class="text-gray-600 dark:text-gray-400">已分配百分比：</span>
            <span class="font-semibold text-blue-600 dark:text-blue-400">{{ allocationsSummary.totalPercentage.toFixed(1) }}%</span>
            <span class="text-gray-500 dark:text-gray-500 text-xs">(剩余: {{ allocationsSummary.remainingPercentage.toFixed(1) }}%)</span>
          </div>
        </div>

        <!-- 分配列表 -->
        <div v-if="allocations.length > 0" class="flex flex-col gap-3">
          <div
            v-for="(allocation, index) in allocations"
            :key="index"
            class="flex justify-between items-center p-3 bg-white dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-700 transition-all hover:border-blue-500 hover:shadow-sm"
          >
            <div class="flex items-center gap-2 flex-1">
              <span v-if="allocation.memberSerialNum" class="font-semibold text-gray-900 dark:text-white">
                {{ allMembers.find(m => m.serialNum === allocation.memberSerialNum)?.name || '未知成员' }}
              </span>
              <span v-if="allocation.categorySerialNum" class="text-gray-600 dark:text-gray-400 text-sm">
                · {{ allocation.categorySerialNum }}
              </span>
              <span class="ml-auto font-semibold text-blue-600 dark:text-blue-400">
                {{ allocation.allocatedAmount
                  ? `¥${Number(allocation.allocatedAmount).toFixed(2)}`
                  : `${Number(allocation.percentage).toFixed(1)}%`
                }}
              </span>
            </div>
            <div class="flex gap-2">
              <button
                type="button"
                class="p-1 border-none bg-transparent cursor-pointer text-base transition-transform hover:scale-125"
                @click="handleEditAllocation(index)"
              >
                ✏️
              </button>
              <button
                type="button"
                class="p-1 border-none bg-transparent cursor-pointer text-base transition-transform hover:scale-125"
                @click="handleDeleteAllocation(index)"
              >
                🗑️
              </button>
            </div>
          </div>
        </div>

        <div v-else class="py-8 text-center text-gray-500 dark:text-gray-400 text-sm">
          <p>暂无成员预算分配，点击“添加分配”开始配置</p>
        </div>
      </div>
    </form>

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
  </Modal>
</template>
