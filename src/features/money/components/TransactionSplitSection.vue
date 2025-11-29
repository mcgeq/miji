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
import { nextTick } from 'vue';
import SplitRuleConfigurator from './SplitRuleConfigurator.vue';
import type { SplitRuleType } from '@/schema/money';

interface Props {
  transactionAmount: number;
  ledgerSerialNum?: string;
  selectedMembers: string[];
  availableMembers?: any[];
  readonly?: boolean; // 只读模式
  initialConfig?: {
    enabled: boolean;
    splitType?: string;
    members?: Array<{
      memberSerialNum: string;
      memberName: string;
      amount: number;
      percentage?: number;
      weight?: number;
    }>;
  };
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
  // 缓存成员名称（用于编辑模式，避免依赖 availableMembers）
  memberNames: {} as Record<string, string>,
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

  const results: Array<{
    memberSerialNum: string;
    memberName: string;
    amount: number;
    percentage?: number;
    weight?: number;
  }> = [];

  // 辅助函数：获取成员名称（优先使用缓存）
  const getMemberName = (memberId: string): string => {
    // 优先使用缓存的名称（编辑模式恢复的）
    if (splitConfig.memberNames[memberId]) {
      return splitConfig.memberNames[memberId];
    }
    // 其次从 availableMembers 查找
    const member = props.availableMembers?.find((m: any) => m.serialNum === memberId);
    return member?.name || 'Unknown';
  };

