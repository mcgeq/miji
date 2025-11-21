<script setup lang="ts">
/**
 * 账户模态框 - 重构版本
 * 使用 BaseModal 和 useFormValidation
 */
import BaseModal from '@/components/common/BaseModal.vue';
import CurrencySelector from '@/components/common/money/CurrencySelector.vue';
import { useFormValidation } from '@/composables/useFormValidation';
import { CreateAccountRequestSchema } from '@/schema/money';
import type { Currency } from '@/schema/common';
import type { Account, CreateAccountRequest, UpdateAccountRequest } from '@/schema/money';

interface Props {
  account?: Account | null;
  readonly?: boolean;
}

const props = defineProps<Props>();
const emit = defineEmits<{
  close: [];
  save: [account: CreateAccountRequest];
  update: [serialNum: string, account: UpdateAccountRequest];
}>();

const { t } = useI18n();

// 表单数据
const form = ref<CreateAccountRequest>({
  name: props.account?.name || '',
  description: props.account?.description || '',
  type: props.account?.type || 'Bank',
  currency: props.account?.currency?.code || 'CNY',
  initialBalance: props.account?.balance || '0',
  isShared: props.account?.isShared ?? false,
  isActive: props.account?.isActive ?? true,
  color: props.account?.color || '#3B82F6',
});

// 货币选择器需要完整的 Currency 对象
const selectedCurrency = ref<Currency | null>(props.account?.currency || null);

// 监听货币选择变化，同步到表单
watch(selectedCurrency, newCurrency => {
  if (newCurrency) {
    form.value.currency = newCurrency.code;
  }
});

// 表单验证
const validation = useFormValidation(CreateAccountRequestSchema);

// 账户类型选项
const accountTypes = [
  { value: 'BankSavings', label: '储蓄账户', icon: 'piggy-bank' },
  { value: 'Cash', label: '现金', icon: 'dollar-sign' },
  { value: 'CreditCard', label: '信用卡', icon: 'credit-card' },
  { value: 'Investment', label: '投资账户', icon: 'trending-up' },
  { value: 'Alipay', label: '支付宝', icon: 'wallet' },
  { value: 'WeChat', label: '微信', icon: 'wallet-2' },
  { value: 'CloudQuickPass', label: '云闪付', icon: 'cloud' },
  { value: 'Other', label: '其他', icon: 'wallet' },
];

// 计算属性
const modalTitle = computed(() => {
  if (props.readonly) return '查看账户';
  return props.account ? '编辑账户' : '创建账户';
});

const confirmText = computed(() => {
  if (props.readonly) return undefined;
  return props.account ? '更新' : '创建';
});

const isFormValid = computed(() => {
  return !validation.hasAnyError.value;
});

// 方法
function handleConfirm() {
  if (props.readonly) {
    emit('close');
    return;
  }

  // 验证表单
  if (!validation.validateAll(form.value)) {
    return;
  }

  // 提交数据
  if (props.account) {
    emit('update', props.account.serialNum, form.value);
  } else {
    emit('save', form.value);
  }
}

function handleFieldBlur(field: keyof CreateAccountRequest) {
  validation.touchField(field);
  validation.validateField(field, form.value[field]);
}
</script>

