<script setup lang="ts">
import {
  OverspendLimitType,
} from '@/types/budget-allocation';
import type {
  BudgetAllocationCreateRequest,
  BudgetAllocationResponse,
} from '@/types/budget-allocation';

interface FormData {
  target: 'member' | 'category' | 'both';
  memberSerialNum?: string;
  categorySerialNum?: string;
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
  target: 'member',
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
  // 必须选择成员或分类
  if (formData.value.target === 'member' && !formData.value.memberSerialNum) {
    return false;
  }
  if (formData.value.target === 'category' && !formData.value.categorySerialNum) {
    return false;
  }
  if (
    formData.value.target === 'both' &&
    (!formData.value.memberSerialNum || !formData.value.categorySerialNum)
  ) {
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
 * 处理提交
 */
function handleSubmit() {
  if (!isValid.value) return;

  const data: BudgetAllocationCreateRequest = {
    memberSerialNum: formData.value.memberSerialNum || undefined,
    categorySerialNum: formData.value.categorySerialNum || undefined,
    allocatedAmount:
      formData.value.amountType === 'fixed'
        ? formData.value.allocatedAmount
        : undefined,
    percentage:
      formData.value.amountType === 'percentage'
        ? formData.value.percentage
        : undefined,
    allowOverspend: formData.value.allowOverspend,
    overspendLimitType: formData.value.allowOverspend
      ? formData.value.overspendLimitType
      : undefined,
    overspendLimitValue:
      formData.value.allowOverspend && formData.value.overspendLimitType !== 'NONE'
        ? formData.value.overspendLimitValue
        : undefined,
    alertEnabled: formData.value.alertEnabled,
    alertThreshold: formData.value.alertEnabled
      ? formData.value.alertThreshold
      : undefined,
    priority: formData.value.priority,
    isMandatory: formData.value.isMandatory,
    notes: formData.value.notes || undefined,
  };

  emit('submit', data);
}

/**
 * 初始化表单（编辑模式）
 */
watch(
  () => props.allocation,
  allocation => {
    if (allocation && props.isEdit) {
      formData.value = {
        target: allocation.memberSerialNum && allocation.categorySerialNum
          ? 'both'
          : allocation.memberSerialNum
            ? 'member'
            : 'category',
        memberSerialNum: allocation.memberSerialNum || undefined,
        categorySerialNum: allocation.categorySerialNum || undefined,
        amountType: allocation.percentage ? 'percentage' : 'fixed',
        allocatedAmount: allocation.allocatedAmount,
        percentage: allocation.percentage || undefined,
        allowOverspend: allocation.allowOverspend,
        overspendLimitType: allocation.overspendLimitType || OverspendLimitType.NONE,
        overspendLimitValue: allocation.overspendLimitValue || undefined,
        alertEnabled: allocation.alertEnabled,
        alertThreshold: allocation.alertThreshold,
        priority: allocation.priority,
        isMandatory: allocation.isMandatory,
        notes: allocation.notes || undefined,
      };
    }
  },
  { immediate: true },
);
</script>

<template>
  <div class="budget-allocation-editor">
    <form @submit.prevent="handleSubmit">
      <!-- 分配目标 -->
      <section class="editor-section">
        <h3 class="section-title">
          分配目标
        </h3>

        <!-- 目标类型选择 -->
        <div class="target-type-selector">
          <label class="radio-label">
            <input
              v-model="formData.target"
              type="radio"
              value="member"
            >
            <span>成员</span>
          </label>
          <label class="radio-label">
            <input
              v-model="formData.target"
              type="radio"
              value="category"
            >
            <span>分类</span>
          </label>
          <label class="radio-label">
            <input
              v-model="formData.target"
              type="radio"
              value="both"
            >
            <span>成员+分类</span>
          </label>
        </div>

        <!-- 成员选择 -->
        <div v-if="['member', 'both'].includes(formData.target)" class="form-group">
          <label class="form-label">选择成员</label>
          <select v-model="formData.memberSerialNum" class="form-select" required>
            <option value="">
              请选择成员
            </option>
            <option
              v-for="member in members"
              :key="member.serialNum"
              :value="member.serialNum"
            >
              {{ member.name }}
            </option>
          </select>
        </div>

        <!-- 分类选择 -->
        <div v-if="['category', 'both'].includes(formData.target)" class="form-group">
          <label class="form-label">选择分类</label>
          <select v-model="formData.categorySerialNum" class="form-select" required>
            <option value="">
              请选择分类
            </option>
            <option
              v-for="category in categories"
              :key="category.serialNum"
              :value="category.serialNum"
            >
              {{ category.name }}
            </option>
          </select>
        </div>
      </section>

      <!-- 金额设置 -->
      <section class="editor-section">
        <h3 class="section-title">
          金额设置
        </h3>

        <!-- 金额类型 -->
        <div class="amount-type-selector">
          <label class="radio-label">
            <input
              v-model="formData.amountType"
              type="radio"
              value="fixed"
            >
            <span>固定金额</span>
          </label>
          <label class="radio-label">
            <input
              v-model="formData.amountType"
              type="radio"
              value="percentage"
            >
            <span>百分比</span>
          </label>
        </div>

        <!-- 固定金额输入 -->
        <div v-if="formData.amountType === 'fixed'" class="form-group">
          <label class="form-label">分配金额</label>
          <div class="input-with-prefix">
            <span class="prefix">¥</span>
            <input
              v-model.number="formData.allocatedAmount"
              type="number"
              class="form-input"
              placeholder="0.00"
              step="0.01"
              min="0"
              required
            >
          </div>
        </div>

        <!-- 百分比输入 -->
        <div v-else class="form-group">
          <label class="form-label">百分比</label>
          <div class="input-with-suffix">
            <input
              v-model.number="formData.percentage"
              type="number"
              class="form-input"
              placeholder="0"
              step="1"
              min="0"
              max="100"
              required
            >
            <span class="suffix">%</span>
          </div>
          <p v-if="budgetTotal && formData.percentage" class="form-hint">
            约等于 ¥{{ ((budgetTotal * formData.percentage!) / 100).toFixed(2) }}
          </p>
        </div>
      </section>

      <!-- 超支控制 -->
      <section class="editor-section">
        <h3 class="section-title">
          超支控制
        </h3>

        <div class="form-group">
          <label class="checkbox-label">
            <input
              v-model="formData.allowOverspend"
              type="checkbox"
            >
            <span>允许超支</span>
          </label>
        </div>

        <div v-if="formData.allowOverspend" class="overspend-config">
          <div class="form-group">
            <label class="form-label">超支限额类型</label>
            <select v-model="formData.overspendLimitType" class="form-select">
              <option value="NONE">
                无限制
              </option>
              <option value="PERCENTAGE">
                百分比限制
              </option>
              <option value="FIXED_AMOUNT">
                固定金额限制
              </option>
            </select>
          </div>

          <div
            v-if="formData.overspendLimitType !== 'NONE'"
            class="form-group"
          >
            <label class="form-label">
              {{ formData.overspendLimitType === 'PERCENTAGE' ? '超支百分比' : '超支金额' }}
            </label>
            <div
              :class="{
                'input-with-suffix': formData.overspendLimitType === 'PERCENTAGE',
                'input-with-prefix': formData.overspendLimitType === 'FIXED_AMOUNT',
              }"
            >
              <span
                v-if="formData.overspendLimitType === 'FIXED_AMOUNT'"
                class="prefix"
              >
                ¥
              </span>
              <input
                v-model.number="formData.overspendLimitValue"
                type="number"
                class="form-input"
                placeholder="0"
                step="0.01"
                min="0"
              >
              <span
                v-if="formData.overspendLimitType === 'PERCENTAGE'"
                class="suffix"
              >
                %
              </span>
            </div>
          </div>
        </div>
      </section>

