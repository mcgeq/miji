<script setup lang="ts">
import { useI18n } from 'vue-i18n';
import { CURRENCY_CNY } from '@/constants/moneyConst';
import { MoneyDb } from '@/services/money/money';
import { DateUtils } from '@/utils/date';
import { Lg } from '@/utils/debugLog';
import { toast } from '@/utils/toast';
import { uuid } from '@/utils/uuid';
import type { Currency } from '@/schema/common';
import type { FamilyLedger, FamilyMember } from '@/schema/money';

interface Props {
  ledger?: FamilyLedger | null;
}

const props = defineProps<Props>();

const emit = defineEmits<{
  close: [];
  save: [ledger: FamilyLedger];
}>();

const { t } = useI18n();

const saving = ref(false);
const isEdit = computed(() => !!props.ledger);
const currencies = ref<Currency[]>([]);

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
  members: [] as FamilyMember[],
  accounts: '',
  transactions: '',
  budgets: '',
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
  memberCount: 0,
  activeTransactionCount: 0,
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
  members: familyLedger.members,
  accounts: familyLedger.accounts,
  transactions: familyLedger.transactions,
  budgets: familyLedger.budgets,
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
  memberCount: familyLedger.memberCount,
  activeTransactionCount: familyLedger.activeTransactionCount,
  lastSettlementAt: familyLedger.lastSettlementAt,
  createdAt: familyLedger.createdAt,
  updatedAt: familyLedger.updatedAt,
});

