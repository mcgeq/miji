<script setup lang="ts">
import BaseModal from '@/components/common/BaseModal.vue';
import CategorySelector from '@/components/common/CategorySelector.vue';
import FormRow from '@/components/ui/FormRow.vue';
import {
  OverspendLimitType,
} from '@/types/budget-allocation';
import type {
  BudgetAllocationCreateRequest,
  BudgetAllocationResponse,
} from '@/types/budget-allocation';

interface FormData {
  allocationType: 'member' | 'member-category';
  memberSerialNum?: string;
  selectedCategories: string[]; // 分类名称数组
  amountType: 'fixed' | 'percentage';
  allocatedAmount?: number;
  percentage?: number;
  allowOverspend: boolean;
  overspendLimitType: OverspendLimitType;
  overspendLimitValue?: number;
  alertEnabled: boolean;
  alertThreshold: number;
  priority: number;
  isMandatory: boolean;
  notes?: string;
}

interface Props {
  /** 是否为编辑模式 */
  isEdit?: boolean;
  /** 编辑的分配数据 */
  allocation?: BudgetAllocationResponse;
  /** 可用成员列表 */
  members?: Array<{ serialNum: string; name: string }>;
  /** 可用分类列表 */
  categories?: Array<{ serialNum: string; name: string }>;
  /** 预算总额（用于百分比计算） */
  budgetTotal?: number;
  /** 是否加载中 */
  loading?: boolean;
}

interface Emits {
  (e: 'submit', data: BudgetAllocationCreateRequest): void;
  (e: 'cancel'): void;
}

const props = withDefaults(defineProps<Props>(), {
  isEdit: false,
  allocation: undefined,
  members: () => [],
  categories: () => [],
  budgetTotal: 0,
  loading: false,
});

const emit = defineEmits<Emits>();

/**
 * 表单数据
 */
const formData = ref<FormData>({
  allocationType: 'member',
  selectedCategories: [],
  amountType: 'fixed',
  allowOverspend: false,
  overspendLimitType: OverspendLimitType.NONE,
  alertEnabled: true,
  alertThreshold: 80,
  priority: 3,
  isMandatory: false,
});

/**
 * 表单验证
 */
const isValid = computed(() => {
  // 必须选择成员
  if (!formData.value.memberSerialNum) {
    return false;
  }

  // 如果是成员+分类，必须选择分类
  if (formData.value.allocationType === 'member-category' && formData.value.selectedCategories.length === 0) {
    return false;
  }

  // 必须输入金额或百分比
  if (formData.value.amountType === 'fixed') {
    if (!formData.value.allocatedAmount || formData.value.allocatedAmount <= 0) {
      return false;
    }
  } else {
    if (!formData.value.percentage || formData.value.percentage <= 0 || formData.value.percentage > 100) {
      return false;
    }
  }

  return true;
});

/**
 * 提交表单
 */
function handleSubmit() {
  if (!isValid.value) return;

  // 将分类名称转换为 serialNum（从 categories 中查找）
  let categorySerialNum: string | undefined;
  if (formData.value.allocationType === 'member-category' && formData.value.selectedCategories.length > 0) {
    const categoryName = formData.value.selectedCategories[0];
    const category = props.categories?.find(c => c.name === categoryName);
    categorySerialNum = category?.serialNum;
  }

  const data: BudgetAllocationCreateRequest = {
    memberSerialNum: formData.value.memberSerialNum,
    categorySerialNum,
    allocatedAmount: formData.value.amountType === 'fixed' ? formData.value.allocatedAmount : undefined,
    percentage: formData.value.amountType === 'percentage' ? formData.value.percentage : undefined,
    allowOverspend: formData.value.allowOverspend,
    overspendLimitType: formData.value.overspendLimitType,
    overspendLimitValue: formData.value.overspendLimitValue,
    alertEnabled: formData.value.alertEnabled,
    alertThreshold: formData.value.alertThreshold,
    priority: formData.value.priority,
    isMandatory: formData.value.isMandatory,
    notes: formData.value.notes,
  };

  emit('submit', data);
}

/**
 * 取消
 */
function handleCancel() {
  emit('cancel');
}

/**
 * 初始化表单数据
 */
watch(
  () => props.allocation,
  newValue => {
    if (newValue) {
      // 将 categorySerialNum 转换为分类名称
      const selectedCategories: string[] = [];
      if (newValue.categorySerialNum) {
        const category = props.categories?.find(c => c.serialNum === newValue.categorySerialNum);
        if (category) {
          selectedCategories.push(category.name);
        }
      }

      formData.value = {
        allocationType: newValue.categorySerialNum ? 'member-category' : 'member',
        memberSerialNum: newValue.memberSerialNum,
        selectedCategories,
        amountType: newValue.allocatedAmount ? 'fixed' : 'percentage',
        allocatedAmount: newValue.allocatedAmount,
        percentage: newValue.percentage,
        allowOverspend: newValue.allowOverspend || false,
        overspendLimitType: newValue.overspendLimitType || OverspendLimitType.NONE,
        overspendLimitValue: newValue.overspendLimitValue,
        alertEnabled: newValue.alertEnabled ?? true,
        alertThreshold: newValue.alertThreshold || 80,
        priority: newValue.priority || 3,
        isMandatory: newValue.isMandatory || false,
        notes: newValue.notes,
      };
    }
  },
  { immediate: true },
);
</script>

