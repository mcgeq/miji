<script setup lang="ts">
import { Check, X } from 'lucide-vue-next';
import ColorSelector from '@/components/common/ColorSelector.vue';
import { COLORS_MAP, DEFAULT_CURRENCY } from '@/constants/moneyConst';
import { AccountTypeSchema } from '@/schema/money';
import { safeGet } from '@/utils/common';
import { getLocalISODateTimeWithOffset } from '@/utils/date';
import { uuid } from '@/utils/uuid';
import type { Account } from '@/schema/money';

interface Props {
  account: Account | null;
}

// 定义 props
const props = defineProps<Props>();

// 定义 emits
const emit = defineEmits(['close', 'save']);

const { t } = useI18n();

const currencys = ref(DEFAULT_CURRENCY);
const colorNameMap = ref(COLORS_MAP);
const account = props.account || {
  serialNum: '',
  name: '',
  description: '',
  type: AccountTypeSchema.enum.Other,
  balance: '0',
  currency: safeGet(DEFAULT_CURRENCY, 1, DEFAULT_CURRENCY[0])!,
  color: COLORS_MAP[0].code,
  isShared: false,
  isActive: false,
  ownerId: '',
  createdAt: getLocalISODateTimeWithOffset(),
  updatedAt: '',
};

// 响应式数据
const form = reactive<Account>({
  serialNum: account.serialNum,
  name: account.name,
  description: account.description,
  type: account.type,
  balance: account.balance,
  currency: account.currency,
  color: account.color,
  isShared: account.isShared,
  isActive: account.isActive,
  ownerId: account.ownerId,
  createdAt: account.createdAt,
  updatedAt: account.updatedAt,
});

function validateForm(data: Account): boolean {
  try {
    AccountTypeSchema.parse(data);
    return true;
  }
  catch (e) {
    console.error('表单验证失败:', e);
    return false;
  }
}

function closeModal() {
  emit('close');
}

function saveAccount() {
  if (!validateForm(form))
    return;
  const accountData: Account = {
    ...form,
    serialNum: props.account?.serialNum || uuid(38),
    createdAt: props.account?.createdAt || getLocalISODateTimeWithOffset(),
    updatedAt: getLocalISODateTimeWithOffset(),
  };
  emit('save', accountData);
  closeModal();
}

// 监听器
watch(
  () => props.account,
  newVal => {
    if (newVal) {
      const clonedAccount = JSON.parse(JSON.stringify(newVal));
      Object.assign(form, clonedAccount);
    }
  },
  { immediate: true, deep: true },
);
</script>

<template>
  <div class="modal-mask">
    <div class="modal-mask-window-money">
      <div class="mb-4 flex items-center justify-between">
        <h3 class="text-lg font-semibold">
          {{ props.account ? t('financial.account.editAccount')
            : t('financial.account.addAccount') }}
        </h3>
        <button class="text-gray-500 hover:text-gray-700" @click="closeModal">
          <svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>
      <form @submit.prevent="saveAccount">
        <div class="mb-2 flex items-center justify-between">
          <label class="mb-2 text-sm text-gray-700 font-medium">{{ t('financial.account.accountName') }}</label>
          <input
            v-model="form.name" type="text" required class="w-2/3 modal-input-select"
            :placeholder="t('common.placeholders.enterName')"
          >
        </div>

        <div class="mb-2 flex items-center justify-between">
          <label class="mb-2 text-sm text-gray-700 font-medium">{{ t('financial.account.accountType') }}</label>
          <select v-model="form.type" required class="w-2/3 modal-input-select">
            <option value="Cash">
              {{ t('financial.accountTypes.cash') }}
            </option>
            <option value="Bank">
              {{ t('financial.accountTypes.bank') }}
            </option>
            <option value="Savings">
              {{ t('financial.accountTypes.savings') }}
            </option>
            <option value="CreditCard">
              {{ t('financial.accountTypes.creditCard') }}
            </option>
            <option value="Investment">
              {{ t('financial.accountTypes.investment') }}
            </option>
            <option value="WeChat">
              {{ t('financial.accountTypes.wechat') }}
            </option>
            <option value="Alipay">
              {{ t('financial.accountTypes.alipay') }}
            </option>
            <option value="CloudQuickPass">
              {{ t('financial.accountTypes.cloudQuickPass') }}
            </option>
            <option value="Other">
              {{ t('financial.accountTypes.other') }}
            </option>
          </select>
        </div>

        <div class="mb-2 flex items-center justify-between">
          <label class="mb-2 text-sm text-gray-700 font-medium">{{ t('financial.initialBalance') }}</label>
          <input
            v-model.number="form.balance" type="number" step="0.01" required class="w-2/3 modal-input-select"
            placeholder="0.00"
          >
        </div>

        <div class="mb-2 flex items-center justify-between">
          <label class="mb-2 text-sm text-gray-700 font-medium">{{ t('financial.currency') }}</label>
          <select v-model="form.currency.code" required class="w-2/3 modal-input-select">
            <option v-for="currency in currencys" :key="currency.code" :value="currency.code">
              {{ currency.nameZh }}
            </option>
          </select>
        </div>

        <div class="mb-2 flex items-center justify-between">
          <label class="mb-2 text-sm text-gray-700 font-medium">{{ t('financial.account.owner') }}</label>
          <select v-model="form.ownerId" required class="w-2/3 modal-input-select">
            <option v-for="currency in currencys" :key="currency.code" :value="currency.code">
              {{ currency.nameZh }}
            </option>
          </select>
        </div>

        <div class="mb-2 flex items-center justify-between">
          <div class="w-1/2">
            <label class="flex items-center">
              <input v-model="form.isShared" type="checkbox" class="mr-2 modal-input-select">
              <span class="text-sm text-gray-700 font-medium">{{ t('financial.account.shared') }}</span>
            </label>
          </div>
          <div class="w-1/2">
            <label class="flex items-center">
              <input v-model="form.isActive" type="checkbox" class="mr-2 modal-input-select">
              <span class="text-sm text-gray-700 font-medium">{{ t('financial.account.activate') }}</span>
            </label>
          </div>
        </div>

        <div class="mb-2 flex items-center justify-between">
          <label class="mb-2 text-sm text-gray-700 font-medium">{{ t('common.misc.color') }}</label>
          <ColorSelector v-model="form.color" :color-names="colorNameMap" />
        </div>

        <div class="mb-2">
          <textarea
            v-model="form.description" rows="3" class="w-full modal-input-select"
            :placeholder="`${t('common.misc.description')}（${t('common.misc.optional')}）`"
          />
        </div>

        <div class="flex justify-center space-x-3">
          <button type="button" class="modal-btn-x" @click="closeModal">
            <X class="wh-5" />
          </button>
          <button type="submit" class="modal-btn-check">
            <Check class="wh-5" />
          </button>
        </div>
      </form>
    </div>
  </div>
</template>

<style scoped>
/* 自定义样式 */
</style>
