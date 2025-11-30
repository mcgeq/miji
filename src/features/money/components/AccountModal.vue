<script setup lang="ts">
  import { isNaN as isNaNValue } from 'es-toolkit/compat';
  import ColorSelector from '@/components/common/ColorSelector.vue';
  import type { SelectOption } from '@/components/ui';
  import { Checkbox, FormRow, Input, Modal, Select, Textarea } from '@/components/ui';
  import { useFormValidation } from '@/composables/useFormValidation';
  import { COLORS_MAP } from '@/constants/moneyConst';
  import type { Currency } from '@/schema/common';
  import type { Account, CreateAccountRequest, UpdateAccountRequest } from '@/schema/money';
  import {
    AccountTypeSchema,
    CreateAccountRequestSchema,
    UpdateAccountRequestSchema,
  } from '@/schema/money';
  import { MoneyDb } from '@/services/money/money';
  import { DateUtils } from '@/utils/date';
  import { Lg } from '@/utils/debugLog';
  import { deepDiff } from '@/utils/diff';
  import { deepClone } from '@/utils/objectUtils';
  import { toast } from '@/utils/toast';

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

  // 定义响应式数据（必须在使用前定义）
  const currencies = ref<Currency[]>([]);
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

  // 响应式数据
  const colorNameMap = ref(COLORS_MAP);
  const isSubmitting = ref(false);

  // 选项数据（依赖上面定义的响应式数据）
  const accountTypeOptions = computed<SelectOption[]>(() =>
    Object.values(AccountTypeSchema.enum).map(type => ({
      value: type,
      label: t(`financial.accountTypes.${type.toLowerCase()}`),
    })),
  );

  const currencyOptions = computed<SelectOption[]>(() =>
    currencies.value.map(currency => ({
      value: currency.code,
      label: t(`currency.${currency.code}`),
    })),
  );

  const userOptions = computed<SelectOption[]>(() =>
    users.value.map(user => ({
      value: user.serialNum,
      label: user.name,
    })),
  );

  // 表单验证
  const validation = useFormValidation(
    props.account ? UpdateAccountRequestSchema : CreateAccountRequestSchema,
  );

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
    ...(props.account ? deepClone(props.account) : {}),
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
    if (typeof value === 'number' && !isNaNValue(value) && value !== 0) {
      form.initialBalance = value;
    } else {
      const num = Number.parseFloat(value);
      if (!Number.isNaN(num)) {
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

    isSubmitting.value = true;
    try {
      if (!props.account) {
        // 创建模式：直接发送完整数据
        const requestData: CreateAccountRequest = commonRequestFields;
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        if (!validation.validateAll(requestData as any)) {
          toast.error(t('financial.account.validationFailed'));
          return;
        }
        emit('save', requestData);
      } else {
        // 编辑模式：只发送改变的字段
        const updatePartial = deepDiff(props.account, commonRequestFields, {
          ignoreKeys: ['createdAt', 'updatedAt'],
        }) as UpdateAccountRequest;

        // 如果没有任何改变，直接关闭
        if (Object.keys(updatePartial).length === 0) {
          toast.info(t('common.messages.noChanges'));
          closeModal();
          return;
        }

        // 验证改变的字段
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        if (!validation.validateAll(updatePartial as any)) {
          toast.error(t('financial.account.validationFailed'));
          return;
        }

        emit('update', props.account.serialNum, updatePartial);
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
        Object.assign(form, deepClone(newVal));
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

  watch(
    () => form.initialBalance,
    newBalance => {
      form.balance = newBalance;
    },
  );
</script>

<template>
  <Modal
    :open="true"
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
        <Input v-model="form.name" :placeholder="t('common.placeholders.enterName')" />
      </FormRow>

      <!-- 账户类型 -->
      <FormRow
        :label="t('financial.account.accountType')"
        required
        :error="validation.shouldShowError('type') ? validation.getError('type') : ''"
      >
        <Select
          v-model="form.type"
          :options="accountTypeOptions"
          :placeholder="t('financial.account.accountType')"
        />
      </FormRow>

      <!-- 初始余额 -->
      <FormRow
        :label="t('financial.initialBalance')"
        required
        :error="validation.shouldShowError('initialBalance') ? validation.getError('initialBalance') : ''"
      >
        <Input
          v-model="form.initialBalance"
          type="text"
          placeholder="0.00"
          @input="handleBalanceInput($event)"
          @blur="form.initialBalance = formatBalance(form.initialBalance)"
        />
      </FormRow>

      <!-- 货币 -->
      <FormRow
        :label="t('financial.currency')"
        required
        :error="validation.shouldShowError('currency') ? validation.getError('currency') : ''"
      >
        <Select
          v-model="form.currency.code"
          :options="currencyOptions"
          :placeholder="t('financial.currency')"
        />
      </FormRow>

      <!-- 所有者 -->
      <FormRow
        :label="t('financial.account.owner')"
        required
        :error="validation.shouldShowError('ownerId') ? validation.getError('ownerId') : ''"
      >
        <Select
          v-model="form.ownerId!"
          :options="userOptions"
          :placeholder="t('financial.account.owner')"
        />
      </FormRow>

      <!-- 共享和激活 -->
      <div class="flex gap-4 mb-3">
        <Checkbox v-model="form.isShared" :label="t('financial.account.shared')" />
        <Checkbox v-model="form.isActive" :label="t('financial.account.activate')" />
      </div>

      <!-- 颜色 -->
      <FormRow :label="t('common.misc.color')" optional>
        <ColorSelector
          v-model="formColor"
          width="full"
          :color-names="colorNameMap"
          :extended="true"
          :show-categories="true"
          :show-custom-color="true"
          :show-random-button="true"
        />
      </FormRow>

      <!-- 描述 -->
      <FormRow
        :error="validation.shouldShowError('description') ? validation.getError('description') : ''"
        full-width
      >
        <Textarea
          v-model="form.description"
          :rows="3"
          :max-length="200"
          :placeholder="t('common.misc.description')"
        />
      </FormRow>
    </form>
  </Modal>
</template>
