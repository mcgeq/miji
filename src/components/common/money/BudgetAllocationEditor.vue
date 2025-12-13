<script setup lang="ts">
  import CategorySelector from '@/components/common/CategorySelector.vue';
  import { Modal } from '@/components/ui';
  import FormRow from '@/components/ui/FormRow.vue';
  import FormInput from '@/components/ui/Input.vue';
  import Select from '@/components/ui/Select.vue';
  import Textarea from '@/components/ui/Textarea.vue';
  import type { SelectOption } from '@/components/ui/types';
  import type {
    BudgetAllocationCreateRequest,
    BudgetAllocationResponse,
  } from '@/types/budget-allocation';
  import { OverspendLimitType } from '@/types/budget-allocation';

  interface FormData {
    allocationType: 'member' | 'member-category';
    memberSerialNum?: string;
    selectedCategories: string[]; // 分类名称数组
    amountType: 'fixed' | 'percentage';
    allocatedAmount?: number;
    percentage?: number;
    allowOverspend: boolean;
    overspendLimitType: OverspendLimitType;
    overspendLimitValue?: number;
    alertEnabled: boolean;
    alertThreshold: number;
    priority: number;
    isMandatory: boolean;
    notes?: string;
  }

  interface Props {
    /** 是否为编辑模式 */
    isEdit?: boolean;
    /** 编辑的分配数据 */
    allocation?: BudgetAllocationResponse;
    /** 可用成员列表 */
    members?: Array<{ serialNum: string; name: string }>;
    /** 可用分类列表 */
    categories?: Array<{ serialNum: string; name: string }>;
    /** 预算总额（用于百分比计算） */
    budgetTotal?: number;
    /** 是否加载中 */
    loading?: boolean;
  }

  interface Emits {
    (e: 'submit', data: BudgetAllocationCreateRequest): void;
    (e: 'cancel'): void;
  }

  const props = withDefaults(defineProps<Props>(), {
    isEdit: false,
    allocation: undefined,
    members: () => [],
    categories: () => [],
    budgetTotal: 0,
    loading: false,
  });

  const emit = defineEmits<Emits>();

  /**
   * 成员选项
   */
  const memberOptions = computed<SelectOption[]>(() => [
    { value: '', label: '请选择成员' },
    ...props.members.map(m => ({
      value: m.serialNum,
      label: m.name,
    })),
  ]);

  /**
   * 表单数据
   */
  const formData = ref<FormData>({
    allocationType: 'member',
    selectedCategories: [],
    amountType: 'fixed',
    allowOverspend: false,
    overspendLimitType: OverspendLimitType.NONE,
    alertEnabled: true,
    alertThreshold: 80,
    priority: 3,
    isMandatory: false,
  });

  /**
   * 表单验证
   */
  const isValid = computed(() => {
    // 必须选择成员
    if (!formData.value.memberSerialNum) {
      return false;
    }

    // 如果是成员+分类，必须选择分类
    if (
      formData.value.allocationType === 'member-category' &&
      formData.value.selectedCategories.length === 0
    ) {
      return false;
    }

    // 必须输入金额或百分比
    if (formData.value.amountType === 'fixed') {
      if (!formData.value.allocatedAmount || formData.value.allocatedAmount <= 0) {
        return false;
      }
    } else {
      if (
        !formData.value.percentage ||
        formData.value.percentage <= 0 ||
        formData.value.percentage > 100
      ) {
        return false;
      }
    }

    return true;
  });

  /**
   * 提交表单
   */
  function handleSubmit() {
    if (!isValid.value) return;

    // 将分类名称转换为 serialNum（从 categories 中查找）
    let categorySerialNum: string | undefined;
    if (
      formData.value.allocationType === 'member-category' &&
      formData.value.selectedCategories.length > 0
    ) {
      const categoryName = formData.value.selectedCategories[0];
      const category = props.categories?.find(c => c.name === categoryName);
      categorySerialNum = category?.serialNum;
    }

    const data: BudgetAllocationCreateRequest = {
      memberSerialNum: formData.value.memberSerialNum,
      categorySerialNum,
      allocatedAmount:
        formData.value.amountType === 'fixed' ? formData.value.allocatedAmount : undefined,
      percentage:
        formData.value.amountType === 'percentage' ? formData.value.percentage : undefined,
      allowOverspend: formData.value.allowOverspend,
      overspendLimitType: formData.value.overspendLimitType,
      overspendLimitValue: formData.value.overspendLimitValue,
      alertEnabled: formData.value.alertEnabled,
      alertThreshold: formData.value.alertThreshold,
      priority: formData.value.priority,
      isMandatory: formData.value.isMandatory,
      notes: formData.value.notes,
    };

    emit('submit', data);
  }

  /**
   * 取消
   */
  function handleCancel() {
    emit('cancel');
  }

  /**
   * 获取分类名称
   */
  function getCategoryNames(categorySerialNum: string | undefined): string[] {
    if (!categorySerialNum) return [];
    const category = props.categories?.find(c => c.serialNum === categorySerialNum);
    return category ? [category.name] : [];
  }

  /**
   * 初始化表单数据
   */
  watch(
    () => props.allocation,
    newValue => {
      if (!newValue) return;

      formData.value = {
        allocationType: newValue.categorySerialNum ? 'member-category' : 'member',
        memberSerialNum: newValue.memberSerialNum,
        selectedCategories: getCategoryNames(newValue.categorySerialNum),
        amountType: newValue.allocatedAmount ? 'fixed' : 'percentage',
        allocatedAmount: newValue.allocatedAmount,
        percentage: newValue.percentage,
        allowOverspend: Boolean(newValue.allowOverspend),
        overspendLimitType: newValue.overspendLimitType || OverspendLimitType.NONE,
        overspendLimitValue: newValue.overspendLimitValue,
        alertEnabled: newValue.alertEnabled ?? true,
        alertThreshold: newValue.alertThreshold || 80,
        priority: newValue.priority || 3,
        isMandatory: Boolean(newValue.isMandatory),
        notes: newValue.notes,
      };
    },
    { immediate: true },
  );
