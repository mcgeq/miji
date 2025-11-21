<script setup lang="ts">
import { isNaN } from 'es-toolkit/compat';
import BaseModal from '@/components/common/BaseModal.vue';
import ColorSelector from '@/components/common/ColorSelector.vue';
import FormRow from '@/components/common/FormRow.vue';
import { useFormValidation } from '@/composables/useFormValidation';
import { COLORS_MAP } from '@/constants/moneyConst';
import { AccountTypeSchema, CreateAccountRequestSchema, UpdateAccountRequestSchema } from '@/schema/money';
import { MoneyDb } from '@/services/money/money';
import { DateUtils } from '@/utils/date';
import { Lg } from '@/utils/debugLog';
import { toast } from '@/utils/toast';
import type { Currency } from '@/schema/common';
import type { Account, CreateAccountRequest, UpdateAccountRequest } from '@/schema/money';

interface Props {
  account: Account | null;
}

interface User {
  serialNum: string;
  name: string;
  role: string;
}

const props = defineProps<Props>();
const emit = defineEmits(['close', 'save', 'update']);
const { t } = useI18n();

// 响应式数据
const colorNameMap = ref(COLORS_MAP);
const accountTypes = computed(() => AccountTypeSchema.options);
const isSubmitting = ref(false);

// 表单验证
const validation = useFormValidation(
  props.account ? UpdateAccountRequestSchema : CreateAccountRequestSchema,
);
const currentUser = computed(() => getCurrentUser());
const familyMembers = computedAsync(async () => {
  try {
    return await MoneyDb.listFamilyMembers();
  } catch (error) {
    Lg.w('AccountModal', 'Failed to load family members, using empty array', error);
    return [];
  }
}, []);
const users = computed<User[]>(() => {
  const usersSet = new Set('');
  const userList: User[] = [];

  const familyMembersList = familyMembers.value?.map(item => {
    const { permissions, createdAt, updatedAt, ...rest } = item;
    return rest as Omit<User, 'permissions' | 'createdAt' | 'updatedAt'>;
  });
  if (currentUser.value) {
    userList.push({
      serialNum: currentUser.value.serialNum,
      name: currentUser.value.name || 'Current User',
      role: currentUser.value.role || 'user',
    });
    usersSet.add(currentUser.value.serialNum);
  }

  familyMembersList?.forEach(item => {
    if (!usersSet.has(item.serialNum)) {
      usersSet.add(item.serialNum);
      userList.push(item);
    }
  });
  return userList;
});

// Use ref instead of computed for async data
const currencies = ref<Currency[]>([]);

// Fetch currencies asynchronously
async function loadCurrencies() {
  try {
    const fetchedCurrencies = await MoneyDb.listCurrencies();
    currencies.value = fetchedCurrencies;
  } catch (err: unknown) {
    toast.error(t('financial.account.currencyLoadFailed'));
    Lg.e('AccountModal', 'Failed to load currencies:', err);
  }
}

// Call loadCurrencies on component setup
loadCurrencies();

// 默认账户
const defaultAccount: Account = props.account || {
  serialNum: '',
  name: '',
  description: '',
  type: AccountTypeSchema.enum.Other,
  balance: '0.00',
  initialBalance: '0.00',
  currency: {
    locale: 'zh-CN',
    code: 'CNY',
    symbol: '¥',
    isDefault: true,
    isActive: true,
    createdAt: DateUtils.getLocalISODateTimeWithOffset(),
    updatedAt: null,
  },
  color: COLORS_MAP[0].code,
  isShared: false,
  isActive: true,
  isVirtual: false,
  ownerId: currentUser.value?.serialNum || '',
  createdAt: DateUtils.getLocalISODateTimeWithOffset(),
  updatedAt: null,
};

// 初始化表单
const form = reactive<Account>({
  ...defaultAccount,
  ...(props.account ? JSON.parse(JSON.stringify(props.account)) : {}),
  // 确保 color 有默认值
  color: (props.account?.color || defaultAccount.color) ?? COLORS_MAP[0].code,
});

// 创建 color 的计算属性，确保始终是字符串类型
const formColor = computed({
  get: () => form.color || COLORS_MAP[0].code,
  set: (value: string) => {
    form.color = value;
  },
});

// 同步 currency 对象的 locale 和 symbol
function syncCurrency(code: string) {
  const currency = currencies.value.find(c => c.code === code);
  if (currency) {
    form.currency = { ...currency };
  } else {
    form.currency = {
      locale: 'zh-CN',
      code: 'CNY',
      symbol: '¥',
      isDefault: true,
      isActive: true,
      createdAt: DateUtils.getLocalISODateTimeWithOffset(),
      updatedAt: null,
    };
  }
}

// 格式化 balance 为两位小数字符串
function formatBalance(value: string | number): string {
  const num = Number.parseFloat(value.toString());
  return Number.isNaN(num) ? '0.00' : num.toFixed(2);
}

