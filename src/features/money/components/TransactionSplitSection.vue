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
import SplitRuleConfigurator from './SplitRuleConfigurator.vue';
import type { SplitRuleType } from '@/schema/money';

interface Props {
  transactionAmount: number;
  ledgerSerialNum?: string;
  selectedMembers: string[];
  availableMembers?: any[];
}

const props = defineProps<Props>();
const emit = defineEmits<{
  'update:splitConfig': [config: any];
}>();

// 分摊开关
const enableSplit = ref(false);

// 选中的模板
const selectedTemplate = ref<any>(null);

// 分摊配置
const splitConfig = reactive({
  splitType: 'EQUAL' as SplitRuleType,
  selectedMembers: props.selectedMembers || [],
  splitParams: {} as Record<string, { percentage?: number; amount?: number; weight?: number }>,
});

// 显示配置器
const showConfigurator = ref(false);

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
        const member = props.availableMembers?.find((m: any) => m.serialNum === memberId);
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
        const member = props.availableMembers?.find((m: any) => m.serialNum === memberId);
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
        const member = props.availableMembers?.find((m: any) => m.serialNum === memberId);
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
          const member = props.availableMembers?.find((m: any) => m.serialNum === memberId);
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

  // 使用父组件传入的已选成员，不再自动选择所有成员
  // splitConfig.selectedMembers 已经由 watch 同步

  initializeSplitParams();
}

// 打开配置器
function openConfigurator() {
  showConfigurator.value = true;
}

// 关闭配置器
function closeConfigurator() {
  showConfigurator.value = false;
}

// 保存配置
function handleConfigSave(config: any) {
  // 应用配置到 splitConfig
  splitConfig.splitType = config.ruleType;
  config.participants.forEach((participant: any) => {
    const memberId = participant.memberSerialNum;
    if (!splitConfig.splitParams[memberId]) {
      splitConfig.splitParams[memberId] = {};
    }
    splitConfig.splitParams[memberId].percentage = participant.percentage;
    splitConfig.splitParams[memberId].amount = participant.fixedAmount;
    splitConfig.splitParams[memberId].weight = participant.weight;
  });
  showConfigurator.value = false;
}

// 初始化分摊参数
function initializeSplitParams() {
  const memberCount = splitConfig.selectedMembers.length;
  const defaultPercentage = memberCount > 0 ? Number((100 / memberCount).toFixed(2)) : 0;

  splitConfig.selectedMembers.forEach(memberId => {
    if (!splitConfig.splitParams[memberId]) {
      splitConfig.splitParams[memberId] = {
        percentage: splitConfig.splitType === 'PERCENTAGE' ? defaultPercentage : undefined,
        amount: splitConfig.splitType === 'FIXED_AMOUNT' ? 0 : undefined,
        weight: splitConfig.splitType === 'WEIGHTED' ? 1 : undefined,
      };
    } else {
      // 确保切换到权重模式时，如果没有设置权重，默认为1
      if (splitConfig.splitType === 'WEIGHTED' && (splitConfig.splitParams[memberId].weight === undefined || splitConfig.splitParams[memberId].weight === 0)) {
        splitConfig.splitParams[memberId].weight = 1;
      }
    }
  });
}

// 计算权重占比
function getWeightPercentage(memberId: string): string {
  if (splitConfig.splitType !== 'WEIGHTED') return '';

  const totalWeight = splitConfig.selectedMembers.reduce((sum, id) => {
    return sum + (splitConfig.splitParams[id]?.weight || 0);
  }, 0);

  if (totalWeight === 0) return '0%';

  const memberWeight = splitConfig.splitParams[memberId]?.weight || 0;
  const percentage = (memberWeight / totalWeight) * 100;
  return `${percentage.toFixed(1)}%`;
}

// 格式化金额
function formatAmount(amount: number): string {
  return `¥${amount.toFixed(2)}`;
}

// 计算总和验证
const totalValidation = computed(() => {
  if (splitConfig.splitType === 'PERCENTAGE') {
    const total = splitConfig.selectedMembers.reduce((sum, id) => {
      return sum + (splitConfig.splitParams[id]?.percentage || 0);
    }, 0);
    return {
      total: Number(total.toFixed(2)),
      target: 100,
      isValid: Math.abs(total - 100) < 0.01,
      unit: '%',
    };
  }
  if (splitConfig.splitType === 'FIXED_AMOUNT') {
    const total = splitConfig.selectedMembers.reduce((sum, id) => {
      return sum + (splitConfig.splitParams[id]?.amount || 0);
    }, 0);
    return {
      total: Number(total.toFixed(2)),
      target: props.transactionAmount,
      isValid: Math.abs(total - props.transactionAmount) < 0.01,
      unit: '¥',
    };
  }
  return { total: 0, target: 0, isValid: true, unit: '' };
});

