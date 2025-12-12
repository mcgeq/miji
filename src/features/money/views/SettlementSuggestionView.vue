<script setup lang="ts">
  import {
    ArrowLeft,
    ArrowRight,
    ArrowRightLeft,
    BarChart3,
    CheckCircle2,
    DollarSign,
    Inbox,
    Lightbulb,
    Network,
    RefreshCw,
    TrendingDown,
    TrendingUp,
    Users,
    XCircle,
    Zap,
  } from 'lucide-vue-next';
  import { useRouter } from 'vue-router';
  import Button from '@/components/ui/Button.vue';
  import { useMoneyAuth } from '@/composables/useMoneyAuth';
  import type { TransferSuggestion } from '@/services/money/settlement';
  import { settlementService } from '@/services/money/settlement';
  import { handleApiError } from '@/utils/apiHelper';
  import { toast } from '@/utils/toast';
  import SettlementPathVisualization from '../components/SettlementPathVisualization.vue';

  // ==================== 接口定义 ====================

  interface SettlementSuggestion {
    familyLedgerSerialNum: string;
    optimizedTransfers: TransferSuggestion[];
    totalTransfers: number;
    totalAmount: number;
    savings: number;
  }

  // ==================== 状态管理 ====================

  const router = useRouter();

  const suggestion = ref<SettlementSuggestion | null>(null);
  const loading = ref(false);
  const executing = ref(false);
  const showVisualization = ref(true);

  // 使用认证composable获取当前用户信息
  const { currentLedgerSerialNum, currentMemberSerialNum } = useMoneyAuth();

  // ==================== 计算属性 ====================

  // 原始转账次数（未优化前）
  const originalTransferCount = computed(() => {
    if (!suggestion.value) return 0;
    return suggestion.value.totalTransfers + suggestion.value.savings;
  });

  // 优化节省的转账次数
  const optimizationSavings = computed(() => {
    return suggestion.value?.savings || 0;
  });

  // 优化百分比
  const optimizationPercentage = computed(() => {
    if (!suggestion.value || originalTransferCount.value === 0) return 0;
    return Math.round((suggestion.value.savings / originalTransferCount.value) * 100);
  });

  // 参与成员数量
  const participantCount = computed(() => {
    if (!suggestion.value) return 0;
    const members = new Set<string>();
    suggestion.value.optimizedTransfers.forEach(transfer => {
      members.add(transfer.from);
      members.add(transfer.to);
    });
    return members.size;
  });

  // ==================== 方法 ====================

  // 加载结算建议
  async function loadSuggestion() {
    loading.value = true;
    try {
      const result = await settlementService.calculateSuggestion({
        familyLedgerSerialNum: currentLedgerSerialNum.value,
        settlementType: 'optimized',
      });

      suggestion.value = {
        familyLedgerSerialNum: currentLedgerSerialNum.value,
        optimizedTransfers: result.optimizedTransfers,
        totalTransfers: result.optimizedTransfers.length,
        totalAmount: result.totalAmount,
        savings: result.savings,
      };
    } catch (error) {
      handleApiError(error, '加载结算建议失败');
    } finally {
      loading.value = false;
    }
  }

  // 返回
  function handleBack() {
    router.back();
  }

  // 刷新
  async function handleRefresh() {
    await loadSuggestion();
    toast.success('已刷新');
  }

  // 执行结算
  async function handleExecute() {
    if (!suggestion.value) return;

    executing.value = true;
    try {
      const now = new Date();
      const periodStart = new Date(now.getFullYear(), now.getMonth(), 1)
        .toISOString()
        .split('T')[0];
      const periodEnd = now.toISOString().split('T')[0];

      const result = await settlementService.executeSettlement({
        familyLedgerSerialNum: suggestion.value.familyLedgerSerialNum,
        settlementType: 'optimized',
        periodStart,
        periodEnd,
        participantMembers: Array.from(
          new Set([
            ...suggestion.value.optimizedTransfers.map(t => t.from),
            ...suggestion.value.optimizedTransfers.map(t => t.to),
          ]),
        ),
        optimizedTransfers: suggestion.value.optimizedTransfers,
        totalAmount: suggestion.value.totalAmount,
        currency: 'CNY',
        initiatedBy: currentMemberSerialNum.value,
      });

      toast.success(`结算已成功执行，单号：${result.serialNum}`);
      router.push('/money/settlement-records');
    } catch (error) {
      handleApiError(error, '执行结算失败');
    } finally {
      executing.value = false;
    }
  }

  // 切换可视化显示
  function toggleVisualization() {
    showVisualization.value = !showVisualization.value;
  }

  // 获取成员颜色
  function getMemberColor(memberSerialNum: string): string {
    const colors = [
      '#3b82f6',
      '#ef4444',
      '#10b981',
      '#f59e0b',
      '#8b5cf6',
      '#ec4899',
      '#14b8a6',
      '#f97316',
    ];
    const index = Number.parseInt(memberSerialNum.slice(-1), 16) % colors.length;
    return colors[index];
  }

  // 获取首字母
  function getInitials(name: string): string {
    return name.charAt(0).toUpperCase();
  }

  // 格式化金额
  function formatAmount(amount: number): string {
    return amount.toFixed(2);
  }

  // ==================== 生命周期 ====================

  onMounted(() => {
    loadSuggestion();
  });
