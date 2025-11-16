<script setup lang="ts">
import FamilyMemberDetailView from '@/features/money/views/FamilyMemberDetailView.vue';

definePage({
  name: 'family-member-detail',
  meta: {
    requiresAuth: true,
    layout: 'default',
  },
});
</script>

<template>
  <FamilyMemberDetailView />
</template>
