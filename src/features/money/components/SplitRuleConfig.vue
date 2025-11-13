<script setup lang="ts">
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
  <div class="modal-mask">
    <div class="modal-window">
      <div class="modal-header">
        <h3 class="modal-title">
          {{ props.rule ? '编辑分摊规则' : '创建分摊规则' }}
        </h3>
        <button class="modal-close-btn" @click="closeDialog">
          <LucideX class="w-5 h-5" />
        </button>
      </div>

      <div class="modal-content">
        <!-- 基本信息 -->
        <div class="form-section">
          <div class="form-row">
            <label class="form-label">规则名称</label>
            <input
              v-model="form.name"
              type="text"
              class="form-input"
              placeholder="请输入规则名称"
              required
            >
          </div>

          <div class="form-row">
            <label class="form-label">描述</label>
            <textarea
              v-model="form.description"
              class="form-textarea"
              placeholder="可选的规则描述"
              rows="2"
            />
          </div>

          <div class="form-row">
            <label class="form-label">分摊类型</label>
            <select v-model="form.ruleType" class="form-select">
              <option value="EQUAL">
                均摊
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

          <div class="form-row">
            <label class="checkbox-label">
              <input v-model="form.isTemplate" type="checkbox" class="checkbox">
              <span>保存为模板</span>
            </label>
          </div>
        </div>

        <!-- 参与者配置 -->
        <div class="form-section">
          <div class="section-header">
            <h4 class="section-title">
              参与者配置
            </h4>
            <button type="button" class="add-btn" @click="addParticipant">
              <LucidePlus class="w-4 h-4" />
              添加参与者
            </button>
          </div>

          <div class="participants-list">
            <div
              v-for="(participant, index) in form.participants"
              :key="participant.memberSerialNum"
              class="participant-item"
            >
              <div class="participant-info">
                <LucideUser class="w-4 h-4 text-gray-500" />
                <span class="participant-name">{{ getMemberName(participant.memberSerialNum) }}</span>
              </div>

              <div class="participant-config">
                <!-- 百分比配置 -->
                <div v-if="form.ruleType === 'PERCENTAGE'" class="config-item">
                  <input
                    v-model.number="participant.percentage"
                    type="number"
                    min="0"
                    max="100"
                    step="0.01"
                    class="config-input"
                    placeholder="0"
                  >
                  <span class="config-unit">%</span>
                </div>

                <!-- 固定金额配置 -->
                <div v-else-if="form.ruleType === 'FIXED_AMOUNT'" class="config-item">
                  <input
                    v-model.number="participant.fixedAmount"
                    type="number"
                    min="0"
                    step="0.01"
                    class="config-input"
                    placeholder="0"
                  >
                  <span class="config-unit">元</span>
                </div>

                <!-- 权重配置 -->
                <div v-else-if="form.ruleType === 'WEIGHTED'" class="config-item">
                  <input
                    v-model.number="participant.weight"
                    type="number"
                    min="0.1"
                    step="0.1"
                    class="config-input"
                    placeholder="1"
                  >
                  <span class="config-unit">权重</span>
                </div>
              </div>

              <button
                type="button"
                class="remove-btn"
                @click="removeParticipant(index)"
              >
                <LucideTrash class="w-4 h-4" />
              </button>
            </div>
          </div>
        </div>

        <!-- 预览 -->
        <div class="form-section">
          <div class="section-header">
            <h4 class="section-title">
              预览
            </h4>
            <div class="preview-amount">
              <label>测试金额:</label>
              <input
                v-model.number="previewAmount"
                type="number"
                min="1"
                step="0.01"
                class="amount-input"
              >
              <span>元</span>
            </div>
          </div>

          <div class="preview-results">
            <div
              v-for="result in previewResults"
              :key="result.memberSerialNum"
              class="preview-item"
            >
              <span class="preview-name">{{ result.memberName }}</span>
              <span class="preview-amount">{{ result.amount.toFixed(2) }}元</span>
              <span class="preview-percentage">({{ result.percentage.toFixed(1) }}%)</span>
            </div>
          </div>
        </div>
      </div>

      <!-- 操作按钮 -->
      <div class="modal-actions">
        <button type="button" class="btn-cancel" @click="closeDialog">
          取消
        </button>
        <button type="button" class="btn-save" @click="saveRule">
          保存
        </button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.modal-mask {
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background-color: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
}

