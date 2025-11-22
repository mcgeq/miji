import { AppError } from '@/errors/appError';
import { SortDirection } from '@/schema/common';
import { HealthsDb } from '@/services/healths/healths';
import { DateUtils } from '@/utils/date';
import { Lg } from '@/utils/debugLog';
import type { PageQuery } from '@/schema/common';
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

// Define Health-specific error codes
export enum HealthStoreErrorCode {
  DATABASE_OPERATION_FAILED = 'HEALTH_DB_OPERATION_FAILED',
  INVALID_RECORD = 'HEALTH_INVALID_RECORD',
  RECORD_NOT_FOUND = 'HEALTH_RECORD_NOT_FOUND',
  SYNC_FAILED = 'HEALTH_SYNC_FAILED',
}

// Custom error class for Health database operations
export class HealthDbError extends AppError {
  public readonly operation: string;
  public readonly entity: string;
  public readonly originalError?: unknown;

  constructor(
    code: HealthStoreErrorCode,
    message: string,
    details: {
      operation: string;
      entity: string;
      originalError?: unknown;
    },
  ) {
    super('health', code, message);
    this.operation = details.operation;
    this.entity = details.entity;
    this.originalError = details.originalError;
  }
}

interface PeriodStoreState {
  periodRecords: PeriodRecords[];
  periodDailyRecords: PeriodDailyRecords[];
  symptoms: PeriodSymptoms[];
  pmsRecords: PeriodPmsRecords[];
  pmsSymptoms: PeriodPmsSymptoms[];
  settings: PeriodSettings;
  lastFetch: Date | null;
  loading: boolean;
  error: string | null;
  CACHE_DURATION: number;
}

