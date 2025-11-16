<script setup lang="ts">
import {
  LucideCheck,
  LucideChevronLeft,
  LucideChevronRight,
  LucideCoins,
  LucideEqual,
  LucidePercent,
  LucideSave,
  LucideScale,
  LucideX,
} from 'lucide-vue-next';
import { useFamilyMemberStore } from '@/stores/money';
import type { FamilyMember, SplitRuleType } from '@/schema/money';

interface Props {
  transactionAmount?: number;
  initialTemplate?: any;
}

const props = defineProps<Props>();
const emit = defineEmits<{
  close: [];
  save: [config: any];
}>();

const memberStore = useFamilyMemberStore();

// 当前步骤（1-4）
const currentStep = ref(1);

// 配置数据
const config = reactive({
  splitType: 'EQUAL' as SplitRuleType,
  selectedMembers: [] as string[],
  splitParams: {} as Record<string, { percentage?: number; amount?: number; weight?: number }>,
  templateName: '',
  templateDescription: '',
});

// 交易金额
const amount = ref(props.transactionAmount || 100);

// 分摊类型选项
const splitTypes = [
  {
    value: 'EQUAL' as SplitRuleType,
    label: '均等分摊',
    icon: LucideEqual,
    color: '#3b82f6',
    description: '所有参与成员平均分摊费用',
  },
  {
    value: 'PERCENTAGE' as SplitRuleType,
    label: '按比例分摊',
    icon: LucidePercent,
    color: '#10b981',
    description: '根据设定的比例分摊费用',
  },
  {
    value: 'FIXED_AMOUNT' as SplitRuleType,
    label: '固定金额',
    icon: LucideCoins,
    color: '#f59e0b',
    description: '为每个成员指定固定的分摊金额',
  },
  {
    value: 'WEIGHTED' as SplitRuleType,
    label: '按权重分摊',
    icon: LucideScale,
    color: '#8b5cf6',
    description: '根据权重比例分摊费用',
  },
];

// 可用成员列表
const availableMembers = computed(() => memberStore.members);

// 已选成员详情
const selectedMemberDetails = computed(() => {
  return config.selectedMembers
    .map(id => availableMembers.value.find(m => m.serialNum === id))
    .filter(Boolean) as FamilyMember[];
});