  switch (splitConfig.splitType) {
    case 'EQUAL': {
      const perPerson = props.transactionAmount / splitConfig.selectedMembers.length;
      splitConfig.selectedMembers.forEach(memberId => {
        results.push({
          memberSerialNum: memberId,
          memberName: getMemberName(memberId),
          amount: perPerson,
        });
      });
      break;
    }

    case 'PERCENTAGE': {
      splitConfig.selectedMembers.forEach(memberId => {
        const percentage = splitConfig.splitParams[memberId]?.percentage || 0;
        results.push({
          memberSerialNum: memberId,
          memberName: getMemberName(memberId),
          amount: (props.transactionAmount * percentage) / 100,
          percentage, // 包含百分比
        });
      });
      break;
    }

    case 'FIXED_AMOUNT': {
      splitConfig.selectedMembers.forEach(memberId => {
        const amount = splitConfig.splitParams[memberId]?.amount || 0;
        results.push({
          memberSerialNum: memberId,
          memberName: getMemberName(memberId),
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
          const weight = splitConfig.splitParams[memberId]?.weight || 0;
          results.push({
            memberSerialNum: memberId,
            memberName: getMemberName(memberId),
            amount: (props.transactionAmount * weight) / totalWeight,
            weight, // 包含权重
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
      splitConfig.splitParams[memberId] = {};
    }

    // 根据当前分摊类型初始化相应的参数
    if (splitConfig.splitType === 'PERCENTAGE') {
      if (splitConfig.splitParams[memberId].percentage === undefined) {
        splitConfig.splitParams[memberId].percentage = defaultPercentage;
      }
    } else if (splitConfig.splitType === 'FIXED_AMOUNT') {
      if (splitConfig.splitParams[memberId].amount === undefined) {
        splitConfig.splitParams[memberId].amount = 0;
      }
    } else if (splitConfig.splitType === 'WEIGHTED') {
      if (splitConfig.splitParams[memberId].weight === undefined || splitConfig.splitParams[memberId].weight === 0) {
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
function formatAmount(amount: number | undefined | null): string {
  if (amount === undefined || amount === null || Number.isNaN(amount)) {
    return '¥0.00';
  }
  const numAmount = typeof amount === 'number' ? amount : Number(amount);
  return `¥${numAmount.toFixed(2)}`;
}

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

// 标记是否正在恢复配置（避免被 selectedMembers 的 watch 覆盖）
const isRestoringConfig = ref(false);

// 监听 initialConfig，用于编辑时恢复配置（优先级高）
watch(() => props.initialConfig, config => {
  if (config && config.enabled) {
    isRestoringConfig.value = true; // 标记正在恢复

    enableSplit.value = true;

    // 🔑 关键修复：转换后端的 PascalCase 格式为前端的 UPPER_CASE 格式
    const splitTypeMap: Record<string, SplitRuleType> = {
      Equal: 'EQUAL',
      Percentage: 'PERCENTAGE',
      FixedAmount: 'FIXED_AMOUNT',
      Weighted: 'WEIGHTED',
    };
    splitConfig.splitType = (config.splitType && splitTypeMap[config.splitType]) || config.splitType as SplitRuleType || 'EQUAL';

    // 🔑 设置选中的模板（用于按钮高亮显示）
    selectedTemplate.value = quickTemplates.find(t => t.type === splitConfig.splitType) || null;

    // 恢复分摊参数
    if (config.members && config.members.length > 0) {
      // 🔑 关键修复：恢复 selectedMembers（splitPreview 依赖这个）
      splitConfig.selectedMembers = config.members.map(m => m.memberSerialNum);

      config.members.forEach(member => {
        // 🔑 缓存成员名称（避免依赖 availableMembers）
        splitConfig.memberNames[member.memberSerialNum] = member.memberName;

        if (!splitConfig.splitParams[member.memberSerialNum]) {
          splitConfig.splitParams[member.memberSerialNum] = {};
        }
        splitConfig.splitParams[member.memberSerialNum].amount = member.amount;
        if (member.percentage !== undefined && member.percentage !== null) {
          splitConfig.splitParams[member.memberSerialNum].percentage = Number(member.percentage);
        }
        if (member.weight !== undefined && member.weight !== null) {
          splitConfig.splitParams[member.memberSerialNum].weight = Number(member.weight);
        }
      });
    }

    // 延迟重置标记，确保所有 watch 和 computed 都执行完毕
    // 使用双 nextTick 确保所有 reactive 更新都传播完成
    nextTick(() => {
      nextTick(() => {
        isRestoringConfig.value = false;
      });
    });
  }
}, { immediate: true });

// 监听 selectedMembers prop 变化
watch(() => props.selectedMembers, newMembers => {
  // 如果正在恢复配置，不要覆盖 selectedMembers（已由 initialConfig 设置）
  if (!isRestoringConfig.value) {
    // 编辑模式额外保护：如果 initialConfig 有数据，且当前 selectedMembers 已经有值，不要覆盖
    if (props.initialConfig?.enabled && splitConfig.selectedMembers.length > 0) {
      return;
    }

    splitConfig.selectedMembers = newMembers || [];
    initializeSplitParams();
  }
}, { immediate: true });

// 监听配置变化，通知父组件
watch([enableSplit, splitConfig, splitPreview], () => {
  // 如果正在恢复配置，不要 emit（避免覆盖父组件的 splitConfig）
  if (isRestoringConfig.value) {
    return;
  }

  if (enableSplit.value && splitPreview.value.length > 0) {
    emit('update:splitConfig', {
      enabled: true,
      splitType: splitConfig.splitType,
      members: splitPreview.value,
    });
  } else {
    // 编辑模式保护：如果 initialConfig 曾经是 enabled，不要主动 emit disabled
    // 这种情况通常是因为 availableMembers 还未加载完成导致 splitPreview 为空
    if (props.initialConfig?.enabled) {
      return;
    }

    // 额外检查：如果是因为还在初始化而导致的空数据，不要急着 emit disabled
    if (splitConfig.selectedMembers.length === 0 && props.selectedMembers.length > 0) {
      return;
    }

    emit('update:splitConfig', {
      enabled: false,
    });
  }
}, { deep: true });
</script>

<template>
  <div class="flex flex-col gap-4 p-4 bg-gray-50 dark:bg-gray-800 rounded-xl border border-gray-200 dark:border-gray-700">
    <!-- 分摊开关 -->
    <div class="flex justify-between items-center">
      <label class="flex items-center gap-3 cursor-pointer">
        <input
          v-model="enableSplit"
          type="checkbox"
          class="w-5 h-5 cursor-pointer disabled:cursor-not-allowed disabled:opacity-60"
          :disabled="props.readonly"
        >
        <span class="flex items-center gap-2 text-sm font-medium text-gray-900 dark:text-white">
          <LucideUsers class="w-4 h-4 text-blue-600 dark:text-blue-400" />
          启用费用分摊
        </span>
      </label>
      <span v-if="enableSplit" class="text-xs text-gray-500 dark:text-gray-400">
        {{ splitConfig.selectedMembers.length }} 人参与分摊
      </span>
    </div>

    <!-- 分摊配置区域 -->
    <div v-if="enableSplit" class="flex flex-col gap-4 pt-4 border-t border-gray-200 dark:border-gray-700">
      <!-- 快速模板选择 -->
      <div class="flex flex-col gap-3">
        <label class="block mb-2 text-sm font-medium text-gray-700 dark:text-gray-300">快速选择</label>
        <div class="grid grid-cols-2 md:grid-cols-4 gap-2">
          <button
            v-for="template in quickTemplates"
            :key="template.id"
            type="button"
            class="flex flex-col items-center gap-1 px-2 py-2 border-2 rounded-md cursor-pointer transition-all text-xs disabled:cursor-not-allowed disabled:opacity-60" :class="[
              selectedTemplate?.id === template.id
                ? 'border-current bg-opacity-15'
                : 'border-gray-200 dark:border-gray-600 bg-gray-50 dark:bg-gray-700 hover:border-current hover:bg-opacity-5',
            ]"
            :style="{ color: template.color, backgroundColor: selectedTemplate?.id === template.id ? `${template.color}26` : undefined }"
            :disabled="props.readonly"
            @click="applyQuickTemplate(template)"
          >
            <component :is="template.icon" class="w-4 h-4" :style="{ color: template.color }" />
            <span>{{ template.name }}</span>
          </button>
        </div>
      </div>

      <!-- 参数配置（按比例、固定金额、按权重） -->
      <div v-if="splitConfig.splitType !== 'EQUAL'" class="flex flex-col gap-3">
        <div class="flex justify-between items-center">
          <div class="flex flex-col gap-1">
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">设置分摊参数</label>
            <span v-if="splitConfig.splitType === 'WEIGHTED'" class="text-xs text-gray-500 dark:text-gray-400 italic">
              权重数字越大，分摊金额越多
            </span>
          </div>
          <button
            type="button"
            class="flex items-center gap-1 px-3 py-1.5 bg-blue-600 dark:bg-blue-500 text-white border-0 rounded-md text-xs cursor-pointer transition-all hover:bg-blue-700 dark:hover:bg-blue-600 disabled:bg-gray-200 dark:disabled:bg-gray-700 disabled:text-gray-500 dark:disabled:text-gray-400 disabled:cursor-not-allowed disabled:opacity-60"
            :disabled="props.readonly"
            @click="distributeEvenly"
          >
            <LucideEqual class="w-3.5 h-3.5" />
            平均分配
          </button>
        </div>
        <div class="flex flex-col gap-2">
          <div
            v-for="memberId in splitConfig.selectedMembers"
            :key="memberId"
            class="flex items-center justify-between px-3 py-3 bg-gray-50 dark:bg-gray-700 border border-gray-200 dark:border-gray-600 rounded-lg gap-4"
          >
            <span class="text-sm font-medium text-gray-700 dark:text-gray-200 min-w-[80px]">{{ props.availableMembers?.find((m: any) => m.serialNum === memberId)?.name || 'Unknown' }}</span>
            <div class="flex items-center gap-2 flex-1 justify-end">
              <input
                v-if="splitConfig.splitType === 'PERCENTAGE'"
                v-model.number="splitConfig.splitParams[memberId].percentage"
                type="number"
                class="w-[100px] px-2 py-2 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-600 rounded-md text-sm text-right transition-all focus:outline-none focus:bg-white focus:border-blue-600 focus:ring-2 focus:ring-blue-600/10 read-only:bg-gray-100 dark:read-only:bg-gray-600 read-only:text-gray-600 dark:read-only:text-gray-400 read-only:cursor-not-allowed"
                placeholder="比例"
                min="0"
                :max="getMaxPercentage(memberId)"
                step="0.01"
                :readonly="props.readonly"
                @input="handlePercentageInput(memberId, splitConfig.splitParams[memberId].percentage || 0)"
              >
              <span v-if="splitConfig.splitType === 'PERCENTAGE'" class="text-sm text-gray-500 dark:text-gray-400 font-medium min-w-[20px]">%</span>
              <input
                v-if="splitConfig.splitType === 'FIXED_AMOUNT'"
                v-model.number="splitConfig.splitParams[memberId].amount"
                type="number"
                class="w-[100px] px-2 py-2 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-600 rounded-md text-sm text-right transition-all focus:outline-none focus:bg-white focus:border-blue-600 focus:ring-2 focus:ring-blue-600/10 read-only:bg-gray-100 dark:read-only:bg-gray-600 read-only:text-gray-600 dark:read-only:text-gray-400 read-only:cursor-not-allowed"
                placeholder="金额"
                min="0"
                :max="getMaxAmount(memberId)"
                step="0.01"
                :readonly="props.readonly"
                @input="handleAmountInput(memberId, splitConfig.splitParams[memberId].amount || 0)"
              >
              <span v-if="splitConfig.splitType === 'FIXED_AMOUNT'" class="text-sm text-gray-500 dark:text-gray-400 font-medium min-w-[20px]">¥</span>
              <input
                v-if="splitConfig.splitType === 'WEIGHTED'"
                v-model.number="splitConfig.splitParams[memberId].weight"
                type="number"
                class="w-[100px] px-2 py-2 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-600 rounded-md text-sm text-right transition-all focus:outline-none focus:bg-white focus:border-blue-600 focus:ring-2 focus:ring-blue-600/10 read-only:bg-gray-100 dark:read-only:bg-gray-600 read-only:text-gray-600 dark:read-only:text-gray-400 read-only:cursor-not-allowed"
                placeholder="权重"
                min="0"
                step="1"
                :readonly="props.readonly"
              >
              <span v-if="splitConfig.splitType === 'WEIGHTED'" class="text-xs text-blue-600 dark:text-blue-400 font-semibold px-2 py-1 bg-blue-600/10 dark:bg-blue-500/20 rounded min-w-[50px] text-center">
                {{ getWeightPercentage(memberId) }}
              </span>
            </div>
          </div>
        </div>
      </div>

      <!-- 高级配置按钮 -->
      <button
        v-if="!props.readonly"
        type="button"
        class="flex items-center justify-center gap-2 px-3 py-3 bg-gray-50 dark:bg-gray-700 border border-gray-200 dark:border-gray-600 rounded-lg text-sm cursor-pointer transition-all hover:bg-gray-100 dark:hover:bg-gray-600 hover:border-blue-600 dark:hover:border-blue-500"
        @click="openConfigurator"
      >
        <LucideSettings class="w-4 h-4" />
        高级配置
        <LucideChevronDown class="w-3.5 h-3.5 ml-auto" />
      </button>

      <!-- 分摊预览 -->
      <div v-if="splitPreview.length > 0" class="flex flex-col gap-3 p-4 bg-gray-50 dark:bg-gray-700 rounded-lg border border-gray-200 dark:border-gray-600">
        <div class="flex justify-between items-center">
          <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">分摊预览</label>
          <span class="px-3 py-1 bg-gray-100 dark:bg-gray-600 text-gray-700 dark:text-gray-200 rounded-xl text-xs font-medium">
            {{ getTypeName(splitConfig.splitType) }}
          </span>
        </div>

        <div class="flex flex-col gap-2">
          <div
            v-for="item in splitPreview"
            :key="item.memberSerialNum"
            class="flex justify-between items-center px-3 py-2 bg-white dark:bg-gray-800 rounded-md border border-gray-200 dark:border-gray-600"
          >
            <span class="text-sm text-gray-900 dark:text-white">{{ item.memberName }}</span>
            <strong class="text-sm font-semibold text-gray-700 dark:text-gray-200">{{ formatAmount(item.amount) }}</strong>
          </div>
        </div>

        <div class="flex justify-between items-center pt-3 border-t-2 border-gray-200 dark:border-gray-600 text-sm font-semibold">
          <span class="text-gray-900 dark:text-white">总计</span>
          <strong class="text-base font-semibold text-gray-900 dark:text-white">{{ formatAmount(splitPreview.reduce((sum, item) => sum + item.amount, 0)) }}</strong>
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
