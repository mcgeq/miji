<script setup lang="ts">
import { CURRENCY_CNY } from '@/constants/moneyConst';
import { MoneyDb } from '@/services/money/money';
import { DateUtils } from '@/utils/date';
import { Lg } from '@/utils/debugLog';
import { uuid } from '@/utils/uuid';
import { getRoleName } from '../utils/family';
import MemberModal from './MemberModal.vue';
import type { Currency } from '@/schema/common';
import type { FamilyLedger, FamilyMember } from '@/schema/money';

interface Props {
  ledger: FamilyLedger | null;
}

const props = defineProps<Props>();
const emit = defineEmits(['close', 'save']);
const { t } = useI18n();

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
  const ledgerData: FamilyLedger = {
    ...form,
    serialNum: props.ledger?.serialNum || uuid(38),
    createdAt: props.ledger?.createdAt || DateUtils.getLocalISODateTimeWithOffset(),
    updatedAt: DateUtils.getLocalISODateTimeWithOffset(),
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
            <label class="form-label">基础币种</label>
            <select v-model="form.baseCurrency.code" required class="modal-input-select form-input-2-3">
              <option v-for="currency in currencies" :key="currency.code" :value="currency.code">
                {{ t(currency.code) }} ({{ currency.code }})
              </option>
            </select>
          </div>
        </div>

        <!-- 成员管理 -->
        <div class="members-section">
          <div class="members-header">
            <label class="form-label">成员管理</label>
            <button type="button" class="add-member-btn" @click="showMemberModal = true">
              <LucidePlus class="btn-icon" />
              添加成员
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
          <button type="button" class="modal-btn-x" @click="closeModal">
            <LucideX class="modal-icon" />
          </button>
          <button type="submit" class="modal-btn-check">
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
  font-size: 0.75rem;
  padding: 0.25rem 0.5rem;
  background-color: #e5e7eb;
  color: #374151;
  border-radius: 0.25rem;
  transition: all 0.2s ease-in-out;
  display: flex;
  align-items: center;
  gap: 0.25rem;
}

.add-member-btn:hover {
  background-color: #d1d5db;
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
