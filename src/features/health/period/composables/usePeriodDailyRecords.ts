import { HealthsDb } from '@/services/healths/healths';
import { Lg } from '@/utils/debugLog';
import { toast } from '@/utils/toast';
import type { PeriodDailyRecordCreate, PeriodDailyRecordUpdate } from '@/schema/health/period';
import type { ComposerTranslation } from 'vue-i18n';

export function usePeriodDailyRecords(
  t: ComposerTranslation<import('vue-i18n').DefineLocaleMessage>,
) {
  const periodStore = usePeriodStore();

  // 通用处理函数
  async function handlePeriodAction<T>(
    action: () => Promise<T>,
    successMessageKey: string,
    errorMessageKey: string,
  ): Promise<T | undefined> {
    try {
      const result = await action();
      // 同时刷新经期记录和日常记录，因为它们可能相互影响
      await Promise.all([
        periodStore.periodRecordAll(),
        periodStore.periodDailyRecorAll(),
      ]);
      toast.success(t(successMessageKey));
      return result;
    } catch {
      toast.error(t(errorMessageKey) || '操作失败');
      return undefined;
    }
  }

  function create(record: PeriodDailyRecordCreate) {
    return handlePeriodAction(
      () => HealthsDb.createPeriodDailyRecord(record),
      'period.messages.periodDailyRecordSaved',
      'period.messages.periodDailyRecordSaveFailed',
    );
  }

  function update(serialNum: string, record: PeriodDailyRecordUpdate) {
    return handlePeriodAction(
      () => HealthsDb.updatePeriodDailyRecord(serialNum, record),
      'period.messages.periodDailyRecordUpdated',
      'period.messages.periodDailyRecordUpdatedFailed',
    );
  }

  function remove(serialNum: string) {
    Lg.i('Deleting record:', serialNum);
    return handlePeriodAction(
      async () => {
        await periodStore.periodDailyRecordDelete(serialNum);
        await nextTick();
      },
      'period.messages.periodDailyRecordDeleted',
      'period.messages.recordDailyRecordDeletedFailed',
    );
  }

  return { create, update, remove };
}
