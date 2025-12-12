<script setup lang="ts">
  import {
    Calculator,
    Calendar,
    CheckCircle2,
    ChevronLeft,
    ChevronRight,
    Users,
    X,
    Zap,
  } from 'lucide-vue-next';
  import Button from '@/components/ui/Button.vue';
  import Spinner from '@/components/ui/Spinner.vue';
  import { toast } from '@/utils/toast';

  interface SettlementMember {
    serialNum: string;
    name: string;
    selected: boolean;
  }

  interface SettlementTransfer {
    from: string;
    fromName: string;
    to: string;
    toName: string;
    amount: number;
  }

  interface SettlementSuggestion {
    totalAmount: number;
    transfers: SettlementTransfer[];
    savings: number;
  }

  interface ExecutionResult {
    success: boolean;
    message: string;
    serialNum?: string;
  }

  interface Props {
    familyLedgerSerialNum: string;
  }

  defineProps<Props>();

  const emit = defineEmits<{
    close: [];
    complete: [];
  }>();

  const currentStep = ref(1);
  const processing = ref(false);

  const settlementRange = ref({
    startDate: '',
    endDate: '',
    settlementType: 'optimized' as 'manual' | 'auto' | 'optimized',
  });

  const members = ref<SettlementMember[]>([
    { serialNum: 'M001', name: '张三', selected: true },
    { serialNum: 'M002', name: '李四', selected: true },
    { serialNum: 'M003', name: '王五', selected: true },
  ]);

  const settlementSuggestion = ref<SettlementSuggestion | null>(null);
  const executionResult = ref<ExecutionResult | null>(null);

  const selectedMembers = computed(() => members.value.filter(m => m.selected));

  const canProceedStep1 = computed(() => {
    return (
      settlementRange.value.startDate &&
      settlementRange.value.endDate &&
      selectedMembers.value.length >= 2
    );
  });

  function toggleMember(member: SettlementMember) {
    member.selected = !member.selected;
  }

  async function handleNext() {
    if (currentStep.value === 1) {
      if (!canProceedStep1.value) {
        toast.error('请完善结算信息');
        return;
      }
      await calculateSettlement();
      currentStep.value = 2;
    } else if (currentStep.value === 2) {
      currentStep.value = 3;
      await executeSettlement();
    }
  }

  function handlePrev() {
    if (currentStep.value > 1) currentStep.value--;
  }

  async function calculateSettlement() {
    processing.value = true;
    try {
      await new Promise(resolve => setTimeout(resolve, 1000));
      settlementSuggestion.value = {
        totalAmount: 450,
        transfers: [
          { from: 'M002', fromName: '李四', to: 'M001', toName: '张三', amount: 300 },
          { from: 'M001', fromName: '张三', to: 'M003', toName: '王五', amount: 150 },
        ],
        savings: 3,
      };
    } finally {
      processing.value = false;
    }
  }

  async function executeSettlement() {
    processing.value = true;
    try {
      await new Promise(resolve => setTimeout(resolve, 1500));
      executionResult.value = {
        success: true,
        message: '结算已成功完成',
        serialNum: `SR${Date.now()}`,
      };
      toast.success('结算成功');
    } catch {
      executionResult.value = { success: false, message: '结算执行失败' };
      toast.error('结算失败');
    } finally {
      processing.value = false;
    }
  }

  function handleComplete() {
    emit('complete');
    emit('close');
  }

  function handleClose() {
    if (currentStep.value === 3 && executionResult.value?.success) {
      handleComplete();
    } else {
      // eslint-disable-next-line no-alert
      if (window.confirm('确定要退出结算向导吗？')) {
        emit('close');
      }
    }
  }

  function getMemberColor(name: string): string {
    const colors = ['#3b82f6', '#ef4444', '#10b981', '#f59e0b', '#8b5cf6'];
    return colors[name.charCodeAt(0) % colors.length];
  }

  function getInitials(name: string): string {
    return name.charAt(0).toUpperCase();
  }

  function formatAmount(amount: number): string {
    return amount.toFixed(2);
  }
</script>

