<template>
  <GenericViewItem
    :entities="tagsMap"
    :component="GenericItem"
    displayKey="name"
    :readonly="true"
    @update:entities="val => tagsMap = val"
  />
</template>

<script setup lang="ts">
import type { TagsWithUsageStats } from '@/schema/tags';
import GenericViewItem from '@/components/common/GenericViewItem.vue';
import GenericItem from '@/components/common/GenericItem.vue';

const tagsMap = ref(
  new Map<string, TagsWithUsageStats>([
    [
      '001',
      {
        serialNum: '001',
        name: '标签一',
        description: '说明一',
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        usage: {
          todos: {
            count: 1,
            serialNums: ['ssss'],
          },
          projects: {
            count: 2,
            serialNums: ['ssss', 'dhjddg'],
          },
        },
      },
    ],
    [
      '002',
      {
        serialNum: '002',
        name: '标签二',
        description: '说明二',
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        usage: {
          todos: {
            count: 1,
            serialNums: ['ssss'],
          },
          projects: {
            count: 4,
            serialNums: ['ssss', 'ssssdsdsfd', '1', '3'],
          },
        },
      },
    ],
  ]),
);
</script>
