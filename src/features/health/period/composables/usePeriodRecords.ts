import { HealthsDb } from '@/services/healths/healths';
import { Lg } from '@/utils/debugLog';
import { toast } from '@/utils/toast';
import type { PeriodRecordCreate, PeriodRecordUpdate } from '@/schema/health/period';
import type { ComposerTranslation } from 'vue-i18n';

export function usePeriodRecords(
  showSuccessToast: (msg: string) => void,
  t: ComposerTranslation<import('vue-i18n').DefineLocaleMessage>,
) {
  const periodStore = usePeriodStore();

  async function create(record: PeriodRecordCreate) {
    await HealthsDb.createPeriodRecord(record);
    await periodStore.periodRecordAll();
    showSuccessToast(t('period.messages.periodRecordSaved'));
  }

  async function update(serialNum: string, record: PeriodRecordUpdate) {
    await HealthsDb.updatePeriodRecord(serialNum, record);
    await periodStore.periodRecordAll();
    showSuccessToast(t('period.messages.periodRecordSaved'));
  }

  async function remove(serialNum: string) {
    Lg.i('Deleting record:', serialNum);
    try {
      await HealthsDb.deletePeriodRecord(serialNum);
      await periodStore.periodRecordAll();
      showSuccessToast(t('period.messages.periodRecordDeleted'));
    } catch {
      toast.error('删除失败');
    }
  }

  return { create, update, remove };
}