// 平均分配
function distributeEvenly() {
  const memberCount = splitConfig.selectedMembers.length;
  if (memberCount === 0) return;

  if (splitConfig.splitType === 'PERCENTAGE') {
    const perMember = Number((100 / memberCount).toFixed(2));
    splitConfig.selectedMembers.forEach(memberId => {
      if (!splitConfig.splitParams[memberId]) {
        splitConfig.splitParams[memberId] = {};
      }
      splitConfig.splitParams[memberId].percentage = perMember;
    });
  } else if (splitConfig.splitType === 'FIXED_AMOUNT') {
    const perMember = Number((props.transactionAmount / memberCount).toFixed(2));
    splitConfig.selectedMembers.forEach(memberId => {
      if (!splitConfig.splitParams[memberId]) {
        splitConfig.splitParams[memberId] = {};
      }
      splitConfig.splitParams[memberId].amount = perMember;
    });
  } else if (splitConfig.splitType === 'WEIGHTED') {
    splitConfig.selectedMembers.forEach(memberId => {
      if (!splitConfig.splitParams[memberId]) {
        splitConfig.splitParams[memberId] = {};
      }
      splitConfig.splitParams[memberId].weight = 1;
    });
  }
}

// 两人联动：按比例（只有2人时自动调整另一人）
function handlePercentageInput(changedMemberId: string, newValue: number) {
  // 只有3人或以上才强制限制最大值
  if (splitConfig.selectedMembers.length > 2) {
    const maxValue = getMaxPercentage(changedMemberId);
    if (newValue > maxValue) {
      splitConfig.splitParams[changedMemberId].percentage = maxValue;
      return;
    }
  }

  // 2人时自动联动
  if (splitConfig.selectedMembers.length === 2) {
    // 限制在0-100之间
    const clampedValue = Math.max(0, Math.min(100, newValue || 0));
    if (clampedValue !== newValue) {
      splitConfig.splitParams[changedMemberId].percentage = clampedValue;
      newValue = clampedValue;
    }

    const otherMemberId = splitConfig.selectedMembers.find(id => id !== changedMemberId);
    if (!otherMemberId) return;

    const remaining = 100 - newValue;
    if (!splitConfig.splitParams[otherMemberId]) {
      splitConfig.splitParams[otherMemberId] = {};
    }
    splitConfig.splitParams[otherMemberId].percentage = Number(remaining.toFixed(2));
  }
}

// 两人联动：固定金额（只有2人时自动调整另一人）
function handleAmountInput(changedMemberId: string, newValue: number) {
  // 只有3人或以上才强制限制最大值
  if (splitConfig.selectedMembers.length > 2) {
    const maxValue = getMaxAmount(changedMemberId);
    if (newValue > maxValue) {
      splitConfig.splitParams[changedMemberId].amount = maxValue;
      return;
    }
  }

  // 2人时自动联动
  if (splitConfig.selectedMembers.length === 2) {
    // 限制在0到交易金额之间
    const clampedValue = Math.max(0, Math.min(props.transactionAmount, newValue || 0));
    if (clampedValue !== newValue) {
      splitConfig.splitParams[changedMemberId].amount = clampedValue;
      newValue = clampedValue;
    }

    const otherMemberId = splitConfig.selectedMembers.find(id => id !== changedMemberId);
    if (!otherMemberId) return;

    const remaining = props.transactionAmount - newValue;
    if (!splitConfig.splitParams[otherMemberId]) {
      splitConfig.splitParams[otherMemberId] = {};
    }
    splitConfig.splitParams[otherMemberId].amount = Number(remaining.toFixed(2));
  }
}

// 计算每个成员的最大允许值（按比例）
function getMaxPercentage(memberId: string): number {
  const othersTotal = splitConfig.selectedMembers
    .filter(id => id !== memberId)
    .reduce((sum, id) => sum + (splitConfig.splitParams[id]?.percentage || 0), 0);
  return Number((100 - othersTotal).toFixed(2));
}

