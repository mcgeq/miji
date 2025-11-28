<script setup lang="ts">
import { useI18n } from 'vue-i18n';
import { Checkbox, FormRow, Input, Modal, Select, Textarea } from '@/components/ui';
import { CURRENCY_CNY } from '@/constants/moneyConst';
import { MoneyDb } from '@/services/money/money';
import { useFamilyLedgerStore } from '@/stores/money';
import { Lg } from '@/utils/debugLog';
import { toast } from '@/utils/toast';
import type { SelectOption } from '@/components/ui';
import type { Currency } from '@/schema/common';
import type { FamilyLedger, FamilyLedgerCreate, FamilyLedgerUpdate, FamilyMember } from '@/schema/money';

interface Props {
  ledger?: FamilyLedger | null;
}

const props = defineProps<Props>();

const emit = defineEmits<{
  close: [];
  save: [ledger: FamilyLedger];
}>();

const { t } = useI18n();
const familyLedgerStore = useFamilyLedgerStore();

const saving = ref(false);
const isSubmitting = ref(false);
const isEdit = computed(() => !!props.ledger);
const currencies = ref<Currency[]>([]);

// 货币选项
const currencyOptions = computed<SelectOption[]>(() =>
  currencies.value.map(currency => ({
    value: currency.code,
    label: `${currency.symbol} ${currency.code} - ${t(currency.code)}`,
  })),
);

// 角色选项
const roleOptions = computed<SelectOption[]>(() => [
  { value: 'Owner', label: t('roles.owner') },
  { value: 'Admin', label: t('roles.admin') },
  { value: 'Member', label: t('roles.member') },
  { value: 'Viewer', label: t('roles.viewer') },
]);

// Fetch currencies asynchronously
async function loadCurrencies() {
  try {
    const fetchedCurrencies = await MoneyDb.listCurrencies();
    currencies.value = fetchedCurrencies;
  } catch (err: unknown) {
    Lg.e('AccountModal', 'Failed to load currencies:', err);
  }
}

// Call loadCurrencies on component setup
loadCurrencies();

const familyLedger = props.ledger || {
  serialNum: '',
  name: '',
  description: '',
  baseCurrency: CURRENCY_CNY,
  memberList: [] as FamilyMember[],
  members: 0,
  accounts: 0,
  transactions: 0,
  budgets: 0,
  auditLogs: '',
  ledgerType: 'FAMILY' as const,
  settlementCycle: 'MONTHLY' as const,
  autoSettlement: false,
  settlementDay: 1,
  defaultSplitRule: null,
  totalIncome: 0,
  totalExpense: 0,
  sharedExpense: 0,
  personalExpense: 0,
  pendingSettlement: 0,
  lastSettlementAt: null,
  createdAt: '',
  updatedAt: '',
};

// 表单数据
const form = ref<FamilyLedger>({
  serialNum: familyLedger.serialNum,
  name: familyLedger.name,
  description: familyLedger.description,
  baseCurrency: familyLedger.baseCurrency,
  memberList: familyLedger.memberList || [],
  members: familyLedger.members || 0,
  accounts: familyLedger.accounts || 0,
  transactions: familyLedger.transactions || 0,
  budgets: familyLedger.budgets || 0,
  auditLogs: familyLedger.auditLogs,
  ledgerType: familyLedger.ledgerType,
  settlementCycle: familyLedger.settlementCycle,
  autoSettlement: familyLedger.autoSettlement,
  settlementDay: familyLedger.settlementDay,
  defaultSplitRule: familyLedger.defaultSplitRule,
  totalIncome: familyLedger.totalIncome,
  totalExpense: familyLedger.totalExpense,
  sharedExpense: familyLedger.sharedExpense,
  personalExpense: familyLedger.personalExpense,
  pendingSettlement: familyLedger.pendingSettlement,
  lastSettlementAt: familyLedger.lastSettlementAt,
  createdAt: familyLedger.createdAt,
  updatedAt: familyLedger.updatedAt,
});

// 表单验证
const isFormValid = computed(() => {
  return (
    form.value.name.trim().length > 0
    && form.value.baseCurrency.code
    && form.value.memberList && form.value.memberList.length > 0
    && form.value.memberList.every(member => member.name.trim().length > 0)
    && form.value.memberList.some(member => member.isPrimary)
  );
});

// 更新货币信息
function updateCurrencyInfo() {
  const selected = currencies.value.find(
    c => c.code === form.value.baseCurrency.code,
  );
  if (selected) {
    form.value.baseCurrency = { ...selected };
  }
}

