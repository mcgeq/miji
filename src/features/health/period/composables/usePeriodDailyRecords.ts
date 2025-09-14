import { HealthsDb } from '@/services/healths/healths';
import { Lg } from '@/utils/debugLog';
import type { PeriodDailyRecordCreate, PeriodDailyRecordUpdate } from '@/schema/health/period';
import type { ComposerTranslation } from 'vue-i18n';

export function usePeriodDailyRecords(
  showSuccessToast: (msg: string) => void,
  t: ComposerTranslation<import('vue-i18n').DefineLocaleMessage>,
) {
  const periodStore = usePeriodStore();

  async function create(record: PeriodDailyRecordCreate) {
    await HealthsDb.createPeriodDailyRecord(record);
    await periodStore.refreshDailyRecords();
    showSuccessToast(t('period.messages.periodRecordSaved'));
  }

  async function update(serialNum: string, record: PeriodDailyRecordUpdate) {
    await HealthsDb.updatePeriodDailyRecord(serialNum, record);
    await periodStore.refreshDailyRecords();
    showSuccessToast(t('period.messages.periodRecordSaved'));
  }

  async function remove(serialNum: string) {
    Lg.i('Deleting record:', serialNum);
    await periodStore.periodDailyRecordDelete(serialNum);
    await nextTick();
    await periodStore.refreshDailyRecords();
    showSuccessToast(t('period.messages.recordDeleted'));
  }

  return { create, update, remove };
}
