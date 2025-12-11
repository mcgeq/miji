<script setup lang="ts">
  // 重定向到统一的数据字典管理页面
  definePage({
    name: 'projects',
    meta: {
      requiresAuth: true,
      layout: 'default',
    },
    redirect: '/dictionaries',
  });
</script>

<template>
  <div />
</template>
