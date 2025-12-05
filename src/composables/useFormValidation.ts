import { z } from 'zod';
import { Lg } from '@/utils/debugLog';

// ==================== Constants ====================
const COMPOSABLE_MODULE = 'useFormValidation';

/**
 * 表单验证配置选项
 */
export interface FormValidationOptions<T> {
  /** 初始值 */
  initialValues?: Partial<T>;
  /** 验证模式：onChange 实时验证，onBlur 失焦验证，onSubmit 提交时验证 */
  mode?: 'onChange' | 'onBlur' | 'onSubmit';
  /** 是否在首次提交后启用实时验证 */
  revalidateOnChange?: boolean;
}

/**
 * 表单验证 Composable
 * 提供基于 Zod Schema 的表单验证功能
 *
 * @example
 * ```typescript
 * const { values, errors, validate, handleSubmit, reset } = useFormValidation(
 *   TodoCreateSchema,
 *   {
 *     initialValues: { title: '', priority: 'Medium' },
 *     mode: 'onBlur',
 *   }
 * );
 *
 * // 在模板中使用
 * <input v-model="values.title" @blur="() => validateField('title', values.title)" />
 * <span v-if="shouldShowError('title')">{{ getError('title') }}</span>
 *
 * // 提交表单
 * const onSubmit = handleSubmit(async (data) => {
 *   await createTodo(data);
 * });
 * ```
 */
