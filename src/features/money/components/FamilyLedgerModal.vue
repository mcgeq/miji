<script setup lang="ts">
import { CURRENCY_CNY } from '@/constants/moneyConst';
import { MoneyDb } from '@/services/money/money';
import { DateUtils } from '@/utils/date';
import { Lg } from '@/utils/debugLog';
import { getRoleName } from '../utils/family';
import FamilyMemberModal from './FamilyMemberModal.vue';
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
const showMemberModal = ref(false);
const editingMember = ref<FamilyMember | null>(null);
const editingMemberIndex = ref(-1);
const showAccountSelector = ref(false);
const selectedAccounts = ref<Account[]>([]);
// 添加用于表单管理的状态
const memberList = ref<FamilyMember[]>([]);

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
  <div class="modal-mask">
    <div class="modal-mask-window-money">
      <div class="modal-header">
        <h3 class="modal-title">
          {{ props.ledger ? '编辑家庭账本' : '创建家庭账本' }}
        </h3>
        <button class="modal-close-btn" @click="closeModal">
          <LucideX class="modal-icon" />
        </button>
      </div>

      <form class="modal-form" @submit.prevent="saveLedger">
        <!-- 基本信息 -->
        <div class="form-section">
          <div class="form-row">
            <label class="form-label">账本名称</label>
            <input
              v-model="form.name" type="text" required class="modal-input-select form-input-2-3"
              placeholder="请输入账本名称"
            >
          </div>

          <div class="form-row">
            <label class="form-label">账本描述</label>
            <input
              v-model="form.description" type="text" class="modal-input-select form-input-2-3"
              placeholder="请输入账本描述（可选）"
            >
          </div>

          <div class="form-row">
            <label class="form-label">账本类型</label>
            <select v-model="form.ledgerType" required class="modal-input-select form-input-2-3">
              <option value="FAMILY">
                家庭账本
              </option>
              <option value="SHARED">
                共享账本
              </option>
              <option value="PROJECT">
                项目账本
              </option>
            </select>
          </div>

          <div class="form-row">
            <label class="form-label">基础币种</label>
            <select v-model="form.baseCurrency.code" required class="modal-input-select form-input-2-3">
              <option v-for="currency in currencies" :key="currency.code" :value="currency.code">
                {{ getCurrencyDisplayName(currency.code) }} ({{ currency.code }})
              </option>
            </select>
          </div>
        </div>

        <!-- 结算设置 -->
        <div class="form-section">
          <div class="form-row">
            <label class="form-label">结算周期</label>
            <select v-model="form.settlementCycle" class="modal-input-select form-input-2-3">
              <option value="WEEKLY">
                每周
              </option>
              <option value="MONTHLY">
                每月
              </option>
              <option value="QUARTERLY">
                每季度
              </option>
              <option value="YEARLY">
                每年
              </option>
              <option value="MANUAL">
                手动结算
              </option>
            </select>
          </div>

          <div class="form-row">
            <label class="form-label">结算日</label>
            <div class="form-input-2-3 form-input-wrapper">
              <select
                v-if="settlementDayOptions.options.length > 0"
                v-model.number="form.settlementDay"
                class="modal-input-select full-width"
              >
                <option
                  v-for="option in settlementDayOptions.options"
                  :key="option.value"
                  :value="option.value"
                >
                  {{ option.label }}
                </option>
              </select>
              <input
                v-else
                v-model.number="form.settlementDay"
                type="number"
                :min="settlementDayOptions.min"
                :max="settlementDayOptions.max"
                class="modal-input-select full-width"
                :placeholder="settlementDayOptions.placeholder"
              >
              <div class="form-hint">
                {{ getSettlementDayHint() }}
              </div>
            </div>
          </div>

          <div class="form-row">
            <label class="form-label">自动结算</label>
            <div class="form-input-2-3">
              <label class="checkbox-label">
                <input v-model="form.autoSettlement" type="checkbox" class="checkbox-input">
                <span class="checkbox-text">启用自动结算</span>
              </label>
            </div>
          </div>
        </div>

        <!-- 成员管理 -->
        <div class="members-section">
          <div class="members-header">
            <label class="form-label">成员管理</label>
            <button
              type="button"
              class="btn-close add-member-btn"
              aria-label="添加成员"
              @click="showMemberModal = true"
            >
              <LucidePlus class="icon-btn" />
            </button>
          </div>

          <div class="members-list">
            <div
              v-for="(member, index) in memberList" :key="member.serialNum"
              class="member-item"
            >
              <div class="member-info">
                <LucideCrown v-if="member.isPrimary" class="member-icon member-icon-primary" />
                <LucideUser v-else class="member-icon member-icon-default" />
                <span class="member-name">{{ member.name }}</span>
                <span class="member-role">({{ getRoleName(member.role) }})</span>
              </div>
              <div class="member-actions">
                <button type="button" class="action-btn" title="编辑" @click="editMember(index)">
                  <LucideEdit class="action-icon" />
                </button>
                <button
                  type="button" class="action-btn-danger" title="移除" :disabled="member.isPrimary"
                  @click="removeMember(index)"
                >
                  <LucideTrash class="action-icon" />
                </button>
              </div>
            </div>
          </div>
        </div>

        <!-- 账户管理 -->
        <div class="accounts-section">
          <div class="accounts-header">
            <label class="form-label">账户管理</label>
            <button
              type="button"
              class="btn-close add-account-btn"
              aria-label="选择账户"
              @click="toggleAccountSelector"
            >
              <LucidePlus class="icon-btn" />
            </button>
          </div>

          <!-- 已选账户列表 -->
          <div v-if="selectedAccounts.length > 0" class="accounts-list">
            <div
              v-for="account in selectedAccounts"
              :key="account.serialNum"
              class="account-item"
            >
              <div class="account-info" style="display: flex; flex-direction: row; align-items: center; gap: 0.5rem;">
                <LucideWallet class="account-icon" />
                <span style="white-space: nowrap; display: inline;">
                  {{ account.name }} ({{ account.type }})
                </span>
              </div>
              <div class="account-actions">
                <button
                  type="button"
                  class="action-btn-danger"
                  title="移除"
                  @click="removeAccount(account)"
                >
                  <LucideTrash class="action-icon" />
                </button>
              </div>
            </div>
          </div>

          <!-- 账户选择器下拉 -->
          <div v-if="showAccountSelector" class="account-selector">
            <div class="selector-header">
              <span>选择账户</span>
              <button type="button" class="btn-close-selector" @click="toggleAccountSelector">
                <LucideX class="icon-sm" />
              </button>
            </div>
            <div class="selector-list">
              <label
                v-for="account in accounts"
                :key="account.serialNum"
                class="selector-item"
              >
                <input
                  type="checkbox"
                  :checked="isAccountSelected(account)"
                  @change="toggleAccountSelection(account)"
                >
                <span class="selector-item-name">{{ account.name }}</span>
                <span class="selector-item-type">({{ account.type }})</span>
              </label>
            </div>
          </div>
        </div>

        <!-- 操作按钮 -->
        <div class="modal-actions">
          <button type="button" class="btn-close" @click="closeModal">
            <LucideX class="modal-icon" />
          </button>
          <button type="submit" class="btn-submit">
            <LucideCheck class="modal-icon" />
          </button>
        </div>
      </form>
    </div>

    <!-- 成员添加/编辑模态框 -->
    <FamilyMemberModal
      v-if="showMemberModal"
      :member="editingMember"
      :family-ledger-serial-num="props.ledger?.serialNum || ''"
      @close="closeMemberModal"
      @save="saveMember"
    />
  </div>
