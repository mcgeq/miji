<script setup lang="ts">
  import {
    LucideCheck,
    LucideClock,
    LucideCoins,
    LucideEqual,
    LucidePercent,
    LucideScale,
    LucideUsers,
  } from 'lucide-vue-next';
  import { Modal } from '@/components/ui';
  import type { SplitRuleType } from '@/schema/money';

  interface SplitDetail {
    memberSerialNum: string;
    memberName: string;
    amount: number;
    isPaid: boolean;
    percentage?: number;
    paidAt?: string;
  }

  interface Props {
    transactionSerialNum: string;
    transactionAmount: number;
    splitType: SplitRuleType;
    splitDetails: SplitDetail[];
    transactionDate?: string;
  }

  const props = defineProps<Props>();
  const emit = defineEmits<{
    close: [];
    updateStatus: [memberSerialNum: string, isPaid: boolean];
  }>();

  // 获取分摊类型信息
  const splitTypeInfo = computed(() => {
    const typeMap = {
      EQUAL: {
        label: '均等分摊',
        icon: LucideEqual,
        color: '#3b82f6',
        description: '所有成员平均分摊费用',
      },
      PERCENTAGE: {
        label: '按比例分摊',
        icon: LucidePercent,
        color: '#10b981',
        description: '根据设定的比例分摊费用',
      },
      FIXED_AMOUNT: {
        label: '固定金额',
        icon: LucideCoins,
        color: '#f59e0b',
        description: '为每个成员指定固定的分摊金额',
      },
      WEIGHTED: {
        label: '按权重分摊',
        icon: LucideScale,
        color: '#8b5cf6',
        description: '根据权重比例分摊费用',
      },
    };
    return typeMap[props.splitType] || typeMap.EQUAL;
  });

  // 统计信息
  const statistics = computed(() => {
    const total = props.splitDetails.length;
    const paid = props.splitDetails.filter(d => d.isPaid).length;
    const unpaid = total - paid;
    const totalAmount = props.splitDetails.reduce((sum, d) => sum + d.amount, 0);
    const paidAmount = props.splitDetails
      .filter(d => d.isPaid)
      .reduce((sum, d) => sum + d.amount, 0);
    const unpaidAmount = totalAmount - paidAmount;

    return {
      total,
      paid,
      unpaid,
      totalAmount,
      paidAmount,
      unpaidAmount,
      paidPercentage: total > 0 ? (paid / total) * 100 : 0,
    };
  });

  // 格式化金额
  function formatAmount(amount: number): string {
    return `¥${amount.toFixed(2)}`;
  }

  // 格式化日期
  function formatDate(dateStr?: string): string {
    if (!dateStr) return '-';
    const date = new Date(dateStr);
    return date.toLocaleDateString('zh-CN', {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    });
  }

  // 切换支付状态
  function togglePaymentStatus(detail: SplitDetail) {
    emit('updateStatus', detail.memberSerialNum, !detail.isPaid);
  }

  // 关闭
  function close() {
    emit('close');
  }
</script>

