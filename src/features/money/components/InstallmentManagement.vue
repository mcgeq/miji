<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
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
  <div class="installment-management">
    <div class="header">
      <h2>{{ t('financial.installment.title') }}</h2>
      <button class="refresh-btn" @click="refreshData">
        {{ t('common.action.refresh') }}
      </button>
    </div>

    <!-- 待还款列表 -->
    <div class="pending-section">
      <h3>{{ t('financial.installment.pendingPayments') }}</h3>
      <div v-if="pendingInstallments.length === 0" class="empty-state">
        {{ t('financial.installment.noPendingPayments') }}
      </div>
      <div v-else class="installment-list">
        <div
          v-for="installment in pendingInstallments"
          :key="installment.serial_num"
          class="installment-item"
        >
          <div class="installment-info">
            <div class="plan-header">
              <h4>{{ installment.description }}</h4>
              <span class="plan-status">{{ installment.status }}</span>
            </div>
            <div class="plan-details">
              <p>{{ t('financial.installment.totalAmount') }}: ¥{{ installment.totalAmount.toFixed(2) }}</p>
              <p>{{ t('financial.installment.remainingPeriods') }}: {{ installment.remainingPeriods }}/{{ installment.totalPeriods }}</p>
            </div>
          </div>
          <div class="installment-actions">
            <button
              v-for="detail in installment.details.filter((d: any) => d.status === 'PENDING')"
              :key="detail.serial_num"
              class="pay-btn"
              :disabled="isPaying"
              @click="payInstallment(detail)"
            >
              {{ t('financial.installment.payPeriod', { period: detail.period }) }}
              <br>
              <small>¥{{ detail.amount.toFixed(2) }}</small>
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- 还款对话框 -->
    <div v-if="showPaymentModal" class="payment-modal-overlay" @click="closePaymentModal">
      <div class="payment-modal" @click.stop>
        <h3>{{ t('financial.installment.paymentModal.title') }}</h3>
        <div class="payment-form">
          <div class="form-row">
            <label>{{ t('financial.installment.paymentModal.period') }}</label>
            <span>{{ selectedDetail?.period }}</span>
          </div>
          <div class="form-row">
            <label>{{ t('financial.installment.paymentModal.dueDate') }}</label>
            <span>{{ selectedDetail?.dueDate }}</span>
          </div>
          <div class="form-row">
            <label>{{ t('financial.installment.paymentModal.amount') }}</label>
            <span>¥{{ selectedDetail?.amount.toFixed(2) }}</span>
          </div>
          <div class="form-row">
            <label>{{ t('financial.installment.paymentModal.paidAmount') }}</label>
            <input
              v-model="paidAmount"
              type="number"
              step="0.01"
              class="form-control"
              :placeholder="t('financial.installment.paymentModal.enterAmount')"
            >
          </div>
        </div>
        <div class="modal-actions">
          <button class="btn-secondary" @click="closePaymentModal">
            {{ t('common.action.cancel') }}
          </button>
          <button class="btn-primary" :disabled="!canConfirmPayment" @click="confirmPayment">
            {{ t('financial.installment.paymentModal.confirmPayment') }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.installment-management {
  padding: 20px;
  max-width: 1200px;
  margin: 0 auto;
}

.header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 30px;
}

.header h2 {
  margin: 0;
  color: var(--color-text-primary);
}

.refresh-btn {
  padding: 8px 16px;
  background: var(--color-primary);
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  transition: background-color 0.2s;
}

.refresh-btn:hover {
  background: var(--color-primary-dark);
}

.pending-section h3 {
  margin-bottom: 20px;
  color: var(--color-text-primary);
}

.empty-state {
  text-align: center;
  padding: 40px;
  color: var(--color-text-secondary);
  background: var(--color-background-secondary);
  border-radius: 8px;
}

.installment-list {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.installment-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 20px;
  background: var(--color-background-secondary);
  border-radius: 8px;
  border: 1px solid var(--color-border);
}

.installment-info {
  flex: 1;
}

.plan-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 8px;
}

.plan-header h4 {
  margin: 0;
  color: var(--color-text-primary);
}

.plan-status {
  padding: 4px 8px;
  background: var(--color-warning);
  color: white;
  border-radius: 4px;
  font-size: 12px;
}

.plan-details p {
  margin: 4px 0;
  color: var(--color-text-secondary);
  font-size: 14px;
}

.installment-actions {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
}

.pay-btn {
  padding: 8px 12px;
  background: var(--color-success);
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  transition: background-color 0.2s;
  font-size: 12px;
  text-align: center;
}

.pay-btn:hover:not(:disabled) {
  background: var(--color-success-dark);
}

.pay-btn:disabled {
  background: var(--color-disabled);
  cursor: not-allowed;
}

.payment-modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.5);
  display: flex;
  justify-content: center;
  align-items: center;
  z-index: 1000;
}

.payment-modal {
  background: var(--color-background-primary);
  padding: 24px;
  border-radius: 8px;
  min-width: 400px;
  max-width: 500px;
}

.payment-modal h3 {
  margin: 0 0 20px 0;
  color: var(--color-text-primary);
}

.payment-form {
  margin-bottom: 20px;
}

.form-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 12px;
}

.form-row label {
  font-weight: 500;
  color: var(--color-text-primary);
}

.form-row span {
  color: var(--color-text-secondary);
}

.form-control {
  width: 120px;
  padding: 6px 8px;
  border: 1px solid var(--color-border);
  border-radius: 4px;
  background: var(--color-background-primary);
  color: var(--color-text-primary);
}

.modal-actions {
  display: flex;
  justify-content: flex-end;
  gap: 12px;
}

.btn-primary, .btn-secondary {
  padding: 8px 16px;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  transition: background-color 0.2s;
}

.btn-primary {
  background: var(--color-primary);
  color: white;
}

.btn-primary:hover:not(:disabled) {
  background: var(--color-primary-dark);
}

.btn-primary:disabled {
  background: var(--color-disabled);
  cursor: not-allowed;
}

.btn-secondary {
  background: var(--color-background-secondary);
  color: var(--color-text-primary);
  border: 1px solid var(--color-border);
}

.btn-secondary:hover {
  background: var(--color-background-tertiary);
}
</style>