<template>
  <BaseModal
    :model-value="true"
    :title="isEdit ? '编辑分配' : '添加分配'"
    size="md"
    :confirm-loading="loading"
    :confirm-disabled="!isValid"
    @close="handleCancel"
    @confirm="handleSubmit"
  >
    <form class="allocation-form" @submit.prevent="handleSubmit">
      <!-- 分配目标 -->
      <div class="form-section">
        <h3 class="section-title">
          分配目标
        </h3>

        <!-- 分配类型 -->
        <FormRow label="分配类型" required>
          <div class="radio-group">
            <label class="radio-label">
              <input v-model="formData.allocationType" type="radio" value="member">
              <span>成员</span>
            </label>
            <label class="radio-label">
              <input v-model="formData.allocationType" type="radio" value="member-category">
              <span>成员+分类</span>
            </label>
          </div>
        </FormRow>

        <!-- 成员选择 -->
        <FormRow label="选择成员" required>
          <select v-model="formData.memberSerialNum" class="modal-input-select w-full" required>
            <option value="">
              请选择成员
            </option>
            <option v-for="member in members" :key="member.serialNum" :value="member.serialNum">
              {{ member.name }}
            </option>
          </select>
        </FormRow>

        <!-- 分类选择（仅成员+分类时显示） -->
        <div v-if="formData.allocationType === 'member-category'">
          <CategorySelector
            v-model="formData.selectedCategories"
            label="选择分类"
            :required="true"
            :multiple="false"
            :show-quick-select="true"
            help-text="选择此成员在此预算中可使用的具体分类"
          />
        </div>
      </div>

      <!-- 金额设置 -->
      <div class="form-section">
        <h3 class="section-title">
          金额设置
        </h3>

        <!-- 金额类型 -->
        <FormRow label="分配方式" required>
          <div class="radio-group">
            <label class="radio-label">
              <input v-model="formData.amountType" type="radio" value="fixed">
              <span>固定金额</span>
            </label>
            <label class="radio-label">
              <input v-model="formData.amountType" type="radio" value="percentage">
              <span>百分比</span>
            </label>
          </div>
        </FormRow>

        <!-- 固定金额 -->
        <FormRow v-if="formData.amountType === 'fixed'" label="分配金额" required>
          <div class="input-with-prefix">
            <span class="prefix">¥</span>
            <input
              v-model.number="formData.allocatedAmount"
              type="number"
              class="modal-input-select"
              placeholder="0.00"
              step="0.01"
              min="0"
              required
            >
          </div>
        </FormRow>

        <!-- 百分比 -->
        <FormRow v-else label="百分比" required>
          <div class="input-with-suffix">
            <input
              v-model.number="formData.percentage"
              type="number"
              class="modal-input-select"
              placeholder="0"
              min="0"
              max="100"
              required
            >
            <span class="suffix">%</span>
          </div>
        </FormRow>
      </div>

      <!-- 备注 -->
      <textarea
        v-model="formData.notes"
        class="modal-input-select w-full"
        rows="3"
        placeholder="可选的备注信息..."
      />
    </form>
  </BaseModal>
</template>

<style scoped>
.allocation-form {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.form-section {
  padding: 0.75rem;
  background: var(--color-base-200);
  border-radius: 0.5rem;
}

.section-title {
  font-size: 0.875rem;
  font-weight: 600;
  color: var(--color-base-content);
  margin-bottom: 0.75rem;
}

.radio-group {
  display: flex;
  gap: 1rem;
  flex-wrap: wrap;
}

.radio-label {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  cursor: pointer;
  font-size: 0.875rem;
}

.radio-label input[type="radio"] {
  cursor: pointer;
}

.input-with-prefix,
.input-with-suffix {
  display: flex;
  align-items: center;
  border: 1px solid var(--color-base-300);
  border-radius: 0.375rem;
  overflow: hidden;
  background: var(--color-base-100);
}

.input-with-prefix .modal-input-select,
.input-with-suffix .modal-input-select {
  border: none;
  flex: 1;
  min-width: 0;
}

.prefix,
.suffix {
  padding: 0 0.75rem;
  background-color: var(--color-base-200);
  color: var(--color-base-content);
  font-size: 0.875rem;
  font-weight: 500;
}
</style>
