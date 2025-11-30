import { HealthsDb } from '@/services/healths/healths';
import { Lg } from '@/utils/debugLog';
import { toast } from '@/utils/toast';
import type { PeriodRecordCreate, PeriodRecordUpdate } from '@/schema/health/period';
import type { ComposerTranslation } from 'vue-i18n';

export function usePeriodRecords(t: ComposerTranslation<import('vue-i18n').DefineLocaleMessage>) {
  const periodStore = usePeriodStore();

  // 泛型支持返回任意类型
  async function handlePeriodAction<T>(
    action: () => Promise<T>,
    successMessageKey: string,
    errorMessageKey: string,
  ): Promise<T | undefined> {
    try {
      const result = await action();
      // 同时刷新经期记录和日常记录，因为它们可能相互影响
      await Promise.all([periodStore.periodRecordAll(), periodStore.periodDailyRecorAll()]);
      toast.success(t(successMessageKey));
      return result;
    } catch {
      toast.error(t(errorMessageKey) || '操作失败');
      return undefined;
    }
  }

  function create(record: PeriodRecordCreate) {
    return handlePeriodAction(
      () => HealthsDb.createPeriodRecord(record),
      'period.messages.periodRecordSaved',
      'period.messages.periodRecordSaveFailed',
    );
  }

  function update(serialNum: string, record: PeriodRecordUpdate) {
    return handlePeriodAction(
      () => HealthsDb.updatePeriodRecord(serialNum, record),
      'period.messages.periodRecordUpdated',
      'period.messages.periodRecordUpdatedFailed',
    );
  }

  function remove(serialNum: string) {
    Lg.i('Deleting record:', serialNum);
    return handlePeriodAction(
      () => HealthsDb.deletePeriodRecord(serialNum),
      'period.messages.periodRecordDeleted',
      'period.messages.periodRecordDeleteFailed',
    );
  }

  return { create, update, remove };
}
