<script setup lang="ts">
import { useI18n } from 'vue-i18n';
import { Checkbox, FormRow, FormSection, Input, Modal, Select } from '@/components/ui';
import { CURRENCY_CNY } from '@/constants/moneyConst';
import { MoneyDb } from '@/services/money/money';
import { DateUtils } from '@/utils/date';
import { Lg } from '@/utils/debugLog';
import { getRoleName } from '../utils/family';
import FamilyMemberModal from './FamilyMemberModal.vue';
import type { SelectOption } from '@/components/ui';
import type { Currency } from '@/schema/common';
import type { FamilyLedger, FamilyMember } from '@/schema/money';
import type { Account } from '@/schema/money/account';

interface Props {
  ledger: FamilyLedger | null;
}

const props = defineProps<Props>();
const emit = defineEmits(['close', 'save']);
const { t, te } = useI18n();

const currencies = ref<Currency[]>([]);
const accounts = ref<Account[]>([]);

// 账本类型选项
const ledgerTypeOptions = computed<SelectOption[]>(() => [
  { value: 'FAMILY', label: '家庭账本' },
  { value: 'COUPLE', label: '情侣账本' },
  { value: 'ROOMMATE', label: '室友账本' },
  { value: 'GROUP', label: '团体账本' },
]);

// 货币选项
const currencyOptions = computed<SelectOption[]>(() =>
  currencies.value.map(currency => ({
    value: currency.code,
    label: `${currency.symbol} ${currency.code} - ${getCurrencyDisplayName(currency.code)}`,
  })),
);

// 结算周期选项
const settlementCycleOptions = computed<SelectOption[]>(() => [
  { value: 'WEEKLY', label: '每周' },
  { value: 'MONTHLY', label: '每月' },
  { value: 'QUARTERLY', label: '每季度' },
  { value: 'YEARLY', label: '每年' },
  { value: 'MANUAL', label: '手动结算' },
]);

const showMemberModal = ref(false);
const editingMember = ref<FamilyMember | null>(null);
const editingMemberIndex = ref(-1);
const showAccountSelector = ref(false);
const selectedAccounts = ref<Account[]>([]);
// 添加用于表单管理的状态
const memberList = ref<FamilyMember[]>([]);
const isSubmitting = ref(false);

// Fetch currencies asynchronously
async function loadCurrencies() {
  try {
    const fetchedCurrencies = await MoneyDb.listCurrencies();
    currencies.value = fetchedCurrencies;
  } catch (err: unknown) {
    Lg.e('AccountModal', 'Failed to load currencies:', err);
  }
}

// Load currencies and accounts on component setup
loadCurrencies();

// Fetch accounts asynchronously
async function loadAccounts() {
  try {
    const fetchedAccounts = await MoneyDb.listAccounts();
    accounts.value = fetchedAccounts;
  } catch (err: unknown) {
    Lg.e('FamilyLedgerModal', 'Failed to load accounts:', err);
  }
}

loadAccounts();

// 安全获取货币显示名称
function getCurrencyDisplayName(currencyCode: string): string {
  const key = `currency.${currencyCode}`;
  // 使用 te() 方法检查翻译键是否存在
  if (te(key)) {
    return t(key);
  }
  // 如果翻译不存在，返回货币代码本身
  return currencyCode;
}

const defaultLedger: FamilyLedger = {
  name: '',
  serialNum: '',
  description: '',
  baseCurrency: CURRENCY_CNY,
  memberList: [],
  auditLogs: '[]',
  // 扩展字段
  ledgerType: 'FAMILY',
  settlementCycle: 'MONTHLY',
  autoSettlement: false,
  settlementDay: 1,
  defaultSplitRule: null,
  // 统计字段
  totalIncome: 0,
  totalExpense: 0,
  sharedExpense: 0,
  personalExpense: 0,
  pendingSettlement: 0,
  members: 0,
  accounts: 0,
  transactions: 0,
  budgets: 0,
  lastSettlementAt: null,
  createdAt: DateUtils.getLocalISODateTimeWithOffset(),
  updatedAt: null,
};