// 添加成员
function addMember() {
  const newMember: FamilyMember = {
    serialNum: `temp_${Date.now()}`, // 临时ID，保存时会由后端生成
    name: '',
    role: 'Member' as const,
    isPrimary: form.value.memberList!.length === 0, // 第一个成员默认为主要成员
    permissions: '',
    userSerialNum: null,
    avatar: null,
    colorTag: null,
    totalPaid: 0,
    totalOwed: 0,
    netBalance: 0,
    transactionCount: 0,
    splitCount: 0,
    lastActiveAt: null,
    createdAt: new Date().toISOString(),
    updatedAt: null,
  };
  form.value.memberList!.push(newMember);
}

// 删除成员
function removeMember(index: number) {
  if (form.value.memberList!.length === 1) {
    // 使用 toast 显示警告，实际项目中需要替换为你的 toast 实现
    return;
  }

  const memberToRemove = form.value.memberList![index];
  form.value.memberList!.splice(index, 1);

  // 如果删除的是主要成员，且还有其他成员，则将第一个成员设为主要成员
  if (memberToRemove.isPrimary && form.value.memberList!.length > 0) {
    form.value.memberList![0].isPrimary = true;
  }
}

// 提交表单
async function handleSubmit() {
  if (!isFormValid.value) {
    // toast.warning(t('messages.pleaseFillRequired'));
    toast.warning('请完善必填信息');
    return;
  }

  // 确保只有一个主要成员
  const primaryMembers = form.value.memberList!.filter(m => m.isPrimary);
  if (primaryMembers.length === 0) {
    // toast.warning(t('messages.atLeastOnePrimary'));
    toast.warning('请至少指定一个主要成员');
    return;
  }
  if (primaryMembers.length > 1) {
    // toast.warning(t('messages.onlyOnePrimary'));
    console.warn('只能有一个主要成员');
    return;
  }

  saving.value = true;
  try {
    let savedLedger: FamilyLedger;

    // 提取货币代码（API需要字符串，而不是Currency对象）
    const currencyCode = typeof form.value.baseCurrency === 'string'
      ? form.value.baseCurrency
      : form.value.baseCurrency.code;

    if (isEdit.value) {
      // 更新账本
      const updateData: FamilyLedgerUpdate = {
        name: form.value.name,
        description: form.value.description,
        baseCurrency: currencyCode,
      };
      savedLedger = await familyLedgerStore.updateLedger(form.value.serialNum, updateData);
      toast.success('账本更新成功');
    } else {
      // 创建账本
      const createData: FamilyLedgerCreate = {
        name: form.value.name,
        description: form.value.description,
        baseCurrency: currencyCode,
        memberList: form.value.memberList || [],
        ledgerType: form.value.ledgerType || 'FAMILY',
        settlementCycle: form.value.settlementCycle || 'MONTHLY',
        autoSettlement: form.value.autoSettlement || false,
        settlementDay: form.value.settlementDay || 1,
        defaultSplitRule: form.value.defaultSplitRule || null,
      };
      savedLedger = await familyLedgerStore.createLedger(createData);
      toast.success('账本创建成功');
    }

    emit('save', savedLedger);
  } catch (error: any) {
    const errorMsg = isEdit.value ? '更新账本失败' : '创建账本失败';
    toast.error(error.message || errorMsg);
    Lg.e('LedgerFormModal', errorMsg, error);
  } finally {
    saving.value = false;
  }
}

// 初始化表单数据
function initializeForm() {
  if (props.ledger) {
    // 编辑模式：填充现有数据
    form.value = {
      serialNum: props.ledger.serialNum || '',
      name: props.ledger.name || '',
      description: props.ledger.description || '',
      baseCurrency: props.ledger.baseCurrency || CURRENCY_CNY,
      memberList: props.ledger.memberList ? [...props.ledger.memberList] : [],
      members: props.ledger.members || 0,
      accounts: props.ledger.accounts || 0,
      transactions: props.ledger.transactions || 0,
      budgets: props.ledger.budgets || 0,
      auditLogs: props.ledger.auditLogs || '',
      ledgerType: props.ledger.ledgerType || 'FAMILY',
      settlementCycle: props.ledger.settlementCycle || 'MONTHLY',
      autoSettlement: props.ledger.autoSettlement || false,
      settlementDay: props.ledger.settlementDay || 1,
      defaultSplitRule: props.ledger.defaultSplitRule || null,
      totalIncome: props.ledger.totalIncome || 0,
      totalExpense: props.ledger.totalExpense || 0,
      sharedExpense: props.ledger.sharedExpense || 0,
      personalExpense: props.ledger.personalExpense || 0,
      pendingSettlement: props.ledger.pendingSettlement || 0,
      lastSettlementAt: props.ledger.lastSettlementAt || null,
      createdAt: props.ledger.createdAt || '',
      updatedAt: props.ledger.updatedAt || '',
    };
  } else {
    // 创建模式：默认值
    form.value = {
      serialNum: '',
      name: '',
      description: '',
      baseCurrency: CURRENCY_CNY,
      memberList: [],
      members: 0,
      accounts: 0,
      budgets: 0,
      transactions: 0,
      auditLogs: '',
      ledgerType: 'FAMILY',
      settlementCycle: 'MONTHLY',
      autoSettlement: false,
      settlementDay: 1,
      defaultSplitRule: null,
      totalIncome: 0,
      totalExpense: 0,
      sharedExpense: 0,
      personalExpense: 0,
      pendingSettlement: 0,
      lastSettlementAt: null,
      createdAt: '',
      updatedAt: '',
    };

    // 自动添加一个默认成员
    addMember();
  }
}

