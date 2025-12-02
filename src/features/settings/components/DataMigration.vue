<script setup lang="ts">
import { Database as LucideDatabase } from 'lucide-vue-next';
import { Card } from '@/components/ui';

// 注意：此功能已废弃，仅保留UI展示
// split_members 字段已从数据库中完全移除，新数据直接使用 split_records 表
</script>

<template>
  <div class="max-w-3xl mx-auto p-4 md:p-6">
    <Card shadow="md" padding="lg">
      <div class="flex items-center gap-4">
        <div class="w-12 h-12 rounded-xl bg-gray-100 dark:bg-gray-800 flex items-center justify-center shrink-0">
          <LucideDatabase class="w-6 h-6 text-gray-400 dark:text-gray-500" />
        </div>
      </div>
    </Card>
  </div>
</template>