      <!-- 预警设置 -->
      <section class="editor-section">
        <h3 class="section-title">
          预警设置
        </h3>

        <div class="form-group">
          <label class="checkbox-label">
            <input
              v-model="formData.alertEnabled"
              type="checkbox"
            >
            <span>启用预警</span>
          </label>
        </div>

        <div v-if="formData.alertEnabled" class="alert-config">
          <div class="form-group">
            <label class="form-label">
              预警阈值
              <span class="threshold-value">{{ formData.alertThreshold }}%</span>
            </label>
            <input
              v-model.number="formData.alertThreshold"
              type="range"
              class="range-slider"
              min="50"
              max="100"
              step="5"
            >
            <div class="range-labels">
              <span>50%</span>
              <span>75%</span>
              <span>100%</span>
            </div>
          </div>
        </div>
      </section>

      <!-- 管理设置 -->
      <section class="editor-section">
        <h3 class="section-title">
          管理设置
        </h3>

        <div class="form-group">
          <label class="form-label">优先级</label>
          <select v-model.number="formData.priority" class="form-select">
            <option :value="1">
              1 - 最低
            </option>
            <option :value="2">
              2 - 较低
            </option>
            <option :value="3">
              3 - 中等
            </option>
            <option :value="4">
              4 - 较高
            </option>
            <option :value="5">
              5 - 最高
            </option>
          </select>
        </div>

