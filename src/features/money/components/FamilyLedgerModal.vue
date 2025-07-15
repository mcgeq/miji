<template>
  <div class="modal-mask">
    <div class="modal-mask-window-money">
      <div class="flex justify-between items-center mb-6">
        <h3 class="text-lg font-semibold">{{ props.ledger ? '编辑家庭账本' : '创建家庭账本' }}</h3>
        <button @click="closeModal" class="text-gray-500 hover:text-gray-700">
          <X class="w-6 h-6" />
        </button>
      </div>

      <form @submit.prevent="saveLedger" class="space-y-4">
        <!-- 基本信息 -->
        <div class="space-y-4">
          <div class="flex items-center justify-between">
            <label class="text-sm font-medium text-gray-700">账本名称</label>
            <input
              v-model="form.description"
              type="text"
              required
              class="w-2/3 modal-input-select"
              placeholder="请输入账本名称"
            />
          </div>

          <div class="flex items-center justify-between">
            <label class="text-sm font-medium text-gray-700">基础币种</label>
            <select
              v-model="form.baseCurrency.code"
              required
              class="w-2/3 modal-input-select"
            >
              <option v-for="currency in currencies" :key="currency.code" :value="currency.code">
                {{ currency.nameZh }} ({{ currency.code }})
              </option>
            </select>
          </div>
        </div>

        <!-- 成员管理 -->
        <div class="space-y-3">
          <div class="flex justify-between items-center">
            <label class="text-sm font-medium text-gray-700">成员管理</label>
            <button
              type="button"
              @click="showMemberModal = true"
              class="btn-secondary text-xs px-2 py-1"
            >
              <Plus class="w-3 h-3 mr-1" />
              添加成员
            </button>
          </div>

          <div class="space-y-2 max-h-40 overflow-y-auto">
            <div v-for="(member, index) in form.members" :key="member.serialNum"
                 class="flex items-center justify-between p-2 bg-gray-50 rounded-lg">
              <div class="flex items-center gap-2">
                <Crown v-if="member.isPrimary" class="w-4 h-4 text-yellow-500" />
                <User v-else class="w-4 h-4 text-gray-500" />
                <span class="text-sm font-medium">{{ member.name }}</span>
                <span class="text-xs text-gray-500">({{ getRoleName(member.role) }})</span>
              </div>
              <div class="flex gap-1">
                <button
                  type="button"
                  @click="editMember(index)"
                  class="action-btn"
                  title="编辑"
                >
                  <Edit class="w-3 h-3" />
                </button>
                <button
                  type="button"
                  @click="removeMember(index)"
                  class="action-btn-danger"
                  title="移除"
                  :disabled="member.isPrimary"
                >
                  <Trash class="w-3 h-3" />
                </button>
              </div>
            </div>
          </div>
        </div>

        <!-- 操作按钮 -->
        <div class="flex justify-center space-x-3 pt-4">
          <button type="button" @click="closeModal" class="modal-btn-x">
            <X class="wh-5" />
          </button>
          <button type="submit" class="modal-btn-check">
            <Check class="wh-5" />
          </button>
        </div>
      </form>
    </div>

    <!-- 成员添加/编辑模态框 -->
    <MemberModal
      v-if="showMemberModal"
      :member="editingMember"
      @close="closeMemberModal"
      @save="saveMember"
    />
  </div>
</template>

<script setup lang="ts">
import { Check, X, Plus, Edit, Trash, Crown, User } from 'lucide-vue-next';
import { uuid } from '@/utils/uuid';
import { getLocalISODateTimeWithOffset } from '@/utils/date';
import type { UserRole } from '@/schema/userRole';
import { DEFAULT_CURRENCY } from '@/constants/moneyConst';
import { safeGet } from '@/utils/common';
import MemberModal from './MemberModal.vue';
import { FamilyLedger, FamilyMember } from '@/schema/money';

interface Props {
  ledger: FamilyLedger | null;
}

const props = defineProps<Props>();
const emit = defineEmits(['close', 'save']);

const currencies = ref(DEFAULT_CURRENCY);
const showMemberModal = ref(false);
const editingMember = ref<FamilyMember | null>(null);
const editingMemberIndex = ref(-1);

const defaultLedger: FamilyLedger = {
  serialNum: '',
  description: '',
  baseCurrency: safeGet(DEFAULT_CURRENCY, 0, DEFAULT_CURRENCY[0])!,
  members: [],
  accounts: '[]',
  transactions: '[]',
  budgets: '[]',
  auditLogs: '[]',
  createdAt: getLocalISODateTimeWithOffset(),
  updatedAt: null,
};

const form = reactive<FamilyLedger>({
  ...defaultLedger,
  ...(props.ledger || {}),
});

const getRoleName = (role: UserRole): string => {
  const roleNames: Record<UserRole, string> = {
    Owner: '所有者',
    Admin: '管理员',
    User: '用户',
    Moderator: '协调员',
    Editor: '编辑者',
    Guest: '访客',
    Developer: '开发者',
  };
  return roleNames[role] || '未知';
};

const editMember = (index: number) => {
  editingMemberIndex.value = index;
  editingMember.value = { ...form.members[index] };
  showMemberModal.value = true;
};

const removeMember = (index: number) => {
  if (form.members[index].isPrimary) return;
  form.members.splice(index, 1);
};

const closeMemberModal = () => {
  showMemberModal.value = false;
  editingMember.value = null;
  editingMemberIndex.value = -1;
};

const saveMember = (member: FamilyMember) => {
  if (editingMemberIndex.value >= 0) {
    form.members[editingMemberIndex.value] = member;
  } else {
    form.members.push(member);
  }
  closeMemberModal();
};

const closeModal = () => {
  emit('close');
};

const saveLedger = () => {
  const ledgerData: FamilyLedger = {
    ...form,
    serialNum: props.ledger?.serialNum || uuid(38),
    createdAt: props.ledger?.createdAt || getLocalISODateTimeWithOffset(),
    updatedAt: getLocalISODateTimeWithOffset(),
  };
  emit('save', ledgerData);
};

// 监听 props 变化
watch(
  () => props.ledger,
  (newVal) => {
    if (newVal) {
      Object.assign(form, JSON.parse(JSON.stringify(newVal)));
    } else {
      Object.assign(form, JSON.parse(JSON.stringify(defaultLedger)));
    }
  },
  { immediate: true, deep: true },
);
</script>
