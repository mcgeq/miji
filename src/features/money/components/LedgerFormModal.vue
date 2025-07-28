<script setup lang="ts">
import { Plus, Trash2, Users, X } from 'lucide-vue-next';
import { computed, onMounted, ref } from 'vue';
import { CURRENCY_CNY } from '@/constants/moneyConst';
import { MoneyDb } from '@/services/money/money';
import { DateUtils } from '@/utils/date';
import { Lg } from '@/utils/debugLog';
import { toast } from '@/utils/toast';
import { uuid } from '@/utils/uuid';
import type { Currency } from '@/schema/common';
import type { FamilyLedger } from '@/schema/money';
import type { MemberUserRole } from '@/schema/userRole';

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
  }
  catch (err: unknown) {
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
  members: [] as Array<{
    serialNum: string;
    name: string;
    role: MemberUserRole;
    isPrimary: boolean;
    permissions: string;
    createdAt: string;
    updated: string;
  }>,
  accounts: '',
  transactions: '',
  budgets: '',
  auditLogs: '',
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
  const newMember = {
    serialNum: `temp_${Date.now()}`, // 临时ID，保存时会由后端生成
    name: '',
    role: 'Member' as const,
    isPrimary: form.value.members.length === 0, // 第一个成员默认为主要成员
    permissions: '',
    createdAt: new Date().toISOString(),
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
    }
    else {
      // await familyLedgerStore.createLedger(ledgerData);
      toast.info('创建账本');
    }

    emit('save', ledgerData);
  }
  catch (error) {
    // toast.error(isEdit.value ? t('familyLedger.updateFailed') : t('familyLedger.createFailed'));
    Lg.e('LedgerFormModal', isEdit.value ? '更新账本失败' : '创建账本失败', error);
  }
  finally {
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
      createdAt: props.ledger.createdAt || '',
      updatedAt: props.ledger.updatedAt || '',
    };
  }
  else {
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
    class="fixed inset-0 z-[60] flex items-center justify-center bg-black bg-opacity-50"
    @click.self="$emit('close')"
  >
    <div class="max-h-[90vh] max-w-2xl w-full overflow-hidden rounded-lg bg-white shadow-2xl">
      <!-- 头部 -->
      <div class="flex items-center justify-between border-b border-gray-200 bg-gray-50 p-6">
        <h2 class="text-xl text-gray-800 font-bold">
          {{ isEdit ? t('familyLedger.editLedger') : t('familyLedger.createNewLedger') }}
        </h2>
        <button class="text-gray-400 transition-colors hover:text-gray-600" @click="$emit('close')">
          <X class="h-6 w-6" />
        </button>
      </div>

      <!-- 表单内容 -->
      <div class="max-h-[calc(90vh-160px)] overflow-y-auto p-6">
        <form class="space-y-6" @submit.prevent="handleSubmit">
          <!-- 基本信息 -->
          <div class="space-y-4">
            <h3 class="border-b border-gray-200 pb-2 text-lg text-gray-900 font-medium">
              {{ t('familyLedger.basicInfo')
              }}
            </h3>

            <!-- 账本名称 -->
            <div>
              <label for="name" class="mb-2 block text-sm text-gray-700 font-medium">
                {{ t('familyLedger.ledgerName') }} <span class="text-red-500">*</span>
              </label>
              <input
                id="name" v-model="form.name" type="text" required maxlength="50"
                :placeholder="t('common.placeholders.enterName')"
                class="w-full border border-gray-300 rounded-md px-3 py-2 focus:border-blue-500 focus:outline-none focus:ring-2 focus:ring-blue-500"
              >
              <p class="mt-1 text-xs text-gray-500">
                {{ form.name.length }}/50
              </p>
            </div>

            <!-- 账本描述 -->
            <div>
              <label for="description" class="mb-2 block text-sm text-gray-700 font-medium">
                {{ t('familyLedger.ledgerDescription') }}
              </label>
              <textarea
                id="description" v-model="form.description" rows="3" maxlength="200"
                :placeholder="t('common.placeholders.enterDescription')"
                class="w-full border border-gray-300 rounded-md px-3 py-2 focus:border-blue-500 focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
              <p class="mt-1 text-xs text-gray-500">
                {{ form.description.length }}/200
              </p>
            </div>
          </div>

          <!-- 货币设置 -->
          <div class="space-y-4">
            <h3 class="border-b border-gray-200 pb-2 text-lg text-gray-900 font-medium">
              {{
                t('familyLedger.currencySettings') }}
            </h3>

            <div>
              <label for="currency" class="mb-2 block text-sm text-gray-700 font-medium">
                {{ t('financial.baseCurrency') }} <span class="text-red-500">*</span>
              </label>
              <select
                id="currency" v-model="form.baseCurrency.code" required class="w-full border border-gray-300 rounded-md px-3 py-2 focus:border-blue-500 focus:outline-none focus:ring-2 focus:ring-blue-500"
                @change="updateCurrencyInfo"
              >
                <option value="">
                  {{ t('messages.selectCurrency') }}
                </option>
                <option v-for="currency in currencies" :key="currency.code" :value="currency.code">
                  {{ currency.symbol }} {{ currency.code }} - {{ t(currency.code) }}
                </option>
              </select>
              <p class="mt-1 text-xs text-gray-500">
                {{ t('messages.selectedAsDefault') }}
              </p>
            </div>
          </div>

          <!-- 成员管理 -->
          <div class="space-y-4">
            <div class="flex items-center justify-between border-b border-gray-200 pb-2">
              <h3 class="text-lg text-gray-900 font-medium">
                {{ t('familyLedger.members') }}
              </h3>
              <button
                type="button" class="flex items-center gap-1 text-sm text-blue-600 hover:text-blue-700"
                @click="addMember"
              >
                <Plus class="h-4 w-4" />
                {{ t('familyLedger.addMember') }}
              </button>
            </div>

            <div v-if="form.members.length === 0" class="py-6 text-center text-gray-500">
              <Users class="mx-auto mb-2 h-12 w-12 text-gray-300" />
              <p>{{ t('familyLedger.noMembers') }}</p>
              <p class="text-sm">
                {{ t('familyLedger.clickAddMember') }}
              </p>
            </div>

            <div v-else class="space-y-3">
              <div
                v-for="(member, index) in form.members" :key="index"
                class="flex items-center gap-3 border border-gray-200 rounded-md p-3"
              >
                <div class="flex-1">
                  <input
                    v-model="member.name" type="text" :placeholder="t('familyLedger.memberName')" required
                    maxlength="20"
                    class="w-full border border-gray-300 rounded px-2 py-1 text-sm focus:border-blue-500 focus:outline-none"
                  >
                </div>
                <div class="flex-1">
                  <select
                    v-model="member.role"
                    class="w-full border border-gray-300 rounded px-2 py-1 text-sm focus:border-blue-500 focus:outline-none"
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
                <div class="flex items-center gap-2">
                  <label class="flex items-center gap-1 text-sm text-gray-600">
                    <input v-model="member.isPrimary" type="checkbox" class="border-gray-300 rounded">
                    {{ t('familyLedger.primaryMember') }}
                  </label>
                  <button
                    type="button" class="p-1 text-red-500 hover:text-red-700" :disabled="form.members.length === 1"
                    @click="removeMember(index)"
                  >
                    <Trash2 class="h-4 w-4" />
                  </button>
                </div>
              </div>
            </div>
          </div>
        </form>
      </div>

      <!-- 底部操作栏 -->
      <div class="flex items-center justify-between border-t border-gray-200 bg-gray-50 p-6">
        <div class="text-sm text-gray-600">
          <span v-if="isEdit">{{ t('familyLedger.editLedger') }}</span>
          <span v-else>{{ t('familyLedger.createNewLedger') }}</span>
        </div>
        <div class="flex gap-3">
          <button
            type="button" class="border border-gray-300 rounded-md px-4 py-2 text-gray-700 transition-colors hover:bg-gray-50"
            @click="$emit('close')"
          >
            {{ t('common.actions.cancel') }}
          </button>
          <button
            :disabled="!isFormValid || saving" class="rounded-md bg-blue-600 px-4 py-2 text-white transition-colors disabled:cursor-not-allowed hover:bg-blue-700 disabled:opacity-50"
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
  @apply space-y-4;
}

.form-section h3 {
  @apply text-lg font-medium text-gray-900 border-b border-gray-200 pb-2;
}

.form-field {
  @apply space-y-2;
}

.form-label {
  @apply block text-sm font-medium text-gray-700;
}

.form-input {
  @apply w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500;
}

.form-help {
  @apply text-xs text-gray-500;
}

/* 成员卡片样式 */
.member-card {
  @apply flex items-center gap-3 p-3 border border-gray-200 rounded-md hover:border-gray-300 transition-colors;
}

.member-card input,
.member-card select {
  @apply px-2 py-1 border border-gray-300 rounded text-sm focus:outline-none focus:border-blue-500;
}

/* 按钮样式 */
.btn-primary {
  @apply px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed;
}

.btn-secondary {
  @apply px-4 py-2 border border-gray-300 rounded-md text-gray-700 hover:bg-gray-50 transition-colors;
}

.btn-danger {
  @apply text-red-500 hover:text-red-700 p-1;
}
</style>
