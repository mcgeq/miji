import { z } from 'zod';

/**
 * 表单验证 Composable
 * 提供基于 Zod Schema 的表单验证功能
 */
export function useFormValidation<T extends Record<string, any>>(
  schema: z.ZodSchema<T>,
) {
  const errors = ref<Partial<Record<keyof T, string>>>({});
  const touched = ref<Partial<Record<keyof T, boolean>>>({});
  const isValidating = ref(false);

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

  return {
    // 状态
    errors: readonly(errors),
    touched: readonly(touched),
    isValidating: readonly(isValidating),
    hasAnyError,
    isAllTouched,

    // 方法
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