</script>

<template>
  <div class="p-6 flex flex-col gap-6">
    <!-- 页面标题 -->
    <div class="flex flex-col md:flex-row items-start justify-between gap-4">
      <div class="flex items-start gap-3">
        <button
          class="p-2 rounded-lg transition-colors text-gray-600 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-800"
          @click="handleBack"
        >
          <component :is="ArrowLeft" class="w-5 h-5" />
        </button>
        <div>
          <h1 class="text-2xl font-bold text-gray-900 dark:text-gray-100">智能结算建议</h1>
          <p class="mt-1 text-sm text-gray-600 dark:text-gray-400">
            基于当前债务关系，为您优化结算方案
          </p>
        </div>
      </div>
      <div class="flex items-center gap-3">
        <Button variant="secondary" :disabled="loading" @click="handleRefresh">
          <component :is="RefreshCw" :class="{ 'animate-spin': loading }" class="w-4 h-4" />
          <span>刷新</span>
        </Button>
        <Button variant="primary" :disabled="!suggestion || executing" @click="handleExecute">
          <component :is="Zap" class="w-4 h-4" />
          <span>{{ executing ? '执行中...' : '一键结算' }}</span>
        </Button>
      </div>
    </div>

    <!-- 优化统计 -->
    <div v-if="suggestion" class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
      <div
        class="bg-white dark:bg-gray-800 rounded-lg p-5 flex items-center gap-4 shadow-sm border-l-4 border-green-500 md:col-span-2"
      >
        <div
          class="w-12 h-12 rounded-lg bg-green-100 dark:bg-green-900/30 text-green-600 dark:text-green-400 flex items-center justify-center"
        >
          <component :is="TrendingUp" class="w-8 h-8" />
        </div>
        <div class="flex-1">
          <div class="text-sm text-gray-600 dark:text-gray-400">优化效果</div>
          <div class="text-2xl font-bold text-gray-900 dark:text-gray-100 mt-1">
            减少 {{ optimizationSavings }}笔转账
          </div>
          <div class="text-xs text-gray-500 dark:text-gray-500 mt-1">
            从 {{ originalTransferCount }}笔优化至 {{ suggestion.totalTransfers }}笔
          </div>
        </div>
      </div>

      <div
        class="bg-white dark:bg-gray-800 rounded-lg p-5 flex items-center gap-4 shadow-sm border-l-4 border-blue-500"
      >
        <div
          class="w-12 h-12 rounded-lg bg-blue-100 dark:bg-blue-900/30 text-blue-600 dark:text-blue-400 flex items-center justify-center"
        >
          <component :is="ArrowRightLeft" class="w-6 h-6" />
        </div>
        <div class="flex-1">
          <div class="text-sm text-gray-600 dark:text-gray-400">需要转账</div>
          <div class="text-2xl font-bold text-gray-900 dark:text-gray-100 mt-1">
            {{ suggestion.totalTransfers }}笔
          </div>
          <div class="text-xs text-gray-500 dark:text-gray-500 mt-1">最优方案</div>
        </div>
      </div>

      <div
        class="bg-white dark:bg-gray-800 rounded-lg p-5 flex items-center gap-4 shadow-sm border-l-4 border-purple-500"
      >
        <div
          class="w-12 h-12 rounded-lg bg-purple-100 dark:bg-purple-900/30 text-purple-600 dark:text-purple-400 flex items-center justify-center"
        >
          <component :is="DollarSign" class="w-6 h-6" />
        </div>
        <div class="flex-1">
          <div class="text-sm text-gray-600 dark:text-gray-400">结算总额</div>
          <div class="text-2xl font-bold text-gray-900 dark:text-gray-100 mt-1">
            ¥{{ formatAmount(suggestion.totalAmount) }}
          </div>
          <div class="text-xs text-gray-500 dark:text-gray-500 mt-1">CNY</div>
        </div>
      </div>

      <div
        class="bg-white dark:bg-gray-800 rounded-lg p-5 flex items-center gap-4 shadow-sm border-l-4 border-orange-500"
      >
        <div
          class="w-12 h-12 rounded-lg bg-orange-100 dark:bg-orange-900/30 text-orange-600 dark:text-orange-400 flex items-center justify-center"
        >
          <component :is="Users" class="w-6 h-6" />
        </div>
        <div class="flex-1">
          <div class="text-sm text-gray-600 dark:text-gray-400">参与成员</div>
          <div class="text-2xl font-bold text-gray-900 dark:text-gray-100 mt-1">
            {{ participantCount }}人
          </div>
          <div class="text-xs text-gray-500 dark:text-gray-500 mt-1">全部成员</div>
        </div>
      </div>
    </div>

    <!-- 加载状态 -->
    <div
      v-if="loading"
      class="flex flex-col items-center justify-center py-20 bg-white dark:bg-gray-800 rounded-lg"
    >
      <div
        class="w-16 h-16 border-4 border-blue-600 border-t-transparent rounded-full animate-spin"
      />
      <p class="mt-4 text-gray-600 dark:text-gray-400">正在计算最优结算方案...</p>
    </div>

    <!-- 无建议状态 -->
    <div
      v-else-if="!suggestion"
      class="flex flex-col items-center justify-center py-20 bg-white dark:bg-gray-800 rounded-lg"
    >
      <component :is="Inbox" class="w-16 h-16 text-gray-400 dark:text-gray-600" />
      <p class="mt-4 text-lg font-medium text-gray-900 dark:text-gray-100">暂无结算建议</p>
      <p class="mt-2 text-sm text-gray-600 dark:text-gray-400">当前没有需要结算的债务关系</p>
      <Button variant="primary" class="mt-4" @click="handleRefresh">
        <component :is="RefreshCw" class="w-4 h-4" />
        <span>重新计算</span>
      </Button>
    </div>

    <!-- 结算方案 -->
    <div v-else class="flex flex-col gap-6">
      <!-- 算法说明 -->
      <div
        class="bg-blue-50 dark:bg-blue-900/20 rounded-lg p-4 border border-blue-200 dark:border-blue-800"
      >
        <div class="flex items-center gap-2 text-blue-700 dark:text-blue-300 font-medium mb-2">
          <component :is="Lightbulb" class="w-5 h-5" />
          <span>算法说明</span>
        </div>
        <p class="text-sm text-blue-600 dark:text-blue-400 leading-relaxed">
          使用贪心算法优化结算路径，通过计算每个成员的净欠款，
          将多对多的债务关系简化为最少的转账次数。 本次优化节省了 {{ optimizationSavings }}
          笔转账操作。
        </p>
      </div>

      <!-- 转账列表 -->
      <div class="bg-white dark:bg-gray-800 rounded-lg p-6 shadow-sm">
        <div class="flex items-center justify-between mb-4">
          <h3
            class="flex items-center gap-2 text-lg font-semibold text-gray-900 dark:text-gray-100"
          >
            <component :is="ArrowRightLeft" class="w-5 h-5" />
            <span>转账明细</span>
          </h3>
          <span class="text-sm text-gray-500">{{ suggestion.optimizedTransfers.length }}笔</span>
        </div>

        <div class="flex flex-col gap-4">
          <div
            v-for="(transfer, index) in suggestion.optimizedTransfers"
            :key="index"
            class="flex items-center gap-4 p-4 bg-gray-50 dark:bg-gray-900/50 rounded-lg border border-gray-200 dark:border-gray-700"
          >
            <!-- 序号 -->
            <div
              class="w-8 h-8 rounded-full bg-blue-100 dark:bg-blue-900/30 text-blue-700 dark:text-blue-300 flex items-center justify-center font-bold text-sm flex-shrink-0"
            >
              {{ index + 1 }}
            </div>

            <!-- 转账信息 -->
            <div
              class="flex-1 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4"
            >
              <div class="flex items-center gap-4 flex-wrap">
                <!-- 付款人 -->
                <div class="flex items-center gap-3">
                  <div
                    class="w-10 h-10 rounded-full flex items-center justify-center text-white font-bold text-sm"
                    :style="{ backgroundColor: getMemberColor(transfer.from) }"
                  >
                    {{ getInitials(transfer.fromName) }}
                  </div>
                  <div>
                    <div class="font-medium text-sm text-gray-900 dark:text-gray-100">
                      {{ transfer.fromName }}
                    </div>
                    <div class="text-xs text-gray-500">付款人</div>
                  </div>
                </div>

                <!-- 箭头 -->
                <div class="text-blue-600 dark:text-blue-400">
                  <component :is="ArrowRight" class="w-6 h-6" />
                </div>

                <!-- 收款人 -->
                <div class="flex items-center gap-3">
                  <div
                    class="w-10 h-10 rounded-full flex items-center justify-center text-white font-bold text-sm"
                    :style="{ backgroundColor: getMemberColor(transfer.to) }"
                  >
                    {{ getInitials(transfer.toName) }}
                  </div>
                  <div>
                    <div class="font-medium text-sm text-gray-900 dark:text-gray-100">
                      {{ transfer.toName }}
                    </div>
                    <div class="text-xs text-gray-500">收款人</div>
                  </div>
                </div>
              </div>

              <!-- 金额 -->
              <div class="flex items-baseline gap-2">
                <span class="text-xl font-bold text-gray-900 dark:text-gray-100"
                  >¥{{ formatAmount(transfer.amount) }}</span
                >
                <span class="text-sm text-gray-500">{{ transfer.currency }}</span>
              </div>
            </div>

            <!-- 状态 -->
            <div class="flex items-center">
              <span
                class="px-3 py-1 rounded-full text-xs font-medium bg-yellow-100 dark:bg-yellow-900/30 text-yellow-800 dark:text-yellow-300"
                >待执行</span
              >
            </div>
          </div>
        </div>
      </div>

      <!-- 可视化图表 -->
      <div class="bg-white dark:bg-gray-800 rounded-lg p-6 shadow-sm">
        <div class="flex items-center justify-between mb-4">
          <h3
            class="flex items-center gap-2 text-lg font-semibold text-gray-900 dark:text-gray-100"
          >
            <component :is="Network" class="w-5 h-5" />
            <span>结算路径图</span>
          </h3>
          <button
            class="text-sm text-blue-600 dark:text-blue-400 hover:underline"
            @click="toggleVisualization"
          >
            {{ showVisualization ? '收起' : '展开' }}
          </button>
        </div>

        <div v-if="showVisualization" class="mt-4">
          <SettlementPathVisualization
            v-if="suggestion"
            :transfers="suggestion.optimizedTransfers"
          />
        </div>
      </div>

      <!-- 对比分析 -->
      <div class="bg-white dark:bg-gray-800 rounded-lg p-6 shadow-sm">
        <div class="flex items-center justify-between mb-4">
          <h3
            class="flex items-center gap-2 text-lg font-semibold text-gray-900 dark:text-gray-100"
          >
            <component :is="BarChart3" class="w-5 h-5" />
            <span>优化对比</span>
          </h3>
        </div>

        <div class="flex flex-col md:flex-row items-center justify-center gap-6">
          <div
            class="flex-1 max-w-xs p-4 rounded-lg border-2 border-red-200 dark:border-red-800 bg-red-50 dark:bg-red-900/20"
          >
            <div class="flex items-center gap-2 font-medium mb-3 text-red-700 dark:text-red-300">
              <component :is="XCircle" class="w-5 h-5" />
              <span>优化前</span>
            </div>
            <div class="flex flex-col gap-2">
              <div class="flex items-center justify-between">
                <span class="text-sm text-gray-600 dark:text-gray-400">转账次数</span>
                <span class="text-lg font-bold text-gray-900 dark:text-gray-100"
                  >{{ originalTransferCount }}</span
                >
              </div>
              <div class="flex items-center justify-between">
                <span class="text-sm text-gray-600 dark:text-gray-400">复杂度</span>
                <span class="text-lg font-bold text-red-600 dark:text-red-400">高</span>
              </div>
            </div>
          </div>

          <div class="text-gray-400 dark:text-gray-600">
            <component :is="ArrowRight" class="w-8 h-8" />
          </div>

          <div
            class="flex-1 max-w-xs p-4 rounded-lg border-2 border-green-200 dark:border-green-800 bg-green-50 dark:bg-green-900/20"
          >
            <div
              class="flex items-center gap-2 font-medium mb-3 text-green-700 dark:text-green-300"
            >
              <component :is="CheckCircle2" class="w-5 h-5" />
              <span>优化后</span>
            </div>
            <div class="flex flex-col gap-2">
              <div class="flex items-center justify-between">
                <span class="text-sm text-gray-600 dark:text-gray-400">转账次数</span>
                <span class="text-lg font-bold text-gray-900 dark:text-gray-100"
                  >{{ suggestion.totalTransfers }}</span
                >
              </div>
              <div class="flex items-center justify-between">
                <span class="text-sm text-gray-600 dark:text-gray-400">复杂度</span>
                <span class="text-lg font-bold text-green-600 dark:text-green-400">低</span>
              </div>
            </div>
          </div>
        </div>

        <div
          class="mt-4 flex items-center justify-center gap-2 text-green-700 dark:text-green-300 font-medium"
        >
          <component :is="TrendingDown" class="w-5 h-5" />
          <span>节省 {{ optimizationPercentage }}% 的转账操作</span>
        </div>
      </div>
    </div>
  </div>
</template>
