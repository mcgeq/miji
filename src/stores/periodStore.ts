import {
  PeriodCalendarEvent,
  PeriodDailyRecords,
  PeriodPhase,
  PeriodPmsRecords,
  PeriodPmsSymptoms,
  PeriodRecords,
  PeriodSettings,
  PeriodStats,
  PeriodSymptoms,
} from '@/schema/health/period';
import {defineStore} from 'pinia';
import {computed, ref} from 'vue';

export const usePeriodStore = defineStore('period', () => {
  // 状态
  const periodRecords = ref<PeriodRecords[]>([]);
  const dailyRecords = ref<PeriodDailyRecords[]>([]);
  const symptoms = ref<PeriodSymptoms[]>([]);
  const pmsRecords = ref<PeriodPmsRecords[]>([]);
  const pmsSymptoms = ref<PeriodPmsSymptoms[]>([]);
  const settings = ref<PeriodSettings>({
    averageCycleLength: 28,
    averagePeriodLength: 5,
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
  });

  // 加载状态
  const loading = ref(false);
  const error = ref<string | null>(null);

  // 缓存状态
  const lastFetch = ref<Date | null>(null);
  const CACHE_DURATION = 5 * 60 * 1000; // 5分钟缓存

  // 计算属性 - 经期统计数据
  const periodStats = computed<PeriodStats>(() => {
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
      (a, b) =>
        new Date(a.startDate).getTime() - new Date(b.startDate).getTime(),
    );

    // 计算周期长度
    const cycles = sortedRecords.slice(0, -1).map((record, index) => {
      const nextRecord = sortedRecords[index + 1];
      const start = new Date(record.startDate);
      const nextStart = new Date(nextRecord.startDate);
      return (
        Math.abs(nextStart.getTime() - start.getTime()) / (1000 * 60 * 60 * 24)
      );
    });

    const averageCycleLength =
      cycles.length > 0
        ? Math.round(
            cycles.reduce((sum, cycle) => sum + cycle, 0) / cycles.length,
          )
        : settings.value.averageCycleLength;

    // 计算经期长度
    const periodLengths = sortedRecords.map((record) => {
      const start = new Date(record.startDate);
      const end = new Date(record.endDate);
      return (
        Math.abs(end.getTime() - start.getTime()) / (1000 * 60 * 60 * 24) + 1
      );
    });

    const averagePeriodLength = Math.round(
      periodLengths.reduce((sum, length) => sum + length, 0) /
        periodLengths.length,
    );

    // 预测下次经期
    const lastPeriod = sortedRecords[sortedRecords.length - 1];
    const lastPeriodStart = new Date(lastPeriod.startDate);
    const nextPredictedDate = new Date(
      lastPeriodStart.getTime() + averageCycleLength * 24 * 60 * 60 * 1000,
    );

    const today = new Date();
    const daysUntilNext = Math.ceil(
      (nextPredictedDate.getTime() - today.getTime()) / (1000 * 60 * 60 * 24),
    );

    // 计算当前阶段
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

  // 计算属性 - 日历事件
  const calendarEvents = computed<PeriodCalendarEvent[]>(() => {
    const events: PeriodCalendarEvent[] = [];

    // 添加经期事件
    periodRecords.value.forEach((record) => {
      const start = new Date(record.startDate);
      const end = new Date(record.endDate);

      for (let d = new Date(start); d <= end; d.setDate(d.getDate() + 1)) {
        events.push({
          date: d.toISOString().split('T')[0],
          type: 'period',
          intensity: 'Medium',
        });
      }
    });

    // 添加排卵期事件（基于预测）
    const stats = periodStats.value;
    if (stats.averageCycleLength > 0) {
      periodRecords.value.forEach((record) => {
        const start = new Date(record.startDate);
        const ovulationDate = new Date(start);
        ovulationDate.setDate(
          ovulationDate.getDate() + Math.floor(stats.averageCycleLength / 2),
        );

        // 排卵期前后各1天
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

  // 计算属性 - 当前月份的记录
  const currentMonthRecords = computed(() => {
    const currentMonth = new Date().toISOString().slice(0, 7); // YYYY-MM
    return dailyRecords.value.filter((record) =>
      record.date.startsWith(currentMonth),
    );
  });

  // 计算属性 - 症状统计
  const symptomsStats = computed(() => {
    const stats: Record<string, number> = {};
    symptoms.value.forEach((symptom) => {
      stats[symptom.symptomType] = (stats[symptom.symptomType] || 0) + 1;
    });
    return stats;
  });

  // Actions
  const setLoading = (value: boolean) => {
    loading.value = value;
  };

  const setError = (message: string | null) => {
    error.value = message;
  };

  const clearError = () => {
    error.value = null;
  };

  // 检查缓存是否有效
  const isCacheValid = (): boolean => {
    if (!lastFetch.value) return false;
    return Date.now() - lastFetch.value.getTime() < CACHE_DURATION;
  };

  // 获取经期记录
  const fetchPeriodRecords = async (force = false) => {
    if (!force && isCacheValid()) {
      return;
    }

    setLoading(true);
    clearError();

    try {
      // 模拟API调用
      await new Promise((resolve) => setTimeout(resolve, 1000));

      // 这里应该是实际的API调用
      // const response = await periodApi.getPeriodRecords();
      // periodRecords.value = response.data;

      // 模拟数据
      const mockData: PeriodRecords[] = [
        {
          serialNum: 'period_001'.padEnd(38, '0'),
          startDate: '2024-01-15',
          endDate: '2024-01-20',
          createdAt: new Date().toISOString(),
          updatedAt: null,
        },
        {
          serialNum: 'period_002'.padEnd(38, '0'),
          startDate: '2024-02-12',
          endDate: '2024-02-17',
          createdAt: new Date().toISOString(),
          updatedAt: null,
        },
      ];

      periodRecords.value = mockData;
      lastFetch.value = new Date();
    } catch (e) {
      const errorMessage =
        e instanceof Error ? e.message : 'Failed to fetch period records';
      setError(errorMessage);
      throw new Error(errorMessage);
    } finally {
      setLoading(false);
    }
  };

  // 获取每日记录
  const fetchDailyRecords = async (dateRange?: {
    start: string;
    end: string;
  }) => {
    setLoading(true);
    clearError();

    try {
      await new Promise((resolve) => setTimeout(resolve, 800));

      // 模拟API调用
      // const response = await periodApi.getDailyRecords(dateRange);
      // dailyRecords.value = response.data;

      // 模拟数据
      const mockData: PeriodDailyRecords[] = [];
      dailyRecords.value = mockData;
    } catch (e) {
      const errorMessage =
        e instanceof Error ? e.message : 'Failed to fetch daily records';
      setError(errorMessage);
      throw new Error(errorMessage);
    } finally {
      setLoading(false);
    }
  };

  // 添加经期记录
  const addPeriodRecord = async (
    record: Omit<PeriodRecords, 'serialNum' | 'createdAt' | 'updatedAt'>,
  ) => {
    setLoading(true);
    clearError();

    try {
      await new Promise((resolve) => setTimeout(resolve, 500));

      // 模拟API调用
      // const response = await periodApi.addPeriodRecord(record);

      const newRecord: PeriodRecords = {
        serialNum: `period_${Date.now()}`.padEnd(38, '0'),
        ...record,
        createdAt: new Date().toISOString(),
        updatedAt: null,
      };

      periodRecords.value.push(newRecord);

      // 清除缓存，强制重新获取
      lastFetch.value = null;

      return newRecord;
    } catch (e) {
      const errorMessage =
        e instanceof Error ? e.message : 'Failed to add period record';
      setError(errorMessage);
      throw new Error(errorMessage);
    } finally {
      setLoading(false);
    }
  };

  // 更新经期记录
  const updatePeriodRecord = async (
    serialNum: string,
    updates: Partial<PeriodRecords>,
  ) => {
    setLoading(true);
    clearError();

    try {
      await new Promise((resolve) => setTimeout(resolve, 500));

      // 模拟API调用
      // const response = await periodApi.updatePeriodRecord(serialNum, updates);

      const index = periodRecords.value.findIndex(
        (record) => record.serialNum === serialNum,
      );
      if (index !== -1) {
        periodRecords.value[index] = {
          ...periodRecords.value[index],
          ...updates,
          updatedAt: new Date().toISOString(),
        };
      }
    } catch (e) {
      const errorMessage =
        e instanceof Error ? e.message : 'Failed to update period record';
      setError(errorMessage);
      throw new Error(errorMessage);
    } finally {
      setLoading(false);
    }
  };

  // 删除经期记录
  const deletePeriodRecord = async (serialNum: string) => {
    setLoading(true);
    clearError();

    try {
      await new Promise((resolve) => setTimeout(resolve, 500));

      // 模拟API调用
      // await periodApi.deletePeriodRecord(serialNum);

      periodRecords.value = periodRecords.value.filter(
        (record) => record.serialNum !== serialNum,
      );
    } catch (e) {
      const errorMessage =
        e instanceof Error ? e.message : 'Failed to delete period record';
      setError(errorMessage);
      throw new Error(errorMessage);
    } finally {
      setLoading(false);
    }
  };

  // 添加或更新每日记录
  const upsertDailyRecord = async (record: Partial<PeriodDailyRecords>) => {
    setLoading(true);
    clearError();

    try {
      await new Promise((resolve) => setTimeout(resolve, 500));

      // 检查是否已存在该日期的记录
      const existingIndex = dailyRecords.value.findIndex(
        (r) => r.date === record.date,
      );

      if (existingIndex !== -1) {
        // 更新现有记录
        dailyRecords.value[existingIndex] = {
          ...dailyRecords.value[existingIndex],
          ...record,
          updatedAt: new Date().toISOString(),
        };
      } else {
        // 创建新记录
        const newRecord: PeriodDailyRecords = {
          serialNum: `daily_${Date.now()}`.padEnd(38, '0'),
          periodSerialNum: 'period_current'.padEnd(38, '0'),
          date: record.date || new Date().toISOString().split('T')[0],
          sexualActivity: record.sexualActivity || false,
          exerciseIntensity: record.exerciseIntensity || 'None',
          diet: record.diet || '',
          flowLevel: record.flowLevel || null,
          mood: record.mood || null,
          waterIntake: record.waterIntake,
          sleepHours: record.sleepHours,
          notes: record.notes,
          createdAt: new Date().toISOString(),
          updatedAt: null,
        };

        dailyRecords.value.push(newRecord);
      }
    } catch (e) {
      const errorMessage =
        e instanceof Error ? e.message : 'Failed to save daily record';
      setError(errorMessage);
      throw new Error(errorMessage);
    } finally {
      setLoading(false);
    }
  };

  // 获取特定日期的记录
  const getDailyRecord = (date: string): PeriodDailyRecords | null => {
    return dailyRecords.value.find((record) => record.date === date) || null;
  };

  // 更新设置
  const updateSettings = async (newSettings: Partial<PeriodSettings>) => {
    setLoading(true);
    clearError();

    try {
      await new Promise((resolve) => setTimeout(resolve, 300));

      // 模拟API调用
      // await periodApi.updateSettings(newSettings);

      settings.value = {
        ...settings.value,
        ...newSettings,
      };
    } catch (e) {
      const errorMessage =
        e instanceof Error ? e.message : 'Failed to update settings';
      setError(errorMessage);
      throw new Error(errorMessage);
    } finally {
      setLoading(false);
    }
  };

  // 重置所有数据
  const resetAllData = async () => {
    setLoading(true);
    clearError();

    try {
      await new Promise((resolve) => setTimeout(resolve, 500));

      // 模拟API调用
      // await periodApi.resetAllData();

      periodRecords.value = [];
      dailyRecords.value = [];
      symptoms.value = [];
      pmsRecords.value = [];
      pmsSymptoms.value = [];
      lastFetch.value = null;
    } catch (e) {
      const errorMessage =
        e instanceof Error ? e.message : 'Failed to reset data';
      setError(errorMessage);
      throw new Error(errorMessage);
    } finally {
      setLoading(false);
    }
  };

  // 导出数据
  const exportData = () => {
    const data = {
      periodRecords: periodRecords.value,
      dailyRecords: dailyRecords.value,
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
  };

  const getCalendarEvents = (
    startDate: string,
    endDate: string,
  ): PeriodCalendarEvent[] => {
    const events: PeriodCalendarEvent[] = [];

    // 添加经期事件
    periodRecords.value.forEach((period) => {
      const start = new Date(period.startDate);
      const end = new Date(period.endDate);

      for (let d = start; d <= end; d.setDate(d.getDate() + 1)) {
        const dateStr = d.toISOString().split('T')[0];
        if (dateStr >= startDate && dateStr <= endDate) {
          events.push({
            date: dateStr,
            type: 'period',
            intensity: 'Medium',
          });
        }
      }
    });

    // 添加排卵期事件
    // 简化计算：经期开始后14天为排卵日
    periodRecords.value.forEach((period) => {
      const ovulationDate = new Date(period.startDate);
      ovulationDate.setDate(ovulationDate.getDate() + 14);
      const dateStr = ovulationDate.toISOString().split('T')[0];

      if (dateStr >= startDate && dateStr <= endDate) {
        events.push({
          date: dateStr,
          type: 'ovulation',
        });
      }
    });

    return events;
  };
  const initialize = () => {
    // 从本地存储或API加载数据
    const savedSettings = localStorage.getItem('periodSettings');
    if (savedSettings) {
      settings.value = JSON.parse(savedSettings);
    }
  };
  return {
    // 状态
    periodRecords,
    dailyRecords,
    symptoms,
    pmsRecords,
    pmsSymptoms,
    settings,
    loading,
    error,

    // 计算属性
    periodStats,
    calendarEvents,
    currentMonthRecords,
    symptomsStats,

    // Actions
    initialize,
    setLoading,
    setError,
    clearError,
    fetchPeriodRecords,
    fetchDailyRecords,
    addPeriodRecord,
    updatePeriodRecord,
    deletePeriodRecord,
    upsertDailyRecord,
    getDailyRecord,
    updateSettings,
    resetAllData,
    exportData,
    getCalendarEvents,
  };
});
