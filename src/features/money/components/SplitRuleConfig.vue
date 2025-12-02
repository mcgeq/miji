<script setup lang="ts">
import { LucidePlus, LucideTrash, LucideUser, LucideX } from 'lucide-vue-next';
import Button from '@/components/ui/Button.vue';
import { useFamilyMemberStore, useFamilySplitStore } from '@/stores/money';
import { toast } from '@/utils/toast';
import type { SplitResult, SplitRuleConfig, SplitRuleType } from '@/schema/money';

interface Props {
  rule?: SplitRuleConfig | null;
  familyLedgerSerialNum: string;
}

const props = defineProps<Props>();
const emit = defineEmits<{
  close: [];
  save: [rule: SplitRuleConfig];
}>();

const splitStore = useFamilySplitStore();
const memberStore = useFamilyMemberStore();

// 表单数据
const form = reactive({
  name: '',
  description: '',
  ruleType: 'EQUAL' as SplitRuleType,
  isTemplate: false,
  participants: [] as Array<{
    memberSerialNum: string;
    percentage?: number;
    fixedAmount?: number;
    weight?: number;
  }>,
});

// 预览数据
const previewAmount = ref(1000);
const previewResults = ref<SplitResult[]>([]);

// 获取成员列表
const { members } = storeToRefs(memberStore);

// 初始化表单
onMounted(() => {
  if (props.rule) {
    Object.assign(form, {
      name: props.rule.name,
      description: props.rule.description,
      ruleType: props.rule.ruleType,
      isTemplate: props.rule.isTemplate,
      participants: [...props.rule.participants],
    });
  }

  // 加载成员列表
  memberStore.fetchMembers(props.familyLedgerSerialNum);

  // 初始化参与者
  if (form.participants.length === 0 && members.value.length > 0) {
    form.participants = members.value.map(member => ({
      memberSerialNum: member.serialNum,
      percentage: form.ruleType === 'PERCENTAGE' ? 0 : undefined,
      fixedAmount: form.ruleType === 'FIXED_AMOUNT' ? 0 : undefined,
      weight: form.ruleType === 'WEIGHTED' ? 1 : undefined,
    }));
  }

  updatePreview();
});

// 监听规则类型变化
watch(() => form.ruleType, newType => {
  // 重置参与者配置
  form.participants.forEach(participant => {
    participant.percentage = newType === 'PERCENTAGE' ? 0 : undefined;
    participant.fixedAmount = newType === 'FIXED_AMOUNT' ? 0 : undefined;
    participant.weight = newType === 'WEIGHTED' ? 1 : undefined;
  });
  updatePreview();
});

// 监听表单变化，更新预览
watch([() => form.participants, () => previewAmount.value], updatePreview, { deep: true });

// 添加参与者
function addParticipant() {
  const availableMembers = members.value.filter(member =>
    !form.participants.some(p => p.memberSerialNum === member.serialNum),
  );

  if (availableMembers.length === 0) {
    toast.warning('所有成员都已添加');
    return;
  }

  const member = availableMembers[0];
  form.participants.push({
    memberSerialNum: member.serialNum,
    percentage: form.ruleType === 'PERCENTAGE' ? 0 : undefined,
    fixedAmount: form.ruleType === 'FIXED_AMOUNT' ? 0 : undefined,
    weight: form.ruleType === 'WEIGHTED' ? 1 : undefined,
  });

  updatePreview();
}

// 移除参与者
function removeParticipant(index: number) {
  form.participants.splice(index, 1);
  updatePreview();
}

// 获取成员名称
function getMemberName(serialNum: string): string {
  const member = members.value.find(m => m.serialNum === serialNum);
  return member?.name || 'Unknown';
}

// 更新预览
function updatePreview() {
  if (form.participants.length === 0 || previewAmount.value <= 0) {
    previewResults.value = [];
    return;
  }

  try {
    // 创建临时规则用于预览
    const tempRule: SplitRuleConfig = {
      serialNum: 'temp',
      familyLedgerSerialNum: props.familyLedgerSerialNum,
      name: form.name || 'Preview',
      description: form.description,
      ruleType: form.ruleType,
      isTemplate: form.isTemplate,
      isActive: true,
      participants: form.participants,
      createdAt: new Date().toISOString(),
      updatedAt: null,
    };

    // 使用store的计算方法
    splitStore.splitRules = [tempRule];
    previewResults.value = splitStore.calculateSplit('temp', previewAmount.value);
  } catch (error) {
    console.error('Preview calculation error:', error);
    previewResults.value = [];
  }
}

