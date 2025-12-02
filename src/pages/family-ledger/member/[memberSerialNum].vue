<script setup lang="ts">
import FamilyMemberDetailView from '@/features/money/views/FamilyMemberDetailView.vue';
import { Permission } from '@/types/auth';

definePage({
  name: 'family-member-detail',
  meta: {
    requiresAuth: true,
    layout: 'default',
    permissions: [Permission.MEMBER_VIEW],
    title: '成员详情',
    icon: 'user',
  },
});
</script>

<template>
  <FamilyMemberDetailView />
</template>
