<template>
  <TagsView />
</template>

<script setup lang="ts">
import TagsView from '@/features/tags/views/TagsView.vue';
definePage({
  name: 'tags',
  meta: {
    requiresAuth: true,
  },
});
</script>