function handleBalanceInput(event: Event) {
  const input = event.target as HTMLInputElement;
  const value = input.value.replace(/[^0-9.]/g, '');
  if (value === '.' || value === '') {
    form.initialBalance = value;
  } else {
    const num = Number.parseFloat(value);
    if (!isNaN(num)) {
      form.initialBalance = value;
    }
  }
}

// 关闭模态框
function closeModal() {
  emit('close');
}

// 保存账户
async function saveAccount() {
  if (isSubmitting.value) return;

  // 格式化 balance
  form.balance = formatBalance(form.balance);

  const commonRequestFields = buildCommonRequestFields(form);
  const requestData: CreateAccountRequest | UpdateAccountRequest = commonRequestFields;

  // 使用 useFormValidation 验证
  if (!validation.validateAll(requestData as any)) {
    toast.error(t('financial.account.validationFailed'));
    return;
  }

  isSubmitting.value = true;
  try {
    if (!props.account) {
      emit('save', requestData);
    } else {
      emit('update', props.account.serialNum, requestData);
    }
    closeModal();
  } catch (err: unknown) {
    toast.error(t('financial.account.saveFailed'));
    Lg.e('AccountModal', 'Save account failed:', err);
  } finally {
    isSubmitting.value = false;
  }
}

function buildCommonRequestFields(form: Account) {
  return {
    name: form.name,
    description: form.description,
    type: form.type,
    isShared: form.isShared,
    ownerId: form.ownerId,
    color: form.color,
    isActive: form.isActive,
    initialBalance: form.initialBalance,
    currency: form.currency?.code || 'CNY', // 安全访问 optional 字段 + 默认值
  };
}

// 监听 props.account 变化
watch(
  () => props.account,
  newVal => {
    if (newVal) {
      Object.assign(form, JSON.parse(JSON.stringify(newVal)));
      syncCurrency(form.currency.code);
    }
  },
  { immediate: true, deep: true },
);

// 监听 currency.code 变化
watch(
  () => form.currency.code,
  newCode => {
    syncCurrency(newCode);
  },
);

watch(() => form.initialBalance, newBalance => {
  form.balance = newBalance;
});
</script>

<template>
  <BaseModal
    :title="props.account ? t('financial.account.editAccount') : t('financial.account.addAccount')"
    size="md"
    :confirm-text="props.account ? t('common.actions.update') : t('common.actions.create')"
    :confirm-loading="isSubmitting"
    :confirm-disabled="validation.hasAnyError.value"
    @close="closeModal"
    @confirm="saveAccount"
  >
    <form @submit.prevent="saveAccount">
      <!-- 账户名称 -->
      <FormRow
        :label="t('financial.account.accountName')"
        required
        :error="validation.shouldShowError('name') ? validation.getError('name') : ''"
      >
        <input
          v-model="form.name"
          type="text"
          required
          class="modal-input-select w-full"
          :placeholder="t('common.placeholders.enterName')"
        >
      </FormRow>

      <!-- 账户类型 -->
      <FormRow
        :label="t('financial.account.accountType')"
        required
        :error="validation.shouldShowError('type') ? validation.getError('type') : ''"
      >
        <select v-model="form.type" required class="modal-input-select w-full">
          <option v-for="type in accountTypes" :key="type" :value="type">
            {{ t(`financial.accountTypes.${type.toLowerCase()}`) }}
          </option>
        </select>
      </FormRow>

      <!-- 初始余额 -->
      <FormRow
        :label="t('financial.initialBalance')"
        required
        :error="validation.shouldShowError('initialBalance') ? validation.getError('initialBalance') : ''"
      >
        <input
          v-model="form.initialBalance"
          type="text"
          required
          class="modal-input-select w-full"
          placeholder="0.00"
          @input="handleBalanceInput($event)"
          @blur="form.initialBalance = formatBalance(form.initialBalance)"
        >
      </FormRow>

      <!-- 货币 -->
      <FormRow
        :label="t('financial.currency')"
        required
        :error="validation.shouldShowError('currency') ? validation.getError('currency') : ''"
      >
        <select v-model="form.currency.code" required class="modal-input-select w-full">
          <option v-for="currency in currencies" :key="currency.code" :value="currency.code">
            {{ t(`currency.${currency.code}`) }}
          </option>
        </select>
      </FormRow>

      <!-- 所有者 -->
      <FormRow
        :label="t('financial.account.owner')"
        required
        :error="validation.shouldShowError('ownerId') ? validation.getError('ownerId') : ''"
      >
        <select v-model="form.ownerId" required class="modal-input-select w-full">
          <option v-for="user in users" :key="user.serialNum" :value="user.serialNum">
            {{ user.name }}
          </option>
        </select>
      </FormRow>

      <!-- 共享和激活 -->
      <div class="checkbox-row">
        <div class="checkbox-group">
          <label class="checkbox-label">
            <input
              v-model="form.isShared"
              type="checkbox"
              class="checkbox-radius"
            >
            <span class="checkbox-text">{{ t('financial.account.shared') }}</span>
          </label>
        </div>
        <div class="checkbox-group">
          <label class="checkbox-label">
            <input
              v-model="form.isActive"
              type="checkbox"
              class="checkbox-radius"
            >
            <span class="checkbox-text-secondary">{{ t('financial.account.activate') }}</span>
          </label>
        </div>
      </div>

      <!-- 颜色 -->
      <div class="form-row">
        <label class="form-label">
          {{ t('common.misc.color') }}
        </label>
        <div class="form-input-2-3">
          <ColorSelector
            v-model="formColor"
            :color-names="colorNameMap"
            :extended="true"
            :show-categories="true"
            :show-custom-color="true"
          />
        </div>
      </div>

      <!-- 描述 -->
      <div class="form-textarea">
        <textarea
          v-model="form.description"
          rows="3"
          class="modal-input-select w-full"
          :placeholder="`${t('common.misc.description')}（${t('common.misc.optional')}）`"
        />
        <span v-if="validation.shouldShowError('description')" class="form-error">{{ validation.getError('description') }}</span>
      </div>
    </form>
  </BaseModal>