onMounted(() => {
  initializeForm();
});
</script>

<template>
  <Modal
    :open="true"
    :title="isEdit ? t('familyLedger.editLedger') : t('familyLedger.createNewLedger')"
    size="md"
    :confirm-loading="isSubmitting || saving"
    @close="$emit('close')"
    @confirm="handleSubmit"
  >
    <form @submit.prevent="handleSubmit">
      <!-- 基本信息 -->
      <div class="flex flex-col gap-0 mb-6">
        <h3 class="text-lg text-gray-900 dark:text-white font-medium pb-2 mb-3 border-b border-gray-200 dark:border-gray-700">
          {{ t('familyLedger.basicInfo') }}
        </h3>

        <FormRow :label="t('familyLedger.ledgerName')" required>
          <Input
            v-model="form.name"
            type="text"
            :max-length="50"
            :placeholder="t('common.placeholders.enterName')"
          />
        </FormRow>

        <FormRow full-width>
          <Textarea
            v-model="form.description"
            :rows="3"
            :max-length="200"
            :placeholder="t('common.placeholders.enterDescription')"
          />
        </FormRow>
      </div>

      <!-- 货币设置 -->
      <div class="flex flex-col gap-0 mb-6">
        <h3 class="text-lg text-gray-900 dark:text-white font-medium pb-2 mb-3 border-b border-gray-200 dark:border-gray-700">
          {{ t('familyLedger.currencySettings') }}
        </h3>

        <FormRow :label="t('financial.baseCurrency')" required>
          <Select
            v-model="form.baseCurrency.code"
            :options="currencyOptions"
            :placeholder="t('messages.selectCurrency')"
            @update:model-value="updateCurrencyInfo"
          />
          <p class="text-xs text-gray-500 dark:text-gray-400 mt-1">
            {{ t('messages.selectedAsDefault') }}
          </p>
        </FormRow>
      </div>

      <!-- 成员管理 -->
      <div class="space-y-4">
        <div class="pb-2 border-b border-gray-200 dark:border-gray-700 flex items-center justify-between">
          <h3 class="text-lg text-gray-900 dark:text-white font-medium">
            {{ t('familyLedger.members') }}
          </h3>
          <button
            type="button" class="text-sm text-blue-600 dark:text-blue-400 flex gap-1 items-center hover:text-blue-700 dark:hover:text-blue-300 transition-colors"
            @click="addMember"
          >
            <LucidePlus :size="16" />
            {{ t('familyLedger.addMember') }}
          </button>
        </div>

        <div v-if="form.memberList && form.memberList.length === 0" class="text-gray-500 dark:text-gray-400 py-6 text-center">
          <LucideUsers :size="48" class="text-gray-300 dark:text-gray-600 mx-auto mb-2" />
          <p class="mb-1">
            {{ t('familyLedger.noMembers') }}
          </p>
          <p class="text-sm text-gray-400 dark:text-gray-500">
            {{ t('familyLedger.clickAddMember') }}
          </p>
        </div>

        <div v-else class="space-y-3">
          <div
            v-for="(member, index) in form.memberList" :key="index"
            class="p-3 border border-gray-200 dark:border-gray-700 rounded-lg bg-white dark:bg-gray-900/50 flex flex-col sm:flex-row gap-3 items-start sm:items-center"
          >
            <div class="flex-1">
              <Input
                v-model="member.name"
                type="text"
                size="sm"
                :placeholder="t('familyLedger.memberName')"
              />
            </div>
            <div class="flex-1">
              <Select
                v-model="member.role"
                :options="roleOptions"
                size="sm"
              />
            </div>
            <div class="flex gap-2 items-center shrink-0">
              <Checkbox
                v-model="member.isPrimary"
                :label="t('familyLedger.primaryMember')"
              />
              <button
                type="button"
                class="text-red-500 dark:text-red-400 p-1.5 rounded hover:text-red-700 dark:hover:text-red-300 hover:bg-red-50 dark:hover:bg-red-900/20 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                :disabled="form.memberList && form.memberList.length === 1"
                @click="removeMember(index)"
              >
                <LucideTrash2 :size="16" />
              </button>
            </div>
          </div>
        </div>
      </div>
    </form>
  </Modal>
</template>
