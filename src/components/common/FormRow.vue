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
    class="flex justify-between mb-3 gap-4 max-md:gap-2"
    :class="fullWidth ? 'flex-col items-start' : 'items-center max-md:items-center'"
  >
    <label
      class="text-sm font-medium text-[light-dark(#0f172a,white)] mb-0 flex-none w-24 min-w-[6rem] whitespace-nowrap text-left max-md:w-16 max-md:min-w-[4rem] max-md:text-[0.8rem]"
      :class="fullWidth && 'w-full mb-2'"
      :style="labelStyle"
    >
      {{ label }}
      <span v-if="required" class="text-[var(--color-error)] ml-1">*</span>
      <span v-if="optional" class="text-[light-dark(#6b7280,#94a3b8)] font-normal text-xs ml-1">(可选)</span>
    </label>

    <div
      class="flex-1 w-2/3 block max-md:flex-1 max-md:w-auto"
      :class="fullWidth && 'w-full'"
    >
      <slot />

      <span v-if="error" class="block text-sm text-[var(--color-error)] text-right mt-1" role="alert">
        {{ error }}
      </span>

      <span v-if="helpText && !error" class="block text-xs text-[light-dark(#6b7280,#94a3b8)] mt-1">
        {{ helpText }}
      </span>
    </div>
  </div>
</template>
