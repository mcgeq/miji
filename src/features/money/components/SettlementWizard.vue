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
import { toast } from '@/utils/toast';

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

const members = ref([
  { serialNum: 'M001', name: '张三', selected: true },
  { serialNum: 'M002', name: '李四', selected: true },
  { serialNum: 'M003', name: '王五', selected: true },
]);

const settlementSuggestion = ref<any>(null);
const executionResult = ref<any>(null);

const selectedMembers = computed(() => members.value.filter(m => m.selected));

const canProceedStep1 = computed(() => {
  return settlementRange.value.startDate && settlementRange.value.endDate && selectedMembers.value.length >= 2;
});

function toggleMember(member: any) {
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
  <div class="wizard-overlay" @click.self="handleClose">
    <div class="wizard-container">
      <div class="wizard-header">
        <h2 class="wizard-title">
          {{ currentStep === 1 ? '选择结算范围' : currentStep === 2 ? '确认结算方案' : '执行结算' }}
        </h2>
        <button class="close-btn" @click="handleClose">
          <component :is="X" class="w-5 h-5" />
        </button>
      </div>

      <div class="progress-indicator">
        <div
          v-for="step in 3"
          :key="step"
          class="progress-step"
          :class="{ 'step-active': step === currentStep, 'step-completed': step < currentStep }"
        >
          <div class="step-circle">
            <component :is="CheckCircle2" v-if="step < currentStep" class="w-5 h-5" />
            <span v-else>{{ step }}</span>
          </div>
          <span class="step-label">
            {{ step === 1 ? '选择范围' : step === 2 ? '确认方案' : '执行结算' }}
          </span>
        </div>
      </div>

      <div class="wizard-body">
        <!-- 步骤1 -->
        <div v-if="currentStep === 1" class="step-content">
          <div class="form-section">
            <h3 class="form-title">
              <component :is="Calendar" class="w-5 h-5" />
              <span>结算周期</span>
            </h3>
            <div class="date-inputs">
              <input v-model="settlementRange.startDate" type="date" class="date-input">
              <span>至</span>
              <input v-model="settlementRange.endDate" type="date" class="date-input">
            </div>
          </div>

          <div class="form-section">
            <h3 class="form-title">
              <component :is="Calculator" class="w-5 h-5" />
              <span>结算类型</span>
            </h3>
            <div class="radio-group">
              <label class="radio-option">
                <input v-model="settlementRange.settlementType" type="radio" value="optimized">
                <div class="radio-content">
                  <component :is="Zap" class="w-5 h-5" />
                  <div>
                    <div class="radio-title">优化结算</div>
                    <div class="radio-desc">自动优化转账次数</div>
                  </div>
                </div>
              </label>
              <label class="radio-option">
                <input v-model="settlementRange.settlementType" type="radio" value="manual">
                <div class="radio-content">
                  <component :is="Users" class="w-5 h-5" />
                  <div>
                    <div class="radio-title">手动结算</div>
                    <div class="radio-desc">按原始债务关系</div>
                  </div>
                </div>
              </label>
            </div>
          </div>

          <div class="form-section">
            <h3 class="form-title">
              <component :is="Users" class="w-5 h-5" />
              <span>参与成员 ({{ selectedMembers.length }}/{{ members.length }})</span>
            </h3>
            <div class="members-grid">
              <div
                v-for="member in members"
                :key="member.serialNum"
                class="member-option"
                :class="{ 'member-selected': member.selected }"
                @click="toggleMember(member)"
              >
                <div class="member-avatar" :style="{ backgroundColor: getMemberColor(member.name) }">
                  {{ getInitials(member.name) }}
                </div>
                <span class="member-name">{{ member.name }}</span>
                <component :is="CheckCircle2" v-if="member.selected" class="check-icon" />
              </div>
            </div>
          </div>
        </div>

        <!-- 步骤2 -->
        <div v-else-if="currentStep === 2" class="step-content">
          <div v-if="processing" class="loading-state">
            <div class="loading-spinner" />
            <p>正在计算...</p>
          </div>
          <div v-else-if="settlementSuggestion" class="suggestion-content">
            <div class="summary-cards">
              <div class="summary-card">
                <span class="summary-label">结算金额</span>
                <span class="summary-value">¥{{ formatAmount(settlementSuggestion.totalAmount) }}</span>
              </div>
              <div class="summary-card">
                <span class="summary-label">转账次数</span>
                <span class="summary-value">{{ settlementSuggestion.transfers.length }}笔</span>
              </div>
              <div class="summary-card">
                <span class="summary-label">优化节省</span>
                <span class="summary-value">{{ settlementSuggestion.savings }}笔</span>
              </div>
            </div>
            <div class="transfers-list">
              <div v-for="(t, i) in settlementSuggestion.transfers" :key="i" class="transfer-row">
                <div class="transfer-index">
                  {{ i + 1 }}
                </div>
                <div class="transfer-info">
                  <span>{{ t.fromName }} → {{ t.toName }}</span>
                </div>
                <div class="transfer-amount">
                  ¥{{ formatAmount(t.amount) }}
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- 步骤3 -->
        <div v-else-if="currentStep === 3" class="step-content">
          <div v-if="processing" class="loading-state">
            <div class="loading-spinner" />
            <p>正在执行结算...</p>
          </div>
          <div v-else-if="executionResult" class="result-content">
            <div class="result-icon" :class="executionResult.success ? 'result-success' : 'result-error'">
              <component :is="CheckCircle2" class="w-16 h-16" />
            </div>
            <h3 class="result-title">
              {{ executionResult.success ? '结算完成' : '结算失败' }}
            </h3>
            <p class="result-message">
              {{ executionResult.message }}
            </p>
            <div v-if="executionResult.serialNum" class="result-detail">
              <span>结算单号：{{ executionResult.serialNum }}</span>
            </div>
          </div>
        </div>
      </div>

      <div class="wizard-footer">
        <button v-if="currentStep > 1 && currentStep < 3" class="btn-secondary" @click="handlePrev">
          <component :is="ChevronLeft" class="w-4 h-4" />
          <span>上一步</span>
        </button>
        <div class="footer-spacer" />
        <button
          v-if="currentStep < 3"
          class="btn-primary"
          :disabled="(currentStep === 1 && !canProceedStep1) || (currentStep === 2 && processing)"
          @click="handleNext"
        >
          <span>{{ currentStep === 2 ? '执行结算' : '下一步' }}</span>
          <component :is="ChevronRight" class="w-4 h-4" />
        </button>
        <button v-else class="btn-primary" @click="handleComplete">
          完成
        </button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.wizard-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0,0,0,0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 50;
  padding: 1rem;
}