// 表单验证
const isFormValid = computed(() => {
  return (
    form.value.name.trim().length > 0
    && form.value.baseCurrency.code
    && form.value.members.length > 0
    && form.value.members.every(member => member.name.trim().length > 0)
    && form.value.members.some(member => member.isPrimary)
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
    isPrimary: form.value.members.length === 0, // 第一个成员默认为主要成员
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
  form.value.members.push(newMember);
}

// 删除成员
function removeMember(index: number) {
  if (form.value.members.length === 1) {
    // 使用 toast 显示警告，实际项目中需要替换为你的 toast 实现
    return;
  }

  const memberToRemove = form.value.members[index];
  form.value.members.splice(index, 1);

  // 如果删除的是主要成员，且还有其他成员，则将第一个成员设为主要成员
  if (memberToRemove.isPrimary && form.value.members.length > 0) {
    form.value.members[0].isPrimary = true;
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
  const primaryMembers = form.value.members.filter(m => m.isPrimary);
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
    const localTime = DateUtils.getLocalISODateTimeWithOffset();
    const ledgerData: FamilyLedger = {
      ...form.value,
      serialNum: isEdit.value ? form.value.serialNum : uuid(38),
      createdAt: isEdit.value ? form.value.createdAt : localTime,
      updatedAt: localTime,
    };

    // TODO: 调用实际 API
    if (isEdit.value) {
      // await familyLedgerStore.updateLedger(ledgerData);
      toast.info('更新账本');
    } else {
      // await familyLedgerStore.createLedger(ledgerData);
      toast.info('创建账本');
    }

    emit('save', ledgerData);
  } catch (error) {
    // toast.error(isEdit.value ? t('familyLedger.updateFailed') : t('familyLedger.createFailed'));
    Lg.e('LedgerFormModal', isEdit.value ? '更新账本失败' : '创建账本失败', error);
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
      members: props.ledger.members ? [...props.ledger.members] : [],
      accounts: props.ledger.accounts || '',
      transactions: props.ledger.transactions || '',
      budgets: props.ledger.budgets || '',
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
      memberCount: props.ledger.memberCount || 0,
      activeTransactionCount: props.ledger.activeTransactionCount || 0,
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
      members: [],
      accounts: '',
      budgets: '',
      transactions: '',
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
      memberCount: 0,
      activeTransactionCount: 0,
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
  <div
    class="modal-overlay"
    @click.self="$emit('close')"
  >
    <div class="modal-container">
      <!-- 头部 -->
      <div class="modal-header">
        <h2 class="modal-title">
          {{ isEdit ? t('familyLedger.editLedger') : t('familyLedger.createNewLedger') }}
        </h2>
        <button class="modal-close-btn" @click="$emit('close')">
          <LucideX class="modal-icon" />
        </button>
      </div>

      <!-- 表单内容 -->
      <div class="modal-body">
        <form class="modal-form" @submit.prevent="handleSubmit">
          <!-- 基本信息 -->
          <div class="form-section">
            <h3 class="section-title">
              {{ t('familyLedger.basicInfo')
              }}
            </h3>

            <!-- 账本名称 -->
            <div class="form-field">
              <label for="name" class="form-label">
                {{ t('familyLedger.ledgerName') }} <span class="required-mark">*</span>
              </label>
              <input
                id="name" v-model="form.name" type="text" required maxlength="50"
                :placeholder="t('common.placeholders.enterName')"
                class="form-input"
              >
              <p class="form-help">
                {{ form.name.length }}/50
              </p>
            </div>

            <!-- 账本描述 -->
            <div class="form-field">
              <label for="description" class="form-label">
                {{ t('familyLedger.ledgerDescription') }}
              </label>
              <textarea
                id="description" v-model="form.description" rows="3" maxlength="200"
                :placeholder="t('common.placeholders.enterDescription')"
                class="form-input"
              />
              <p class="form-help">
                {{ form.description.length }}/200
              </p>
            </div>
          </div>

          <!-- 货币设置 -->
          <div class="form-section">
            <h3 class="section-title">
              {{
                t('familyLedger.currencySettings') }}
            </h3>

            <div class="form-field">
              <label for="currency" class="form-label">
                {{ t('financial.baseCurrency') }} <span class="required-mark">*</span>
              </label>
              <select
                id="currency" v-model="form.baseCurrency.code" required class="form-input"
                @change="updateCurrencyInfo"
              >
                <option value="">
                  {{ t('messages.selectCurrency') }}
                </option>
                <option v-for="currency in currencies" :key="currency.code" :value="currency.code">
                  {{ currency.symbol }} {{ currency.code }} - {{ t(currency.code) }}
                </option>
              </select>
              <p class="form-help">
                {{ t('messages.selectedAsDefault') }}
              </p>
            </div>
          </div>

          <!-- 成员管理 -->
          <div class="space-y-4">
            <div class="pb-2 border-b border-gray-200 flex items-center justify-between">
              <h3 class="text-lg text-gray-900 font-medium">
                {{ t('familyLedger.members') }}
              </h3>
              <button
                type="button" class="text-sm text-blue-600 flex gap-1 items-center hover:text-blue-700"
                @click="addMember"
              >
                <LucidePlus class="h-4 w-4" />
                {{ t('familyLedger.addMember') }}
              </button>
            </div>

            <div v-if="form.members.length === 0" class="text-gray-500 py-6 text-center">
              <LucideUsers class="text-gray-300 mx-auto mb-2 h-12 w-12" />
              <p>{{ t('familyLedger.noMembers') }}</p>
              <p class="text-sm">
                {{ t('familyLedger.clickAddMember') }}
              </p>
            </div>

            <div v-else class="space-y-3">
              <div
                v-for="(member, index) in form.members" :key="index"
                class="p-3 border border-gray-200 rounded-md flex gap-3 items-center"
              >
                <div class="flex-1">
                  <input
                    v-model="member.name" type="text" :placeholder="t('familyLedger.memberName')" required
                    maxlength="20"
                    class="text-sm px-2 py-1 border border-gray-300 rounded w-full focus:outline-none focus:border-blue-500"
                  >
                </div>
                <div class="flex-1">
                  <select
                    v-model="member.role"
                    class="text-sm px-2 py-1 border border-gray-300 rounded w-full focus:outline-none focus:border-blue-500"
                  >
                    <option value="Owner">
                      {{ t('roles.owner') }}
                    </option>
                    <option value="Admin">
                      {{ t('roles.admin') }}
                    </option>
                    <option value="Member">
                      {{ t('roles.member') }}
                    </option>
                    <option value="Viewer">
                      {{ t('roles.viewer') }}
                    </option>
                  </select>
                </div>
                <div class="flex gap-2 items-center">
                  <label class="text-sm text-gray-600 flex gap-1 items-center">
                    <input v-model="member.isPrimary" type="checkbox" class="border-gray-300 rounded">
                    {{ t('familyLedger.primaryMember') }}
                  </label>
                  <button
                    type="button" class="text-red-500 p-1 hover:text-red-700" :disabled="form.members.length === 1"
                    @click="removeMember(index)"
                  >
                    <LucideTrash2 class="h-4 w-4" />
                  </button>
                </div>
              </div>
            </div>
          </div>
        </form>
      </div>

      <!-- 底部操作栏 -->
      <div class="p-6 border-t border-gray-200 bg-gray-50 flex items-center justify-between">
        <div class="text-sm text-gray-600">
          <span v-if="isEdit">{{ t('familyLedger.editLedger') }}</span>
          <span v-else>{{ t('familyLedger.createNewLedger') }}</span>
        </div>
        <div class="flex gap-3">
          <button
            type="button" class="text-gray-700 px-4 py-2 border border-gray-300 rounded-md transition-colors hover:bg-gray-50"
            @click="$emit('close')"
          >
            {{ t('common.actions.cancel') }}
          </button>
          <button
            :disabled="!isFormValid || saving" class="text-white px-4 py-2 rounded-md bg-blue-600 transition-colors hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
            @click="handleSubmit"
          >
            <span v-if="saving">{{ t('common.misc.saving') }}</span>
            <span v-else>{{ isEdit ? t('common.actions.update') : t('common.actions.create') }}</span>
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped lang="postcss">
/* 自定义滚动条样式 */
.overflow-y-auto::-webkit-scrollbar {
  width: 6px;
}

.overflow-y-auto::-webkit-scrollbar-track {
  background: #f1f1f1;
  border-radius: 3px;
}

.overflow-y-auto::-webkit-scrollbar-thumb {
  background: #c1c1c1;
  border-radius: 3px;
}

.overflow-y-auto::-webkit-scrollbar-thumb:hover {
  background: #a1a1a1;
}

/* 表单样式优化 */
.form-section {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.form-section h3 {
  font-size: 1.125rem;
  font-weight: 500;
  color: #111827;
  border-bottom: 1px solid #e5e7eb;
  padding-bottom: 0.5rem;
}

.form-field {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.form-label {
  display: block;
  font-size: 0.875rem;
  font-weight: 500;
  color: #374151;
}

.form-input {
  width: 100%;
  padding: 0.5rem 0.75rem;
  border: 1px solid #d1d5db;
  border-radius: 0.375rem;
  transition: all 0.2s ease-in-out;
}

.form-input:focus {
  outline: none;
  ring: 2px;
  ring-color: #3b82f6;
  border-color: #3b82f6;
}

.form-help {
  font-size: 0.75rem;
  color: #6b7280;
}

/* 成员卡片样式 */
.member-card {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.75rem;
  border: 1px solid #e5e7eb;
  border-radius: 0.375rem;
  transition: all 0.2s ease-in-out;
}

.member-card:hover {
  border-color: #d1d5db;
}

.member-card input,
.member-card select {
  padding: 0.25rem 0.5rem;
  border: 1px solid #d1d5db;
  border-radius: 0.25rem;
  font-size: 0.875rem;
  transition: all 0.2s ease-in-out;
}

.member-card input:focus,
.member-card select:focus {
  outline: none;
  border-color: #3b82f6;
}

/* 按钮样式 */
.btn-primary {
  padding: 0.5rem 1rem;
  background-color: #2563eb;
  color: white;
  border-radius: 0.375rem;
  transition: all 0.2s ease-in-out;
}

.btn-primary:hover {
  background-color: #1d4ed8;
}

.btn-primary:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.btn-secondary {
  padding: 0.5rem 1rem;
  border: 1px solid #d1d5db;
  border-radius: 0.375rem;
  color: #374151;
  transition: all 0.2s ease-in-out;
}

.btn-secondary:hover {
  background-color: #f9fafb;
}

.btn-danger {
  color: #ef4444;
  padding: 0.25rem;
  transition: all 0.2s ease-in-out;
}

.btn-danger:hover {
  color: #b91c1c;
}

/* 模态框样式 */
.modal-overlay {
  background-color: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  inset: 0;
  justify-content: center;
  position: fixed;
  z-index: 60;
}

.modal-container {
  border-radius: 0.5rem;
  background-color: white;
  max-height: 90vh;
  max-width: 42rem;
  width: 100%;
  box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
  overflow: hidden;
}

.modal-header {
  padding: 1.5rem;
  border-bottom: 1px solid #e5e7eb;
  background-color: #f9fafb;
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.modal-title {
  font-size: 1.25rem;
  color: #1f2937;
  font-weight: 700;
}

.modal-close-btn {
  color: #9ca3af;
  transition: color 0.2s ease-in-out;
}

.modal-close-btn:hover {
  color: #4b5563;
}

.modal-icon {
  height: 1.5rem;
  width: 1.5rem;
}

.modal-body {
  padding: 1.5rem;
  max-height: calc(90vh - 160px);
  overflow-y: auto;
}

.modal-form {
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
}

.form-section {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.section-title {
  font-size: 1.125rem;
  color: #111827;
  font-weight: 500;
  padding-bottom: 0.5rem;
  border-bottom: 1px solid #e5e7eb;
}

.form-field {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.form-label {
  font-size: 0.875rem;
  color: #374151;
  font-weight: 500;
  margin-bottom: 0.5rem;
  display: block;
}

.required-mark {
  color: #ef4444;
}

.form-input {
  padding: 0.5rem 0.75rem;
  border: 1px solid #d1d5db;
  border-radius: 0.375rem;
  width: 100%;
  transition: all 0.2s ease-in-out;
}

.form-input:focus {
  outline: none;
  border-color: #3b82f6;
  ring: 2px;
  ring-color: #3b82f6;
}

.form-help {
  font-size: 0.75rem;
  color: #6b7280;
  margin-top: 0.25rem;
}
</style>