// 验证表单
function validateForm(): boolean {
  if (!form.name.trim()) {
    toast.error('请输入规则名称');
    return false;
  }

  if (form.participants.length === 0) {
    toast.error('请至少添加一个参与者');
    return false;
  }

  // 根据规则类型验证
  switch (form.ruleType) {
    case 'PERCENTAGE': {
      const totalPercentage = form.participants.reduce((sum, p) => sum + (p.percentage || 0), 0);
      if (Math.abs(totalPercentage - 100) > 0.01) {
        toast.error('百分比总和必须等于100%');
        return false;
      }
      break;
    }

    case 'FIXED_AMOUNT': {
      const totalFixed = form.participants.reduce((sum, p) => sum + (p.fixedAmount || 0), 0);
      if (totalFixed > previewAmount.value) {
        toast.error('固定金额总和不能超过总金额');
        return false;
      }
      break;
    }

    case 'WEIGHTED': {
      const hasValidWeights = form.participants.every(p => (p.weight || 0) > 0);
      if (!hasValidWeights) {
        toast.error('所有权重必须大于0');
        return false;
      }
      break;
    }
  }

  return true;
}

// 保存规则
async function saveRule() {
  if (!validateForm()) {
    return;
  }

  try {
    const ruleData = {
      familyLedgerSerialNum: props.familyLedgerSerialNum,
      name: form.name,
      description: form.description,
      ruleType: form.ruleType,
      isTemplate: form.isTemplate,
      participants: form.participants,
    };

    let savedRule: SplitRuleConfig;
    if (props.rule) {
      savedRule = await splitStore.updateSplitRule(props.rule.serialNum, ruleData);
    } else {
      savedRule = await splitStore.createSplitRule(ruleData);
    }

    toast.success('分摊规则保存成功');
    emit('save', savedRule);
  } catch (_error) {
    toast.error('保存失败');
  }
}

// 关闭对话框
function closeDialog() {
  emit('close');
}
</script>