.wizard-container {
  background: white;
  border-radius: 0.75rem;
  box-shadow: 0 20px 25px -5px rgba(0,0,0,0.1);
  max-width: 56rem;
  width: 100%;
  max-height: 90vh;
  display: flex;
  flex-direction: column;
}

:global(.dark) .wizard-container {
  background: #1f2937;
}

.wizard-header {
  padding: 1.5rem;
  display: flex;
  align-items: center;
  justify-content: space-between;
  border-bottom: 1px solid #e5e7eb;
}

:global(.dark) .wizard-header {
  border-color: #374151;
}

.wizard-title {
  font-size: 1.25rem;
  font-weight: 700;
  color: #111827;
}

:global(.dark) .wizard-title {
  color: #f3f4f6;
}

.close-btn {
  padding: 0.5rem;
  border-radius: 0.375rem;
  color: #6b7280;
  transition: background-color 0.15s;
}

.close-btn:hover {
  background: #f3f4f6;
}

:global(.dark) .close-btn:hover {
  background: #374151;
}

.progress-indicator {
  padding: 2rem 1.5rem;
  display: flex;
  align-items: center;
  justify-content: space-around;
}

.progress-step {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.5rem;
}

.step-circle {
  width: 3rem;
  height: 3rem;
  border-radius: 9999px;
  background: #e5e7eb;
  color: #6b7280;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 700;
  transition: all 0.3s;
}

.step-active .step-circle {
  background: #3b82f6;
  color: white;
  box-shadow: 0 0 0 4px rgba(59,130,246,0.2);
}

.step-completed .step-circle {
  background: #10b981;
  color: white;
}

.step-label {
  font-size: 0.875rem;
  color: #6b7280;
  font-weight: 500;
}

.step-active .step-label {
  color: #3b82f6;
  font-weight: 600;
}

.step-completed .step-label {
  color: #10b981;
}

.wizard-body {
  flex: 1;
  overflow-y: auto;
  padding: 1.5rem;
}

.step-content {
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
}

.form-section {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.form-title {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 1rem;
  font-weight: 600;
  color: #111827;
}

:global(.dark) .form-title {
  color: #f3f4f6;
}

.date-inputs {
  display: flex;
  align-items: center;
  gap: 1rem;
}

.date-input {
  flex: 1;
  padding: 0.75rem;
  border: 1px solid #d1d5db;
  border-radius: 0.5rem;
  font-size: 0.875rem;
}

.date-input:focus {
  outline: 2px solid #3b82f6;
  outline-offset: 2px;
  border-color: transparent;
}

:global(.dark) .date-input {
  background: #374151;
  border-color: #4b5563;
  color: #f3f4f6;
}

.radio-group {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.radio-option {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 1rem;
  border: 2px solid #e5e7eb;
  border-radius: 0.5rem;
  cursor: pointer;
  transition: all 0.15s;
}

.radio-option:hover {
  border-color: #3b82f6;
  background: #eff6ff;
}

.radio-option:has(input:checked) {
  border-color: #3b82f6;
  background: #eff6ff;
}

:global(.dark) .radio-option {
  border-color: #374151;
}

:global(.dark) .radio-option:hover,
:global(.dark) .radio-option:has(input:checked) {
  border-color: #60a5fa;
  background: rgba(30,58,138,0.2);
}

.radio-content {
  flex: 1;
  display: flex;
  align-items: center;
  gap: 0.75rem;
  color: #3b82f6;
}

.radio-title {
  font-weight: 600;
  color: #111827;
}

:global(.dark) .radio-title {
  color: #f3f4f6;
}

.radio-desc {
  font-size: 0.875rem;
  color: #6b7280;
  margin-top: 0.25rem;
}

.members-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(140px, 1fr));
  gap: 0.75rem;
}