</template>

<style scoped lang="postcss">
/* 引入共享的 Modal 表单样式 */
@import '@/assets/styles/modal-forms.css';

/* Form Layout */
.form-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 0.75rem;
  gap: 0;
}

.form-label {
  font-size: 0.875rem;
  font-weight: 500;
  color: var(--color-base-content);
  margin-bottom: 0;
  margin-right: 0;
  flex: 0 0 6rem;
  width: 6rem;
  min-width: 6rem;
  max-width: 6rem;
  white-space: nowrap;
  text-align: left;
}

.form-input-2-3 {
  width: 66%;
  flex: 0 0 66%;
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
  margin-left: 0;
}

/* 颜色选择器特殊处理 - 移除 flex 布局的影响 */
.form-row:has(.color-selector) .form-input-2-3 {
  display: block;
}

.form-textarea {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
  margin-bottom: 0.75rem;
}

.form-error {
  font-size: 0.875rem;
  color: var(--color-error);
  text-align: right;
}

/* Color Selector - 覆盖默认宽度并确保对齐 */
.form-input-2-3 :deep(.color-selector) {
  width: 100% !important;
  max-width: 100% !important;
  margin: 0 !important;
  padding: 0 !important;
}

/* ColorSelector 触发按钮 - 与输入框样式保持一致 */
.form-input-2-3 :deep(.color-selector__trigger) {
  padding: 0.5rem 1rem !important;
  border-radius: 0.75rem !important;
}

/* Checkbox Layout */
.checkbox-row {
  margin-bottom: 0.5rem;
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.checkbox-group {
  width: 50%;
}

.checkbox-label {
  display: flex;
  align-items: center;
}

.checkbox-text {
  font-size: 0.875rem;
  color: #374151;
  font-weight: 500;
}

.checkbox-text-secondary {
  font-size: 0.875rem;
  color: #6b7280;
  font-weight: 500;
}

/* Checkbox Styling */
.checkbox-radius {
  -webkit-appearance: none; /* 去掉浏览器默认样式 */
  appearance: none;
  display: inline-block;
  height: 1.5rem;           /* h-6 */
  width: 1.5rem;            /* w-6 */
  border-radius: 50%;        /* rounded-full */
  margin-left: 0.5rem;      /* ml-2 */
  margin-right: 0.5rem;     /* mr-2 */
  padding-top: 0;           /* py-0 */
  padding-bottom: 0;        /* py-0 */
  padding-left: 0.5rem;     /* px-2 */
  padding-right: 0.5rem;    /* px-2 */
  border: 1px solid #D1D5DB; /* border-gray-300 */
  color: #111827;           /* text-gray-900 */
  background-color: #ffffff; /* 默认背景 */
  cursor: pointer;
  transition: all 0.2s ease-in-out; /* transition-all duration-200 */
  vertical-align: middle;
}

.checkbox-radius:focus {
  outline: none; /* 去掉默认轮廓 */
  border-color: transparent; /* focus:border-transparent */
  box-shadow: 0 0 0 2px rgba(59, 130, 246, 0.5); /* focus:ring-2 focus:ring-blue-500 */
}

/* placeholder 样式 */
.checkbox-radius::placeholder {
  color: #9CA3AF;              /* placeholder-gray-400 */
}

/* checked 状态 */
.checkbox-radius:checked {
  background-color: #3B82F6;  /* bg-blue-500 */
  border-color: #4B5563;      /* border-gray-600 */
}

/* dark mode */
@media (prefers-color-scheme: dark) {
  .checkbox-radius {
    color: #ffffff; /* dark:text-white */
    border-color: #4B5563; /* dark:border-gray-600 */
    background-color: #1F2937; /* dark:bg-gray-800 */
  }
  .checkbox-radius::placeholder {
    color: #6B7280;            /* dark:placeholder-gray-500 */
  }
  .checkbox-radius:checked {
    background-color: #3B82F6;
    border-color: #4B5563;
  }
}
</style>
