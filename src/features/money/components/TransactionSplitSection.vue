<script setup lang="ts">
import {
  LucideChevronDown,
  LucideCoins,
  LucideEqual,
  LucidePercent,
  LucideScale,
  LucideSettings,
  LucideUsers,
} from 'lucide-vue-next';
import { useFamilyMemberStore } from '@/stores/money';
import type { SplitRuleType } from '@/schema/money';

interface Props {
  transactionAmount: number;
  ledgerSerialNum?: string;
}

const props = defineProps<Props>();
const emit = defineEmits<{
  'update:splitConfig': [config: any];
}>();

const memberStore = useFamilyMemberStore();

// 分摊开关
const enableSplit = ref(false);

// 选中的模板
const selectedTemplate = ref<any>(null);

// 分摊配置
const splitConfig = reactive({
  splitType: 'EQUAL' as SplitRuleType,
  selectedMembers: [] as string[],
  splitParams: {} as Record<string, { percentage?: number; amount?: number; weight?: number }>,
});

// 显示配置器
const showConfigurator = ref(false);

// 可用成员
const availableMembers = computed(() => memberStore.members);

// 预设模板（快速选择）
const quickTemplates = [
  {
    id: 'equal',
    name: '均摊',
    icon: LucideEqual,
    color: '#3b82f6',
    type: 'EQUAL' as SplitRuleType,
  },
  {
    id: 'percentage',
    name: '按比例',
    icon: LucidePercent,
    color: '#10b981',
    type: 'PERCENTAGE' as SplitRuleType,
  },
  {
    id: 'fixed',
    name: '固定金额',
    icon: LucideCoins,
    color: '#f59e0b',
    type: 'FIXED_AMOUNT' as SplitRuleType,
  },
  {
    id: 'weighted',
    name: '按权重',
    icon: LucideScale,
    color: '#8b5cf6',
    type: 'WEIGHTED' as SplitRuleType,
  },
];

// 计算分摊预览
const splitPreview = computed(() => {
  if (!enableSplit.value || splitConfig.selectedMembers.length === 0) {
    return [];
  }

  const results: Array<{ memberSerialNum: string; memberName: string; amount: number }> = [];

  switch (splitConfig.splitType) {
    case 'EQUAL': {
      const perPerson = props.transactionAmount / splitConfig.selectedMembers.length;
      splitConfig.selectedMembers.forEach(memberId => {
        const member = availableMembers.value.find(m => m.serialNum === memberId);
        results.push({
          memberSerialNum: memberId,
          memberName: member?.name || 'Unknown',
          amount: perPerson,
        });
      });
      break;
    }

    case 'PERCENTAGE': {
      splitConfig.selectedMembers.forEach(memberId => {
        const member = availableMembers.value.find(m => m.serialNum === memberId);
        const percentage = splitConfig.splitParams[memberId]?.percentage || 0;
        results.push({
          memberSerialNum: memberId,
          memberName: member?.name || 'Unknown',
          amount: (props.transactionAmount * percentage) / 100,
        });
      });
      break;
    }

    case 'FIXED_AMOUNT': {
      splitConfig.selectedMembers.forEach(memberId => {
        const member = availableMembers.value.find(m => m.serialNum === memberId);
        const amount = splitConfig.splitParams[memberId]?.amount || 0;
        results.push({
          memberSerialNum: memberId,
          memberName: member?.name || 'Unknown',
          amount,
        });
      });
      break;
    }

    case 'WEIGHTED': {
      const totalWeight = splitConfig.selectedMembers.reduce((sum, id) => {
        return sum + (splitConfig.splitParams[id]?.weight || 0);
      }, 0);

      if (totalWeight > 0) {
        splitConfig.selectedMembers.forEach(memberId => {
          const member = availableMembers.value.find(m => m.serialNum === memberId);
          const weight = splitConfig.splitParams[memberId]?.weight || 0;
          results.push({
            memberSerialNum: memberId,
            memberName: member?.name || 'Unknown',
            amount: (props.transactionAmount * weight) / totalWeight,
          });
        });
      }
      break;
    }
  }

  return results;
});

