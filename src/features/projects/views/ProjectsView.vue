<script setup lang="ts">
import GenericItem from '@/components/common/GenericItem.vue';
import GenericViewItem from '@/components/common/GenericViewItem.vue';
import type { ProjectWithUsageStats } from '@/schema/todos';

const projectsMap = ref(
  new Map<string, ProjectWithUsageStats>([
    [
      'P001',
      {
        serialNum: 'P001',
        name: '项目一',
        description: '项目说明',
        ownerId: 'U123',
        color: '#ff00ff',
        isArchived: false,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        usage: {
          todos: {
            count: 1,
            serialNums: ['ssss'],
          },
        },
      },
    ],
    [
      'P002',
      {
        serialNum: 'P002',
        name: '项目二',
        description: '项目说明2',
        ownerId: 'U123',
        color: '#00ffff',
        isArchived: true,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        usage: {
          todos: {
            count: 1,
            serialNums: ['ssss'],
          },
        },
      },
    ],
  ]),
);
</script>

<template>
  <GenericViewItem
    :entities="projectsMap" :component="GenericItem" display-key="name" :readonly="false"
    @update:entities="val => projectsMap = val"
  />
</template>
