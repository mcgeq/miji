<script setup lang="ts">
/**
 * FormRow 组件
 * 用于 Modal 表单的标准行布局
 *
 * @example
 * <FormRow label="账户名称" required>
 *   <input v-model="form.name" class="modal-form-control" />
 * </FormRow>
 */

interface Props {
  /** 标签文本 */
  label: string;
  /** 是否必填 */
  required?: boolean;
  /** 是否可选（显示"可选"标记） */
  optional?: boolean;
  /** 错误消息 */
  error?: string;
  /** 帮助文本 */
  helpText?: string;
  /** 标签宽度（覆盖默认值） */
  labelWidth?: string;
  /** 是否全宽（标签和输入框各占一行） */
  fullWidth?: boolean;
}

const props = withDefaults(defineProps<Props>(), {
  required: false,
  optional: false,
  error: '',
  helpText: '',
  labelWidth: '',
  fullWidth: false,
});

const labelStyle = computed(() => {
  if (props.labelWidth) {
    return {
      width: props.labelWidth,
      minWidth: props.labelWidth,
    };
  }
  return {};
});
</script>

<template>
  <div
    class="form-row"
    :class="{ 'form-row-full-width': fullWidth }"
  >
    <label
      class="form-label"
      :style="labelStyle"
    >
      {{ label }}
      <span v-if="required" class="required-mark">*</span>
      <span v-if="optional" class="optional-mark">(可选)</span>
    </label>

    <div class="form-control-wrapper">
      <slot />

      <span v-if="error" class="form-error" role="alert">
        {{ error }}
      </span>

      <span v-if="helpText && !error" class="form-help">
        {{ helpText }}
      </span>
    </div>
  </div>
</template>

<style scoped>
.form-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 0.75rem;
  gap: 1rem;
}

.form-row-full-width {
  flex-direction: column;
  align-items: flex-start;
}

.form-label {
  font-size: 0.875rem;
  font-weight: 500;
  color: var(--color-base-content);
  margin-bottom: 0;
  flex: 0 0 auto;
  width: 6rem;
  min-width: 6rem;
  white-space: nowrap;
  text-align: left;
}

.form-row-full-width .form-label {
  width: 100%;
  margin-bottom: 0.5rem;
}

.required-mark {
  color: var(--color-error);
  margin-left: 0.25rem;
}

.optional-mark {
  color: var(--color-neutral);
  font-weight: normal;
  font-size: 0.75rem;
  margin-left: 0.25rem;
}

.form-control-wrapper {
  flex: 1;
  width: 66%;
  display: block;
}

.form-row-full-width .form-control-wrapper {
  width: 100%;
}

.form-error {
  display: block;
  font-size: 0.875rem;
  color: var(--color-error);
  text-align: right;
  margin-top: 0.25rem;
}

.form-help {
  display: block;
  font-size: 0.75rem;
  color: var(--color-neutral);
  margin-top: 0.25rem;
}

@media (max-width: 768px) {
  .form-row {
    flex-direction: row;
    align-items: center;
    gap: 0.5rem;
  }

  .form-label {
    width: 4rem;
    min-width: 4rem;
    font-size: 0.8rem;
  }

  .form-control-wrapper {
    flex: 1;
    width: auto;
  }
}
</style>