.member-option {
  padding: 1rem;
  border: 2px solid #e5e7eb;
  border-radius: 0.5rem;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.5rem;
  cursor: pointer;
  transition: all 0.15s;
  position: relative;
}

.member-option:hover {
  border-color: #3b82f6;
  background: #eff6ff;
}

.member-selected {
  border-color: #3b82f6;
  background: #eff6ff;
}

:global(.dark) .member-option {
  border-color: #374151;
}

:global(.dark) .member-option:hover,
:global(.dark) .member-selected {
  border-color: #60a5fa;
  background: rgba(30,58,138,0.2);
}

.member-avatar {
  width: 3rem;
  height: 3rem;
  border-radius: 9999px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
  font-weight: 700;
  font-size: 1.125rem;
}

.member-name {
  font-size: 0.875rem;
  font-weight: 500;
  color: #111827;
}

:global(.dark) .member-name {
  color: #f3f4f6;
}

.check-icon {
  position: absolute;
  top: 0.5rem;
  right: 0.5rem;
  color: #3b82f6;
}

.loading-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 4rem 0;
  gap: 1rem;
}

.loading-spinner {
  width: 3rem;
  height: 3rem;
  border: 4px solid #3b82f6;
  border-top-color: transparent;
  border-radius: 9999px;
  animation: spin 1s linear infinite;
}

.summary-cards {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 1rem;
}

.summary-card {
  padding: 1.25rem;
  background: #f9fafb;
  border-radius: 0.5rem;
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

:global(.dark) .summary-card {
  background: rgba(17,24,39,0.5);
}

.summary-label {
  font-size: 0.875rem;
  color: #6b7280;
}

.summary-value {
  font-size: 1.5rem;
  font-weight: 700;
  color: #111827;
}

:global(.dark) .summary-value {
  color: #f3f4f6;
}

.transfers-list {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
  margin-top: 1rem;
}

.transfer-row {
  display: flex;
  align-items: center;
  gap: 1rem;
  padding: 1rem;
  background: #f9fafb;
  border-radius: 0.5rem;
  border: 1px solid #e5e7eb;
}

:global(.dark) .transfer-row {
  background: rgba(17,24,39,0.5);
  border-color: #374151;
}

.transfer-index {
  width: 2rem;
  height: 2rem;
  border-radius: 9999px;
  background: #dbeafe;
  color: #1d4ed8;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 700;
  font-size: 0.875rem;
}

.transfer-info {
  flex: 1;
  color: #111827;
}

:global(.dark) .transfer-info {
  color: #f3f4f6;
}

.transfer-amount {
  font-weight: 700;
  color: #111827;
}

:global(.dark) .transfer-amount {
  color: #f3f4f6;
}

.result-content {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 3rem 0;
  gap: 1rem;
}

.result-icon {
  width: 5rem;
  height: 5rem;
  border-radius: 9999px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.result-success {
  background: #d1fae5;
  color: #059669;
}

.result-error {
  background: #fee2e2;
  color: #dc2626;
}

.result-title {
  font-size: 1.5rem;
  font-weight: 700;
  color: #111827;
}

:global(.dark) .result-title {
  color: #f3f4f6;
}

.result-message {
  color: #6b7280;
  text-align: center;
}

.result-detail {
  margin-top: 1rem;
  padding: 0.75rem 1.5rem;
  background: #f9fafb;
  border-radius: 0.5rem;
  font-size: 0.875rem;
  color: #111827;
}

:global(.dark) .result-detail {
  background: rgba(17,24,39,0.5);
  color: #f3f4f6;
}

.wizard-footer {
  padding: 1.5rem;
  display: flex;
  align-items: center;
  gap: 0.75rem;
  border-top: 1px solid #e5e7eb;
}

:global(.dark) .wizard-footer {
  border-color: #374151;
}

.footer-spacer {
  flex: 1;
}

.btn-primary {
  padding: 0.5rem 1rem;
  background: #2563eb;
  color: white;
  border-radius: 0.5rem;
  font-size: 0.875rem;
  font-weight: 500;
  display: flex;
  align-items: center;
  gap: 0.5rem;
  transition: background-color 0.15s;
  border: none;
  cursor: pointer;
}

.btn-primary:hover:not(:disabled) {
  background: #1d4ed8;
}

.btn-primary:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.btn-secondary {
  padding: 0.5rem 1rem;
  background: #f3f4f6;
  color: #111827;
  border-radius: 0.5rem;
  font-size: 0.875rem;
  font-weight: 500;
  display: flex;
  align-items: center;
  gap: 0.5rem;
  border: none;
  cursor: pointer;
}

.btn-secondary:hover {
  background: #e5e7eb;
}

:global(.dark) .btn-secondary {
  background: #374151;
  color: #f3f4f6;
}

:global(.dark) .btn-secondary:hover {
  background: #4b5563;
}

@keyframes spin {
  from { transform: rotate(0deg); }
  to { transform: rotate(360deg); }
}
</style>
