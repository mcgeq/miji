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
import Button from '@/components/ui/Button.vue';
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
  <div class="fixed inset-0 z-[1000] flex items-center justify-center">
    <div class="absolute inset-0 bg-black/50 backdrop-blur-sm" @click="close" />

    <div class="relative w-[90%] max-w-[800px] max-h-[90vh] bg-white dark:bg-gray-800 rounded-2xl shadow-2xl flex flex-col overflow-hidden">
      <!-- Header -->
      <div class="flex justify-between items-center px-6 md:px-8 py-6 border-b border-gray-200 dark:border-gray-700">
        <h3 class="m-0 text-xl font-semibold text-gray-900 dark:text-white">
          分摆规则配置
        </h3>
        <button
          class="p-2 bg-transparent border-0 rounded-md cursor-pointer transition-all hover:bg-gray-100 dark:hover:bg-gray-700"
          @click="close"
        >
          <LucideX class="w-5 h-5 text-gray-600 dark:text-gray-300" />
        </button>
      </div>

      <!-- 步骤指示器 -->
      <div class="flex justify-between p-8 bg-gray-50 dark:bg-gray-700">
        <div
          v-for="step in 4"
          :key="step"
          class="flex flex-col items-center gap-2 flex-1 relative"
        >
          <!-- 连接线 -->
          <div
            v-if="step < 4"
            class="absolute top-5 left-1/2 right-[-50%] h-0.5 z-0" :class="[
              currentStep > step ? 'bg-blue-600 dark:bg-blue-500' : 'bg-gray-200 dark:bg-gray-600',
            ]"
          />

          <!-- 步骤圆圈 -->
          <div
            class="w-10 h-10 rounded-full flex items-center justify-center font-semibold z-10 transition-all duration-300" :class="[
              currentStep === step ? 'border-2 border-blue-600 dark:border-blue-500 bg-blue-600 dark:bg-blue-500 text-white'
              : currentStep > step ? 'border-2 border-blue-600 dark:border-blue-500 bg-blue-600 dark:bg-blue-500 text-white'
                : 'bg-white dark:bg-gray-800 border-2 border-gray-200 dark:border-gray-600 text-gray-600 dark:text-gray-400',
            ]"
          >
            <LucideCheck v-if="currentStep > step" class="w-4 h-4" />
            <span v-else>{{ step }}</span>
          </div>

          <!-- 标签 -->
          <span
            class="text-sm font-medium" :class="[
              currentStep === step ? 'text-blue-600 dark:text-blue-400' : 'text-gray-600 dark:text-gray-400',
            ]"
          >
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
      <div class="flex-1 overflow-y-auto p-8">
        <!-- 步骤 1: 选择分摊类型 -->
        <div v-if="currentStep === 1" class="flex flex-col gap-6">
          <h4 class="m-0 text-lg font-semibold text-gray-900 dark:text-white">
            选择分摊类型
          </h4>
          <p class="m-0 text-gray-600 dark:text-gray-400 text-sm">
            选择适合您需求的分摊方式
          </p>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <label
              v-for="type in splitTypes"
              :key="type.value"
              class="p-6 border-2 rounded-xl cursor-pointer transition-all duration-300 text-center" :class="[
                config.splitType === type.value
                  ? 'border-blue-600 dark:border-blue-500 bg-blue-50/50 dark:bg-blue-900/20 shadow-md'
                  : 'border-gray-200 dark:border-gray-600 hover:border-blue-500 dark:hover:border-blue-400 hover:shadow-md',
              ]"
            >
              <input
                v-model="config.splitType"
                type="radio"
                :value="type.value"
                hidden
              >
              <div
                class="w-16 h-16 mx-auto mb-4 rounded-xl flex items-center justify-center"
                :style="{ backgroundColor: `${type.color}26` }"
              >
                <component :is="type.icon" class="w-9 h-9" :style="{ color: type.color }" />
              </div>
              <h5 class="m-0 mb-2 text-base font-semibold text-gray-900 dark:text-white">{{ type.label }}</h5>
              <p class="m-0 text-sm text-gray-600 dark:text-gray-400">{{ type.description }}</p>
            </label>
          </div>
        </div>

        <!-- 步骤 2: 选择参与成员 -->
        <div v-if="currentStep === 2" class="flex flex-col gap-6">
          <div class="flex justify-between items-start">
            <div>
              <h4 class="m-0 text-lg font-semibold text-gray-900 dark:text-white">
                选择参与成员
              </h4>
              <p class="m-0 mt-1 text-gray-600 dark:text-gray-400 text-sm">
                选择参与此次分摊的成员
              </p>
            </div>
            <div class="flex gap-2">
              <button
                class="px-4 py-2 bg-transparent border border-gray-300 dark:border-gray-600 rounded-md text-sm cursor-pointer transition-all hover:bg-gray-100 dark:hover:bg-gray-600 hover:border-blue-500 dark:hover:border-blue-400"
                @click="selectAllMembers"
              >
                全选
              </button>
              <button
                class="px-4 py-2 bg-transparent border border-gray-300 dark:border-gray-600 rounded-md text-sm cursor-pointer transition-all hover:bg-gray-100 dark:hover:bg-gray-600 hover:border-blue-500 dark:hover:border-blue-400"
                @click="clearMembers"
              >
                清空
              </button>
            </div>
          </div>

          <div class="grid grid-cols-2 md:grid-cols-[repeat(auto-fill,minmax(150px,1fr))] gap-4">
            <label
              v-for="member in availableMembers"
              :key="member.serialNum"
              class="cursor-pointer"
            >
              <input
                v-model="config.selectedMembers"
                type="checkbox"
                :value="member.serialNum"
                class="hidden"
                @change="onMemberSelectionChange"
              >
              <div
                class="flex flex-col items-center gap-3 p-4 border-2 rounded-xl transition-all" :class="[
                  config.selectedMembers.includes(member.serialNum)
                    ? 'border-blue-600 dark:border-blue-500 bg-blue-50/50 dark:bg-blue-900/10'
                    : 'border-gray-200 dark:border-gray-600',
                ]"
              >
                <div
                  class="w-12 h-12 rounded-full flex items-center justify-center text-white font-semibold text-lg"
                  :style="{ backgroundColor: member.colorTag || '#3b82f6' }"
                >
                  {{ member.name.charAt(0) }}
                </div>
                <span class="text-sm font-medium text-center text-gray-900 dark:text-white">{{ member.name }}</span>
              </div>
            </label>
          </div>

          <div v-if="config.selectedMembers.length > 0" class="p-4 bg-gray-50 dark:bg-gray-700 rounded-lg text-center text-sm text-gray-600 dark:text-gray-400">
            已选择 {{ config.selectedMembers.length }} 位成员
          </div>
        </div>

        <!-- 步骤 3: 配置分摊参数 -->
        <div v-if="currentStep === 3" class="flex flex-col gap-6">
          <h4 class="m-0 text-lg font-semibold text-gray-900 dark:text-white">
            配置分摊参数
          </h4>
          <p class="m-0 text-gray-600 dark:text-gray-400 text-sm">
            为每位成员设置
            {{
              config.splitType === 'PERCENTAGE' ? '分摊比例'
              : config.splitType === 'FIXED_AMOUNT' ? '分摊金额'
                : config.splitType === 'WEIGHTED' ? '权重值'
                  : '参数'
            }}
          </p>

          <!-- 均摊：无需配置 -->
          <div v-if="config.splitType === 'EQUAL'">
            <div class="flex items-center gap-4 p-6 bg-blue-50/50 dark:bg-blue-900/10 border border-blue-600 dark:border-blue-500 rounded-xl">
              <LucideEqual class="w-8 h-8 text-blue-600 dark:text-blue-400 flex-shrink-0" />
              <p class="m-0 text-gray-900 dark:text-white">
                均等分摊无需额外配置，每位成员将平均分摊费用
              </p>
            </div>
          </div>

          <!-- 按比例 -->
          <div v-if="config.splitType === 'PERCENTAGE'" class="flex flex-col gap-4">
            <div
              v-for="member in selectedMemberDetails"
              :key="member.serialNum"
              class="flex justify-between items-center p-4 bg-gray-50 dark:bg-gray-700 rounded-lg"
            >
              <span class="font-medium text-gray-900 dark:text-white">{{ member.name }}</span>
              <div class="flex items-center gap-2">
                <input
                  v-model.number="config.splitParams[member.serialNum].percentage"
                  type="number"
                  min="0"
                  max="100"
                  step="0.1"
                  class="w-[120px] px-2 py-1.5 border border-gray-300 dark:border-gray-600 rounded-md text-right text-base bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                >
                <span class="text-gray-500 dark:text-gray-400 text-sm">%</span>
              </div>
            </div>

            <div
              class="p-4 rounded-lg text-center font-medium" :class="[
                isValid
                  ? 'bg-emerald-100 dark:bg-emerald-900/20 border border-emerald-600 dark:border-emerald-500 text-emerald-700 dark:text-emerald-300'
                  : 'bg-red-100 dark:bg-red-900/20 border border-red-600 dark:border-red-500 text-red-700 dark:text-red-300',
              ]"
            >
              总计: {{ config.selectedMembers.reduce((sum, id) => sum + (config.splitParams[id]?.percentage || 0), 0).toFixed(1) }}%
              <span v-if="isValid" class="ml-2 text-emerald-600 dark:text-emerald-400">✓</span>
              <span v-else class="ml-2 text-red-600 dark:text-red-400">必须为 100%</span>
            </div>
          </div>

          <!-- 固定金额 -->
          <div v-if="config.splitType === 'FIXED_AMOUNT'" class="flex flex-col gap-4">
            <div
              v-for="member in selectedMemberDetails"
              :key="member.serialNum"
              class="flex justify-between items-center p-4 bg-gray-50 dark:bg-gray-700 rounded-lg"
            >
              <span class="font-medium text-gray-900 dark:text-white">{{ member.name }}</span>
              <div class="flex items-center gap-2">
                <span class="text-gray-500 dark:text-gray-400 text-sm">¥</span>
                <input
                  v-model.number="config.splitParams[member.serialNum].amount"
                  type="number"
                  min="0"
                  step="0.01"
                  class="w-[120px] px-2 py-1.5 border border-gray-300 dark:border-gray-600 rounded-md text-right text-base bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                >
              </div>
            </div>

            <div
              class="p-4 rounded-lg text-center font-medium" :class="[
                isValid
                  ? 'bg-emerald-100 dark:bg-emerald-900/20 border border-emerald-600 dark:border-emerald-500 text-emerald-700 dark:text-emerald-300'
                  : 'bg-red-100 dark:bg-red-900/20 border border-red-600 dark:border-red-500 text-red-700 dark:text-red-300',
              ]"
            >
              总计: ¥{{ config.selectedMembers.reduce((sum, id) => sum + (config.splitParams[id]?.amount || 0), 0).toFixed(2) }}
              / ¥{{ amount.toFixed(2) }}
              <span v-if="isValid" class="ml-2 text-emerald-600 dark:text-emerald-400">✓</span>
              <span v-else class="ml-2 text-red-600 dark:text-red-400">必须等于交易金额</span>
            </div>
          </div>

          <!-- 按权重 -->
          <div v-if="config.splitType === 'WEIGHTED'" class="flex flex-col gap-4">
            <div
              v-for="member in selectedMemberDetails"
              :key="member.serialNum"
              class="flex justify-between items-center p-4 bg-gray-50 dark:bg-gray-700 rounded-lg"
            >
              <span class="font-medium text-gray-900 dark:text-white">{{ member.name }}</span>
              <div class="flex items-center gap-2">
                <input
                  v-model.number="config.splitParams[member.serialNum].weight"
                  type="number"
                  min="1"
                  step="1"
                  class="w-[120px] px-2 py-1.5 border border-gray-300 dark:border-gray-600 rounded-md text-right text-base bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                >
                <span class="text-gray-500 dark:text-gray-400 text-sm">权重</span>
              </div>
            </div>

            <div class="p-4 bg-emerald-100 dark:bg-emerald-900/20 border border-emerald-600 dark:border-emerald-500 rounded-lg text-center font-medium text-emerald-700 dark:text-emerald-300">
              总权重: {{ config.selectedMembers.reduce((sum, id) => sum + (config.splitParams[id]?.weight || 0), 0) }}
            </div>
          </div>
        </div>

        <!-- 步骤 4: 预览结果 -->
        <div v-if="currentStep === 4" class="flex flex-col gap-6">
          <h4 class="m-0 text-lg font-semibold text-gray-900 dark:text-white">
            预览分摊结果
          </h4>
          <p class="m-0 text-gray-600 dark:text-gray-400 text-sm">
            确认分摊结果无误后，可以保存或应用
          </p>

          <div class="flex flex-col gap-6">
            <div class="grid grid-cols-1 md:grid-cols-3 gap-4 p-6 bg-gray-50 dark:bg-gray-700 rounded-xl">
              <div class="flex flex-col gap-2">
                <label class="text-sm text-gray-600 dark:text-gray-400">交易金额</label>
                <strong class="text-lg font-semibold text-gray-900 dark:text-white">{{ formatAmount(amount) }}</strong>
              </div>
              <div class="flex flex-col gap-2">
                <label class="text-sm text-gray-600 dark:text-gray-400">分摊类型</label>
                <strong class="text-lg font-semibold text-gray-900 dark:text-white">{{ splitTypes.find(t => t.value === config.splitType)?.label }}</strong>
              </div>
              <div class="flex flex-col gap-2">
                <label class="text-sm text-gray-600 dark:text-gray-400">参与人数</label>
                <strong class="text-lg font-semibold text-gray-900 dark:text-white">{{ config.selectedMembers.length }} 人</strong>
              </div>
            </div>

            <div class="flex flex-col gap-3">
              <div
                v-for="result in calculatedSplit"
                :key="result.memberSerialNum"
                class="flex justify-between items-center p-4 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-600 rounded-lg"
              >
                <span class="font-medium text-gray-900 dark:text-white">{{ result.memberName }}</span>
                <div class="flex items-center gap-4">
                  <span v-if="result.percentage" class="text-sm text-gray-500 dark:text-gray-400">
                    {{ result.percentage.toFixed(1) }}%
                  </span>
                  <strong class="text-lg font-semibold text-blue-600 dark:text-blue-400">{{ formatAmount(result.amount) }}</strong>
                </div>
              </div>
            </div>

            <!-- 保存为模板 -->
            <div class="p-6 bg-gray-50 dark:bg-gray-700 rounded-xl flex flex-col gap-4">
              <h5 class="m-0 text-base font-semibold text-gray-900 dark:text-white">
                保存为模板（可选）
              </h5>
              <input
                v-model="config.templateName"
                type="text"
                placeholder="模板名称"
                class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg text-sm bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              >
              <textarea
                v-model="config.templateDescription"
                placeholder="模板描述（可选）"
                class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg text-sm bg-white dark:bg-gray-800 text-gray-900 dark:text-white resize-y focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                rows="2"
              />
            </div>
          </div>
        </div>
      </div>

      <!-- Footer -->
      <div class="flex gap-4 px-6 md:px-8 py-6 border-t border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-700">
        <Button v-if="currentStep > 1" variant="secondary" @click="prevStep">
          <LucideChevronLeft class="w-4 h-4" />
          上一步
        </Button>

        <div class="flex-1" />

        <Button
          v-if="currentStep < 4"
          variant="primary"
          :disabled="!isValid"
          @click="nextStep"
        >
          下一步
          <LucideChevronRight class="w-4 h-4" />
        </Button>

        <template v-if="currentStep === 4">
          <Button
            v-if="config.templateName"
            variant="secondary"
            @click="saveAsTemplate"
          >
            <LucideSave class="w-4 h-4" />
            保存模板
          </Button>
          <Button variant="primary" @click="saveConfig">
            <LucideCheck class="w-4 h-4" />
            应用分摊
          </Button>
        </template>
      </div>
    </div>
  </div>
</template>
