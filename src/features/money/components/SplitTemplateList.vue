<script setup lang="ts">
import {
  LucideCoins,
  LucideEdit,
  LucideEqual,
  LucidePercent,
  LucidePlus,
  LucideScale,
  LucideTrash2,
} from 'lucide-vue-next';
import { useFamilySplitStore } from '@/stores/money';
import type { SplitRuleType } from '@/schema/money';

const splitStore = useFamilySplitStore();
const showConfigurator = ref(false);
const selectedTemplate = ref<any>(null);

// 预设模板
const presetTemplates = [
  {
    id: 'preset-equal',
    name: '均等分摊',
    description: '所有参与成员平均分摊费用',
    splitType: 'EQUAL' as SplitRuleType,
    icon: LucideEqual,
    color: '#3b82f6',
    isPreset: true,
  },
  {
    id: 'preset-percentage',
    name: '按比例分摊',
    description: '根据设定的比例分摊费用',
    splitType: 'PERCENTAGE' as SplitRuleType,
    icon: LucidePercent,
    color: '#10b981',
    isPreset: true,
  },
  {
    id: 'preset-fixed',
    name: '固定金额',
    description: '为每个成员指定固定的分摊金额',
    splitType: 'FIXED_AMOUNT' as SplitRuleType,
    icon: LucideCoins,
    color: '#f59e0b',
    isPreset: true,
  },
  {
    id: 'preset-weighted',
    name: '按权重分摊',
    description: '根据权重比例分摊费用（如收入比）',
    splitType: 'WEIGHTED' as SplitRuleType,
    icon: LucideScale,
    color: '#8b5cf6',
    isPreset: true,
  },
];

// 自定义模板（从 store 获取）
const customTemplates = computed(() => splitStore.splitTemplates);

// 加载模板
onMounted(async () => {
  // TODO: 从后端加载自定义模板
  // await splitStore.fetchTemplates();
});

// 应用模板
function applyTemplate(template: any) {
  selectedTemplate.value = template;
  // TODO: 触发应用模板的逻辑
  // eslint-disable-next-line no-console
  console.log('Applying template:', template);
}

// 编辑模板
function editTemplate(template: any) {
  selectedTemplate.value = template;
  showConfigurator.value = true;
}

// 删除模板
async function deleteTemplate(template: any) {
  // eslint-disable-next-line no-alert
  if (window.confirm(`确定要删除模板“${template.name}”吗？`)) {
    try {
      // TODO: 调用 API 删除
      // await splitStore.deleteTemplate(template.serialNum);
      // eslint-disable-next-line no-console
      console.log('Deleting template:', template);
    } catch (error) {
      console.error('Failed to delete template:', error);
    }
  }
}

// 创建新模板
function createNewTemplate() {
  selectedTemplate.value = null;
  showConfigurator.value = true;
}

// 获取分摊类型名称
function getSplitTypeName(type: SplitRuleType): string {
  const typeMap: Record<SplitRuleType, string> = {
    EQUAL: '均摊',
    PERCENTAGE: '按比例',
    FIXED_AMOUNT: '固定金额',
    WEIGHTED: '按权重',
  };
  return typeMap[type] || type;
}
</script>

<template>
  <div class="split-template-list">
    <div class="list-header">
      <h3>分摊模板</h3>
      <button class="btn-create" @click="createNewTemplate">
        <LucidePlus class="icon" />
        新建模板
      </button>
    </div>

    <!-- 预设模板 -->
    <section class="templates-section">
      <h4 class="section-title">
        预设模板
      </h4>
      <p class="section-description">
        系统提供的常用分摊方式，可直接应用到交易中
      </p>

      <div class="template-grid">
        <div
          v-for="template in presetTemplates"
          :key="template.id"
          class="template-card preset"
          :style="{ '--template-color': template.color }"
        >
          <div class="template-icon-wrapper">
            <component :is="template.icon" class="template-icon" />
          </div>

          <div class="template-content">
            <h5 class="template-name">
              {{ template.name }}
            </h5>
            <p class="template-description">
              {{ template.description }}
            </p>
            <span class="template-type">{{ getSplitTypeName(template.splitType) }}</span>
          </div>

          <div class="template-actions">
            <button class="btn-apply" @click="applyTemplate(template)">
              应用
            </button>
          </div>
        </div>
      </div>
    </section>

    <!-- 自定义模板 -->
    <section class="templates-section">
      <h4 class="section-title">
        自定义模板
      </h4>
      <p class="section-description">
        保存的自定义分摊规则，可以快速应用到类似场景
      </p>

      <div v-if="customTemplates.length > 0" class="template-grid">
        <div
          v-for="template in customTemplates"
          :key="template.serialNum"
          class="template-card custom"
        >
          <div class="template-content">
            <h5 class="template-name">
              {{ template.name }}
            </h5>
            <p v-if="template.description" class="template-description">
              {{ template.description }}
            </p>
            <div class="template-meta">
              <span class="template-type">{{ getSplitTypeName(template.ruleType) }}</span>
              <span class="template-members">
                {{ template.participants?.length || 0 }} 人参与
              </span>
            </div>
          </div>

          <div class="template-actions">
            <button class="btn-icon" title="编辑" @click="editTemplate(template)">
              <LucideEdit class="icon" />
            </button>
            <button class="btn-icon" title="删除" @click="deleteTemplate(template)">
              <LucideTrash2 class="icon" />
            </button>
            <button class="btn-apply" @click="applyTemplate(template)">
              应用
            </button>
          </div>
        </div>
      </div>

      <div v-else class="empty-state">
        <p>暂无自定义模板</p>
        <span>点击"新建模板"创建您的第一个自定义分摊规则</span>
      </div>
    </section>

    <!-- 配置器弹窗（待实现） -->
    <!-- <SplitRuleConfigurator
      v-if="showConfigurator"
      :template="selectedTemplate"
      @close="showConfigurator = false"
      @save="handleTemplateSave"
    /> -->
  </div>