// 计算分摊结果
const calculatedSplit = computed(() => {
  if (!amount.value || config.selectedMembers.length === 0) {
    return [];
  }

  const results: Array<{ memberSerialNum: string; memberName: string; amount: number; percentage?: number }> = [];

  switch (config.splitType) {
    case 'EQUAL': {
      const perPerson = amount.value / config.selectedMembers.length;
      config.selectedMembers.forEach(memberId => {
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
      config.selectedMembers.forEach(memberId => {
        const member = availableMembers.value.find(m => m.serialNum === memberId);
        const percentage = config.splitParams[memberId]?.percentage || 0;
        results.push({
          memberSerialNum: memberId,
          memberName: member?.name || 'Unknown',
          amount: (amount.value * percentage) / 100,
          percentage,
        });
      });
      break;
    }

    case 'FIXED_AMOUNT': {
      config.selectedMembers.forEach(memberId => {
        const member = availableMembers.value.find(m => m.serialNum === memberId);
        const fixedAmount = config.splitParams[memberId]?.amount || 0;
        results.push({
          memberSerialNum: memberId,
          memberName: member?.name || 'Unknown',
          amount: fixedAmount,
        });
      });
      break;
    }

    case 'WEIGHTED': {
      const totalWeight = config.selectedMembers.reduce((sum, id) => {
        return sum + (config.splitParams[id]?.weight || 0);
      }, 0);

      if (totalWeight > 0) {
        config.selectedMembers.forEach(memberId => {
          const member = availableMembers.value.find(m => m.serialNum === memberId);
          const weight = config.splitParams[memberId]?.weight || 0;
          results.push({
            memberSerialNum: memberId,
            memberName: member?.name || 'Unknown',
            amount: (amount.value * weight) / totalWeight,
          });
        });
      }
      break;
    }
  }

  // 处理尾数
  return handleRemainder(results, amount.value);
});

// 验证配置
const isValid = computed(() => {
  if (currentStep.value === 1) {
    return config.splitType !== null;
  }

  if (currentStep.value === 2) {
    return config.selectedMembers.length > 0;
  }

  if (currentStep.value === 3) {
    return validateSplitParams();
  }

  return true;
});

// 验证分摊参数
function validateSplitParams(): boolean {
  if (config.splitType === 'PERCENTAGE') {
    const total = config.selectedMembers.reduce((sum, id) => {
      return sum + (config.splitParams[id]?.percentage || 0);
    }, 0);
    return Math.abs(total - 100) < 0.01;
  }

  if (config.splitType === 'FIXED_AMOUNT') {
    const total = config.selectedMembers.reduce((sum, id) => {
      return sum + (config.splitParams[id]?.amount || 0);
    }, 0);
    return Math.abs(total - amount.value) < 0.01;
  }

  if (config.splitType === 'WEIGHTED') {
    const totalWeight = config.selectedMembers.reduce((sum, id) => {
      return sum + (config.splitParams[id]?.weight || 0);
    }, 0);
    return totalWeight > 0;
  }

  return true;
}

// 处理尾数
function handleRemainder(splits: any[], totalAmount: number) {
  const calculatedTotal = splits.reduce((sum, s) => sum + s.amount, 0);
  const remainder = totalAmount - calculatedTotal;

  if (Math.abs(remainder) > 0.01 && splits.length > 0) {
    splits[0].amount += remainder;
  }

  return splits;
}

// 格式化金额
function formatAmount(value: number): string {
  return `¥${value.toFixed(2)}`;
}

// 步骤导航
function nextStep() {
  if (currentStep.value < 4 && isValid.value) {
    currentStep.value++;
  }
}

function prevStep() {
  if (currentStep.value > 1) {
    currentStep.value--;
  }
}

// 全选/清空成员
function selectAllMembers() {
  config.selectedMembers = availableMembers.value.map(m => m.serialNum);
  initializeSplitParams();
}

function clearMembers() {
  config.selectedMembers = [];
  config.splitParams = {};
}

// 成员选择变化
function onMemberSelectionChange() {
  initializeSplitParams();
}

// 初始化分摊参数
function initializeSplitParams() {
  config.selectedMembers.forEach(memberId => {
    if (!config.splitParams[memberId]) {
      config.splitParams[memberId] = {
        percentage: config.splitType === 'PERCENTAGE' ? 0 : undefined,
        amount: config.splitType === 'FIXED_AMOUNT' ? 0 : undefined,
        weight: config.splitType === 'WEIGHTED' ? 1 : undefined,
      };
    }
  });
}

// 保存配置
function saveConfig() {
  emit('save', {
    ...config,
    calculatedSplit: calculatedSplit.value,
  });
}

// 保存为模板
function saveAsTemplate() {
  // eslint-disable-next-line no-console
  console.log('Saving as template:', config);
}

// 关闭
function close() {
  emit('close');
}

// 初始化
onMounted(() => {
  if (props.initialTemplate) {
    Object.assign(config, props.initialTemplate);
  }
});
</script>

<template>
  <div class="split-rule-configurator">
    <div class="configurator-overlay" @click="close" />

    <div class="configurator-modal">
      <!-- Header -->
      <div class="modal-header">
        <h3>分摊规则配置</h3>
        <button class="btn-close" @click="close">
          <LucideX class="icon" />
        </button>
      </div>

      <!-- 步骤指示器 -->
      <div class="step-indicator">
        <div
          v-for="step in 4"
          :key="step"
          class="step-item"
          :class="{ active: currentStep === step, completed: currentStep > step }"
        >
          <div class="step-number">
            <LucideCheck v-if="currentStep > step" class="icon" />
            <span v-else>{{ step }}</span>
          </div>
          <span class="step-label">
            {{
              step === 1 ? '选择类型'
              : step === 2 ? '选择成员'
                : step === 3 ? '配置参数'
                  : '预览结果'
            }}
          </span>
        </div>
      </div>

      <!-- 内容区域 -->
      <div class="modal-content">
        <!-- 步骤 1: 选择分摊类型 -->
        <div v-if="currentStep === 1" class="step-content">
          <h4>选择分摊类型</h4>
          <p class="step-description">
            选择适合您需求的分摊方式
          </p>

          <div class="split-type-grid">
            <label
              v-for="type in splitTypes"
              :key="type.value"
              class="type-option"
              :class="{ selected: config.splitType === type.value }"
              :style="{ '--type-color': type.color }"
            >
              <input
                v-model="config.splitType"
                type="radio"
                :value="type.value"
                hidden
              >
              <div class="type-icon-wrapper">
                <component :is="type.icon" class="type-icon" />
              </div>
              <h5>{{ type.label }}</h5>
              <p>{{ type.description }}</p>
            </label>
          </div>
        </div>

        <!-- 步骤 2: 选择参与成员 -->
        <div v-if="currentStep === 2" class="step-content">
          <div class="step-header">
            <div>
              <h4>选择参与成员</h4>
              <p class="step-description">
                选择参与此次分摊的成员
              </p>
            </div>
            <div class="quick-actions">
              <button class="btn-text" @click="selectAllMembers">
                全选
              </button>
              <button class="btn-text" @click="clearMembers">
                清空
              </button>
            </div>
          </div>

          <div class="member-selection-grid">
            <label
              v-for="member in availableMembers"
              :key="member.serialNum"
              class="member-checkbox"
            >
              <input
                v-model="config.selectedMembers"
                type="checkbox"
                :value="member.serialNum"
                @change="onMemberSelectionChange"
              >
              <div class="member-card">
                <div class="member-avatar" :style="{ backgroundColor: member.colorTag || '#3b82f6' }">
                  {{ member.name.charAt(0) }}
                </div>
                <span class="member-name">{{ member.name }}</span>
              </div>
            </label>
          </div>

          <div v-if="config.selectedMembers.length > 0" class="selection-summary">
            已选择 {{ config.selectedMembers.length }} 位成员
          </div>
        </div>

        <!-- 步骤 3: 配置分摊参数 -->
        <div v-if="currentStep === 3" class="step-content">
          <h4>配置分摊参数</h4>
          <p class="step-description">
            为每位成员设置
            {{
              config.splitType === 'PERCENTAGE' ? '分摊比例'
              : config.splitType === 'FIXED_AMOUNT' ? '分摊金额'
                : config.splitType === 'WEIGHTED' ? '权重值'
                  : '参数'
            }}
          </p>

          <!-- 均摊：无需配置 -->
          <div v-if="config.splitType === 'EQUAL'" class="config-equal">
            <div class="info-card">
              <LucideEqual class="info-icon" />
              <p>均等分摊无需额外配置，每位成员将平均分摊费用</p>
            </div>
          </div>

          <!-- 按比例 -->
          <div v-if="config.splitType === 'PERCENTAGE'" class="config-params">
            <div
              v-for="member in selectedMemberDetails"
              :key="member.serialNum"
              class="param-row"
            >
              <span class="param-label">{{ member.name }}</span>
              <div class="param-input-group">
                <input
                  v-model.number="config.splitParams[member.serialNum].percentage"
                  type="number"
                  min="0"
                  max="100"
                  step="0.1"
                  class="param-input"
                >
                <span class="param-unit">%</span>
              </div>
            </div>

            <div class="validation-summary" :class="{ error: !isValid }">
              总计: {{ config.selectedMembers.reduce((sum, id) => sum + (config.splitParams[id]?.percentage || 0), 0).toFixed(1) }}%
              <span v-if="isValid" class="valid-icon">✓</span>
              <span v-else class="error-text">必须为 100%</span>
            </div>
          </div>

          <!-- 固定金额 -->
          <div v-if="config.splitType === 'FIXED_AMOUNT'" class="config-params">
            <div
              v-for="member in selectedMemberDetails"
              :key="member.serialNum"
              class="param-row"
            >
              <span class="param-label">{{ member.name }}</span>
              <div class="param-input-group">
                <span class="param-prefix">¥</span>
                <input
                  v-model.number="config.splitParams[member.serialNum].amount"
                  type="number"
                  min="0"
                  step="0.01"
                  class="param-input"
                >
              </div>
            </div>

            <div class="validation-summary" :class="{ error: !isValid }">
              总计: ¥{{ config.selectedMembers.reduce((sum, id) => sum + (config.splitParams[id]?.amount || 0), 0).toFixed(2) }}
              / ¥{{ amount.toFixed(2) }}
              <span v-if="isValid" class="valid-icon">✓</span>
              <span v-else class="error-text">必须等于交易金额</span>
            </div>
          </div>

          <!-- 按权重 -->
          <div v-if="config.splitType === 'WEIGHTED'" class="config-params">
            <div
              v-for="member in selectedMemberDetails"
              :key="member.serialNum"
              class="param-row"
            >
              <span class="param-label">{{ member.name }}</span>
              <div class="param-input-group">
                <input
                  v-model.number="config.splitParams[member.serialNum].weight"
                  type="number"
                  min="1"
                  step="1"
                  class="param-input"
                >
                <span class="param-unit">权重</span>
              </div>
            </div>

            <div class="validation-summary">
              总权重: {{ config.selectedMembers.reduce((sum, id) => sum + (config.splitParams[id]?.weight || 0), 0) }}
            </div>
          </div>
        </div>

        <!-- 步骤 4: 预览结果 -->
        <div v-if="currentStep === 4" class="step-content">
          <h4>预览分摊结果</h4>
          <p class="step-description">
            确认分摊结果无误后，可以保存或应用
          </p>

          <div class="preview-section">
            <div class="preview-summary">
              <div class="summary-item">
                <label>交易金额</label>
                <strong>{{ formatAmount(amount) }}</strong>
              </div>
              <div class="summary-item">
                <label>分摊类型</label>
                <strong>{{ splitTypes.find(t => t.value === config.splitType)?.label }}</strong>
              </div>
              <div class="summary-item">
                <label>参与人数</label>
                <strong>{{ config.selectedMembers.length }} 人</strong>
              </div>
            </div>

            <div class="preview-results">
              <div
                v-for="result in calculatedSplit"
                :key="result.memberSerialNum"
                class="result-item"
              >
                <span class="result-name">{{ result.memberName }}</span>
                <div class="result-amount-group">
                  <span v-if="result.percentage" class="result-percentage">
                    {{ result.percentage.toFixed(1) }}%
                  </span>
                  <strong class="result-amount">{{ formatAmount(result.amount) }}</strong>
                </div>
              </div>
            </div>

            <!-- 保存为模板 -->
            <div class="template-save-section">
              <h5>保存为模板（可选）</h5>
              <input
                v-model="config.templateName"
                type="text"
                placeholder="模板名称"
                class="template-name-input"
              >
              <textarea
                v-model="config.templateDescription"
                placeholder="模板描述（可选）"
                class="template-desc-input"
                rows="2"
              />
            </div>
          </div>
        </div>
      </div>

      <!-- Footer -->
      <div class="modal-footer">
        <button v-if="currentStep > 1" class="btn-secondary" @click="prevStep">
          <LucideChevronLeft class="icon" />
          上一步
        </button>

        <div class="footer-spacer" />

        <button
          v-if="currentStep < 4"
          class="btn-primary"
          :disabled="!isValid"
          @click="nextStep"
        >
          下一步
          <LucideChevronRight class="icon" />
        </button>

        <template v-if="currentStep === 4">
          <button
            v-if="config.templateName"
            class="btn-secondary"
            @click="saveAsTemplate"
          >
            <LucideSave class="icon" />
            保存模板
          </button>
          <button class="btn-primary" @click="saveConfig">
            <LucideCheck class="icon" />
            应用分摊
          </button>
        </template>
      </div>
    </div>
  </div>
</template>

<style scoped src="./SplitRuleConfigurator.css"></style>
