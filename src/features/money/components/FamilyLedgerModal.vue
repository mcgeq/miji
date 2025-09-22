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
      <div class="mb-6 flex items-center justify-between">
        <h3 class="text-lg font-semibold">
          {{ props.ledger ? '编辑家庭账本' : '创建家庭账本' }}
        </h3>
        <button class="text-gray-500 hover:text-gray-700" @click="closeModal">
          <LucideX class="h-6 w-6" />
        </button>
      </div>

      <form class="space-y-4" @submit.prevent="saveLedger">
        <!-- 基本信息 -->
        <div class="space-y-4">
          <div class="flex items-center justify-between">
            <label class="text-sm text-gray-700 font-medium">账本名称</label>
            <input
              v-model="form.description" type="text" required class="modal-input-select w-2/3"
              placeholder="请输入账本名称"
            >
          </div>

          <div class="flex items-center justify-between">
            <label class="text-sm text-gray-700 font-medium">基础币种</label>
            <select v-model="form.baseCurrency.code" required class="modal-input-select w-2/3">
              <option v-for="currency in currencies" :key="currency.code" :value="currency.code">
                {{ t(currency.code) }} ({{ currency.code }})
              </option>
            </select>
          </div>
        </div>

        <!-- 成员管理 -->
        <div class="space-y-3">
          <div class="flex items-center justify-between">
            <label class="text-sm text-gray-700 font-medium">成员管理</label>
            <button type="button" class="btn-secondary text-xs px-2 py-1" @click="showMemberModal = true">
              <LucidePlus class="mr-1 h-3 w-3" />
              添加成员
            </button>
          </div>

          <div class="max-h-40 overflow-y-auto space-y-2">
            <div
              v-for="(member, index) in form.members" :key="member.serialNum"
              class="p-2 rounded-lg bg-gray-50 flex items-center justify-between"
            >
              <div class="flex gap-2 items-center">
                <LucideCrown v-if="member.isPrimary" class="text-yellow-500 h-4 w-4" />
                <LucideUser v-else class="text-gray-500 h-4 w-4" />
                <span class="text-sm font-medium">{{ member.name }}</span>
                <span class="text-xs text-gray-500">({{ getRoleName(member.role) }})</span>
              </div>
              <div class="flex gap-1">
                <button type="button" class="action-btn" title="编辑" @click="editMember(index)">
                  <LucideEdit class="h-3 w-3" />
                </button>
                <button
                  type="button" class="action-btn-danger" title="移除" :disabled="member.isPrimary"
                  @click="removeMember(index)"
                >
                  <LucideTrash class="h-3 w-3" />
                </button>
              </div>
            </div>
          </div>
        </div>

        <!-- 操作按钮 -->
        <div class="pt-4 flex justify-center space-x-3">
          <button type="button" class="modal-btn-x" @click="closeModal">
            <LucideX class="wh-5" />
          </button>
          <button type="submit" class="modal-btn-check">
            <LucideCheck class="wh-5" />
          </button>
        </div>
      </form>
    </div>

    <!-- 成员添加/编辑模态框 -->
    <MemberModal v-if="showMemberModal" :member="editingMember" @close="closeMemberModal" @save="saveMember" />
  </div>
</template>

<style scoped>
  @import '@/assets/styles/modal.css';
</style>