// 先初始化一个空的 form
const form = reactive<FamilyLedger>(JSON.parse(JSON.stringify(defaultLedger)));

// 结算日选项计算 - 统一存储方案
const settlementDayOptions = computed(() => {
  switch (form.settlementCycle) {
    case 'WEEKLY':
      return {
        min: 1,
        max: 7,
        placeholder: '周几结算',
        options: [
          { value: 1, label: '周一' },
          { value: 2, label: '周二' },
          { value: 3, label: '周三' },
          { value: 4, label: '周四' },
          { value: 5, label: '周五' },
          { value: 6, label: '周六' },
          { value: 7, label: '周日' },
        ],
      };
    case 'MONTHLY':
      return {
        min: 1,
        max: 31,
        placeholder: '每月几号结算',
        options: Array.from({ length: 31 }, (_, i) => ({
          value: i + 1,
          label: `${i + 1}号`,
        })),
      };
    case 'QUARTERLY':
      return {
        min: 1,
        max: 31,
        placeholder: '每季度第一个月几号结算',
        options: Array.from({ length: 31 }, (_, i) => ({
          value: i + 1,
          label: `${i + 1}号`,
        })),
      };
    case 'YEARLY':
      return {
        min: 1,
        max: 366,
        placeholder: '输入1-366（每年第几天）',
        options: [], // 不提供预设选项，让用户直接输入数字
      };
    default: // MANUAL
      return {
        min: 1,
        max: 31,
        placeholder: '手动结算（无固定日期）',
        options: [],
      };
  }
});

// 结算日选项（动态）- 定义在 settlementDayOptions 之后
const settlementDaySelectOptions = computed<SelectOption[]>(() => {
  const opts = settlementDayOptions.value.options;
  return opts.map(opt => ({
    value: opt.value,
    label: opt.label,
  }));
});

// 当结算周期改变时，重置结算日到合理的默认值
watch(() => form.settlementCycle, () => {
  const options = settlementDayOptions.value;
  if (form.settlementDay < options.min || form.settlementDay > options.max) {
    form.settlementDay = options.min;
  }
});

// 获取结算日提示信息
function getSettlementDayHint(): string {
  switch (form.settlementCycle) {
    case 'WEEKLY':
      return '选择每周的固定结算日';
    case 'MONTHLY':
      return '选择每月的固定结算日期';
    case 'QUARTERLY':
      return '选择每季度第一个月的结算日期';
    case 'YEARLY': {
      const currentValue = form.settlementDay;
      const dateStr = getDayOfYearDescription(currentValue);
      return `输入每年的第几天进行结算（1-366）${dateStr ? ` - 当前：${dateStr}` : ''}`;
    }
    case 'MANUAL':
      return '手动结算模式，无需固定日期';
    default:
      return '';
  }
}

// 判断是否为闰年
function isLeapYear(year: number): boolean {
  return (year % 4 === 0 && year % 100 !== 0) || (year % 400 === 0);
}

