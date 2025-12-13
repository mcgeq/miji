import { defineStore } from 'pinia';
import { computed, ref } from 'vue';
import type { AppError } from '@/errors/appError';
import type { PageQuery } from '@/schema/common';
import { SortDirection } from '@/schema/common';
import type {
  PeriodCalendarEvent,
  PeriodDailyRecordCreate,
  PeriodDailyRecords,
  PeriodDailyRecordUpdate,
  PeriodPhase,
  PeriodPmsRecords,
  PeriodPmsSymptoms,
  PeriodRecordCreate,
  PeriodRecords,
  PeriodRecordUpdate,
  PeriodSettings,
  PeriodStats,
  PeriodSymptoms,
} from '@/schema/health/period';
import type { PeriodDailyRecordFilter } from '@/services/healths/period_daily_record';
import type { PeriodRecordFilter } from '@/services/healths/period_record';
import { periodService } from '@/services/healths/periodService';
import { DateUtils } from '@/utils/date';
import { Lg } from '@/utils/debugLog';
import { wrapError } from '@/utils/errorHandler';
import { withLoadingSafe } from './utils/withLoadingSafe';

/**
 * 经期 Store
 * 使用 Composition API 风格，遵循新的架构模式
 * 通过 PeriodService 访问数据，不直接访问数据库
 */
