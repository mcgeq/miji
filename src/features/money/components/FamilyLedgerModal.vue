<script setup lang="ts">
import { Check, Crown, Edit, Plus, Trash, User, X } from 'lucide-vue-next';
import { DEFAULT_CURRENCY } from '@/constants/moneyConst';
import { safeGet } from '@/utils/common';
import { DateUtils } from '@/utils/date';
import { uuid } from '@/utils/uuid';
import { getRoleName } from '../utils/family';
import MemberModal from './MemberModal.vue';
import type { FamilyLedger, FamilyMember } from '@/schema/money';

interface Props {
  ledger: FamilyLedger | null;
}

const props = defineProps<Props>();
const emit = defineEmits(['close', 'save']);
const { t } = useI18n();

const currencies = ref(DEFAULT_CURRENCY);
const showMemberModal = ref(false);
const editingMember = ref<FamilyMember | null>(null);
const editingMemberIndex = ref(-1);

const defaultLedger: FamilyLedger = {
  name: '',
  serialNum: '',
  description: '',
  baseCurrency: safeGet(DEFAULT_CURRENCY, 0, DEFAULT_CURRENCY[0])!,
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
  }
  else {
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
    }
    else {
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
          <X class="h-6 w-6" />
        </button>
      </div>

      <form class="space-y-4" @submit.prevent="saveLedger">
        <!-- 基本信息 -->
        <div class="space-y-4">
          <div class="flex items-center justify-between">
            <label class="text-sm text-gray-700 font-medium">账本名称</label>
            <input
              v-model="form.description" type="text" required class="w-2/3 modal-input-select"
              placeholder="请输入账本名称"
            >
          </div>

          <div class="flex items-center justify-between">
            <label class="text-sm text-gray-700 font-medium">基础币种</label>
            <select v-model="form.baseCurrency.code" required class="w-2/3 modal-input-select">
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
            <button type="button" class="btn-secondary px-2 py-1 text-xs" @click="showMemberModal = true">
              <Plus class="mr-1 h-3 w-3" />
              添加成员
            </button>
          </div>

          <div class="max-h-40 overflow-y-auto space-y-2">
            <div
              v-for="(member, index) in form.members" :key="member.serialNum"
              class="flex items-center justify-between rounded-lg bg-gray-50 p-2"
            >
              <div class="flex items-center gap-2">
                <Crown v-if="member.isPrimary" class="h-4 w-4 text-yellow-500" />
                <User v-else class="h-4 w-4 text-gray-500" />
                <span class="text-sm font-medium">{{ member.name }}</span>
                <span class="text-xs text-gray-500">({{ getRoleName(member.role) }})</span>
              </div>
              <div class="flex gap-1">
                <button type="button" class="action-btn" title="编辑" @click="editMember(index)">
                  <Edit class="h-3 w-3" />
                </button>
                <button
                  type="button" class="action-btn-danger" title="移除" :disabled="member.isPrimary"
                  @click="removeMember(index)"
                >
                  <Trash class="h-3 w-3" />
                </button>
              </div>
            </div>
          </div>
        </div>

        <!-- 操作按钮 -->
        <div class="flex justify-center pt-4 space-x-3">
          <button type="button" class="modal-btn-x" @click="closeModal">
            <X class="wh-5" />
          </button>
          <button type="submit" class="modal-btn-check">
            <Check class="wh-5" />
          </button>
        </div>
      </form>
    </div>

    <!-- 成员添加/编辑模态框 -->
    <MemberModal v-if="showMemberModal" :member="editingMember" @close="closeMemberModal" @save="saveMember" />
  </div>
</template>