export const usePeriodStore = defineStore('period', {
  state: (): PeriodStoreState => ({
    periodRecords: [],
    periodDailyRecords: [],
    symptoms: [],
    pmsRecords: [],
    pmsSymptoms: [],
    settings: {
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
    } as PeriodSettings,
    loading: false,
    error: null as string | null,
    lastFetch: null as Date | null,
    CACHE_DURATION: 5 * 60 * 1000,
  }),

  getters: {
    periodStats: (state): PeriodStats => {
      if (state.periodRecords.length < 2) {
        return {
          averageCycleLength: state.settings.averageCycleLength,
          averagePeriodLength: state.settings.averagePeriodLength,
          nextPredictedDate: '',
          currentPhase: 'Follicular',
          daysUntilNext: 0,
        };
      }

      const sortedRecords = [...state.periodRecords].sort(
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
          : state.settings.averageCycleLength;

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
    },

    calendarEvents: (state): PeriodCalendarEvent[] => {
      const events: PeriodCalendarEvent[] = [];

      // Add period events
      state.periodRecords.forEach(record => {
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
      const stats = (this as any).periodStats; // Type assertion for getters
      if (stats.averageCycleLength > 0) {
        state.periodRecords.forEach(record => {
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
    },

    currentMonthRecords: state => {
      const currentMonth = new Date().toISOString().slice(0, 7);
      return state.periodDailyRecords.filter(record => record.date.startsWith(currentMonth));
    },

    symptomsStats: state => {
      const stats: Record<string, number> = {};
      state.symptoms.forEach(symptom => {
        stats[symptom.symptomType] = (stats[symptom.symptomType] || 0) + 1;
      });
      return stats;
    },
  },

  actions: {
    setLoading(value: boolean) {
      this.loading = value;
    },

    setError(message: string | null) {
      this.error = message;
    },

    clearError() {
      this.error = null;
    },

    isCacheValid(): boolean {
      if (!this.lastFetch) return false;
      return Date.now() - this.lastFetch.getTime() < this.CACHE_DURATION;
    },
    // 错误处理辅助函数
    handleError(
      err: unknown,
      defaultMessage: string,
      operation?: string,
      entity?: string,
    ): AppError {
      let appError: AppError;
      if (err instanceof HealthDbError) {
        appError = new HealthDbError(
          HealthStoreErrorCode.DATABASE_OPERATION_FAILED,
          `${defaultMessage}: ${err.message}`,
          {
            operation: operation || err.operation,
            entity: entity || err.entity,
            originalError: err.originalError,
          },
        );
      } else if (err instanceof MoneyStoreError) {
        appError = err as AppError;
      } else {
        appError = AppError.wrap(
          'money',
          err,
          MoneyStoreErrorCode.DATABASE_OPERATION_FAILED,
          defaultMessage,
        );
      }
      this.error = appError.getUserMessage();
      appError.log();
      return appError;
    },

    async withLoadingAndError<T>(operation: () => Promise<T>, defaultMessage: string): Promise<T> {
      this.loading = true;
      this.error = null;
      try {
        return await operation();
      } catch (e) {
        const errorMessage = e instanceof Error ? e.message : defaultMessage;
        this.setError(errorMessage);
        throw new Error(errorMessage);
      } finally {
        this.loading = false;
      }
    },

    // ==================== Local State Update Utilities ====================
    async updatePeriodDailyRecords() {
      const query: PageQuery<PeriodDailyRecordFilter> = {
        currentPage: 1,
        pageSize: 20,
        sortOptions: {
          desc: true,
          sortDir: SortDirection.Desc,
        },
        filter: {},
      };
      try {
        this.periodDailyRecords = (await HealthsDb.listPagedPeriodDailyRecord(query)).rows;
      } catch (err) {
        throw this.handleError(err, '获取每日记录失败', 'listPagedPeriodDailyRecord', 'Period');
      }
    },
    async updatePeriodRecords() {
      const query: PageQuery<PeriodRecordFilter> = {
        currentPage: 1,
        pageSize: 20,
        sortOptions: {
          desc: true,
          sortDir: SortDirection.Desc,
        },
        filter: {},
      };
      try {
        this.periodRecords = (await HealthsDb.listPagedPeriodRecord(query)).rows;
      } catch (err) {
        throw this.handleError(
          err,
          '获取经期记录鼠标',
          'listPagedPeriodDailyRecord',
          'PeriodRecord',
        );
      }
    },

    // ==================== PeriodDailyRecord Start ====================
    async periodDailyRecorAll() {
      return this.withLoadingAndError(async () => {
        await this.updatePeriodDailyRecords();
      }, 'Failed to get daily period record');
    },

    async periodDailyRecordGet(serialNum: string) {
      return this.withLoadingAndError(async () => {
        const result = await HealthsDb.getPeriodDailyRecord(serialNum);
        await this.updatePeriodDailyRecords();
        this.lastFetch = null;
        return result;
      }, 'Failed to get daily period record');
    },

    async periodDailyRecordCreate(record: PeriodDailyRecordCreate) {
      return this.withLoadingAndError(async () => {
        const result = await HealthsDb.createPeriodDailyRecord(record);
        await this.updatePeriodDailyRecords();
        this.lastFetch = null;
        return result;
      }, 'Failed to create period record');
    },

    async periodDailyRecordUpdate(serialNum: string, updates: PeriodDailyRecordUpdate) {
      return this.withLoadingAndError(async () => {
        const result = await HealthsDb.updatePeriodDailyRecord(serialNum, updates);
        await this.updatePeriodDailyRecords();
        return result;
      }, 'Failed to update period record');
    },

    async periodDailyRecordDelete(serialNum: string) {
      return this.withLoadingAndError(async () => {
        await HealthsDb.deletePeriodDailyRecord(serialNum);
        // 删除成功后不立即刷新，由调用方统一刷新，避免重复请求
        Lg.i('Period', 'Daily record deleted:', serialNum);
      }, 'Failed to delete daily record');
    },
    // ==================== PeriodDailyRecord End====================

    // ==================== PeriodRecord  Start ====================
    async periodRecordAll() {
      return this.withLoadingAndError(async () => {
        await this.updatePeriodRecords();
        this.lastFetch = null;
      }, 'Failed to get period record');
    },

    async periodRecordGet(serialNum: string) {
      return this.withLoadingAndError(async () => {
        const result = await HealthsDb.getPeriodRecord(serialNum);
        await this.updatePeriodDailyRecords();
        this.lastFetch = null;
        return result;
      }, 'Failed to get period record');
    },

    async periodRecordCreate(record: PeriodRecordCreate) {
      return this.withLoadingAndError(async () => {
        const result = await HealthsDb.createPeriodRecord(record);
        await this.updatePeriodRecords();
        this.lastFetch = null;
        return result;
      }, 'Failed to create period record');
    },

    async periodRecordUpdate(serialNum: string, updates: PeriodRecordUpdate) {
      return this.withLoadingAndError(async () => {
        const result = await HealthsDb.updatePeriodRecord(serialNum, updates);
        await this.updatePeriodRecords();
        return result;
      }, 'Failed to update period record');
    },

    async periodRecordDelete(serialNum: string) {
      return this.withLoadingAndError(async () => {
        await HealthsDb.deletePeriodRecord(serialNum);
        await this.updatePeriodRecords();
      }, 'Failed to delete record');
    },
    // ==================== PeriodRecord  End ====================
    async periodSettingsGet() {
      return this.withLoadingAndError(async () => {
        let result: PeriodSettings | null = null;

        localStorage.removeItem('periodSettings');
        if (this.settings.serialNum) {
          result = await HealthsDb.getPeriodSettings(this.settings.serialNum);
        }
        if (result === null) {
          const { serialNum, createdAt, updatedAt, ...periodSettingsCreate } = this.settings;
          const result = await HealthsDb.createPeriodSettings(periodSettingsCreate);
          this.settings = result;
        }
        localStorage.setItem('periodSettings', JSON.stringify(this.settings));
      }, 'Failed to get period settings');
    },

    async updateSettings(newSettings: Partial<PeriodSettings>) {
      return this.withLoadingAndError(async () => {
        await new Promise(resolve => setTimeout(resolve, 300));
        this.settings = { ...this.settings, ...newSettings };
        localStorage.setItem('periodSettings', JSON.stringify(this.settings));
      }, 'Failed to update settings');
    },

    async resetAllData() {
      return this.withLoadingAndError(async () => {
        await new Promise(resolve => setTimeout(resolve, 500));
        this.periodRecords = [];
        this.periodDailyRecords = [];
        this.symptoms = [];
        this.pmsRecords = [];
        this.pmsSymptoms = [];
        this.lastFetch = null;
      }, 'Failed to reset data');
    },

    async refreshDailyRecords() {
      return this.withLoadingAndError(async () => {
        await new Promise(resolve => setTimeout(resolve, 300));
        this.periodDailyRecords = [...this.periodDailyRecords];
      }, 'Failed to refresh daily records');
    },

    exportData() {
      const data = {
        periodRecords: this.periodRecords,
        dailyRecords: this.periodDailyRecords,
        symptoms: this.symptoms,
        pmsRecords: this.pmsRecords,
        pmsSymptoms: this.pmsSymptoms,
        settings: this.settings,
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
    },

    getCalendarEvents(startDate: string, endDate: string): PeriodCalendarEvent[] {
      const events: PeriodCalendarEvent[] = [];

      // Add historical period events
      this.periodRecords.forEach(period => {
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

      // Add historical ovulation events
      this.periodRecords.forEach(period => {
        const ovulationDate = new Date(period.startDate);
        ovulationDate.setDate(
          ovulationDate.getDate() + Math.floor(this.settings.averageCycleLength / 2),
        );
        const dateStr = ovulationDate.toISOString().split('T')[0];

        if (dateStr >= startDate && dateStr <= endDate) {
          events.push({
            date: dateStr,
            type: 'ovulation',
            isPredicted: false,
          });

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

      // Add predicted future events
      const stats = (this as any).periodStats;
      if (stats.nextPredictedDate && this.periodRecords.length > 0) {
        const predictedStart = new Date(stats.nextPredictedDate);
        const today = new Date();

        if (predictedStart >= today) {
          const predictedPeriodLength = stats.averagePeriodLength;

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
    },

    initialize() {
      const savedSettings = localStorage.getItem('periodSettings');
      if (savedSettings) {
        this.settings = JSON.parse(savedSettings);
      }
    },
  },
});
