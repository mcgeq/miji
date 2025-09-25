<script setup lang="ts">
import { isNaN } from 'es-toolkit/compat';
import { useI18n } from 'vue-i18n';
import ColorSelector from '@/components/common/ColorSelector.vue';
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
const formErrors = ref<Record<string, string>>({});
const isSubmitting = ref(false);
const currentUser = computed(() => getCurrentUser());
const familyMembers = computedAsync(() => MoneyDb.listFamilyMembers());
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
      role: currentUser.value.role || 'user', // Fallback role
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
    createdAt: DateUtils.getLocalISODateTimeWithOffset(),
  },
  color: COLORS_MAP[0].code,
  isShared: false,
  isActive: true,
  ownerId: currentUser.value?.serialNum || '',
  createdAt: DateUtils.getLocalISODateTimeWithOffset(),
  updatedAt: null,
};

// 初始化表单
const form = reactive<Account>({
  ...defaultAccount,
  ...(props.account ? JSON.parse(JSON.stringify(props.account)) : {}),
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
      createdAt: DateUtils.getLocalISODateTimeWithOffset(),
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
  isSubmitting.value = true;

  // 格式化 balance
  form.balance = formatBalance(form.balance);

  try {
    const commonRequestFields = buildCommonRequestFields(form);
    const isUpdate = !!props.account;
    const requestData: CreateAccountRequest | UpdateAccountRequest = isUpdate
      ? {
          ...commonRequestFields,
        }
      : commonRequestFields;

    const schemaToUse = isUpdate ? UpdateAccountRequestSchema : CreateAccountRequestSchema;
    const validationRequest = schemaToUse.safeParse(requestData);

    if (!validationRequest.success) {
      toast.error('数据校验失败');
      Lg.e('AccountModal', validationRequest.error);
      isSubmitting.value = false;
      return;
    }

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
  <div class="modal-mask">
    <div class="modal-mask-window-money">
      <div class="mb-4 flex items-center justify-between">
        <h3 class="text-lg font-semibold">
          {{ props.account ? t('financial.account.editAccount') : t('financial.account.addAccount') }}
        </h3>
        <button class="text-gray-500 hover:text-gray-700" @click="closeModal">
          <svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>
      <form @submit.prevent="saveAccount">
        <!-- 账户名称 -->
        <div class="mb-2 flex items-center justify-between">
          <label class="text-sm text-gray-700 font-medium mb-2">
            {{ t('financial.account.accountName') }}
          </label>
          <div class="w-2/3">
            <input
              v-model="form.name"
              type="text"
              required
              class="modal-input-select w-full"
              :placeholder="t('common.placeholders.enterName')"
            >
            <span v-if="formErrors.name" class="text-xs text-red-500">{{ formErrors.name }}</span>
          </div>
        </div>

        <!-- 账户类型 -->
        <div class="mb-2 flex items-center justify-between">
          <label class="text-sm text-gray-700 font-medium mb-2">
            {{ t('financial.account.accountType') }}
          </label>
          <div class="w-2/3">
            <select v-model="form.type" required class="modal-input-select w-full">
              <option v-for="type in accountTypes" :key="type" :value="type">
                {{ t(`financial.accountTypes.${type.toLowerCase()}`) }}
              </option>
            </select>
            <span v-if="formErrors.type" class="text-xs text-red-500">{{ formErrors.type }}</span>
          </div>
        </div>

        <!-- 初始余额 -->
        <div class="mb-2 flex items-center justify-between">
          <label class="text-sm text-gray-700 font-medium mb-2">
            {{ t('financial.initialBalance') }}
          </label>
          <div class="w-2/3">
            <input
              v-model="form.initialBalance"
              type="text"
              required
              class="modal-input-select w-full"
              placeholder="0.00"
              @input="handleBalanceInput($event)"
              @blur="form.initialBalance = formatBalance(form.initialBalance)"
            >
            <span v-if="formErrors.initialBalance" class="text-xs text-red-500">{{ formErrors.initialBalance }}</span>
          </div>
        </div>

        <!-- 货币 -->
        <div class="mb-2 flex items-center justify-between">
          <label class="text-sm text-gray-700 font-medium mb-2">
            {{ t('financial.currency') }}
          </label>
          <div class="w-2/3">
            <select v-model="form.currency.code" required class="modal-input-select w-full">
              <option v-for="currency in currencies" :key="currency.code" :value="currency.code">
                {{ t(`currency.${currency.code}`) }}
              </option>
            </select>
            <span v-if="formErrors['currency.code']" class="text-xs text-red-500">{{ formErrors['currency.code'] }}</span>
          </div>
        </div>

        <!-- 所有者 -->
        <div class="mb-2 flex items-center justify-between">
          <label class="text-sm text-gray-700 font-medium mb-2">
            {{ t('financial.account.owner') }}
          </label>
          <div class="w-2/3">
            <select v-model="form.ownerId" required class="modal-input-select w-full">
              <option v-for="user in users" :key="user.serialNum" :value="user.serialNum">
                {{ user.name }}
              </option>
            </select>
            <span v-if="formErrors.ownerId" class="text-xs text-red-500">{{ formErrors.ownerId }}</span>
          </div>
        </div>

        <!-- 共享和激活 -->
        <div class="mb-2 flex items-center justify-between">
          <div class="w-1/2">
            <label class="flex items-center">
              <input
                v-model="form.isShared"
                type="checkbox"
                class="checkbox-radius"
              >
              <span class="text-sm text-gray-700 font-medium">{{ t('financial.account.shared') }}</span>
            </label>
          </div>
          <div class="w-1/2">
            <label class="flex items-center">
              <input
                v-model="form.isActive"
                type="checkbox"
                class="checkbox-radius"
              >
              <span class="text-sm text-gray-500 font-medium">{{ t('financial.account.activate') }}</span>
            </label>
          </div>
        </div>

        <!-- 颜色 -->
        <div class="mb-2 flex items-center justify-between">
          <label class="text-sm text-gray-700 font-medium mb-2">
            {{ t('common.misc.color') }}
          </label>
          <ColorSelector v-model="form.color" :color-names="colorNameMap" />
        </div>

        <!-- 描述 -->
        <div class="mb-2">
          <textarea
            v-model="form.description"
            rows="3"
            class="modal-input-select w-full"
            :placeholder="`${t('common.misc.description')}（${t('common.misc.optional')}）`"
          />
          <span v-if="formErrors.description" class="text-xs text-red-500">{{ formErrors.description }}</span>
        </div>

        <!-- 按钮 -->
        <div class="flex justify-center space-x-3">
          <button type="button" class="modal-btn-x" :disabled="isSubmitting" @click="closeModal">
            <LucideX class="wh-5" />
          </button>
          <button type="submit" class="modal-btn-check" :disabled="isSubmitting">
            <LucideCheck class="wh-5" />
            <span v-if="isSubmitting">{{ t('common.actions.saving') }}</span>
          </button>
        </div>
      </form>
    </div>
  </div>
</template>

<style scoped lang="postcss">
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

/* checked 状态 */
.checkbox-radius:checked {
  background-color: #3B82F6;
  border-color: #4B5563;
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