</template>

<style scoped>
/* 模态框头部 */
.modal-header {
  margin-bottom: 1.5rem;
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.modal-title {
  font-size: 1.125rem;
  font-weight: 600;
}

.modal-close-btn {
  color: #6b7280;
  transition: color 0.2s ease-in-out;
}

.modal-close-btn:hover {
  color: #374151;
}

.modal-icon {
  height: 1.5rem;
  width: 1.5rem;
}

/* 表单样式 */
.modal-form {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.form-section {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.form-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.form-label {
  font-size: 0.875rem;
  color: #374151;
  font-weight: 500;
}

.form-input-2-3 {
  width: 66.666667%;
}

.form-input-wrapper {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.full-width {
  width: 100%;
}

.form-hint {
  font-size: 0.75rem;
  color: #6b7280;
  margin-top: 0.25rem;
  font-style: italic;
}

.checkbox-label {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  cursor: pointer;
}

.checkbox-input {
  width: 1rem;
  height: 1rem;
  accent-color: #3b82f6;
}

.checkbox-text {
  font-size: 0.875rem;
  color: #374151;
}

/* 成员管理样式 */
.members-section {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.members-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.add-member-btn {
  background-color: #f3f4f6;
  color: #374151;
  border-radius: 50%;
  padding: 0;
  width: 3rem;
  height: 3rem;
}

.add-member-btn:hover {
  background-color: #e2e6eb;
}

.btn-icon {
  height: 0.75rem;
  width: 0.75rem;
}

.members-list {
  max-height: 10rem;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.member-item {
  padding: 0.5rem;
  border-radius: 0.5rem;
  background-color: #f9fafb;
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.member-info {
  display: flex;
  gap: 0.5rem;
  align-items: center;
}

.member-icon {
  height: 1rem;
  width: 1rem;
}

.member-icon-primary {
  color: #eab308;
}

.member-icon-default {
  color: #6b7280;
}

.member-name {
  font-size: 0.875rem;
  font-weight: 500;
  color: var(--color-base-content);
  white-space: nowrap;
  flex-shrink: 0;
}

.member-role {
  font-size: 0.75rem;
  color: var(--color-neutral);
  white-space: nowrap;
  flex-shrink: 0;
}

.member-actions {
  display: flex;
  gap: 0.25rem;
}

.action-icon {
  height: 0.75rem;
  width: 0.75rem;
}

/* 账户管理样式 */
.accounts-section {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.accounts-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.add-account-btn {
  background-color: var(--color-base-200);
  color: var(--color-base-content);
  border-radius: 50%;
  padding: 0;
  width: 3rem;
  height: 3rem;
  transition: background-color 0.2s;
}

.add-account-btn:hover {
  background-color: var(--color-base-300);
}

.accounts-list {
  max-height: 10rem;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  /* 隐藏滚动条但保持滚动功能 */
  scrollbar-width: none; /* Firefox */
  -ms-overflow-style: none; /* IE/Edge */
}

.accounts-list::-webkit-scrollbar {
  display: none; /* Chrome/Safari/Opera */
}

.account-item {
  padding: 0.5rem;
  border-radius: 0.5rem;
  background-color: var(--color-base-200);
  display: flex;
  align-items: center;
  justify-content: space-between;
  transition: background-color 0.2s;
}

.account-item:hover {
  background-color: var(--color-base-300);
}

.account-info {
  display: flex;
  gap: 0.5rem;
  align-items: center;
}

.account-info span {
  font-size: 0.875rem;
  font-weight: 500;
  color: var(--color-base-content);
  white-space: nowrap;
}

.account-icon {
  height: 1rem;
  width: 1rem;
  color: var(--color-primary);
}

.account-actions {
  display: flex;
  gap: 0.25rem;
}

.account-selector {
  margin-top: 0.5rem;
  border: 1px solid var(--color-base-300);
  border-radius: 0.5rem;
  background-color: var(--color-base-100);
  max-height: 15rem;
  overflow: hidden;
  display: flex;
  flex-direction: column;
  box-shadow: var(--shadow-md);
}

.selector-header {
  padding: 0.75rem;
  border-bottom: 1px solid var(--color-base-300);
  display: flex;
  align-items: center;
  justify-content: space-between;
  font-weight: 500;
  font-size: 0.875rem;
  color: var(--color-base-content);
  background-color: var(--color-base-200);
}

.btn-close-selector {
  background: none;
  border: none;
  padding: 0.25rem;
  cursor: pointer;
  color: var(--color-neutral);
  transition: color 0.2s;
}

.btn-close-selector:hover {
  color: var(--color-base-content);
}

.icon-sm {
  height: 1rem;
  width: 1rem;
}

.selector-list {
  overflow-y: auto;
  padding: 0.5rem;
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
  /* 隐藏滚动条但保持滚动功能 */
  scrollbar-width: none; /* Firefox */
  -ms-overflow-style: none; /* IE/Edge */
}

.selector-list::-webkit-scrollbar {
  display: none; /* Chrome/Safari/Opera */
}

.selector-item {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.5rem;
  border-radius: 0.375rem;
  cursor: pointer;
  transition: background-color 0.2s;
}

.selector-item:hover {
  background-color: var(--color-base-200);
}

.selector-item input[type="checkbox"] {
  width: 1rem;
  height: 1rem;
  accent-color: var(--color-primary);
  cursor: pointer;
}

.selector-item-name {
  font-size: 0.875rem;
  font-weight: 500;
  color: var(--color-base-content);
}

.selector-item-type {
  font-size: 0.75rem;
  color: var(--color-neutral);
}

/* 模态框操作按钮 */
.modal-actions {
  padding-top: 1rem;
  display: flex;
  justify-content: center;
  gap: 0.75rem;
}

/* 账户和成员的操作按钮样式 */
.action-btn {
  padding: 0.5rem;
  border-radius: 0.375rem;
  border: none;
  background-color: transparent;
  color: var(--color-neutral);
  cursor: pointer;
  transition: all 0.2s ease;
  display: flex;
  align-items: center;
  justify-content: center;
}

.action-btn:hover {
  background-color: var(--color-base-300);
  color: var(--color-base-content);
}

.action-btn-danger {
  padding: 0.5rem;
  border-radius: 0.375rem;
  border: none;
  background-color: transparent;
  color: var(--color-error);
  cursor: pointer;
  transition: all 0.2s ease;
  display: flex;
  align-items: center;
  justify-content: center;
}

.action-btn-danger:hover {
  background-color: var(--color-error);
  color: var(--color-error-content);
}

.action-btn-danger:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.action-icon {
  width: 0.75rem;
  height: 0.75rem;
}
</style>