</script>

<template>
  <Modal
    :open="true"
    :model-value="true"
    :title="isEdit ? '编辑分配' : '添加分配'"
    size="md"
    :confirm-loading="loading"
    :confirm-disabled="!isValid"
    @close="handleCancel"
    @confirm="handleSubmit"
  >
    <form class="flex flex-col gap-4" @submit.prevent="handleSubmit">
      <!-- 分配目标 -->
      <div class="p-4 border border-gray-200 dark:border-gray-700 rounded-lg">
        <h3 class="text-sm font-semibold text-gray-900 dark:text-white mb-3">分配目标</h3>

        <!-- 分配类型 -->
        <FormRow label="分配类型" required>
          <div class="flex gap-4 flex-wrap">
            <label class="flex items-center gap-2 cursor-pointer text-sm">
              <input
                v-model="formData.allocationType"
                type="radio"
                value="member"
                class="cursor-pointer"
              />
              <span>成员</span>
            </label>
            <label class="flex items-center gap-2 cursor-pointer text-sm">
              <input
                v-model="formData.allocationType"
                type="radio"
                value="member-category"
                class="cursor-pointer"
              />
              <span>成员+分类</span>
            </label>
          </div>
        </FormRow>

        <!-- 成员选择 -->
        <FormRow label="选择成员" required>
          <Select
            :model-value="formData.memberSerialNum || ''"
            :options="memberOptions"
            placeholder="请选择成员"
            size="sm"
            required
            full-width
            @update:model-value="(val) => formData.memberSerialNum = val as string"
          />
        </FormRow>

        <!-- 分类选择（仅成员+分类时显示） -->
        <div v-if="formData.allocationType === 'member-category'">
          <CategorySelector
            v-model="formData.selectedCategories"
            label="选择分类"
            :required="true"
            :multiple="false"
            :show-quick-select="true"
            help-text="选择此成员在此预算中可使用的具体分类"
          />
        </div>
      </div>

      <!-- 金额设置 -->
      <div class="p-4 border border-gray-200 dark:border-gray-700 rounded-lg">
        <h3 class="text-sm font-semibold text-gray-900 dark:text-white mb-3">金额设置</h3>

        <!-- 金额类型 -->
        <FormRow label="分配方式" required>
          <div class="flex gap-4 flex-wrap">
            <label class="flex items-center gap-2 cursor-pointer text-sm">
              <input
                v-model="formData.amountType"
                type="radio"
                value="fixed"
                class="cursor-pointer"
              />
              <span>固定金额</span>
            </label>
            <label class="flex items-center gap-2 cursor-pointer text-sm">
              <input
                v-model="formData.amountType"
                type="radio"
                value="percentage"
                class="cursor-pointer"
              />
              <span>百分比</span>
            </label>
          </div>
        </FormRow>

        <!-- 固定金额 -->
        <FormRow v-if="formData.amountType === 'fixed'" label="分配金额" required>
          <FormInput
            v-model="formData.allocatedAmount"
            type="number"
            placeholder="0.00"
            size="md"
            :required="true"
            full-width
          >
            <template #prefix>¥</template>
          </FormInput>
        </FormRow>

        <!-- 百分比 -->
        <FormRow v-else label="百分比" required>
          <FormInput
            v-model="formData.percentage"
            type="number"
            placeholder="0"
            size="md"
            :required="true"
            full-width
          >
            <template #suffix>%</template>
          </FormInput>
        </FormRow>
      </div>

      <!-- 备注 -->
      <Textarea
        v-model="formData.notes"
        :rows="3"
        :max-length="200"
        placeholder="可选的备注信息..."
        show-count
        full-width
      />
    </form>
  </Modal>
</template>
