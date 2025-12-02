<script setup lang="ts">
import { useMoneyAuth } from '@/composables/useMoneyAuth';
import FamilyMemberList from '@/features/money/components/FamilyMemberList.vue';
import FamilyMemberModal from '@/features/money/components/FamilyMemberModal.vue';
import { Permission } from '@/types/auth';
import type { FamilyMember } from '@/schema/money';

definePage({
  name: 'members',
  meta: {
    requiresAuth: true,
    permissions: [Permission.MEMBER_VIEW],
    title: '成员管理',
    icon: 'users',
  },
});

const { currentLedgerSerialNum } = useMoneyAuth();

// 成员模态框
const showMemberModal = ref(false);
const editingMember = ref<FamilyMember | null>(null);

// 添加成员
function handleAddMember() {
  editingMember.value = null;
  showMemberModal.value = true;
}

// 编辑成员
function handleEditMember(member: FamilyMember) {
  editingMember.value = member;
  showMemberModal.value = true;
}

// 关闭模态框
function handleCloseModal() {
  showMemberModal.value = false;
  editingMember.value = null;
}
</script>

<template>
  <div class="w-full h-full">
    <FamilyMemberList
      :family-ledger-serial-num="currentLedgerSerialNum"
      @add-member="handleAddMember"
      @edit-member="handleEditMember"
    />

    <FamilyMemberModal
      v-if="showMemberModal"
      :member="editingMember"
      :family-ledger-serial-num="currentLedgerSerialNum"
      @close="handleCloseModal"
    />
  </div>
</template>
