<script setup lang="ts">
import { useI18n } from 'vue-i18n';
import { Button, Card, Input, Modal } from '@/components/ui';
import { invokeCommand } from '@/types/api';
import { DateUtils } from '@/utils/date';
import { toast } from '@/utils/toast';

const { t } = useI18n();

// 响应式数据
const pendingInstallments = ref<any[]>([]);
const showPaymentModal = ref(false);
const selectedDetail = ref<any>(null);
const paidAmount = ref<number>(0);
const isPaying = ref(false);

// 计算属性
const canConfirmPayment = computed(() => {
  return selectedDetail.value && paidAmount.value > 0 && paidAmount.value <= (selectedDetail.value?.amount || 0);
});

// 方法
async function refreshData() {
  try {
    const response = await invokeCommand<any[]>('installment_pending_list', {
      plan_serial_num: '', // 这里可能需要传入正确的plan_serial_num
    });
    pendingInstallments.value = response;
  } catch (error) {
    console.error('获取待还款分期失败:', error);
    toast.error(t('financial.installment.error.fetchFailed'));
  }
}

function payInstallment(detail: any) {
  selectedDetail.value = detail;
  paidAmount.value = detail.amount;
  showPaymentModal.value = true;
}

function closePaymentModal() {
  showPaymentModal.value = false;
  selectedDetail.value = null;
  paidAmount.value = 0;
}

async function confirmPayment() {
  if (!selectedDetail.value || !canConfirmPayment.value) return;

  try {
    isPaying.value = true;

    await invokeCommand('installment_pay', {
      data: {
        detail_serial_num: selectedDetail.value.serial_num,
        paid_amount: paidAmount.value,
        paid_date: DateUtils.formatDateToBackend(new Date()),
      },
    });

    toast.success(t('financial.installment.success.paymentCompleted'));
    closePaymentModal();
    await refreshData();
  } catch (error) {
    console.error('分期还款失败:', error);
    toast.error(t('financial.installment.error.paymentFailed'));
  } finally {
    isPaying.value = false;
  }
}

// 生命周期
onMounted(() => {
  refreshData();
});
</script>

<template>
  <div class="p-5 max-w-6xl mx-auto">
    <div class="flex justify-between items-center mb-8">
      <h2 class="text-2xl font-semibold text-gray-900 dark:text-white">
        {{ t('financial.installment.title') }}
      </h2>
      <Button variant="primary" size="sm" @click="refreshData">
        <LucideRefreshCw :size="16" class="mr-2" />
        {{ t('common.action.refresh') }}
      </Button>
    </div>

    <!-- 待还款列表 -->
    <div>
      <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-5">
        {{ t('financial.installment.pendingPayments') }}
      </h3>
      <div v-if="pendingInstallments.length === 0" class="text-center py-10 text-gray-500 dark:text-gray-400 bg-gray-50 dark:bg-gray-900/50 rounded-lg">
        {{ t('financial.installment.noPendingPayments') }}
      </div>
      <div v-else class="flex flex-col gap-4">
        <Card
          v-for="installment in pendingInstallments"
          :key="installment.serial_num"
          padding="lg"
          hoverable
        >
          <div class="flex flex-col lg:flex-row justify-between items-start lg:items-center gap-4">
            <div class="flex-1">
              <div class="flex flex-wrap justify-between items-center mb-2 gap-2">
                <h4 class="text-base font-semibold text-gray-900 dark:text-white">
                  {{ installment.description }}
                </h4>
                <span class="px-2 py-1 bg-yellow-100 dark:bg-yellow-900/30 text-yellow-600 dark:text-yellow-400 rounded text-xs font-medium">{{ installment.status }}</span>
              </div>
              <div class="space-y-1">
                <p class="text-sm text-gray-600 dark:text-gray-400">
                  {{ t('financial.installment.totalAmount') }}: ¥{{ installment.totalAmount.toFixed(2) }}
                </p>
                <p class="text-sm text-gray-600 dark:text-gray-400">
                  {{ t('financial.installment.remainingPeriods') }}: {{ installment.remainingPeriods }}/{{ installment.totalPeriods }}
                </p>
              </div>
            </div>
            <div class="flex gap-2 flex-wrap">
              <button
                v-for="detail in installment.details.filter((d: any) => d.status === 'PENDING')"
                :key="detail.serial_num"
                class="px-3 py-2 bg-green-600 hover:bg-green-700 disabled:bg-gray-400 dark:disabled:bg-gray-600 text-white rounded transition-colors text-xs text-center disabled:cursor-not-allowed"
                :disabled="isPaying"
                @click="payInstallment(detail)"
              >
                <div>{{ t('financial.installment.payPeriod', { period: detail.period }) }}</div>
                <div class="text-xs opacity-90">
                  ¥{{ detail.amount.toFixed(2) }}
                </div>
              </button>
            </div>
          </div>
        </Card>
      </div>
    </div>

    <!-- 还款对话框 -->
    <Modal
      :open="showPaymentModal"
      :title="t('financial.installment.paymentModal.title')"
      size="sm"
      :confirm-loading="isPaying"
      :confirm-disabled="!canConfirmPayment"
      @close="closePaymentModal"
      @confirm="confirmPayment"
    >
      <div class="space-y-3">
        <div class="flex justify-between items-center">
          <label class="text-sm font-medium text-gray-900 dark:text-white">{{ t('financial.installment.paymentModal.period') }}</label>
          <span class="text-sm text-gray-600 dark:text-gray-400">{{ selectedDetail?.period }}</span>
        </div>
        <div class="flex justify-between items-center">
          <label class="text-sm font-medium text-gray-900 dark:text-white">{{ t('financial.installment.paymentModal.dueDate') }}</label>
          <span class="text-sm text-gray-600 dark:text-gray-400">{{ selectedDetail?.dueDate }}</span>
        </div>
        <div class="flex justify-between items-center">
          <label class="text-sm font-medium text-gray-900 dark:text-white">{{ t('financial.installment.paymentModal.amount') }}</label>
          <span class="text-sm text-gray-600 dark:text-gray-400">¥{{ selectedDetail?.amount.toFixed(2) }}</span>
        </div>
        <div class="flex justify-between items-center gap-4">
          <label class="text-sm font-medium text-gray-900 dark:text-white whitespace-nowrap">{{ t('financial.installment.paymentModal.paidAmount') }}</label>
          <Input
            v-model.number="paidAmount"
            type="number"
            step="0.01"
            class="w-32"
            :placeholder="t('financial.installment.paymentModal.enterAmount')"
          />
        </div>
      </div>
    </Modal>
  </div>
</template>
