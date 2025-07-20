import {defineStore} from 'pinia';
import {computed, ref} from 'vue';
import type {
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
import {Lg} from '@/utils/debugLog';

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

      // Calculate number of days in the period
      const daysDiff =
        Math.ceil((end.getTime() - start.getTime()) / (1000 * 60 * 60 * 24)) +
        1;

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

      // 更新的模拟数据 - 包含更多历史记录以便计算预测
      const today = new Date();
      const mockData: PeriodRecords[] = [
        // 第一次经期 (3个月前)
        {
          serialNum: 'period_001'.padEnd(38, '0'),
          startDate: new Date(today.getFullYear(), today.getMonth() - 3, 10)
            .toISOString()
            .split('T')[0],
          endDate: new Date(today.getFullYear(), today.getMonth() - 3, 15)
            .toISOString()
            .split('T')[0],
          createdAt: new Date().toISOString(),
          updatedAt: null,
          notes: '第一次记录',
        },
        // 第二次经期 (2个月前)
        {
          serialNum: 'period_002'.padEnd(38, '0'),
          startDate: new Date(today.getFullYear(), today.getMonth() - 2, 8)
            .toISOString()
            .split('T')[0],
          endDate: new Date(today.getFullYear(), today.getMonth() - 2, 13)
            .toISOString()
            .split('T')[0],
          createdAt: new Date().toISOString(),
          updatedAt: null,
          notes: '第二次记录',
        },
        // 第三次经期 (1个月前)
        {
          serialNum: 'period_003'.padEnd(38, '0'),
          startDate: new Date(today.getFullYear(), today.getMonth() - 1, 12)
            .toISOString()
            .split('T')[0],
          endDate: new Date(today.getFullYear(), today.getMonth() - 1, 17)
            .toISOString()
            .split('T')[0],
          createdAt: new Date().toISOString(),
          updatedAt: null,
          notes: '第三次记录',
        },
        // 最近一次经期 (15天前，用于预测下次)
        {
          serialNum: 'period_004'.padEnd(38, '0'),
          startDate: new Date(today.getTime() - 15 * 24 * 60 * 60 * 1000)
            .toISOString()
            .split('T')[0],
          endDate: new Date(today.getTime() - 10 * 24 * 60 * 60 * 1000)
            .toISOString()
            .split('T')[0],
          createdAt: new Date().toISOString(),
          updatedAt: null,
          notes: '最近一次经期',
        },
      ];

      periodRecords.value = mockData;
      lastFetch.value = new Date();

      // Use debug logging instead of console.log
      Lg.d('Period', 'Mock period records loaded:', mockData);
      Lg.d(
        'Period',
        'Predicted next period:',
        periodStats.value.nextPredictedDate,
      );
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
  const fetchDailyRecords = async () => {
    setLoading(true);
    clearError();

    try {
      await new Promise((resolve) => setTimeout(resolve, 800));

      // 模拟API调用
      // const response = await periodApi.getDailyRecords();
      // dailyRecords.value = response.data;

      // 添加一些模拟的日常记录
      const today = new Date();
      const mockDailyData: PeriodDailyRecords[] = [
        // 昨天的记录
        {
          serialNum: `daily_${Date.now() - 1}`.padEnd(38, '0'),
          periodSerialNum: 'period_current'.padEnd(38, '0'),
          date: new Date(today.getTime() - 24 * 60 * 60 * 1000)
            .toISOString()
            .split('T')[0],
          sexualActivity: false,
          exerciseIntensity: 'Light',
          diet: '正常饮食',
          flowLevel: null,
          mood: 'Happy',
          waterIntake: 2000,
          sleepHours: 8,
          notes: '感觉不错',
          createdAt: new Date().toISOString(),
          updatedAt: null,
        },
        // 前天的记录
        {
          serialNum: `daily_${Date.now() - 2}`.padEnd(38, '0'),
          periodSerialNum: 'period_current'.padEnd(38, '0'),
          date: new Date(today.getTime() - 2 * 24 * 60 * 60 * 1000)
            .toISOString()
            .split('T')[0],
          sexualActivity: false,
          exerciseIntensity: 'Medium',
          diet: '清淡饮食',
          flowLevel: null,
          mood: 'Calm',
          waterIntake: 1800,
          sleepHours: 7.5,
          notes: '运动后感觉很好',
          createdAt: new Date().toISOString(),
          updatedAt: null,
        },
      ];

      dailyRecords.value = mockDailyData;
    } catch (e) {
      const errorMessage =
        e instanceof Error ? e.message : 'Failed to fetch daily records';
      setError(errorMessage);
      throw new Error(errorMessage);
    } finally {
      setLoading(false);
    }
  };

  const deleteDailyRecord = async (serialNum: string) => {
    setLoading(true);
    clearError();

    try {
      await new Promise((resolve) => setTimeout(resolve, 500));

      // 模拟API调用
      // await periodApi.deleteDailyRecord(serialNum);

      // 立即从本地状态中移除记录
      dailyRecords.value = dailyRecords.value.filter(
        (record) => record.serialNum !== serialNum,
      );

      Lg.i('Period', 'Daily record deleted:', serialNum);
    } catch (e) {
      const errorMessage =
        e instanceof Error ? e.message : 'Failed to delete daily record';
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

      // 检查要删除的是经期记录还是日常记录
      const isDailyRecord = dailyRecords.value.some(
        (record) => record.serialNum === serialNum,
      );

      if (isDailyRecord) {
        // 如果是日常记录，只删除日常记录
        dailyRecords.value = dailyRecords.value.filter(
          (record) => record.serialNum !== serialNum,
        );
      } else {
        // 如果是经期记录，删除经期记录和相关的日常记录
        periodRecords.value = periodRecords.value.filter(
          (record) => record.serialNum !== serialNum,
        );

        // 同时删除与该经期相关的所有日常记录
        dailyRecords.value = dailyRecords.value.filter(
          (record) => record.periodSerialNum !== serialNum,
        );
      }
    } catch (e) {
      const errorMessage =
        e instanceof Error ? e.message : 'Failed to delete record';
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
        const updatedRecord = {
          ...dailyRecords.value[existingIndex],
          ...record,
          updatedAt: new Date().toISOString(),
        };

        // 使用 splice 确保响应式更新
        dailyRecords.value.splice(existingIndex, 1, updatedRecord);
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
          notes: record.notes || '',
          createdAt: new Date().toISOString(),
          updatedAt: null,
        };

        dailyRecords.value.push(newRecord);
      }

      // 强制触发响应式更新
      dailyRecords.value = [...dailyRecords.value];
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
    // 强制获取最新的 dailyRecords
    const records = dailyRecords.value;
    return records.find((record) => record.date === date) || null;
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

  // 强制刷新日常记录的方法
  const refreshDailyRecords = async () => {
    setLoading(true);
    clearError();

    try {
      await new Promise((resolve) => setTimeout(resolve, 300));

      // 模拟重新获取数据
      // const response = await periodApi.getDailyRecords();
      // dailyRecords.value = response.data;

      // 强制触发响应式更新
      dailyRecords.value = [...dailyRecords.value];
    } catch (e) {
      const errorMessage =
        e instanceof Error ? e.message : 'Failed to refresh daily records';
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

    // 添加历史经期事件
    periodRecords.value.forEach((period) => {
      const start = new Date(period.startDate);
      const end = new Date(period.endDate);

      // Calculate number of days in the period
      const daysDiff =
        Math.ceil((end.getTime() - start.getTime()) / (1000 * 60 * 60 * 24)) +
        1;

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

    // 添加历史排卵期事件
    periodRecords.value.forEach((period) => {
      const ovulationDate = new Date(period.startDate);
      ovulationDate.setDate(
        ovulationDate.getDate() +
          Math.floor(settings.value.averageCycleLength / 2),
      );
      const dateStr = ovulationDate.toISOString().split('T')[0];

      if (dateStr >= startDate && dateStr <= endDate) {
        events.push({
          date: dateStr,
          type: 'ovulation',
          isPredicted: false,
        });

        // 排卵期前后各1天为易孕期
        for (let i = -1; i <= 1; i++) {
          if (i === 0) continue; // 排卵日已添加
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

    // 添加预测的未来经期事件
    const stats = periodStats.value;
    if (stats.nextPredictedDate && periodRecords.value.length > 0) {
      const predictedStart = new Date(stats.nextPredictedDate);
      const today = new Date();

      // 只显示未来的预测
      if (predictedStart >= today) {
        // 预测经期天数
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

        // 预测排卵期
        const predictedOvulationDate = new Date(predictedStart);
        predictedOvulationDate.setDate(
          predictedOvulationDate.getDate() +
            Math.floor(stats.averageCycleLength / 2),
        );
        const ovulationDateStr = predictedOvulationDate
          .toISOString()
          .split('T')[0];

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
    deleteDailyRecord,
    refreshDailyRecords,
  };
});