// 应用快速模板
function applyQuickTemplate(template: any) {
  splitConfig.splitType = template.type;
  selectedTemplate.value = template;

  // 如果还没选择成员，默认选择所有成员
  if (splitConfig.selectedMembers.length === 0) {
    splitConfig.selectedMembers = availableMembers.value.map(m => m.serialNum);
  }

  initializeSplitParams();
}

// 打开配置器
function openConfigurator() {
  showConfigurator.value = true;
}

// 初始化分摊参数
function initializeSplitParams() {
  splitConfig.selectedMembers.forEach(memberId => {
    if (!splitConfig.splitParams[memberId]) {
      splitConfig.splitParams[memberId] = {
        percentage: splitConfig.splitType === 'PERCENTAGE' ? 0 : undefined,
        amount: splitConfig.splitType === 'FIXED_AMOUNT' ? 0 : undefined,
        weight: splitConfig.splitType === 'WEIGHTED' ? 1 : undefined,
      };
    }
  });
}

// 格式化金额
function formatAmount(amount: number): string {
  return `¥${amount.toFixed(2)}`;
}

// 获取类型名称
function getTypeName(type: SplitRuleType): string {
  const typeMap: Record<SplitRuleType, string> = {
    EQUAL: '均摊',
    PERCENTAGE: '按比例',
    FIXED_AMOUNT: '固定金额',
    WEIGHTED: '按权重',
  };
  return typeMap[type] || type;
}

// 监听配置变化，通知父组件
watch([enableSplit, splitConfig, splitPreview], () => {
  if (enableSplit.value && splitPreview.value.length > 0) {
    emit('update:splitConfig', {
      enabled: true,
      splitType: splitConfig.splitType,
      members: splitPreview.value,
    });
  } else {
    emit('update:splitConfig', {
      enabled: false,
    });
  }
}, { deep: true });
</script>

<template>
  <div class="transaction-split-section">
    <!-- 分摊开关 -->
    <div class="split-toggle">
      <label class="toggle-label">
        <input
          v-model="enableSplit"
          type="checkbox"
          class="toggle-input"
        >
        <span class="toggle-text">
          <LucideUsers class="icon" />
          启用费用分摊
        </span>
      </label>
      <span v-if="enableSplit" class="toggle-hint">
        {{ splitPreview.length }} 人参与分摊
      </span>
    </div>

    <!-- 分摊配置区域 -->
    <div v-if="enableSplit" class="split-config">
      <!-- 快速模板选择 -->
      <div class="quick-templates">
        <label class="section-label">快速选择</label>
        <div class="template-buttons">
          <button
            v-for="template in quickTemplates"
            :key="template.id"
            class="template-btn"
            :class="{ active: selectedTemplate?.id === template.id }"
            :style="{ '--template-color': template.color }"
            @click="applyQuickTemplate(template)"
          >
            <component :is="template.icon" class="btn-icon" />
            <span>{{ template.name }}</span>
          </button>
        </div>
      </div>

      <!-- 高级配置按钮 -->
      <button class="btn-advanced" @click="openConfigurator">
        <LucideSettings class="icon" />
        高级配置
        <LucideChevronDown class="icon-arrow" />
      </button>

      <!-- 分摊预览 -->
      <div v-if="splitPreview.length > 0" class="split-preview">
        <div class="preview-header">
          <label class="section-label">分摊预览</label>
          <span class="preview-type">{{ getTypeName(splitConfig.splitType) }}</span>
        </div>

        <div class="preview-list">
          <div
            v-for="item in splitPreview"
            :key="item.memberSerialNum"
            class="preview-item"
          >
            <span class="member-name">{{ item.memberName }}</span>
            <strong class="member-amount">{{ formatAmount(item.amount) }}</strong>
          </div>
        </div>

        <div class="preview-summary">
          <span>总计</span>
          <strong>{{ formatAmount(splitPreview.reduce((sum, item) => sum + item.amount, 0)) }}</strong>
        </div>
      </div>
    </div>

    <!-- 配置器弹窗（待集成） -->
    <!-- <SplitRuleConfigurator
      v-if="showConfigurator"
      :transaction-amount="transactionAmount"
      @close="showConfigurator = false"
      @save="handleConfigSave"
    /> -->
  </div>
