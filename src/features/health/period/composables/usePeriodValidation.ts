import {PeriodDailyRecords, PeriodRecords} from '@/schema/health/period';

export function usePeriodValidation() {
  const validationErrors = ref<Record<string, string[]>>({});

  const validateDailyRecord = (
    record: Partial<PeriodDailyRecords>,
  ): boolean => {
    validationErrors.value = {};

    try {
      // 基本验证
      if (!record.date) {
        addValidationError('date', '日期不能为空');
      } else {
        const date = new Date(record.date);
        const today = new Date();
        if (date > today) {
          addValidationError('date', '日期不能超过今天');
        }
      }

      if (!record.diet || record.diet.trim() === '') {
        addValidationError('diet', '饮食记录不能为空');
      }

      if (
        record.waterIntake &&
        (record.waterIntake < 0 || record.waterIntake > 5000)
      ) {
        addValidationError('waterIntake', '饮水量应在0-5000ml之间');
      }

      if (
        record.sleepHours &&
        (record.sleepHours < 0 || record.sleepHours > 24)
      ) {
        addValidationError('sleepHours', '睡眠时间应在0-24小时之间');
      }

      if (record.notes && record.notes.length > 500) {
        addValidationError('notes', '备注不能超过500个字符');
      }

      return Object.keys(validationErrors.value).length === 0;
    } catch (error) {
      addValidationError('general', '数据格式错误');
      return false;
    }
  };

  const validatePeriodRecord = (record: Partial<PeriodRecords>): boolean => {
    validationErrors.value = {};

    try {
      if (!record.startDate) {
        addValidationError('startDate', '开始日期不能为空');
      }

      if (!record.endDate) {
        addValidationError('endDate', '结束日期不能为空');
      }

      if (record.startDate && record.endDate) {
        const startDate = new Date(record.startDate);
        const endDate = new Date(record.endDate);

        if (startDate > endDate) {
          addValidationError('endDate', '结束日期不能早于开始日期');
        }

        const diffDays = Math.ceil(
          (endDate.getTime() - startDate.getTime()) / (1000 * 60 * 60 * 24),
        );
        if (diffDays > 14) {
          addValidationError('endDate', '经期长度不能超过14天');
        }
      }

      return Object.keys(validationErrors.value).length === 0;
    } catch (error) {
      addValidationError('general', '数据格式错误');
      return false;
    }
  };

  const addValidationError = (field: string, message: string) => {
    if (!validationErrors.value[field]) {
      validationErrors.value[field] = [];
    }
    validationErrors.value[field].push(message);
  };

  const clearValidationErrors = () => {
    validationErrors.value = {};
  };

  const getFieldErrors = (field: string): string[] => {
    return validationErrors.value[field] || [];
  };

  const hasErrors = (): boolean => {
    return Object.keys(validationErrors.value).length > 0;
  };

  return {
    validationErrors,
    validateDailyRecord,
    validatePeriodRecord,
    clearValidationErrors,
    getFieldErrors,
    hasErrors,
  };
}