<template>
  <BaseModal
    :title="modalTitle"
    size="md"
    :confirm-text="confirmText"
    :show-confirm="!readonly"
    :show-cancel="!readonly"
    :confirm-disabled="!isFormValid"
    @close="emit('close')"
    @confirm="handleConfirm"
  >
    <form class="account-form" @submit.prevent="handleConfirm">
      <!-- 账户名称 -->
      <div class="form-group">
        <label class="form-label">
          {{ t('financial.account.name') }}
          <span class="required">*</span>
        </label>
        <input
          v-model="form.name"
          type="text"
          class="form-input"
          :class="{ 'form-input-error': validation.shouldShowError('name') }"
          :placeholder="t('financial.account.namePlaceholder')"
          :readonly="readonly"
          @blur="handleFieldBlur('name')"
        >
        <span v-if="validation.shouldShowError('name')" class="form-error">
          {{ validation.getError('name') }}
        </span>
      </div>

      <!-- 账户类型 -->
      <div class="form-group">
        <label class="form-label">
          {{ t('financial.account.type') }}
          <span class="required">*</span>
        </label>
        <select
          v-model="form.type"
          class="form-select"
          :disabled="readonly"
          @blur="handleFieldBlur('type')"
        >
          <option v-for="type in accountTypes" :key="type.value" :value="type.value">
            {{ type.label }}
          </option>
        </select>
      </div>

      <!-- 货币 -->
      <div class="form-group">
        <label class="form-label">
          {{ t('financial.currency') }}
          <span class="required">*</span>
        </label>
        <CurrencySelector
          v-model="selectedCurrency"
          :disabled="props.readonly"
          @blur="handleFieldBlur('currency')"
        />
      </div>

      <!-- 初始余额 -->
      <div class="form-group">
        <label class="form-label">
          {{ t('financial.account.initialBalance') }}
        </label>
        <input
          v-model="form.initialBalance"
          type="number"
          step="0.01"
          class="form-input"
          :class="{ 'form-input-error': validation.shouldShowError('initialBalance') }"
          :placeholder="t('financial.account.initialBalancePlaceholder')"
          :readonly="readonly"
          @blur="handleFieldBlur('initialBalance')"
        >
        <span v-if="validation.shouldShowError('initialBalance')" class="form-error">
          {{ validation.getError('initialBalance') }}
        </span>
      </div>

      <!-- 描述 -->
      <div class="form-group">
        <label class="form-label">
          {{ t('common.description') }}
        </label>
        <textarea
          v-model="form.description"
          class="form-textarea"
          :placeholder="t('financial.account.descriptionPlaceholder')"
          :readonly="readonly"
          rows="3"
          @blur="handleFieldBlur('description')"
        />
      </div>

      <!-- 颜色 -->
      <div class="form-group">
        <label class="form-label">
          {{ t('common.color') }}
        </label>
        <input
          v-model="form.color"
          type="color"
          class="form-color"
          :disabled="readonly"
        >
      </div>

      <!-- 状态 -->
      <div v-if="!readonly" class="form-group">
        <label class="form-checkbox">
          <input
            v-model="form.isActive"
            type="checkbox"
            class="form-checkbox-input"
          >
          <span class="form-checkbox-label">
            {{ t('common.status.active') }}
          </span>
        </label>
      </div>
    </form>
  </BaseModal>
</template>

<style lang="postcss" scoped>
.account-form {
  display: flex;
  flex-direction: column;
  gap: 1.25rem;
}

.form-group {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.form-label {
  font-size: 0.875rem;
  font-weight: 500;
  color: var(--color-base-content);
}

.required {
  color: var(--color-error);
  margin-left: 0.25rem;
}

.form-input,
.form-select,
.form-textarea {
  width: 100%;
  padding: 0.625rem 0.875rem;
  font-size: 0.875rem;
  border: 1px solid var(--color-gray-300);
  border-radius: 0.5rem;
  background: var(--color-base-100);
  color: var(--color-base-content);
  transition: all 0.2s ease;
}

.form-input:focus,
.form-select:focus,
.form-textarea:focus {
  outline: none;
  border-color: var(--color-primary);
  box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
}

.form-input-error {
  border-color: var(--color-error);
}

.form-input-error:focus {
  box-shadow: 0 0 0 3px rgba(239, 68, 68, 0.1);
}

.form-error {
  font-size: 0.75rem;
  color: var(--color-error);
  margin-top: -0.25rem;
}

.form-textarea {
  resize: vertical;
  min-height: 80px;
}

.form-color {
  width: 100px;
  height: 40px;
  border: 1px solid var(--color-gray-300);
  border-radius: 0.5rem;
  cursor: pointer;
}

.form-checkbox {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  cursor: pointer;
}

.form-checkbox-input {
  width: 1.125rem;
  height: 1.125rem;
  cursor: pointer;
}

.form-checkbox-label {
  font-size: 0.875rem;
  color: var(--color-base-content);
}
</style>
