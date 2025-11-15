<script setup lang="ts">
import { CURRENCY_CNY } from '@/constants/moneyConst';
import { MoneyDb } from '@/services/money/money';
import { DateUtils } from '@/utils/date';
import { Lg } from '@/utils/debugLog';
import { getRoleName } from '../utils/family';
import MemberModal from './MemberModal.vue';
import type { Currency } from '@/schema/common';
import type { FamilyLedger, FamilyLedgerCreate, FamilyMember } from '@/schema/money';

interface Props {
  ledger: FamilyLedger | null;
}

const props = defineProps<Props>();
const emit = defineEmits(['close', 'save']);
const { t, te } = useI18n();

const currencies = ref<Currency[]>([]);
const showMemberModal = ref(false);
const editingMember = ref<FamilyMember | null>(null);
const editingMemberIndex = ref(-1);

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
  members: [],
  accounts: '[]',
  transactions: '[]',
  budgets: '[]',
  auditLogs: '[]',
  // 新增字段
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
  createdAt: DateUtils.getLocalISODateTimeWithOffset(),
  updatedAt: null,
};

const form = reactive<FamilyLedger>({
  ...defaultLedger,
  ...(props.ledger || {}),
});

function editMember(index: number) {
  editingMemberIndex.value = index;
  editingMember.value = { ...form.members[index] };
  showMemberModal.value = true;
}

function removeMember(index: number) {
  if (form.members[index].isPrimary)
    return;
  form.members.splice(index, 1);
}

function closeMemberModal() {
  showMemberModal.value = false;
  editingMember.value = null;
  editingMemberIndex.value = -1;
}

function saveMember(member: FamilyMember) {
  if (editingMemberIndex.value >= 0) {
    form.members[editingMemberIndex.value] = member;
  } else {
    form.members.push(member);
  }
  closeMemberModal();
}

function closeModal() {
  emit('close');
}

function saveLedger() {
  // 构建符合后端API期望的数据格式
  const ledgerData: FamilyLedgerCreate = {
    name: form.name,
    description: form.description,
    baseCurrency: form.baseCurrency.code, // 只发送货币代码
    members: form.members,
    accounts: form.accounts,
    transactions: form.transactions,
    budgets: form.budgets,
    ledgerType: form.ledgerType,
    settlementCycle: form.settlementCycle,
    autoSettlement: form.autoSettlement,
    settlementDay: form.settlementDay,
    defaultSplitRule: form.defaultSplitRule,
  };
  emit('save', ledgerData);
}

// 监听 props 变化
watch(
  () => props.ledger,
  newVal => {
    if (newVal) {
      Object.assign(form, JSON.parse(JSON.stringify(newVal)));
    } else {
      Object.assign(form, JSON.parse(JSON.stringify(defaultLedger)));
    }
  },
  { immediate: true, deep: true },
);
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
              v-model="form.description" type="text" required class="modal-input-select form-input-2-3"
              placeholder="请输入账本名称"
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
          <h4 class="section-title">
            结算设置
          </h4>

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
            <input
              v-model.number="form.settlementDay" type="number" min="1" max="31"
              class="modal-input-select form-input-2-3" placeholder="每月几号结算"
            >
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
              v-for="(member, index) in form.members" :key="member.serialNum"
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
    <MemberModal v-if="showMemberModal" :member="editingMember" @close="closeMemberModal" @save="saveMember" />
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

.section-title {
  font-size: 1rem;
  color: #374151;
  font-weight: 600;
  margin-bottom: 0.75rem;
  padding-bottom: 0.5rem;
  border-bottom: 1px solid #e5e7eb;
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
}

.member-role {
  font-size: 0.75rem;
  color: #6b7280;
}

.member-actions {
  display: flex;
  gap: 0.25rem;
}

.action-icon {
  height: 0.75rem;
  width: 0.75rem;
}

/* 模态框操作按钮 */
.modal-actions {
  padding-top: 1rem;
  display: flex;
  justify-content: center;
  gap: 0.75rem;
}
</style>
