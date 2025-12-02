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
import Button from '@/components/ui/Button.vue';
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
  <div class="flex flex-col gap-8">
    <div class="flex flex-col sm:flex-row justify-between items-stretch sm:items-center gap-4">
      <h3 class="m-0 text-2xl font-semibold text-gray-900 dark:text-white">
        分摆模板
      </h3>
      <Button variant="primary" class="w-full sm:w-auto justify-center" @click="createNewTemplate">
        <LucidePlus class="w-4 h-4" />
        新建模板
      </Button>
    </div>

    <!-- 预设模板 -->
    <section class="bg-white dark:bg-gray-800 p-8 rounded-xl shadow-sm">
      <h4 class="m-0 mb-2 text-lg font-semibold text-gray-900 dark:text-white">
        预设模板
      </h4>
      <p class="m-0 mb-6 text-gray-600 dark:text-gray-400 text-sm">
        系统提供的常用分摆方式，可直接应用到交易中
      </p>

      <div class="grid grid-cols-1 md:grid-cols-[repeat(auto-fill,minmax(300px,1fr))] gap-6">
        <div
          v-for="template in presetTemplates"
          :key="template.id"
          class="flex flex-col gap-4 p-6 bg-white dark:bg-gray-700 border-2 rounded-xl transition-all duration-300 hover:shadow-md hover:-translate-y-0.5"
          :style="{ borderColor: template.color }"
        >
          <div
            class="w-16 h-16 rounded-xl flex items-center justify-center"
            :style="{ backgroundColor: `${template.color}26` }"
          >
            <component :is="template.icon" class="w-9 h-9" :style="{ color: template.color }" />
          </div>

          <div class="flex-1 flex flex-col gap-2">
            <h5 class="m-0 text-lg font-semibold text-gray-900 dark:text-white">
              {{ template.name }}
            </h5>
            <p class="m-0 text-gray-600 dark:text-gray-400 text-sm leading-relaxed">
              {{ template.description }}
            </p>
            <span
              class="inline-block self-start px-3 py-1 rounded-xl text-xs font-medium text-white"
              :style="{ backgroundColor: template.color, opacity: 0.9 }"
            >
              {{ getSplitTypeName(template.splitType) }}
            </span>
          </div>

          <div class="flex gap-2 items-center">
            <Button
              variant="primary"
              class="flex-1"
              :style="{ backgroundColor: template.color, borderColor: template.color }"
              @click="applyTemplate(template)"
            >
              应用
            </Button>
          </div>
        </div>
      </div>
    </section>

    <!-- 自定义模板 -->
    <section class="bg-white dark:bg-gray-800 p-8 rounded-xl shadow-sm">
      <h4 class="m-0 mb-2 text-lg font-semibold text-gray-900 dark:text-white">
        自定义模板
      </h4>
      <p class="m-0 mb-6 text-gray-600 dark:text-gray-400 text-sm">
        保存的自定义分摆规则，可以快速应用到类似场景
      </p>

      <div v-if="customTemplates.length > 0" class="grid grid-cols-1 md:grid-cols-[repeat(auto-fill,minmax(300px,1fr))] gap-6">
        <div
          v-for="template in customTemplates"
          :key="template.serialNum"
          class="flex flex-col gap-4 p-6 bg-white dark:bg-gray-700 border-2 border-gray-200 dark:border-gray-600 rounded-xl transition-all duration-300 hover:shadow-md hover:-translate-y-0.5"
        >
          <div class="flex-1 flex flex-col gap-2">
            <h5 class="m-0 text-lg font-semibold text-gray-900 dark:text-white">
              {{ template.name }}
            </h5>
            <p v-if="template.description" class="m-0 text-gray-600 dark:text-gray-400 text-sm leading-relaxed">
              {{ template.description }}
            </p>
            <div class="flex gap-4 mt-2">
              <span class="inline-block px-3 py-1 bg-gray-100 dark:bg-gray-600 rounded-xl text-xs font-medium text-gray-700 dark:text-gray-200">
                {{ getSplitTypeName(template.ruleType) }}
              </span>
              <span class="text-xs text-gray-500 dark:text-gray-400">
                {{ template.participants?.length || 0 }} 人参与
              </span>
            </div>
          </div>

          <div class="flex gap-2 items-center">
            <button
              class="p-2 bg-transparent border border-gray-200 dark:border-gray-600 rounded-md cursor-pointer transition-all hover:bg-gray-100 dark:hover:bg-gray-600 hover:border-blue-500 dark:hover:border-blue-400"
              title="编辑"
              @click="editTemplate(template)"
            >
              <LucideEdit class="w-4 h-4 text-gray-600 dark:text-gray-300" />
            </button>
            <button
              class="p-2 bg-transparent border border-gray-200 dark:border-gray-600 rounded-md cursor-pointer transition-all hover:bg-gray-100 dark:hover:bg-gray-600 hover:border-blue-500 dark:hover:border-blue-400"
              title="删除"
              @click="deleteTemplate(template)"
            >
              <LucideTrash2 class="w-4 h-4 text-gray-600 dark:text-gray-300" />
            </button>
            <Button variant="primary" class="flex-1" @click="applyTemplate(template)">
              应用
            </Button>
          </div>
        </div>
      </div>

      <div v-else class="flex flex-col items-center gap-2 py-12 text-center">
        <p class="m-0 text-base text-gray-600 dark:text-gray-400">
          暂无自定义模板
        </p>
        <span class="text-sm text-gray-400 dark:text-gray-500">点击“新建模板”创建您的第一个自定义分摆规则</span>
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