        <div class="form-group">
          <label class="checkbox-label">
            <input
              v-model="formData.isMandatory"
              type="checkbox"
            >
            <span>强制保障（不可削减）</span>
          </label>
        </div>

        <div class="form-group">
          <label class="form-label">备注</label>
          <textarea
            v-model="formData.notes"
            class="form-textarea"
            rows="3"
            placeholder="可选的备注信息..."
          />
        </div>
      </section>

      <!-- 操作按钮 -->
      <div class="editor-actions">
        <button
          type="submit"
          class="btn btn-primary"
          :disabled="!isValid || loading"
        >
          {{ loading ? '保存中...' : isEdit ? '更新' : '创建' }}
        </button>
        <button
          type="button"
          class="btn btn-secondary"
          :disabled="loading"
          @click="$emit('cancel')"
        >
          取消
        </button>
      </div>
    </form>
  </div>
</template>

<style scoped>
.budget-allocation-editor {
  width: 100%;
  max-width: 600px;
}

.editor-section {
  margin-bottom: 24px;
  padding: 16px;
  background: var(--color-base-200);
  border-radius: 8px;
}

.section-title {
  margin: 0 0 16px 0;
  font-size: 14px;
  font-weight: 600;
  color: var(--color-base-content);
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.target-type-selector,
.amount-type-selector {
  display: flex;
  gap: 12px;
  margin-bottom: 16px;
}

.radio-label,
.checkbox-label {
  display: flex;
  align-items: center;
  gap: 8px;
  cursor: pointer;
  user-select: none;
}

.radio-label input[type='radio'],
.checkbox-label input[type='checkbox'] {
  width: 16px;
  height: 16px;
  cursor: pointer;
}

.form-group {
  margin-bottom: 16px;
}

.form-group:last-child {
  margin-bottom: 0;
}

.form-label {
  display: block;
  margin-bottom: 6px;
  font-size: 13px;
  font-weight: 500;
  color: var(--color-base-content);
}

.threshold-value {
  float: right;
  color: var(--color-primary);
  font-weight: 600;
}

.form-select,
.form-input,
.form-textarea {
  width: 100%;
  padding: 8px 12px;
  background: var(--color-base-100);
  border: 1px solid var(--color-base-300);
  border-radius: 6px;
  font-size: 14px;
  color: var(--color-base-content);
  transition: border-color 0.2s;
}

.form-select:focus,
.form-input:focus,
.form-textarea:focus {
  outline: none;
  border-color: var(--color-primary);
}

.form-textarea {
  resize: vertical;
  font-family: inherit;
}

.input-with-prefix,
.input-with-suffix {
  display: flex;
  align-items: center;
  border: 1px solid var(--color-base-300);
  border-radius: 6px;
  overflow: hidden;
}

.input-with-prefix .form-input,
.input-with-suffix .form-input {
  border: none;
  flex: 1;
}

.prefix,
.suffix {
  padding: 0 12px;
  background-color: var(--color-base-200);
  color: var(--color-neutral);
  font-size: 14px;
  font-weight: 500;
}

.form-hint {
  margin-top: 4px;
  font-size: 12px;
  color: var(--color-neutral);
}

.range-slider {
  width: 100%;
  height: 6px;
  background: var(--color-base-300);
  border-radius: 3px;
  outline: none;
  cursor: pointer;
}

.range-slider::-webkit-slider-thumb {
  width: 18px;
  height: 18px;
  background: var(--color-primary);
  border-radius: 50%;
  cursor: pointer;
}

.range-slider::-moz-range-thumb {
  width: 18px;
  height: 18px;
  background: var(--color-primary);
  border-radius: 50%;
  cursor: pointer;
  border: none;
}

.range-labels {
  display: flex;
  justify-content: space-between;
  margin-top: 4px;
  font-size: 11px;
  color: var(--color-neutral);
}

.overspend-config,
.alert-config {
  margin-top: 12px;
  padding: 12px;
  background: var(--color-base-100);
  border-radius: 6px;
  border: 1px solid var(--color-base-300);
}

.editor-actions {
  display: flex;
  gap: 12px;
  justify-content: flex-end;
  padding-top: 16px;
  border-top: 1px solid var(--color-base-300);
}

.btn {
  padding: 10px 20px;
  border: none;
  border-radius: 6px;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
}

.btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.btn-primary {
  background-color: var(--color-primary);
  color: var(--color-primary-content);
}

.btn-primary:hover:not(:disabled) {
  background-color: var(--color-primary-hover);
}

.btn-secondary {
  background-color: var(--color-base-200);
  color: var(--color-base-content);
}

.btn-secondary:hover:not(:disabled) {
  background-color: var(--color-base-300);
}

/* 深色模式通过主题变量自动适配 */
</style>