<template>
  <div
    class="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4"
    @click.self="handleClose"
  >
    <div
      class="bg-white dark:bg-gray-800 rounded-xl shadow-2xl max-w-4xl w-full max-h-[90vh] flex flex-col"
    >
      <div
        class="flex items-center justify-between p-6 border-b border-gray-200 dark:border-gray-700"
      >
        <h2 class="text-xl font-bold text-gray-900 dark:text-white">
          {{ currentStep === 1 ? '选择结算范围' : currentStep === 2 ? '确认结算方案' : '执行结算' }}
        </h2>
        <button
          class="p-2 rounded-lg text-gray-500 hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors"
          @click="handleClose"
        >
          <X class="w-5 h-5" />
        </button>
      </div>

      <div class="flex items-center justify-around p-8">
        <div v-for="step in 3" :key="step" class="flex flex-col items-center gap-2">
          <div
            class="w-12 h-12 rounded-full flex items-center justify-center font-bold transition-all"
            :class="[
              step === currentStep ? 'bg-blue-600 text-white shadow-[0_0_0_4px_rgba(59,130,246,0.2)]' : '',
              step < currentStep ? 'bg-green-500 text-white' : '',
              step > currentStep ? 'bg-gray-200 dark:bg-gray-700 text-gray-500 dark:text-gray-400' : '',
            ]"
          >
            <CheckCircle2 v-if="step < currentStep" class="w-5 h-5" />
            <span v-else>{{ step }}</span>
          </div>
          <span
            class="text-sm font-medium"
            :class="[
              step === currentStep ? 'text-blue-600 dark:text-blue-400 font-semibold' : '',
              step < currentStep ? 'text-green-600 dark:text-green-400' : '',
              step > currentStep ? 'text-gray-500 dark:text-gray-400' : '',
            ]"
          >
            {{ step === 1 ? '选择范围' : step === 2 ? '确认方案' : '执行结算' }}
          </span>
        </div>
      </div>

      <div class="flex-1 overflow-y-auto p-6">
        <!-- 步骤1 -->
        <div v-if="currentStep === 1" class="flex flex-col gap-6">
          <div class="flex flex-col gap-4">
            <h3
              class="flex items-center gap-2 text-base font-semibold text-gray-900 dark:text-white"
            >
              <Calendar class="w-5 h-5" />
              <span>结算周期</span>
            </h3>
            <div class="flex items-center gap-4">
              <input
                v-model="settlementRange.startDate"
                type="date"
                class="flex-1 px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg text-sm bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
              <span class="text-gray-500 dark:text-gray-400">至</span>
              <input
                v-model="settlementRange.endDate"
                type="date"
                class="flex-1 px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg text-sm bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>
          </div>

          <div class="flex flex-col gap-4">
            <h3
              class="flex items-center gap-2 text-base font-semibold text-gray-900 dark:text-white"
            >
              <Calculator class="w-5 h-5" />
              <span>结算类型</span>
            </h3>
            <div class="flex flex-col gap-3">
              <label
                class="flex items-center gap-3 p-4 border-2 rounded-lg cursor-pointer transition-all hover:border-blue-600 hover:bg-blue-50 dark:hover:bg-blue-900/20"
                :class="settlementRange.settlementType === 'optimized' ? 'border-blue-600 bg-blue-50 dark:bg-blue-900/20' : 'border-gray-200 dark:border-gray-700'"
              >
                <input
                  v-model="settlementRange.settlementType"
                  type="radio"
                  value="optimized"
                  class="sr-only"
                />
                <div class="flex-1 flex items-center gap-3 text-blue-600">
                  <Zap class="w-5 h-5" />
                  <div>
                    <div class="font-semibold text-gray-900 dark:text-white">优化结算</div>
                    <div class="text-sm text-gray-500 dark:text-gray-400 mt-1">
                      自动优化转账次数
                    </div>
                  </div>
                </div>
              </label>
              <label
                class="flex items-center gap-3 p-4 border-2 rounded-lg cursor-pointer transition-all hover:border-blue-600 hover:bg-blue-50 dark:hover:bg-blue-900/20"
                :class="settlementRange.settlementType === 'manual' ? 'border-blue-600 bg-blue-50 dark:bg-blue-900/20' : 'border-gray-200 dark:border-gray-700'"
              >
                <input
                  v-model="settlementRange.settlementType"
                  type="radio"
                  value="manual"
                  class="sr-only"
                />
                <div class="flex-1 flex items-center gap-3 text-blue-600">
                  <Users class="w-5 h-5" />
                  <div>
                    <div class="font-semibold text-gray-900 dark:text-white">手动结算</div>
                    <div class="text-sm text-gray-500 dark:text-gray-400 mt-1">按原始债务关系</div>
                  </div>
                </div>
              </label>
            </div>
          </div>

          <div class="flex flex-col gap-4">
            <h3
              class="flex items-center gap-2 text-base font-semibold text-gray-900 dark:text-white"
            >
              <Users class="w-5 h-5" />
              <span>参与成员 ({{ selectedMembers.length }}/{{ members.length }})</span>
            </h3>
            <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-3">
              <div
                v-for="member in members"
                :key="member.serialNum"
                class="relative p-4 border-2 rounded-lg flex flex-col items-center gap-2 cursor-pointer transition-all hover:border-blue-600 hover:bg-blue-50 dark:hover:bg-blue-900/20"
                :class="member.selected ? 'border-blue-600 bg-blue-50 dark:bg-blue-900/20' : 'border-gray-200 dark:border-gray-700'"
                @click="toggleMember(member)"
              >
                <div
                  class="w-12 h-12 rounded-full flex items-center justify-center text-white font-bold text-lg"
                  :style="{ backgroundColor: getMemberColor(member.name) }"
                >
                  {{ getInitials(member.name) }}
                </div>
                <span class="text-sm font-medium text-gray-900 dark:text-white"
                  >{{ member.name }}</span
                >
                <CheckCircle2
                  v-if="member.selected"
                  class="absolute top-2 right-2 w-5 h-5 text-blue-600"
                />
              </div>
            </div>
          </div>
        </div>

        <!-- 步骤2 -->
        <div v-else-if="currentStep === 2" class="flex flex-col gap-6">
          <div v-if="processing" class="flex flex-col items-center justify-center py-16 gap-4">
            <Spinner size="lg" />
            <p class="text-gray-600 dark:text-gray-400">正在计算...</p>
          </div>
          <div v-else-if="settlementSuggestion">
            <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
              <div class="p-5 bg-gray-50 dark:bg-gray-900 rounded-lg flex flex-col gap-2">
                <span class="text-sm text-gray-500 dark:text-gray-400">结算金额</span>
                <span class="text-2xl font-bold text-gray-900 dark:text-white"
                  >¥{{ formatAmount(settlementSuggestion.totalAmount) }}</span
                >
              </div>
              <div class="p-5 bg-gray-50 dark:bg-gray-900 rounded-lg flex flex-col gap-2">
                <span class="text-sm text-gray-500 dark:text-gray-400">转账次数</span>
                <span class="text-2xl font-bold text-gray-900 dark:text-white"
                  >{{ settlementSuggestion.transfers.length }}笔</span
                >
              </div>
              <div class="p-5 bg-gray-50 dark:bg-gray-900 rounded-lg flex flex-col gap-2">
                <span class="text-sm text-gray-500 dark:text-gray-400">优化节省</span>
                <span class="text-2xl font-bold text-gray-900 dark:text-white"
                  >{{ settlementSuggestion.savings }}笔</span
                >
              </div>
            </div>
            <div class="flex flex-col gap-3 mt-4">
              <div
                v-for="(t, i) in settlementSuggestion.transfers"
                :key="i"
                class="flex items-center gap-4 p-4 bg-gray-50 dark:bg-gray-900 rounded-lg border border-gray-200 dark:border-gray-700"
              >
                <div
                  class="w-8 h-8 rounded-full bg-blue-100 dark:bg-blue-900/30 text-blue-700 dark:text-blue-300 flex items-center justify-center font-bold text-sm shrink-0"
                >
                  {{ i + 1 }}
                </div>
                <div class="flex-1 text-gray-900 dark:text-white">
                  <span>{{ t.fromName }}→ {{ t.toName }}</span>
                </div>
                <div class="font-bold text-gray-900 dark:text-white">
                  ¥{{ formatAmount(t.amount) }}
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- 步骤3 -->
        <div v-else-if="currentStep === 3" class="flex flex-col gap-6">
          <div v-if="processing" class="flex flex-col items-center justify-center py-16 gap-4">
            <Spinner size="lg" />
            <p class="text-gray-600 dark:text-gray-400">正在执行结算...</p>
          </div>
          <div
            v-else-if="executionResult"
            class="flex flex-col items-center justify-center py-12 gap-4"
          >
            <div
              class="w-20 h-20 rounded-full flex items-center justify-center"
              :class="executionResult.success ? 'bg-green-100 dark:bg-green-900/30 text-green-600 dark:text-green-400' : 'bg-red-100 dark:bg-red-900/30 text-red-600 dark:text-red-400'"
            >
              <CheckCircle2 class="w-16 h-16" />
            </div>
            <h3 class="text-2xl font-bold text-gray-900 dark:text-white">
              {{ executionResult.success ? '结算完成' : '结算失败' }}
            </h3>
            <p class="text-gray-500 dark:text-gray-400 text-center">
              {{ executionResult.message }}
            </p>
            <div
              v-if="executionResult.serialNum"
              class="mt-4 px-6 py-3 bg-gray-50 dark:bg-gray-900 rounded-lg text-sm text-gray-900 dark:text-white"
            >
              <span>结算单号：{{ executionResult.serialNum }}</span>
            </div>
          </div>
        </div>
      </div>

      <div class="flex items-center gap-3 p-6 border-t border-gray-200 dark:border-gray-700">
        <Button
          v-if="currentStep > 1 && currentStep < 3"
          variant="secondary"
          size="sm"
          :icon="ChevronLeft"
          @click="handlePrev"
        >
          上一步
        </Button>
        <div class="flex-1" />
        <Button
          v-if="currentStep < 3"
          variant="primary"
          size="sm"
          :icon-right="ChevronRight"
          :disabled="(currentStep === 1 && !canProceedStep1) || (currentStep === 2 && processing)"
          @click="handleNext"
        >
          {{ currentStep === 2 ? '执行结算' : '下一步' }}
        </Button>
        <Button v-else variant="primary" size="sm" @click="handleComplete">完成</Button>
      </div>
    </div>
  </div>
</template>