.modal-window {
  background: white;
  border-radius: 8px;
  width: 90%;
  max-width: 600px;
  max-height: 90vh;
  overflow: hidden;
  display: flex;
  flex-direction: column;
}

.modal-header {
  padding: 1rem 1.5rem;
  border-bottom: 1px solid #e5e7eb;
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.modal-title {
  font-size: 1.125rem;
  font-weight: 600;
  color: #1f2937;
}

.modal-close-btn {
  color: #6b7280;
  transition: color 0.2s;
}

.modal-close-btn:hover {
  color: #374151;
}

.modal-content {
  flex: 1;
  overflow-y: auto;
  padding: 1.5rem;
}

.form-section {
  margin-bottom: 1.5rem;
}

.form-row {
  margin-bottom: 1rem;
}

.form-label {
  display: block;
  font-size: 0.875rem;
  font-weight: 500;
  color: #374151;
  margin-bottom: 0.25rem;
}

.form-input, .form-select, .form-textarea {
  width: 100%;
  padding: 0.5rem 0.75rem;
  border: 1px solid #d1d5db;
  border-radius: 0.375rem;
  font-size: 0.875rem;
}

.form-input:focus, .form-select:focus, .form-textarea:focus {
  outline: none;
  border-color: #3b82f6;
  box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
}

.checkbox-label {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  cursor: pointer;
}

.checkbox {
  width: 1rem;
  height: 1rem;
}

.section-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 1rem;
}

.section-title {
  font-size: 1rem;
  font-weight: 600;
  color: #1f2937;
}

.add-btn {
  display: flex;
  align-items: center;
  gap: 0.25rem;
  padding: 0.25rem 0.5rem;
  background-color: #e5e7eb;
  color: #374151;
  border-radius: 0.25rem;
  font-size: 0.75rem;
  transition: background-color 0.2s;
}

.add-btn:hover {
  background-color: #d1d5db;
}

.participants-list {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.participant-item {
  display: flex;
  align-items: center;
  gap: 1rem;
  padding: 0.75rem;
  background-color: #f9fafb;
  border-radius: 0.5rem;
}

.participant-info {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  flex: 1;
}

.participant-name {
  font-weight: 500;
}

.participant-config {
  flex: 1;
}

.config-item {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.config-input {
  width: 80px;
  padding: 0.25rem 0.5rem;
  border: 1px solid #d1d5db;
  border-radius: 0.25rem;
  font-size: 0.875rem;
}

.config-unit {
  font-size: 0.75rem;
  color: #6b7280;
}

.remove-btn {
  color: #dc2626;
  padding: 0.25rem;
  border-radius: 0.25rem;
  transition: background-color 0.2s;
}

.remove-btn:hover {
  background-color: #fef2f2;
}

.preview-amount {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.875rem;
}

.amount-input {
  width: 100px;
  padding: 0.25rem 0.5rem;
  border: 1px solid #d1d5db;
  border-radius: 0.25rem;
}

.preview-results {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.preview-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0.5rem;
  background-color: #f3f4f6;
  border-radius: 0.375rem;
}

.preview-name {
  font-weight: 500;
}

.preview-amount {
  font-weight: 600;
  color: #059669;
}

.preview-percentage {
  font-size: 0.75rem;
  color: #6b7280;
}

.modal-actions {
  padding: 1rem 1.5rem;
  border-top: 1px solid #e5e7eb;
  display: flex;
  justify-content: flex-end;
  gap: 0.75rem;
}

.btn-cancel {
  padding: 0.5rem 1rem;
  border: 1px solid #d1d5db;
  background-color: white;
  color: #374151;
  border-radius: 0.375rem;
  font-size: 0.875rem;
  transition: all 0.2s;
}

.btn-cancel:hover {
  background-color: #f9fafb;
}

.btn-save {
  padding: 0.5rem 1rem;
  background-color: #3b82f6;
  color: white;
  border-radius: 0.375rem;
  font-size: 0.875rem;
  transition: background-color 0.2s;
}

.btn-save:hover {
  background-color: #2563eb;
}
</style>
