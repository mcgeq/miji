<script setup lang="ts">
import Button from '@/components/ui/Button.vue';
import SplitRuleConfigurator from '@/features/money/components/SplitRuleConfigurator.vue';
import SplitTemplateList from '@/features/money/components/SplitTemplateList.vue';
import SplitTemplateModal from '@/features/money/components/SplitTemplateModal.vue';
import { Permission } from '@/types/auth';

definePage({
  name: 'split-templates',
  meta: {
    requiresAuth: true,
    permissions: [Permission.TRANSACTION_VIEW],
    title: '分摆模板管理',
    icon: 'layout-template',
  },
});

const showTemplateModal = ref(false);
const showConfigurator = ref(false);
const selectedTemplate = ref(null);

// 打开模板编辑
function handleEditTemplate(template: any) {
  selectedTemplate.value = template;
  showTemplateModal.value = true;
}

// 打开规则配置器
function handleConfigureRule() {
  showConfigurator.value = true;
}

// 关闭模态框
function handleCloseModal() {
  showTemplateModal.value = false;
  showConfigurator.value = false;
  selectedTemplate.value = null;
}

// 保存模板
function handleSaveTemplate() {
  // TODO: 保存模板逻辑
  handleCloseModal();
}
</script>

<template>
  <div class="w-full h-full p-4 sm:p-6 lg:p-8">
    <!-- 页面头部 -->
    <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-6 sm:mb-8">
      <!-- 左侧标题区域 -->
      <div class="flex-1 min-w-0">
        <h1 class="text-2xl sm:text-3xl font-semibold text-gray-900 dark:text-white mb-2 truncate">
          分摊模板管理
        </h1>
        <p class="text-sm text-gray-600 dark:text-gray-400">
          创建和管理分摊规则模板
        </p>
      </div>

      <!-- 右侧操作区域 -->
      <div class="flex items-center gap-3 shrink-0">
        <Button
          variant="primary"
          size="sm"
          class="w-full sm:w-auto"
          @click="handleConfigureRule"
        >
          <span class="hidden sm:inline">创建新模板</span>
          <span class="sm:hidden">新建</span>
        </Button>
      </div>
    </div>

    <!-- 模板列表 -->
    <SplitTemplateList
      @edit-template="handleEditTemplate"
      @configure-rule="handleConfigureRule"
    />

    <!-- 模板编辑模态框 -->
    <SplitTemplateModal
      v-if="showTemplateModal"
      :template="selectedTemplate"
      @close="handleCloseModal"
      @save="handleSaveTemplate"
    />

    <!-- 规则配置器 -->
    <SplitRuleConfigurator
      v-if="showConfigurator"
      @close="handleCloseModal"
      @save="handleSaveTemplate"
    />
  </div>
</template>