// 将年度天数转换为可读的日期描述
function getDayOfYearDescription(dayOfYear: number): string {
  if (dayOfYear < 1 || dayOfYear > 366) return '';

  // 使用当前年份判断是否为闰年
  const currentYear = new Date().getFullYear();
  const isCurrentLeapYear = isLeapYear(currentYear);

  // 根据闰年状态设置每月天数
  const months = [31, isCurrentLeapYear ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

  let remainingDays = dayOfYear;
  let month = 0;

  // 查找对应的月份和日期
  for (let i = 0; i < months.length; i++) {
    if (remainingDays <= months[i]) {
      month = i + 1;
      break;
    }
    remainingDays -= months[i];
  }

  if (month === 0) {
    // 超出范围，可能是平年的第366天
    if (dayOfYear === 366 && !isCurrentLeapYear) {
      return '12月31日 (平年无第366天，将使用12月31日)';
    }
    return '';
  }

  const dateStr = `${month}月${remainingDays}日`;

  // 添加特殊情况说明
  if (dayOfYear === 60 && month === 2 && remainingDays === 29) {
    return `${dateStr} (仅闰年有效)`;
  } else if (dayOfYear === 366) {
    return `${dateStr} (仅闰年有效)`;
  } else if (dayOfYear > 59 && !isCurrentLeapYear && dayOfYear <= 365) {
    // 平年��况下，显示当前年份的实际日期
    return `${dateStr} (今年${currentYear}年为平年)`;
  }

  return dateStr;
}

function editMember(index: number) {
  editingMemberIndex.value = index;
  editingMember.value = { ...memberList.value[index] };
  showMemberModal.value = true;
}

function removeMember(index: number) {
  if (memberList.value[index]?.isPrimary)
    return;
  memberList.value.splice(index, 1);
}

function closeMemberModal() {
  showMemberModal.value = false;
  editingMember.value = null;
  editingMemberIndex.value = -1;
}

function saveMember(member: FamilyMember) {
  if (editingMemberIndex.value >= 0) {
    memberList.value[editingMemberIndex.value] = member;
  } else {
    memberList.value.push(member);
  }
  closeMemberModal();
}

// 账户管理方法
function toggleAccountSelector() {
  showAccountSelector.value = !showAccountSelector.value;
}

function toggleAccountSelection(account: Account) {
  const index = selectedAccounts.value.findIndex(a => a.serialNum === account.serialNum);
  if (index >= 0) {
    selectedAccounts.value.splice(index, 1);
  } else {
    selectedAccounts.value.push(account);
  }
}

function isAccountSelected(account: Account): boolean {
  return selectedAccounts.value.some(a => a.serialNum === account.serialNum);
}

function removeAccount(account: Account) {
  const index = selectedAccounts.value.findIndex(a => a.serialNum === account.serialNum);
  if (index >= 0) {
    selectedAccounts.value.splice(index, 1);
  }
}

function closeModal() {
  emit('close');
}

function saveLedger() {
  // 构建数据格式，确保与原始数据结构一致以支持 deepDiff
  const ledgerData = {
    ...form,
    // 规范化 baseCurrency 为字符串格式，保持与后端返回格式一致
    baseCurrency: form.baseCurrency.code,
    // ✅ 包含成员列表
    memberList: memberList.value,
    // 添加选中的账户信息
    selectedAccounts: selectedAccounts.value,
  };

  // 调试日志已移除

  emit('save', ledgerData);
}

function buildLedgerForm(source: FamilyLedger | null): FamilyLedger {
  if (!source) {
    // 初始化时清空列表
    memberList.value = [];
    return JSON.parse(JSON.stringify(defaultLedger));
  }

  // 填充列表数据
  memberList.value = source.memberList || [];

  // 处理 baseCurrency：优先使用后端返回的 baseCurrencyDetail
  let baseCurrencyValue = defaultLedger.baseCurrency;

  if (source.baseCurrencyDetail) {
    // ✅ 后端返回了完整的 Currency 对象，直接使用
    baseCurrencyValue = source.baseCurrencyDetail;
    // baseCurrencyDetail loaded from backend
  } else if (source.baseCurrency) {
    // 降级方案：如果后端没有返回 baseCurrencyDetail（兼容旧版本API）
    if (typeof source.baseCurrency === 'string') {
      const currencyCode = source.baseCurrency;

      // 尝试从已加载的 currencies 列表中查找
      const foundCurrency = currencies.value.find(c => c.code === currencyCode);

      if (foundCurrency) {
        baseCurrencyValue = foundCurrency;
      } else {
        // 构造临时对象
        baseCurrencyValue = {
          locale: 'zh-CN',
          code: currencyCode,
          symbol: currencyCode === 'CNY' ? '¥' : '$',
          isDefault: currencyCode === 'CNY',
          isActive: true,
          createdAt: DateUtils.getLocalISODateTimeWithOffset(),
          updatedAt: null,
        };
      }

      // Fallback: Converting baseCurrency string to object
    } else {
      baseCurrencyValue = source.baseCurrency;
    }
  }

  return {
    ...defaultLedger,
    ...source,
    baseCurrency: baseCurrencyValue,
    ledgerType: (source.ledgerType
      ? source.ledgerType.toUpperCase()
      : defaultLedger.ledgerType) as FamilyLedger['ledgerType'],
    settlementCycle: (source.settlementCycle
      ? source.settlementCycle.toUpperCase()
      : defaultLedger.settlementCycle) as FamilyLedger['settlementCycle'],
    settlementDay: (source.settlementDay && source.settlementDay > 0) ? source.settlementDay : defaultLedger.settlementDay,
  };
}

// 初始化表单数据
function initializeForm(source: FamilyLedger | null) {
  const newFormData = buildLedgerForm(source);
  Object.assign(form, newFormData);
}

// 加载账本的成员
async function loadLedgerMembers(ledgerSerialNum: string) {
  try {
    // Loading members for ledger

    // 获取账本的成员关联
    const ledgerMembers = await MoneyDb.listFamilyLedgerMembers();
    const memberIds = ledgerMembers
      .filter(lm => lm.familyLedgerSerialNum === ledgerSerialNum)
      .map(lm => lm.familyMemberSerialNum);

    // Found member IDs

    // 获取成员详情
    const memberPromises = memberIds.map(id => MoneyDb.getFamilyMember(id));
    const members = await Promise.all(memberPromises);

    // 更新表单的成员列表
    memberList.value = members.filter(m => m !== null) as FamilyMember[];

    // Members loaded successfully
  } catch (error) {
    Lg.e('FamilyLedgerModal', 'Failed to load ledger members:', error);
    console.error('❌ Error loading members:', error);
    memberList.value = [];
  }
}

// 加载账本的账户
async function loadLedgerAccounts(ledgerSerialNum: string) {
  try {
    // 获取账本的账户关联
    const ledgerAccounts = await MoneyDb.listFamilyLedgerAccountsByLedger(ledgerSerialNum);
    const accountIds = ledgerAccounts.map(la => la.accountSerialNum);

    // 获取账户详情
    const accountPromises = accountIds.map(id => MoneyDb.getAccount(id));
    const accountsData = await Promise.all(accountPromises);

    // 更新选中的账户列表
    selectedAccounts.value = accountsData.filter(a => a !== null) as Account[];
  } catch (error) {
    Lg.e('FamilyLedgerModal', 'Failed to load ledger accounts:', error);
    selectedAccounts.value = [];
  }
}

watch(
  () => props.ledger,
  async newVal => {
    initializeForm(newVal);

    // 如果是编辑模式，加载成员和账户列表
    if (newVal?.serialNum) {
      await Promise.all([
        loadLedgerMembers(newVal.serialNum),
        loadLedgerAccounts(newVal.serialNum),
      ]);
    } else {
      // 新建模式，清空选中的账户
      selectedAccounts.value = [];
    }
  },
  { immediate: true, deep: true },
);

// 组件挂载时初始化
onMounted(() => {
  loadCurrencies();
  loadAccounts();
});
</script>

<template>
  <Modal
    :open="true"
    :title="props.ledger ? '编辑家庭账本' : '创建家庭账本'"
    size="md"
    :confirm-loading="isSubmitting"
    @close="closeModal"
    @confirm="saveLedger"
  >
    <form @submit.prevent="saveLedger">
      <!-- 基本信息 -->
      <FormSection title="基本信息">
        <FormRow label="账本名称" required>
          <Input
            v-model="form.name"
            type="text"
            placeholder="请输入账本名称"
          />
        </FormRow>

        <FormRow label="账本描述" optional>
          <Input
            v-model="form.description"
            type="text"
            :max-length="200"
            placeholder="请输入账本描述（可选）"
          />
        </FormRow>

        <FormRow label="账本类型" required>
          <Select
            v-model="form.ledgerType"
            :options="ledgerTypeOptions"
            placeholder="请选择账本类型"
          />
        </FormRow>

        <FormRow label="基础币种" required>
          <Select
            v-model="form.baseCurrency.code"
            :options="currencyOptions"
            placeholder="请选择币种"
          />
        </FormRow>
      </FormSection>

      <!-- 结算设置 -->
      <FormSection title="结算设置">
        <FormRow label="结算周期" optional>
          <Select
            v-model="form.settlementCycle"
            :options="settlementCycleOptions"
          />
        </FormRow>

        <FormRow label="结算日" optional>
          <div class="flex flex-col gap-1 w-full">
            <Select
              v-if="settlementDayOptions.options.length > 0"
              v-model="form.settlementDay"
              :options="settlementDaySelectOptions"
            />
            <Input
              v-else
              v-model.number="form.settlementDay"
              type="number"
              :placeholder="settlementDayOptions.placeholder"
            />
            <div class="text-xs text-gray-500 dark:text-gray-400 italic mt-1">
              {{ getSettlementDayHint() }}
            </div>
          </div>
        </FormRow>

        <div class="mb-3">
          <Checkbox
            v-model="form.autoSettlement"
            label="启用自动结算"
          />
        </div>
      </FormSection>

      <!-- 成员管理 -->
      <div class="flex flex-col gap-3">
        <div class="flex items-center justify-between">
          <label class="text-sm font-medium text-gray-700 dark:text-gray-300">成员管理</label>
          <button
            type="button"
            class="w-12 h-12 rounded-full bg-gray-100 dark:bg-gray-800 text-gray-700 dark:text-gray-300 transition-colors hover:bg-gray-200 dark:hover:bg-gray-700 flex items-center justify-center"
            aria-label="添加成员"
            @click="showMemberModal = true"
          >
            <LucidePlus :size="12" />
          </button>
        </div>

        <div class="max-h-40 overflow-y-auto flex flex-col gap-2">
          <div
            v-for="(member, index) in memberList" :key="member.serialNum"
            class="p-2 rounded-lg bg-gray-50 dark:bg-gray-900/50 flex items-center justify-between"
          >
            <div class="flex gap-2 items-center">
              <LucideCrown v-if="member.isPrimary" :size="16" class="text-yellow-500" />
              <LucideUser v-else :size="16" class="text-gray-500 dark:text-gray-400" />
              <span class="text-sm font-medium text-gray-900 dark:text-white whitespace-nowrap">{{ member.name }}</span>
              <span class="text-xs text-gray-500 dark:text-gray-400 whitespace-nowrap">({{ getRoleName(member.role) }})</span>
            </div>
            <div class="flex gap-1">
              <button
                type="button"
                class="p-2 rounded-md transition-all bg-transparent text-gray-600 dark:text-gray-400 hover:bg-gray-200 dark:hover:bg-gray-700 hover:text-gray-900 dark:hover:text-white"
                title="编辑"
                @click="editMember(index)"
              >
                <LucideEdit :size="12" />
              </button>
              <button
                type="button"
                class="p-2 rounded-md transition-all bg-transparent text-red-600 dark:text-red-400 hover:bg-red-600 dark:hover:bg-red-500 hover:text-white disabled:opacity-50 disabled:cursor-not-allowed"
                title="移除"
                :disabled="member.isPrimary"
                @click="removeMember(index)"
              >
                <LucideTrash :size="12" />
              </button>
            </div>
          </div>
        </div>
      </div>

      <!-- 账户管理 -->
      <div class="flex flex-col gap-3">
        <div class="flex items-center justify-between">
          <label class="text-sm font-medium text-gray-700 dark:text-gray-300">账户管理</label>
          <button
            type="button"
            class="w-12 h-12 rounded-full bg-gray-100 dark:bg-gray-800 text-gray-700 dark:text-gray-300 transition-colors hover:bg-gray-200 dark:hover:bg-gray-700 flex items-center justify-center"
            aria-label="选择账户"
            @click="toggleAccountSelector"
          >
            <LucidePlus :size="12" />
          </button>
        </div>

        <!-- 已选账户列表 -->
        <div v-if="selectedAccounts.length > 0" class="max-h-40 overflow-y-auto flex flex-col gap-2 scrollbar-none">
          <div
            v-for="account in selectedAccounts"
            :key="account.serialNum"
            class="p-2 rounded-lg bg-gray-100 dark:bg-gray-800 flex items-center justify-between transition-colors hover:bg-gray-200 dark:hover:bg-gray-700"
          >
            <div class="flex items-center gap-2">
              <LucideWallet :size="16" class="text-blue-600 dark:text-blue-400" />
              <span class="text-sm font-medium text-gray-900 dark:text-white whitespace-nowrap">
                {{ account.name }} ({{ account.type }})
              </span>
            </div>
            <div class="flex gap-1">
              <button
                type="button"
                class="p-2 rounded-md transition-all bg-transparent text-red-600 dark:text-red-400 hover:bg-red-600 dark:hover:bg-red-500 hover:text-white"
                title="移除"
                @click="removeAccount(account)"
              >
                <LucideTrash :size="12" />
              </button>
            </div>
          </div>
        </div>

        <!-- 账户选择器下拉 -->
        <div v-if="showAccountSelector" class="mt-2 border border-gray-300 dark:border-gray-700 rounded-lg bg-white dark:bg-gray-800 max-h-60 overflow-hidden flex flex-col shadow-md">
          <div class="px-3 py-3 border-b border-gray-300 dark:border-gray-700 flex items-center justify-between font-medium text-sm text-gray-900 dark:text-white bg-gray-100 dark:bg-gray-900/50">
            <span>选择账户</span>
            <button
              type="button"
              class="p-1 transition-colors text-gray-500 dark:text-gray-400 hover:text-gray-900 dark:hover:text-white"
              @click="toggleAccountSelector"
            >
              <LucideX :size="16" />
            </button>
          </div>
          <div class="overflow-y-auto p-2 flex flex-col gap-1 scrollbar-none">
            <label
              v-for="account in accounts"
              :key="account.serialNum"
              class="flex items-center gap-2 p-2 rounded-md cursor-pointer transition-colors hover:bg-gray-100 dark:hover:bg-gray-700"
            >
              <input
                type="checkbox"
                class="w-4 h-4 accent-blue-600 cursor-pointer"
                :checked="isAccountSelected(account)"
                @change="toggleAccountSelection(account)"
              >
              <span class="text-sm font-medium text-gray-900 dark:text-white">{{ account.name }}</span>
              <span class="text-xs text-gray-500 dark:text-gray-400">({{ account.type }})</span>
            </label>
          </div>
        </div>
      </div>
    </form>

    <!-- 成员添加/编辑模态框 -->
    <FamilyMemberModal
      v-if="showMemberModal"
      :member="editingMember"
      :family-ledger-serial-num="props.ledger?.serialNum || ''"
      @close="closeMemberModal"
      @save="saveMember"
    />
  </Modal>
</template>

<style scoped>
.scrollbar-none {
  scrollbar-width: none; /* Firefox */
  -ms-overflow-style: none; /* IE/Edge */
}

.scrollbar-none::-webkit-scrollbar {
  display: none; /* Chrome/Safari/Opera */
}
</style>