</template>

<style scoped>
.transaction-split-section {
  display: flex;
  flex-direction: column;
  gap: 1rem;
  padding: 1rem;
  background: var(--color-base-100);
  border-radius: 12px;
  border: 1px solid var(--color-base-300);
}

/* Toggle */
.split-toggle {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.toggle-label {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  cursor: pointer;
}

.toggle-input {
  width: 20px;
  height: 20px;
  cursor: pointer;
}

.toggle-text {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.875rem;
  font-weight: 500;
}

.toggle-text .icon {
  width: 18px;
  height: 18px;
  color: var(--color-primary);
}

.toggle-hint {
  font-size: 0.75rem;
  color: var(--color-gray-500);
}

/* Config */
.split-config {
  display: flex;
  flex-direction: column;
  gap: 1rem;
  padding-top: 1rem;
  border-top: 1px solid var(--color-base-300);
}

.section-label {
  display: block;
  margin-bottom: 0.5rem;
  font-size: 0.875rem;
  font-weight: 500;
  color: var(--color-gray-700);
}

/* Quick Templates */
.quick-templates {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.template-buttons {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 0.5rem;
}

.template-btn {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.5rem;
  padding: 0.75rem 0.5rem;
  background: white;
  border: 2px solid var(--color-base-300);
  border-radius: 8px;
  cursor: pointer;
  transition: all 0.2s;
  font-size: 0.75rem;
}

.template-btn:hover {
  border-color: var(--template-color);
  background: oklch(from var(--template-color) l c h / 0.05);
}

.template-btn.active {
  border-color: var(--template-color);
  background: var(--template-color);
  color: white;
}

.template-btn .btn-icon {
  width: 20px;
  height: 20px;
  color: var(--template-color);
}

.template-btn.active .btn-icon {
  color: white;
}

/* Advanced Button */
.btn-advanced {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  padding: 0.75rem;
  background: white;
  border: 1px solid var(--color-base-300);
  border-radius: 8px;
  font-size: 0.875rem;
  cursor: pointer;
  transition: all 0.2s;
}

.btn-advanced:hover {
  background: var(--color-base-200);
  border-color: var(--color-primary);
}

.btn-advanced .icon {
  width: 16px;
  height: 16px;
}

.icon-arrow {
  width: 14px;
  height: 14px;
  margin-left: auto;
}

/* Preview */
.split-preview {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
  padding: 1rem;
  background: white;
  border-radius: 8px;
  border: 1px solid var(--color-base-300);
}

.preview-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.preview-type {
  padding: 0.25rem 0.75rem;
  background: var(--color-primary);
  color: white;
  border-radius: 12px;
  font-size: 0.75rem;
  font-weight: 500;
}

.preview-list {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.preview-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0.5rem;
  background: var(--color-base-100);
  border-radius: 6px;
}

.member-name {
  font-size: 0.875rem;
}

.member-amount {
  font-size: 0.875rem;
  font-weight: 600;
  color: var(--color-primary);
}

.preview-summary {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding-top: 0.75rem;
  border-top: 1px solid var(--color-base-200);
  font-size: 0.875rem;
}

.preview-summary strong {
  font-size: 1rem;
  font-weight: 600;
  color: var(--color-gray-900);
}

/* Responsive */
@media (max-width: 768px) {
  .template-buttons {
    grid-template-columns: repeat(2, 1fr);
  }
}
</style>