export function useFormValidation<T extends Record<string, unknown>>(
  schema: z.ZodSchema<T>,
  options: FormValidationOptions<T> = {},
) {
  const { initialValues = {} as Partial<T>, mode = 'onBlur', revalidateOnChange = true } = options;

  // 表单值
  const values = ref<Partial<T>>({ ...initialValues }) as Ref<Partial<T>>;
  const errors = ref<Partial<Record<keyof T, string>>>({});
  const touched = ref<Partial<Record<keyof T, boolean>>>({});
  const isValidating = ref(false);
  const isSubmitting = ref(false);
  const isSubmitted = ref(false);
  const submitCount = ref(0);

  /**
   * 验证单个字段
   */
  function validateField(field: keyof T, value: any): boolean {
    try {
      // 尝试解析整个 schema 的该字段
      const fieldSchema = (schema as any).shape?.[field];
      if (fieldSchema) {
        fieldSchema.parse(value);
        errors.value[field] = undefined;
        return true;
      }
      return false;
    } catch (error) {
      if (error instanceof z.ZodError) {
        errors.value[field] = error.issues[0]?.message || 'Validation error';
      }
      return false;
    }
  }

  /**
   * 验证所有字段
   */
  function validateAll(data: T): boolean {
    isValidating.value = true;
    try {
      schema.parse(data);
      errors.value = {};
      return true;
    } catch (error) {
      if (error instanceof z.ZodError) {
        const newErrors: Partial<Record<keyof T, string>> = {};
        error.issues.forEach((err: z.ZodIssue) => {
          const field = err.path[0] as keyof T;
          if (field) {
            newErrors[field] = err.message;
          }
        });
        errors.value = newErrors;
      }
      return false;
    } finally {
      isValidating.value = false;
    }
  }

  /**
   * 标记字段为已触摸
   */
  function touchField(field: keyof T) {
    touched.value[field] = true;
  }

  /**
   * 标记所有字段为已触摸
   */
  function touchAll(data: T) {
    const keys = Object.keys(data) as Array<keyof T>;
    keys.forEach(key => {
      touched.value[key] = true;
    });
  }

  /**
   * 重置验证状态
   */
  function reset() {
    errors.value = {};
    touched.value = {};
  }

  /**
   * 重置单个字段
   */
  function resetField(field: keyof T) {
    errors.value[field] = undefined;
    touched.value[field] = false;
  }

  /**
   * 检查字段是否有错误
   */
  function hasError(field: keyof T): boolean {
    return !!errors.value[field];
  }

  /**
   * 检查字段是否已触摸
   */
  function isTouched(field: keyof T): boolean {
    return !!touched.value[field];
  }

  /**
   * 检查字段是否应该显示错误
   */
  function shouldShowError(field: keyof T): boolean {
    return isTouched(field) && hasError(field);
  }

  /**
   * 获取字段错误信息
   */
  function getError(field: keyof T): string | undefined {
    return errors.value[field];
  }

  /**
   * 检查表单是否有任何错误
   */
  const hasAnyError = computed(() => {
    return Object.keys(errors.value).length > 0;
  });

  /**
   * 检查表单是否全部字段都已触摸
   */
  const isAllTouched = computed(() => {
    return Object.keys(touched.value).length > 0;
  });

  /**
   * 检查表单是否有效（无错误）
   */
  const isValid = computed(() => !hasAnyError.value);

  /**
   * 检查表单是否脏（值已更改）
   */
  const isDirty = computed(() => {
    const currentKeys = Object.keys(values.value) as Array<keyof T>;
    return currentKeys.some(key => values.value[key] !== initialValues[key]);
  });

  // ==================== 值管理 ====================

  /**
   * 设置单个字段值
   */
  function setFieldValue(field: keyof T, value: T[keyof T]) {
    values.value[field] = value;

    // 根据模式决定是否验证
    if (mode === 'onChange' || (isSubmitted.value && revalidateOnChange)) {
      validateField(field, value);
    }
  }

  /**
   * 设置多个字段值
   */
  function setValues(newValues: Partial<T>) {
    values.value = { ...values.value, ...newValues };

    // 根据模式决定是否验证
    if (mode === 'onChange' || (isSubmitted.value && revalidateOnChange)) {
      validateAll(values.value as T);
    }
  }

  // ==================== 提交处理 ====================

  /**
   * 创建提交处理函数
   * @param onValid - 验证通过时的回调
   * @param onInvalid - 验证失败时的回调（可选）
   */
  function handleSubmit(
    onValid: (data: T) => Promise<void> | void,
    onInvalid?: (errors: Partial<Record<keyof T, string>>) => void,
  ) {
    return async (event?: Event) => {
      event?.preventDefault();

      Lg.d(COMPOSABLE_MODULE, '提交表单', { submitCount: submitCount.value + 1 });

      isSubmitting.value = true;
      isSubmitted.value = true;
      submitCount.value++;

      // 标记所有字段为已触摸
      touchAll(values.value as T);

      // 验证所有字段
      const isFormValid = validateAll(values.value as T);

      if (isFormValid) {
        try {
          await onValid(values.value as T);
          Lg.i(COMPOSABLE_MODULE, '表单提交成功');
        } catch (err) {
          Lg.e(COMPOSABLE_MODULE, '表单提交失败', { error: err });
          throw err;
        }
      } else {
        Lg.w(COMPOSABLE_MODULE, '表单验证失败', { errors: errors.value });
        onInvalid?.(errors.value);
      }

      isSubmitting.value = false;
    };
  }

  /**
   * 重置表单到初始状态
   */
  function resetForm(newInitialValues?: Partial<T>) {
    Lg.d(COMPOSABLE_MODULE, '重置表单');
    values.value = { ...(newInitialValues ?? initialValues) };
    errors.value = {};
    touched.value = {};
    isSubmitted.value = false;
    submitCount.value = 0;
  }

  return {
    // 状态
    values,
    errors: readonly(errors),
    touched: readonly(touched),
    isValidating: readonly(isValidating),
    isSubmitting: readonly(isSubmitting),
    isSubmitted: readonly(isSubmitted),
    submitCount: readonly(submitCount),

    // 计算属性
    hasAnyError,
    isAllTouched,
    isValid,
    isDirty,

    // 字段验证方法
    validateField,
    validateAll,
    touchField,
    touchAll,
    reset,
    resetField,
    hasError,
    isTouched,
    shouldShowError,
    getError,

    // 值管理方法
    setFieldValue,
    setValues,

    // 提交处理
    handleSubmit,
    resetForm,
  };
}

/**
 * 表单字段验证辅助函数
 * 用于在 @blur 事件中验证字段
 */
export function createFieldValidator<T extends Record<string, any>>(
  validation: ReturnType<typeof useFormValidation<T>>,
) {
  return (field: keyof T, value: any) => {
    validation.touchField(field);
    validation.validateField(field, value);
  };
}
