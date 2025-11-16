<script setup lang="ts">
import SplitRuleConfigurator from '@/features/money/components/SplitRuleConfigurator.vue';
import SplitTemplateList from '@/features/money/components/SplitTemplateList.vue';
import SplitTemplateModal from '@/features/money/components/SplitTemplateModal.vue';

definePage({
  name: 'split-templates',
  meta: {
    requiresAuth: true,
    title: '分摊模板管理',
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
  <div class="split-templates-page">
    <div class="page-header">
      <div class="header-left">
        <h1 class="page-title">
          分摊模板管理
        </h1>
        <p class="page-subtitle">
          创建和管理分摊规则模板
        </p>
      </div>
      <div class="header-right">
        <button class="btn-primary" @click="handleConfigureRule">
          创建新模板
        </button>
      </div>
    </div>

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

<style scoped>
.split-templates-page {
  width: 100%;
  height: 100%;
  padding: 24px;
}

.page-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 24px;
}

.header-left {
  flex: 1;
}

.page-title {
  font-size: 24px;
  font-weight: 600;
  color: #1f2937;
  margin: 0 0 8px 0;
}

.page-subtitle {
  font-size: 14px;
  color: #6b7280;
  margin: 0;
}

.header-right {
  display: flex;
  gap: 12px;
}

.btn-primary {
  padding: 8px 16px;
  background-color: #3b82f6;
  color: white;
  border: none;
  border-radius: 6px;
  font-size: 14px;
  cursor: pointer;
  transition: background-color 0.2s;
}

.btn-primary:hover {
  background-color: #2563eb;
}
</style>