// 计算每个成员的最大允许值（固定金额）
function getMaxAmount(memberId: string): number {
  const othersTotal = splitConfig.selectedMembers
    .filter(id => id !== memberId)
    .reduce((sum, id) => sum + (splitConfig.splitParams[id]?.amount || 0), 0);
  return Number((props.transactionAmount - othersTotal).toFixed(2));
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

// 监听 selectedMembers prop 变化
watch(() => props.selectedMembers, newMembers => {
  splitConfig.selectedMembers = newMembers || [];
  initializeSplitParams();
}, { immediate: true });

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
        {{ splitConfig.selectedMembers.length }} 人参与分摊
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
            type="button"
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

      <!-- 参数配置（按比例、固定金额、按权重） -->
      <div v-if="splitConfig.splitType !== 'EQUAL'" class="params-config">
        <div class="params-header">
          <div class="header-left">
            <label class="section-label">设置分摊参数</label>
            <span v-if="splitConfig.splitType === 'WEIGHTED'" class="helper-text">
              权重数字越大，分摊金额越多
            </span>
          </div>
          <button type="button" class="btn-distribute" @click="distributeEvenly">
            <LucideEqual class="icon-sm" />
            平均分配
          </button>
        </div>
        <div class="params-list">
          <div
            v-for="memberId in splitConfig.selectedMembers"
            :key="memberId"
            class="param-item"
          >
            <span class="param-member">{{ props.availableMembers?.find((m: any) => m.serialNum === memberId)?.name || 'Unknown' }}</span>
            <div class="param-input-group">
              <input
                v-if="splitConfig.splitType === 'PERCENTAGE'"
                v-model.number="splitConfig.splitParams[memberId].percentage"
                type="number"
                class="param-input"
                placeholder="比例"
                min="0"
                :max="getMaxPercentage(memberId)"
                step="0.01"
                @input="handlePercentageInput(memberId, splitConfig.splitParams[memberId].percentage || 0)"
              >
              <span v-if="splitConfig.splitType === 'PERCENTAGE'" class="param-unit">%</span>
              <input
                v-if="splitConfig.splitType === 'FIXED_AMOUNT'"
                v-model.number="splitConfig.splitParams[memberId].amount"
                type="number"
                class="param-input"
                placeholder="金额"
                min="0"
                :max="getMaxAmount(memberId)"
                step="0.01"
                @input="handleAmountInput(memberId, splitConfig.splitParams[memberId].amount || 0)"
              >
              <span v-if="splitConfig.splitType === 'FIXED_AMOUNT'" class="param-unit">¥</span>
              <input
                v-if="splitConfig.splitType === 'WEIGHTED'"
                v-model.number="splitConfig.splitParams[memberId].weight"
                type="number"
                class="param-input"
                placeholder="权重"
                min="0"
                step="1"
              >
              <span v-if="splitConfig.splitType === 'WEIGHTED'" class="param-percentage">
                {{ getWeightPercentage(memberId) }}
              </span>
            </div>
          </div>
        </div>

        <!-- 总和验证提示（仅在不正确时显示） -->
        <div v-if="!totalValidation.isValid" class="validation-hint validation-error">
          <span class="validation-label">总计：</span>
          <strong class="validation-value">{{ totalValidation.unit }}{{ totalValidation.total }}</strong>
          <span class="validation-target">
            / 目标：{{ totalValidation.unit }}{{ totalValidation.target }}
          </span>
        </div>
      </div>

      <!-- 高级配置按钮 -->
      <button type="button" class="btn-advanced" @click="openConfigurator">
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

    <!-- 配置器弹窗 -->
    <SplitRuleConfigurator
      v-if="showConfigurator"
      :transaction-amount="transactionAmount"
      @close="closeConfigurator"
      @save="handleConfigSave"
    />
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

/* Params Config */
.params-config {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.params-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.header-left {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.helper-text {
  font-size: 0.75rem;
  color: var(--color-gray-500);
  font-style: italic;
}

.btn-distribute {
  display: flex;
  align-items: center;
  gap: 0.25rem;
  padding: 0.375rem 0.75rem;
  background: var(--color-primary);
  color: white;
  border: none;
  border-radius: 6px;
  font-size: 0.75rem;
  cursor: pointer;
  transition: all 0.2s;
}

.btn-distribute:hover {
  background: oklch(from var(--color-primary) calc(l * 0.9) c h);
}

.btn-distribute .icon-sm {
  width: 14px;
  height: 14px;
}

.params-list {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.param-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0.75rem;
  background: white;
  border: 1px solid var(--color-base-300);
  border-radius: 8px;
  gap: 1rem;
}

.param-member {
  font-size: 0.875rem;
  font-weight: 500;
  color: var(--color-gray-700);
  min-width: 80px;
}

.param-input-group {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  flex: 1;
  justify-content: flex-end;
}

.param-input {
  width: 100px;
  padding: 0.5rem;
  border: 1px solid var(--color-base-300);
  border-radius: 6px;
  font-size: 0.875rem;
  text-align: right;
  transition: all 0.2s;
}

.param-input:focus {
  outline: none;
  border-color: var(--color-primary);
  box-shadow: 0 0 0 3px oklch(from var(--color-primary) l c h / 0.1);
}

.param-unit {
  font-size: 0.875rem;
  color: var(--color-gray-500);
  font-weight: 500;
  min-width: 20px;
}

.param-percentage {
  font-size: 0.75rem;
  color: var(--color-primary);
  font-weight: 600;
  padding: 0.25rem 0.5rem;
  background: oklch(from var(--color-primary) l c h / 0.1);
  border-radius: 4px;
  min-width: 50px;
  text-align: center;
}

/* Validation Hint */
.validation-hint {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.75rem;
  background: oklch(from var(--color-primary) l c h / 0.1);
  border: 1px solid var(--color-primary);
  border-radius: 8px;
  font-size: 0.875rem;
}

.validation-hint.validation-error {
  background: oklch(from #ef4444 l c h / 0.1);
  border-color: #ef4444;
}

.validation-label {
  color: var(--color-gray-600);
}

.validation-value {
  color: var(--color-gray-900);
  font-size: 1rem;
}

.validation-error .validation-value {
  color: #ef4444;
}

.validation-target {
  color: var(--color-gray-500);
  font-size: 0.75rem;
}

.validation-success {
  margin-left: auto;
  color: #10b981;
  font-size: 1rem;
  font-weight: bold;
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