export const usePeriodStore = defineStore('period', () => {
  // ============ 状态 ============
  const periodRecords = ref<PeriodRecords[]>([]);
  const periodDailyRecords = ref<PeriodDailyRecords[]>([]);
  const symptoms = ref<PeriodSymptoms[]>([]);
  const pmsRecords = ref<PeriodPmsRecords[]>([]);
  const pmsSymptoms = ref<PeriodPmsSymptoms[]>([]);
  const settings = ref<PeriodSettings>({
    averageCycleLength: 30,
    averagePeriodLength: 7,
    notifications: {
      periodReminder: true,
      ovulationReminder: true,
      pmsReminder: true,
      reminderDays: 3,
    },
    privacy: {
      dataSync: true,
      analytics: false,
    },
    createdAt: DateUtils.getLocalISODateTimeWithOffset(),
    updatedAt: null,
  } as PeriodSettings);
  const lastFetch = ref<Date | null>(null);
  const isLoading = ref(false);
  const error = ref<AppError | null>(null);

  const CACHE_DURATION = 5 * 60 * 1000;

  // ============ 计算属性 ============
  const periodStats = computed((): PeriodStats => {
    if (periodRecords.value.length < 2) {
      return {
        averageCycleLength: settings.value.averageCycleLength,
        averagePeriodLength: settings.value.averagePeriodLength,
        nextPredictedDate: '',
        currentPhase: 'Follicular',
        daysUntilNext: 0,
      };
    }

    const sortedRecords = [...periodRecords.value].sort(
      (a, b) => new Date(a.startDate).getTime() - new Date(b.startDate).getTime(),
    );

    // Calculate cycle lengths
    const cycles = sortedRecords.slice(0, -1).map((record, index) => {
      const nextRecord = sortedRecords[index + 1];
      const start = new Date(record.startDate);
      const nextStart = new Date(nextRecord.startDate);
      return Math.abs(nextStart.getTime() - start.getTime()) / (1000 * 60 * 60 * 24);
    });

    const averageCycleLength =
      cycles.length > 0
        ? Math.round(cycles.reduce((sum, cycle) => sum + cycle, 0) / cycles.length)
        : settings.value.averageCycleLength;

    // Calculate period lengths
    const periodLengths = sortedRecords.map(record => {
      const start = new Date(record.startDate);
      const end = new Date(record.endDate);
      return Math.abs(end.getTime() - start.getTime()) / (1000 * 60 * 60 * 24) + 1;
    });

    const averagePeriodLength = Math.round(
      periodLengths.reduce((sum, length) => sum + length, 0) / periodLengths.length,
    );

    // Predict next period
    const lastPeriod = sortedRecords[sortedRecords.length - 1];
    const lastPeriodStart = new Date(lastPeriod.startDate);
    const nextPredictedDate = new Date(
      lastPeriodStart.getTime() + averageCycleLength * 24 * 60 * 60 * 1000,
    );

    const today = new Date();
    const daysUntilNext = Math.ceil(
      (nextPredictedDate.getTime() - today.getTime()) / (1000 * 60 * 60 * 24),
    );

    // Calculate current phase
    const daysSinceLastPeriod = Math.floor(
      (today.getTime() - lastPeriodStart.getTime()) / (1000 * 60 * 60 * 24),
    );

    let currentPhase: PeriodPhase = 'Follicular';
    if (daysSinceLastPeriod <= averagePeriodLength) {
      currentPhase = 'Menstrual';
    } else if (daysSinceLastPeriod <= averageCycleLength / 2) {
      currentPhase = 'Follicular';
    } else if (daysSinceLastPeriod <= averageCycleLength / 2 + 3) {
      currentPhase = 'Ovulation';
    } else {
      currentPhase = 'Luteal';
    }

    return {
      averageCycleLength,
      averagePeriodLength,
      nextPredictedDate: nextPredictedDate.toISOString().split('T')[0],
      currentPhase,
      daysUntilNext: Math.max(0, daysUntilNext),
    };
  });

  const calendarEvents = computed((): PeriodCalendarEvent[] => {
    const events: PeriodCalendarEvent[] = [];

    // Add period events
    periodRecords.value.forEach(record => {
      const start = new Date(record.startDate);
      const end = new Date(record.endDate);
      const daysDiff = Math.ceil((end.getTime() - start.getTime()) / (1000 * 60 * 60 * 24)) + 1;

      for (let i = 0; i < daysDiff; i++) {
        const currentDate = new Date(start);
        currentDate.setDate(start.getDate() + i);
        events.push({
          date: currentDate.toISOString().split('T')[0],
          type: 'period',
          intensity: 'Medium',
        });
      }
    });

    // Add ovulation events
    const stats = periodStats.value;
    if (stats.averageCycleLength > 0) {
      periodRecords.value.forEach(record => {
        const start = new Date(record.startDate);
        const ovulationDate = new Date(start);
        ovulationDate.setDate(ovulationDate.getDate() + Math.floor(stats.averageCycleLength / 2));

        for (let i = -1; i <= 1; i++) {
          const date = new Date(ovulationDate);
          date.setDate(date.getDate() + i);
          events.push({
            date: date.toISOString().split('T')[0],
            type: i === 0 ? 'ovulation' : 'fertile',
          });
        }
      });
    }

    return events;
  });

  const currentMonthRecords = computed(() => {
    const currentMonth = new Date().toISOString().slice(0, 7);
    return periodDailyRecords.value.filter(record => record.date.startsWith(currentMonth));
  });

  const symptomsStats = computed(() => {
    const stats: Record<string, number> = {};
    symptoms.value.forEach(symptom => {
      stats[symptom.symptomType] = (stats[symptom.symptomType] || 0) + 1;
    });
    return stats;
  });

  // ============ Helper Functions ============
  function isCacheValid(): boolean {
    if (!lastFetch.value) return false;
    return Date.now() - lastFetch.value.getTime() < CACHE_DURATION;
  }

  // ============ Actions ============

  /**
   * 更新本地经期记录列表
   */
  const updatePeriodRecords = withLoadingSafe(
    async () => {
      try {
        const query: PageQuery<PeriodRecordFilter> = {
          currentPage: 1,
          pageSize: 20,
          sortOptions: {
            desc: true,
            sortDir: SortDirection.Desc,
          },
          filter: {},
        };
        const result = await periodService.listPagedPeriodRecords(query);
        periodRecords.value = result.items;
      } catch (err) {
        error.value = wrapError('PeriodStore', err, 'UPDATE_RECORDS_FAILED', '更新经期记录失败');
        throw error.value;
      }
    },
    isLoading,
    error,
  );

  /**
   * 更新本地每日记录列表
   */
  const updatePeriodDailyRecords = withLoadingSafe(
    async () => {
      try {
        const query: PageQuery<PeriodDailyRecordFilter> = {
          currentPage: 1,
          pageSize: 20,
          sortOptions: {
            desc: true,
            sortDir: SortDirection.Desc,
          },
          filter: {},
        };
        const result = await periodService.listPagedDailyRecords(query);
        periodDailyRecords.value = result.items;
      } catch (err) {
        error.value = wrapError(
          'PeriodStore',
          err,
          'UPDATE_DAILY_RECORDS_FAILED',
          '更新每日记录失败',
        );
        throw error.value;
      }
    },
    isLoading,
    error,
  );

  // ==================== PeriodRecord Actions ====================

  /**
   * 获取所有经期记录
   */
  const periodRecordAll = withLoadingSafe(
    async () => {
      try {
        await updatePeriodRecords();
        lastFetch.value = null;
      } catch (err) {
        error.value = wrapError('PeriodStore', err, 'FETCH_RECORDS_FAILED', '获取经期记录失败');
        throw error.value;
      }
    },
    isLoading,
    error,
  );

  /**
   * 获取单个经期记录
   */
  const periodRecordGet = withLoadingSafe(
    async (serialNum: string) => {
      try {
        const result = await periodService.getPeriodRecord(serialNum);
        await updatePeriodRecords();
        lastFetch.value = null;
        return result;
      } catch (err) {
        error.value = wrapError(
          'PeriodStore',
          err,
          'GET_RECORD_FAILED',
          `获取经期记录失败: ${serialNum}`,
        );
        throw error.value;
      }
    },
    isLoading,
    error,
  );

  /**
   * 创建经期记录
   */
  const periodRecordCreate = withLoadingSafe(
    async (record: PeriodRecordCreate) => {
      try {
        const result = await periodService.createPeriodRecord(record);
        await updatePeriodRecords();
        lastFetch.value = null;
        return result;
      } catch (err) {
        error.value = wrapError('PeriodStore', err, 'CREATE_RECORD_FAILED', '创建经期记录失败');
        throw error.value;
      }
    },
    isLoading,
    error,
  );

  /**
   * 更新经期记录
   */
  const periodRecordUpdate = withLoadingSafe(
    async (serialNum: string, updates: PeriodRecordUpdate) => {
      try {
        const result = await periodService.updatePeriodRecord(serialNum, updates);
        await updatePeriodRecords();
        return result;
      } catch (err) {
        error.value = wrapError(
          'PeriodStore',
          err,
          'UPDATE_RECORD_FAILED',
          `更新经期记录失败: ${serialNum}`,
        );
        throw error.value;
      }
    },
    isLoading,
    error,
  );

  /**
   * 删除经期记录
   */
  const periodRecordDelete = withLoadingSafe(
    async (serialNum: string) => {
      try {
        await periodService.deletePeriodRecord(serialNum);
        await updatePeriodRecords();
      } catch (err) {
        error.value = wrapError(
          'PeriodStore',
          err,
          'DELETE_RECORD_FAILED',
          `删除经期记录失败: ${serialNum}`,
        );
        throw error.value;
      }
    },
    isLoading,
    error,
  );

  // ==================== PeriodDailyRecord Actions ====================

  /**
   * 获取所有每日记录
   */
  const periodDailyRecorAll = withLoadingSafe(
    async () => {
      try {
        await updatePeriodDailyRecords();
      } catch (err) {
        error.value = wrapError(
          'PeriodStore',
          err,
          'FETCH_DAILY_RECORDS_FAILED',
          '获取每日记录失败',
        );
        throw error.value;
      }
    },
    isLoading,
    error,
  );

  /**
   * 获取单个每日记录
   */
  const periodDailyRecordGet = withLoadingSafe(
    async (serialNum: string) => {
      try {
        const result = await periodService.getDailyRecord(serialNum);
        await updatePeriodDailyRecords();
        lastFetch.value = null;
        return result;
      } catch (err) {
        error.value = wrapError(
          'PeriodStore',
          err,
          'GET_DAILY_RECORD_FAILED',
          `获取每日记录失败: ${serialNum}`,
        );
        throw error.value;
      }
    },
    isLoading,
    error,
  );

  /**
   * 创建每日记录
   */
  const periodDailyRecordCreate = withLoadingSafe(
    async (record: PeriodDailyRecordCreate) => {
      try {
        const result = await periodService.createDailyRecord(record);
        await updatePeriodDailyRecords();
        lastFetch.value = null;
        return result;
      } catch (err) {
        error.value = wrapError(
          'PeriodStore',
          err,
          'CREATE_DAILY_RECORD_FAILED',
          '创建每日记录失败',
        );
        throw error.value;
      }
    },
    isLoading,
    error,
  );

  /**
   * 更新每日记录
   */
  const periodDailyRecordUpdate = withLoadingSafe(
    async (serialNum: string, updates: PeriodDailyRecordUpdate) => {
      try {
        const result = await periodService.updateDailyRecord(serialNum, updates);
        await updatePeriodDailyRecords();
        return result;
      } catch (err) {
        error.value = wrapError(
          'PeriodStore',
          err,
          'UPDATE_DAILY_RECORD_FAILED',
          `更新每日记录失败: ${serialNum}`,
        );
        throw error.value;
      }
    },
    isLoading,
    error,
  );

  /**
   * 删除每日记录
   */
  const periodDailyRecordDelete = withLoadingSafe(
    async (serialNum: string) => {
      try {
        await periodService.deleteDailyRecord(serialNum);
        Lg.i('Period', 'Daily record deleted:', serialNum);
      } catch (err) {
        error.value = wrapError(
          'PeriodStore',
          err,
          'DELETE_DAILY_RECORD_FAILED',
          `删除每日记录失败: ${serialNum}`,
        );
        throw error.value;
      }
    },
    isLoading,
    error,
  );

  // ==================== Settings Actions ====================

  /**
   * 获取经期设置
   */
  const periodSettingsGet = withLoadingSafe(
    async () => {
      try {
        let result: PeriodSettings | null = null;

        localStorage.removeItem('periodSettings');
        if (settings.value.serialNum) {
          result = await periodService.getSettings(settings.value.serialNum);
        }
        if (result === null) {
          const { serialNum, createdAt, updatedAt, ...periodSettingsCreate } = settings.value;
          result = await periodService.createSettings(periodSettingsCreate);
          settings.value = result;
        }
        localStorage.setItem('periodSettings', JSON.stringify(settings.value));
      } catch (err) {
        error.value = wrapError('PeriodStore', err, 'GET_SETTINGS_FAILED', '获取经期设置失败');
        throw error.value;
      }
    },
    isLoading,
    error,
  );

  /**
   * 更新设置
   */
  const updateSettings = withLoadingSafe(
    async (newSettings: Partial<PeriodSettings>) => {
      try {
        await new Promise(resolve => setTimeout(resolve, 300));
        settings.value = { ...settings.value, ...newSettings };
        localStorage.setItem('periodSettings', JSON.stringify(settings.value));
      } catch (err) {
        error.value = wrapError('PeriodStore', err, 'UPDATE_SETTINGS_FAILED', '更新设置失败');
        throw error.value;
      }
    },
    isLoading,
    error,
  );

  // ==================== Utility Actions ====================

  /**
   * 重置所有数据
   */
  const resetAllData = withLoadingSafe(
    async () => {
      try {
        await new Promise(resolve => setTimeout(resolve, 500));
        periodRecords.value = [];
        periodDailyRecords.value = [];
        symptoms.value = [];
        pmsRecords.value = [];
        pmsSymptoms.value = [];
        lastFetch.value = null;
      } catch (err) {
        error.value = wrapError('PeriodStore', err, 'RESET_DATA_FAILED', '重置数据失败');
        throw error.value;
      }
    },
    isLoading,
    error,
  );

  /**
   * 刷新每日记录
   */
  const refreshDailyRecords = withLoadingSafe(
    async () => {
      try {
        await new Promise(resolve => setTimeout(resolve, 300));
        periodDailyRecords.value = [...periodDailyRecords.value];
      } catch (err) {
        error.value = wrapError('PeriodStore', err, 'REFRESH_RECORDS_FAILED', '刷新记录失败');
        throw error.value;
      }
    },
    isLoading,
    error,
  );

  /**
   * 导出数据
   */
  function exportData() {
    const data = {
      periodRecords: periodRecords.value,
      dailyRecords: periodDailyRecords.value,
      symptoms: symptoms.value,
      pmsRecords: pmsRecords.value,
      pmsSymptoms: pmsSymptoms.value,
      settings: settings.value,
      exportDate: new Date().toISOString(),
    };

    const blob = new Blob([JSON.stringify(data, null, 2)], {
      type: 'application/json',
    });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `period-data-${new Date().toISOString().split('T')[0]}.json`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  }

  /**
   * 获取日历事件（同步计算，基于已加载的数据）
   */
  function getCalendarEvents(startDate: string, endDate: string): PeriodCalendarEvent[] {
    const events: PeriodCalendarEvent[] = [];

    // 添加历史经期事件
    periodRecords.value.forEach(period => {
      const start = new Date(period.startDate);
      const end = new Date(period.endDate);
      const daysDiff = Math.ceil((end.getTime() - start.getTime()) / (1000 * 60 * 60 * 24)) + 1;

      for (let i = 0; i < daysDiff; i++) {
        const currentDate = new Date(start);
        currentDate.setDate(start.getDate() + i);
        const dateStr = currentDate.toISOString().split('T')[0];

        if (dateStr >= startDate && dateStr <= endDate) {
          events.push({
            date: dateStr,
            type: 'period',
            intensity: 'Medium',
            isPredicted: false,
          });
        }
      }
    });

    // 添加历史排卵事件
    periodRecords.value.forEach(period => {
      const ovulationDate = new Date(period.startDate);
      ovulationDate.setDate(
        ovulationDate.getDate() + Math.floor(settings.value.averageCycleLength / 2),
      );
      const dateStr = ovulationDate.toISOString().split('T')[0];

      if (dateStr >= startDate && dateStr <= endDate) {
        events.push({
          date: dateStr,
          type: 'ovulation',
          isPredicted: false,
        });

        // 添加易孕期
        for (let i = -1; i <= 1; i++) {
          if (i === 0) continue;
          const fertileDate = new Date(ovulationDate);
          fertileDate.setDate(fertileDate.getDate() + i);
          const fertileDateStr = fertileDate.toISOString().split('T')[0];

          if (fertileDateStr >= startDate && fertileDateStr <= endDate) {
            events.push({
              date: fertileDateStr,
              type: 'fertile',
              isPredicted: false,
            });
          }
        }
      }
    });

    // 添加预测的未来事件
    const stats = periodStats.value;
    if (stats.nextPredictedDate && periodRecords.value.length > 0) {
      const predictedStart = new Date(stats.nextPredictedDate);
      const today = new Date();

      if (predictedStart >= today) {
        const predictedPeriodLength = stats.averagePeriodLength;

        // 预测经期
        for (let i = 0; i < predictedPeriodLength; i++) {
          const predictedDate = new Date(predictedStart);
          predictedDate.setDate(predictedDate.getDate() + i);
          const dateStr = predictedDate.toISOString().split('T')[0];

          if (dateStr >= startDate && dateStr <= endDate) {
            events.push({
              date: dateStr,
              type: 'predicted-period',
              intensity: 'Medium',
              isPredicted: true,
            });
          }
        }

        // 预测排卵期
        const predictedOvulationDate = new Date(predictedStart);
        predictedOvulationDate.setDate(
          predictedOvulationDate.getDate() + Math.floor(stats.averageCycleLength / 2),
        );
        const ovulationDateStr = predictedOvulationDate.toISOString().split('T')[0];

        if (ovulationDateStr >= startDate && ovulationDateStr <= endDate) {
          events.push({
            date: ovulationDateStr,
            type: 'predicted-ovulation',
            isPredicted: true,
          });

          // 预测易孕期
          for (let i = -1; i <= 1; i++) {
            if (i === 0) continue;
            const fertileDate = new Date(predictedOvulationDate);
            fertileDate.setDate(fertileDate.getDate() + i);
            const fertileDateStr = fertileDate.toISOString().split('T')[0];

            if (fertileDateStr >= startDate && fertileDateStr <= endDate) {
              events.push({
                date: fertileDateStr,
                type: 'predicted-fertile',
                isPredicted: true,
              });
            }
          }
        }
      }
    }

    return events;
  }

  /**
   * 初始化 Store
   */
  function initialize() {
    const savedSettings = localStorage.getItem('periodSettings');
    if (savedSettings) {
      settings.value = JSON.parse(savedSettings);
    }
  }

  /**
   * 重置 Store 状态
   */
  function $reset() {
    periodRecords.value = [];
    periodDailyRecords.value = [];
    symptoms.value = [];
    pmsRecords.value = [];
    pmsSymptoms.value = [];
    settings.value = {
      averageCycleLength: 30,
      averagePeriodLength: 7,
      notifications: {
        periodReminder: true,
        ovulationReminder: true,
        pmsReminder: true,
        reminderDays: 3,
      },
      privacy: {
        dataSync: true,
        analytics: false,
      },
      createdAt: DateUtils.getLocalISODateTimeWithOffset(),
      updatedAt: null,
    } as PeriodSettings;
    lastFetch.value = null;
    isLoading.value = false;
    error.value = null;
  }

  return {
    // 状态
    periodRecords,
    periodDailyRecords,
    symptoms,
    pmsRecords,
    pmsSymptoms,
    settings,
    lastFetch,
    isLoading,
    error,
    // 计算属性
    periodStats,
    calendarEvents,
    currentMonthRecords,
    symptomsStats,
    // Helper Functions
    isCacheValid,
    // Actions - Period Records
    periodRecordAll,
    periodRecordGet,
    periodRecordCreate,
    periodRecordUpdate,
    periodRecordDelete,
    // Actions - Daily Records
    periodDailyRecorAll,
    periodDailyRecordGet,
    periodDailyRecordCreate,
    periodDailyRecordUpdate,
    periodDailyRecordDelete,
    // Actions - Settings
    periodSettingsGet,
    updateSettings,
    // Utility Actions
    resetAllData,
    refreshDailyRecords,
    exportData,
    getCalendarEvents,
    initialize,
    // 重置
    $reset,
  };
});
