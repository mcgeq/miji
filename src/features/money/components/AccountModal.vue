<template>
  <div class="modal-mask">
    <div class="modal-mask-window-money">
      <div class="flex justify-between items-center mb-4">
        <h3 class="text-lg font-semibold">{{ props.account ? '编辑账户' : '添加账户' }}</h3>
        <button @click="closeModal" class="text-gray-500 hover:text-gray-700">
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
          </svg>
        </button>
      </div>
      <form @submit.prevent="saveAccount">
        <div class="mb-2 flex items-center justify-between">
          <label class="text-sm font-medium text-gray-700 mb-2">账户名称</label>
          <input
            v-model="form.name"
            type="text"
            required
            class="w-2/3 modal-input-select"
            placeholder="请输入账户名称"
          />
        </div>
 
        <div class="mb-2 flex items-center justify-between">
          <label class="text-sm font-medium text-gray-700 mb-2">账户类型</label>
          <select
            v-model="form.type"
            required
            class="w-2/3 modal-input-select"
          >
            <option value="Cash">现金</option>
            <option value="Bank">银行卡</option>
            <option value="Savings">储蓄账户</option>
            <option value="CreditCard">信用卡</option>
            <option value="Investment">投资账户</option>
            <option value="WeChat">微信</option>
            <option value="Alipay">支付宝</option>
            <option value="CloudQuickPass">云闪付</option>
            <option value="Other">其他</option>
          </select>
        </div>
 
        <div class="mb-2 flex items-center justify-between">
          <label class="text-sm font-medium text-gray-700 mb-2">初始余额</label>
          <input
            v-model.number="form.balance"
            type="number"
            step="0.01"
            required
            class="w-2/3 modal-input-select"
            placeholder="0.00"
          />
        </div>

        <div class="mb-2 flex items-center justify-between">
          <label class="text-sm font-medium text-gray-700 mb-2">币种</label>
          <select
            v-model="form.currency.code"
            required
            class="w-2/3 modal-input-select"
          >
            <option v-for="currency in currencys" :key="currency.code" :value="currency.code">
              {{ currency.nameZh }}
            </option>
          </select>
        </div>
        <div class="mb-2 flex items-center justify-between">
          <label class="text-sm font-medium text-gray-700 mb-2">所属</label>
          <select
            v-model="form.ownerId"
            required
            class="w-2/3 modal-input-select"
          >
            <option v-for="currency in currencys" :key="currency.code" :value="currency.code">
              {{ currency.nameZh }}
            </option>
          </select>
        </div>

        <div class="mb-2 flex items-center justify-between">
          <div class="w-1/2">
            <label class="flex items-center">
              <input
                v-model="form.isShared"
                type="checkbox"
                class="mr-2 modal-input-select"
              />
              <span class="text-sm font-medium text-gray-700">共享</span>
            </label>
          </div>
          <div class="w-1/2">
            <label class="flex items-center">
              <input
                v-model="form.isActive"
                type="checkbox"
                class="mr-2 modal-input-select"
              />
              <span class="text-sm font-medium text-gray-700">激活</span>
            </label>
          </div>
        </div>
        <div class="mb-2 flex items-center justify-between">
          <label class="text-sm font-medium text-gray-700 mb-2">颜色</label>
          <div class="flex gap-2">
            <div
              v-for="color in colors"
              :key="color"
              @click="form.color = color"
              :class="[
                'w-6 h-6 rounded-full cursor-pointer border-2',
                form.color === color ? 'border-gray-800' : 'border-gray-300'
              ]"
              :style="{ backgroundColor: color }"
            ></div>
          </div>
        </div>
        <div class="mb-2">
          <textarea
            v-model="form.description"
            rows="3"
            class="w-full modal-input-select"
            placeholder="账户描述（可选）"
          ></textarea>
        </div>
 
        <div class="flex justify-center space-x-3">
          <button
            type="button"
            @click="closeModal"
            class="modal-btn-x"
          >
            <X class="wh-5" />
          </button>
          <button
            type="submit"
            class="modal-btn-check"
          >
            <Check class="wh-5" />
          </button>
        </div>
      </form>
    </div>
  </div>
</template>

<script setup lang="ts">
import { Check, X } from 'lucide-vue-next';
import { uuid } from '@/utils/uuid';
import { getLocalISODateTimeWithOffset } from '@/utils/date';
import { Account, AccountTypeSchema } from '@/schema/money';
import { DEFAULT_COLORS, DEFAULT_CURRENCY } from '@/constants/moneyConst';
import { safeGet } from '@/utils/common';

interface Props {
  account: Account;
}
// 定义 props
const props = defineProps<Props>();

// 定义 emits
const emit = defineEmits(['close', 'save']);

const colors = ref(DEFAULT_COLORS);
const currencys = ref(DEFAULT_CURRENCY);

const account = props.account || {
  serialNum: '',
  name: '',
  description: '',
  type: AccountTypeSchema.enum.Other,
  balance: '0',
  currency: safeGet(DEFAULT_CURRENCY, 1),
  color: safeGet(DEFAULT_COLORS, 0),
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

const validateForm = (data: Account): boolean => {
  try {
    AccountTypeSchema.parse(data);
    return true;
  } catch (e) {
    console.error('表单验证失败:', e);
    return false;
  }
};
const closeModal = () => {
  emit('close');
};

const saveAccount = () => {
  if (!validateForm(form)) return;
  const accountData: Account = {
    ...form,
    serialNum: props.account?.serialNum || uuid(38),
    createdAt: props.account?.createdAt || getLocalISODateTimeWithOffset(),
    updatedAt: getLocalISODateTimeWithOffset(),
  };
  emit('save', accountData);
  closeModal();
};

// 监听器
watch(
  () => props.account,
  (newVal) => {
    if (newVal) {
      const clonedAccount = JSON.parse(JSON.stringify(newVal));
      Object.assign(form, clonedAccount);
    }
  },
  { immediate: true, deep: true },
);
</script>
<style scoped>
/* 自定义样式 */
</style>