</template>

<style scoped>
.split-template-list {
  display: flex;
  flex-direction: column;
  gap: 2rem;
}

/* Header */
.list-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.list-header h3 {
  margin: 0;
  font-size: 1.5rem;
  font-weight: 600;
}

.btn-create {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.75rem 1.5rem;
  background: var(--color-primary);
  color: white;
  border: none;
  border-radius: 8px;
  font-size: 0.875rem;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
}

.btn-create:hover {
  background: var(--color-primary-dark);
  transform: translateY(-1px);
  box-shadow: var(--shadow-md);
}

.btn-create .icon {
  width: 18px;
  height: 18px;
}

/* Section */
.templates-section {
  background: white;
  padding: 2rem;
  border-radius: 12px;
  box-shadow: var(--shadow-sm);
}

.section-title {
  margin: 0 0 0.5rem 0;
  font-size: 1.125rem;
  font-weight: 600;
}

.section-description {
  margin: 0 0 1.5rem 0;
  color: var(--color-gray-600);
  font-size: 0.875rem;
}

/* Template Grid */
.template-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: 1.5rem;
}

.template-card {
  display: flex;
  flex-direction: column;
  gap: 1rem;
  padding: 1.5rem;
  background: white;
  border: 2px solid var(--color-base-300);
  border-radius: 12px;
  transition: all 0.3s;
}

.template-card:hover {
  box-shadow: var(--shadow-md);
  transform: translateY(-2px);
}

.template-card.preset {
  border-color: var(--template-color);
  background: linear-gradient(135deg, var(--template-color) 0%, transparent 100%);
  background-size: 200% 200%;
  background-position: 100% 100%;
}

.template-card.preset:hover {
  background-position: 0% 0%;
  border-color: var(--template-color);
}

/* Template Icon */
.template-icon-wrapper {
  width: 64px;
  height: 64px;
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--template-color);
  opacity: 0.15;
}

.template-icon {
  width: 36px;
  height: 36px;
  color: var(--template-color);
  opacity: 10;
}

/* Template Content */
.template-content {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.template-name {
  margin: 0;
  font-size: 1.125rem;
  font-weight: 600;
}

.template-description {
  margin: 0;
  color: var(--color-gray-600);
  font-size: 0.875rem;
  line-height: 1.6;
}

.template-meta {
  display: flex;
  gap: 1rem;
  margin-top: 0.5rem;
}

.template-type {
  display: inline-block;
  padding: 0.25rem 0.75rem;
  background: var(--color-base-200);
  border-radius: 12px;
  font-size: 0.75rem;
  font-weight: 500;
  color: var(--color-gray-700);
}

.template-card.preset .template-type {
  background: var(--template-color);
  color: white;
  opacity: 0.9;
}

.template-members {
  font-size: 0.75rem;
  color: var(--color-gray-500);
}

/* Template Actions */
.template-actions {
  display: flex;
  gap: 0.5rem;
  align-items: center;
}

.btn-icon {
  padding: 0.5rem;
  background: transparent;
  border: 1px solid var(--color-base-300);
  border-radius: 6px;
  cursor: pointer;
  transition: all 0.2s;
}

.btn-icon:hover {
  background: var(--color-base-200);
  border-color: var(--color-primary);
}

.btn-icon .icon {
  width: 16px;
  height: 16px;
  color: var(--color-gray-600);
}

.btn-apply {
  flex: 1;
  padding: 0.5rem 1rem;
  background: var(--color-primary);
  color: white;
  border: none;
  border-radius: 6px;
  font-size: 0.875rem;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
}

.btn-apply:hover {
  background: var(--color-primary-dark);
}

.template-card.preset .btn-apply {
  background: var(--template-color);
}

/* Empty State */
.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.5rem;
  padding: 3rem 0;
  text-align: center;
}

.empty-state p {
  margin: 0;
  font-size: 1rem;
  color: var(--color-gray-600);
}

.empty-state span {
  font-size: 0.875rem;
  color: var(--color-gray-400);
}

/* Responsive */
@media (max-width: 768px) {
  .template-grid {
    grid-template-columns: 1fr;
  }

  .list-header {
    flex-direction: column;
    align-items: stretch;
    gap: 1rem;
  }

  .btn-create {
    width: 100%;
    justify-content: center;
  }
}
</style>