<template>
  <Modal :open="true" title="分摊详情" size="lg" :show-footer="false" @close="close">
    <div class="flex flex-col gap-6">
      <!-- 统计卡片 -->
      <div class="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <div
          class="flex items-center gap-3 p-4 bg-gray-50 dark:bg-gray-700 rounded-xl border-2 border-gray-200 dark:border-gray-600"
        >
          <LucideUsers class="w-6 h-6 shrink-0 text-gray-600 dark:text-gray-300" />
          <div class="flex flex-col gap-1">
            <label class="text-xs text-gray-600 dark:text-gray-400">参与人数</label>
            <strong class="text-base font-semibold text-gray-900 dark:text-white"
              >{{ statistics.total }}人</strong
            >
          </div>
        </div>

        <div
          class="flex items-center gap-3 p-4 bg-emerald-50 dark:bg-emerald-900/20 rounded-xl border-2 border-emerald-600 dark:border-emerald-500"
        >
          <LucideCheck class="w-6 h-6 shrink-0 text-emerald-600 dark:text-emerald-400" />
          <div class="flex flex-col gap-1">
            <label class="text-xs text-gray-600 dark:text-gray-400">已支付</label>
            <strong class="text-base font-semibold text-gray-900 dark:text-white"
              >{{ statistics.paid }}人</strong
            >
          </div>
        </div>

        <div
          class="flex items-center gap-3 p-4 bg-amber-50 dark:bg-amber-900/20 rounded-xl border-2 border-amber-500 dark:border-amber-400"
        >
          <LucideClock class="w-6 h-6 shrink-0 text-amber-500 dark:text-amber-400" />
          <div class="flex flex-col gap-1">
            <label class="text-xs text-gray-600 dark:text-gray-400">待支付</label>
            <strong class="text-base font-semibold text-gray-900 dark:text-white"
              >{{ statistics.unpaid }}人</strong
            >
          </div>
        </div>

        <div
          class="flex items-center gap-3 p-4 bg-blue-50 dark:bg-blue-900/20 rounded-xl border-2 border-blue-500 dark:border-blue-400"
        >
          <LucideCoins class="w-6 h-6 shrink-0 text-blue-500 dark:text-blue-400" />
          <div class="flex flex-col gap-1">
            <label class="text-xs text-gray-600 dark:text-gray-400">总金额</label>
            <strong class="text-base font-semibold text-gray-900 dark:text-white"
              >{{ formatAmount(statistics.totalAmount) }}</strong
            >
          </div>
        </div>
      </div>

      <!-- 进度条 -->
      <div class="flex flex-col gap-3 p-4 bg-gray-50 dark:bg-gray-700 rounded-xl">
        <div class="flex justify-between items-center text-sm font-medium">
          <span class="text-gray-900 dark:text-white">支付进度</span>
          <span class="text-blue-600 dark:text-blue-400 font-semibold"
            >{{ statistics.paidPercentage.toFixed(0) }}%</span
          >
        </div>
        <div class="h-3 bg-gray-200 dark:bg-gray-600 rounded-full overflow-hidden">
          <div
            class="h-full bg-gradient-to-r from-blue-500 to-emerald-500 dark:from-blue-400 dark:to-emerald-400 rounded-full transition-all duration-300"
            :style="{ width: `${statistics.paidPercentage}%` }"
          />
        </div>
        <div class="flex justify-between text-xs">
          <span class="text-emerald-600 dark:text-emerald-400"
            >已支付: {{ formatAmount(statistics.paidAmount) }}</span
          >
          <span class="text-amber-500 dark:text-amber-400"
            >待支付: {{ formatAmount(statistics.unpaidAmount) }}</span
          >
        </div>
      </div>

      <!-- 分摊明细列表 -->
      <div class="flex flex-col gap-4">
        <h4 class="m-0 text-base font-semibold text-gray-900 dark:text-white">分摊明细</h4>

        <div class="flex flex-col gap-3">
          <div
            v-for="detail in splitDetails"
            :key="detail.memberSerialNum"
            class="p-4 rounded-xl border-2 transition-all duration-200"
            :class="[
              detail.isPaid ? 'border-emerald-600 dark:border-emerald-500 bg-emerald-50 dark:bg-emerald-900/10' : 'border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800',
            ]"
          >
            <div
              class="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4"
            >
              <div class="flex items-center gap-3">
                <div
                  class="w-10 h-10 rounded-full bg-blue-500 dark:bg-blue-600 text-white flex items-center justify-center font-semibold text-base"
                >
                  {{ detail.memberName.charAt(0) }}
                </div>
                <div class="flex flex-col gap-1">
                  <span class="text-sm font-medium text-gray-900 dark:text-white"
                    >{{ detail.memberName }}</span
                  >
                  <span v-if="detail.percentage" class="text-xs text-gray-500 dark:text-gray-400">
                    {{ detail.percentage.toFixed(1) }}%
                  </span>
                </div>
              </div>

              <div class="flex items-center gap-4">
                <strong class="text-lg font-semibold text-blue-600 dark:text-blue-400"
                  >{{ formatAmount(detail.amount) }}</strong
                >
                <button
                  class="flex items-center gap-2 px-4 py-2 rounded-full text-xs font-medium cursor-pointer transition-all duration-200"
                  :class="[
                    detail.isPaid
                      ? 'bg-emerald-100 dark:bg-emerald-900/30 border border-emerald-600 dark:border-emerald-500 text-emerald-700 dark:text-emerald-300 hover:bg-emerald-200 dark:hover:bg-emerald-900/50'
                      : 'bg-amber-50 dark:bg-amber-900/30 border border-amber-500 dark:border-amber-400 text-amber-800 dark:text-amber-300 hover:bg-amber-100 dark:hover:bg-amber-900/50',
                  ]"
                  @click="togglePaymentStatus(detail)"
                >
                  <component :is="detail.isPaid ? LucideCheck : LucideClock" class="w-3.5 h-3.5" />
                  <span>{{ detail.isPaid ? '已支付' : '待支付' }}</span>
                </button>
              </div>
            </div>

            <div
              v-if="detail.isPaid && detail.paidAt"
              class="mt-3 pt-3 border-t border-gray-200 dark:border-gray-600"
            >
              <span class="text-xs text-gray-500 dark:text-gray-400"
                >支付时间: {{ formatDate(detail.paidAt) }}</span
              >
            </div>
          </div>
        </div>
      </div>

      <!-- 交易信息 -->
      <div class="flex flex-col gap-3 p-4 bg-gray-50 dark:bg-gray-700 rounded-xl">
        <div class="flex justify-between items-center text-sm">
          <label class="text-gray-600 dark:text-gray-400">交易金额</label>
          <strong class="font-semibold text-gray-900 dark:text-white"
            >{{ formatAmount(transactionAmount) }}</strong
          >
        </div>
        <div v-if="transactionDate" class="flex justify-between items-center text-sm">
          <label class="text-gray-600 dark:text-gray-400">交易日期</label>
          <span class="text-gray-900 dark:text-white">{{ formatDate(transactionDate) }}</span>
        </div>
        <div class="flex justify-between items-center text-sm">
          <label class="text-gray-600 dark:text-gray-400">分摊方式</label>
          <span class="text-gray-900 dark:text-white">{{ splitTypeInfo.description }}</span>
        </div>
      </div>
    </div>
  </Modal>
</template>
