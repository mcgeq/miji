<template>
  <div class="flex flex-wrap gap-3 p-4 bg-gray-100">
    <TagItem
      v-for="([key, tag]) in tagsArray"
      :key="key"
      :modelValue="tag"
      :readonly="true"
      @update:modelValue="val => updateTag(key, val)"
      @remove="onRemove(key)"
    />
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';
import { Tags } from '@/schema/tags';
import TagItem from '../components/TagItem.vue';

const tagsMap = ref(
  new Map<string, Tags>([
    [
      '001',
      {
        serialNum: '001',
        name: 'Vue 3.4 标签1',
        description: '标签说明1',
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      },
    ],
    [
      '002',
      {
        serialNum: '002',
        name: 'Vue 3.4 标签2',
        description: '标签说明2',
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      },
    ],
    [
      '003',
      {
        serialNum: '002',
        name: 'Vue 3.4 标签2',
        description: '标签说明2',
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      },
    ],
    [
      '004',
      {
        serialNum: '002',
        name: 'Vue 3.4 标签2',
        description: '标签说明2',
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      },
    ],
    [
      '005',
      {
        serialNum: '002',
        name: 'Vue 3.4 标签2',
        description: '标签说明2',
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      },
    ],
  ]),
);

const tagsArray = computed(() => Array.from(tagsMap.value.entries()));

function onRemove(key: string) {
  console.log('标签被移除，key:', key);
  tagsMap.value.delete(key);
}

function updateTag(key: string, updated: Tags) {
  tagsMap.value.set(key, updated);
}
</script>
