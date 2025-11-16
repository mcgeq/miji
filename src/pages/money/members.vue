<script setup lang="ts">
import { useMoneyAuth } from '@/composables/useMoneyAuth';
import FamilyMemberList from '@/features/money/components/FamilyMemberList.vue';
import FamilyMemberModal from '@/features/money/components/FamilyMemberModal.vue';
import type { FamilyMember } from '@/schema/money';

definePage({
  name: 'members',
  meta: {
    requiresAuth: true,
    title: '成员管理',
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
  <div class="members-page">
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

<style scoped>
.members-page {
  width: 100%;
  height: 100%;
}
</style>