<template>
  <div class="fixed inset-0 bg-black/50 flex items-center justify-center z-[1000]">
    <div class="bg-white dark:bg-gray-800 rounded-lg w-[90%] max-w-[600px] max-h-[90vh] overflow-hidden flex flex-col">
      <div class="px-6 py-4 border-b border-gray-200 dark:border-gray-700 flex items-center justify-between">
        <h3 class="text-lg font-semibold text-gray-900 dark:text-white">
          {{ props.rule ? '编辑分摆规则' : '创建分摆规则' }}
        </h3>
        <button class="text-gray-600 dark:text-gray-400 transition-colors hover:text-gray-900 dark:hover:text-white" @click="closeDialog">
          <LucideX class="w-5 h-5" />
        </button>
      </div>

      <div class="flex-1 overflow-y-auto px-6 py-4">
        <!-- 基本信息 -->
        <div class="mb-6">
          <div class="mb-4">
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">规则名称</label>
            <input
              v-model="form.name"
              type="text"
              class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md text-sm bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              placeholder="请输入规则名称"
              required
            >
          </div>

          <div class="mb-4">
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">描述</label>
            <textarea
              v-model="form.description"
              class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md text-sm bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              placeholder="可选的规则描述"
              rows="2"
            />
          </div>

          <div class="mb-4">
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">分摆类型</label>
            <select v-model="form.ruleType" class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md text-sm bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent">
              <option value="EQUAL">
                均摆
              </option>
              <option value="PERCENTAGE">
                按比例
              </option>
              <option value="FIXED_AMOUNT">
                固定金额
              </option>
              <option value="WEIGHTED">
                按权重
              </option>
            </select>
          </div>

          <div class="mb-4">
            <label class="flex items-center gap-2 cursor-pointer">
              <input v-model="form.isTemplate" type="checkbox" class="w-4 h-4">
              <span class="text-sm text-gray-900 dark:text-white">保存为模板</span>
            </label>
          </div>
        </div>

        <!-- 参与者配置 -->
        <div class="mb-6">
          <div class="flex items-center justify-between mb-4">
            <h4 class="text-base font-semibold text-gray-900 dark:text-white">
              参与者配置
            </h4>
            <button
              type="button"
              class="flex items-center gap-1 px-2 py-1 bg-gray-200 dark:bg-gray-600 text-gray-700 dark:text-gray-200 rounded text-xs transition-colors hover:bg-gray-300 dark:hover:bg-gray-500"
              @click="addParticipant"
            >
              <LucidePlus class="w-4 h-4" />
              添加参与者
            </button>
          </div>

          <div class="flex flex-col gap-3">
            <div
              v-for="(participant, index) in form.participants"
              :key="participant.memberSerialNum"
              class="flex items-center gap-4 p-3 bg-gray-50 dark:bg-gray-700 rounded-lg"
            >
              <div class="flex items-center gap-2 flex-1">
                <LucideUser class="w-4 h-4 text-gray-500 dark:text-gray-400" />
                <span class="font-medium text-gray-900 dark:text-white">{{ getMemberName(participant.memberSerialNum) }}</span>
              </div>

              <div class="flex-1">
                <!-- 百分比配置 -->
                <div v-if="form.ruleType === 'PERCENTAGE'" class="flex items-center gap-2">
                  <input
                    v-model.number="participant.percentage"
                    type="number"
                    min="0"
                    max="100"
                    step="0.01"
                    class="w-20 px-2 py-1 border border-gray-300 dark:border-gray-600 rounded text-sm bg-white dark:bg-gray-800 text-gray-900 dark:text-white"
                    placeholder="0"
                  >
                  <span class="text-xs text-gray-600 dark:text-gray-400">%</span>
                </div>

                <!-- 固定金额配置 -->
                <div v-else-if="form.ruleType === 'FIXED_AMOUNT'" class="flex items-center gap-2">
                  <input
                    v-model.number="participant.fixedAmount"
                    type="number"
                    min="0"
                    step="0.01"
                    class="w-20 px-2 py-1 border border-gray-300 dark:border-gray-600 rounded text-sm bg-white dark:bg-gray-800 text-gray-900 dark:text-white"
                    placeholder="0"
                  >
                  <span class="text-xs text-gray-600 dark:text-gray-400">元</span>
                </div>

                <!-- 权重配置 -->
                <div v-else-if="form.ruleType === 'WEIGHTED'" class="flex items-center gap-2">
                  <input
                    v-model.number="participant.weight"
                    type="number"
                    min="0.1"
                    step="0.1"
                    class="w-20 px-2 py-1 border border-gray-300 dark:border-gray-600 rounded text-sm bg-white dark:bg-gray-800 text-gray-900 dark:text-white"
                    placeholder="1"
                  >
                  <span class="text-xs text-gray-600 dark:text-gray-400">权重</span>
                </div>
              </div>

              <button
                type="button"
                class="text-red-600 dark:text-red-400 p-1 rounded transition-colors hover:bg-red-50 dark:hover:bg-red-900/20"
                @click="removeParticipant(index)"
              >
                <LucideTrash class="w-4 h-4" />
              </button>
            </div>
          </div>
        </div>

        <!-- 预览 -->
        <div class="mb-6">
          <div class="flex items-center justify-between mb-4">
            <h4 class="text-base font-semibold text-gray-900 dark:text-white">
              预览
            </h4>
            <div class="flex items-center gap-2 text-sm">
              <label class="text-gray-700 dark:text-gray-300">测试金额:</label>
              <input
                v-model.number="previewAmount"
                type="number"
                min="1"
                step="0.01"
                class="w-[100px] px-2 py-1 border border-gray-300 dark:border-gray-600 rounded text-sm bg-white dark:bg-gray-800 text-gray-900 dark:text-white"
              >
              <span class="text-gray-700 dark:text-gray-300">元</span>
            </div>
          </div>

          <div class="flex flex-col gap-2">
            <div
              v-for="result in previewResults"
              :key="result.memberSerialNum"
              class="flex items-center justify-between p-2 bg-gray-100 dark:bg-gray-700 rounded-md"
            >
              <span class="font-medium text-gray-900 dark:text-white">{{ result.memberName }}</span>
              <span class="font-semibold text-emerald-600 dark:text-emerald-400">{{ result.amount.toFixed(2) }}元</span>
              <span class="text-xs text-gray-600 dark:text-gray-400">({{ result.percentage.toFixed(1) }}%)</span>
            </div>
          </div>
        </div>
      </div>

      <!-- 操作按钮 -->
      <div class="px-6 py-4 border-t border-gray-200 dark:border-gray-700 flex justify-end gap-3">
        <Button variant="secondary" @click="closeDialog">
          取消
        </Button>
        <Button variant="primary" @click="saveRule">
          保存
        </Button>
      </div>
    </div>
  </div>
</template>
