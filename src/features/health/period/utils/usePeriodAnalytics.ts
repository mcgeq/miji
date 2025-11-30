import type {
  PeriodCalendarEvent,
  PeriodDailyRecords,
  PeriodPhase,
  PeriodRecords,
} from '@/schema/health/period';

export interface PeriodAnalytics {
  // 基础统计
  totalRecords: number;
  averageCycleLength: number;
  averagePeriodLength: number;
  cycleLengthVariation: number;
  periodLengthVariation: number;

  // 趋势分析
  cycleRegularity: number;
  trendDirection: 'stable' | 'increasing' | 'decreasing';

  // 预测
  nextPeriodDate: string;
  fertilityWindow: { start: string; end: string };
  ovulationDate: string;

  // 健康指标
  healthScore: number;
  riskFactors: string[];
  recommendations: string[];
}

export interface CycleAnalysis {
  cycleNumber: number;
  startDate: string;
  endDate: string;
  periodLength: number;
  cycleLength: number;
  phase: PeriodPhase;
  symptoms: string[];
  averageFlow: string;
  mood: string[];
}

export function usePeriodAnalytics(
  periodRecords: PeriodRecords[],
  dailyRecords: PeriodDailyRecords[],
) {
  // 基础计算函数
  const calculatePeriodLength = (record: PeriodRecords): number => {
    const start = new Date(record.startDate);
    const end = new Date(record.endDate);
    return Math.ceil((end.getTime() - start.getTime()) / (1000 * 60 * 60 * 24)) + 1;
  };

  const calculateCycleLength = (current: PeriodRecords, previous: PeriodRecords): number => {
    const currentStart = new Date(current.startDate);
    const previousStart = new Date(previous.startDate);
    return Math.ceil((currentStart.getTime() - previousStart.getTime()) / (1000 * 60 * 60 * 24));
  };

  // 排序后的记录
  const sortedRecords = computed(() => {
    return [...periodRecords].sort(
      (a, b) => new Date(a.startDate).getTime() - new Date(b.startDate).getTime(),
    );
  });

  // 周期长度数组
  const cycleLengths = computed(() => {
    const lengths: number[] = [];
    const records = sortedRecords.value;

    for (let i = 1; i < records.length; i++) {
      const cycleLength = calculateCycleLength(records[i], records[i - 1]);
      if (cycleLength > 0 && cycleLength <= 60) {
        // 过滤异常值
        lengths.push(cycleLength);
      }
    }

    return lengths;
  });

  // 经期长度数组
  const periodLengths = computed(() => {
    return sortedRecords.value.map(record => calculatePeriodLength(record));
  });

  // 基础统计
  const analytics = computed<PeriodAnalytics>(() => {
    const records = sortedRecords.value;
    const cycles = cycleLengths.value;
    const periods = periodLengths.value;

    // 平均值计算
    const avgCycleLength =
      cycles.length > 0 ? cycles.reduce((sum, length) => sum + length, 0) / cycles.length : 28;

    const avgPeriodLength =
      periods.length > 0 ? periods.reduce((sum, length) => sum + length, 0) / periods.length : 5;

    // 变异系数计算
    const cycleLengthVariation = cycles.length > 1 ? calculateVariationCoefficient(cycles) : 0;

    const periodLengthVariation = periods.length > 1 ? calculateVariationCoefficient(periods) : 0;

    // 规律性评分 (0-100)
    const cycleRegularity = Math.max(0, 100 - cycleLengthVariation * 100);

    // 趋势分析
    const trendDirection = analyzeTrend(cycles);

    // 预测下次经期
    const nextPeriodDate = predictNextPeriod(records, avgCycleLength);

    // 排卵期和易孕期
    const ovulationDate = calculateOvulationDate(nextPeriodDate, avgCycleLength);
    const fertilityWindow = calculateFertilityWindow(ovulationDate);

    // 健康评分
    const healthScore = calculateHealthScore(cycles, periods, dailyRecords);

    // 风险因素
    const riskFactors = identifyRiskFactors(cycles, periods, dailyRecords);

    // 建议
    const recommendations = generateRecommendations(cycleRegularity, healthScore, riskFactors);

    return {
      totalRecords: records.length,
      averageCycleLength: Math.round(avgCycleLength),
      averagePeriodLength: Math.round(avgPeriodLength * 10) / 10,
      cycleLengthVariation: Math.round(cycleLengthVariation * 100) / 100,
      periodLengthVariation: Math.round(periodLengthVariation * 100) / 100,
      cycleRegularity: Math.round(cycleRegularity),
      trendDirection,
      nextPeriodDate,
      fertilityWindow,
      ovulationDate,
      healthScore: Math.round(healthScore),
      riskFactors,
      recommendations,
    };
  });

  // 详细周期分析
  const cycleAnalysis = computed<CycleAnalysis[]>(() => {
    const records = sortedRecords.value;
    const analysis: CycleAnalysis[] = [];

    records.forEach((record, index) => {
      const periodLength = calculatePeriodLength(record);
      const cycleLength = index > 0 ? calculateCycleLength(record, records[index - 1]) : 0;

      // 获取该周期的日常记录
      const periodDailyRecords = dailyRecords.filter(daily => {
        const dailyDate = new Date(daily.date);
        const periodStart = new Date(record.startDate);
        const periodEnd = new Date(record.endDate);
        return dailyDate >= periodStart && dailyDate <= periodEnd;
      });

      // 分析症状
      const symptoms = extractSymptoms(periodDailyRecords);
      const averageFlow = calculateAverageFlow(periodDailyRecords);
      const mood = extractMoodData(periodDailyRecords);

      analysis.push({
        cycleNumber: index + 1,
        startDate: record.startDate,
        endDate: record.endDate,
        periodLength,
        cycleLength,
        phase: getCurrentPhase(record, new Date()),
        symptoms,
        averageFlow,
        mood,
      });
    });

    return analysis.reverse(); // 最新的在前面
  });

  // 月度统计
  const monthlyStats = computed(() => {
    const stats: Record<
      string,
      {
        periodCount: number;
        averageCycleLength: number;
        averagePeriodLength: number;
        symptoms: Record<string, number>;
      }
    > = {};

    sortedRecords.value.forEach(record => {
      const month = record.startDate.substring(0, 7); // YYYY-MM

      if (!stats[month]) {
        stats[month] = {
          periodCount: 0,
          averageCycleLength: 0,
          averagePeriodLength: 0,
          symptoms: {},
        };
      }

      stats[month].periodCount++;
      stats[month].averagePeriodLength += calculatePeriodLength(record);

      // 统计症状
      // const monthlyDailyRecords = dailyRecords.filter(daily =>
      //   daily.date.startsWith(month),
      // );
      //
      // monthlyDailyRecords.forEach(daily => {
      //   // 这里可以添加症状统计逻辑
      // });
    });

    // 计算平均值
    Object.keys(stats).forEach(month => {
      if (stats[month].periodCount > 0) {
        stats[month].averagePeriodLength /= stats[month].periodCount;
      }
    });

    return stats;
  });

  // 辅助函数
  function calculateVariationCoefficient(values: number[]): number {
    if (values.length < 2) return 0;

    const mean = values.reduce((sum, val) => sum + val, 0) / values.length;
    const variance = values.reduce((sum, val) => sum + (val - mean) ** 2, 0) / values.length;
    const standardDeviation = Math.sqrt(variance);

    return mean > 0 ? standardDeviation / mean : 0;
  }

  function analyzeTrend(cycles: number[]): 'stable' | 'increasing' | 'decreasing' {
    if (cycles.length < 3) return 'stable';

    const recentCycles = cycles.slice(-6); // 最近6个周期
    const earlierCycles = cycles.slice(-12, -6); // 之前6个周期

    if (earlierCycles.length === 0) return 'stable';

    const recentAvg = recentCycles.reduce((sum, val) => sum + val, 0) / recentCycles.length;
    const earlierAvg = earlierCycles.reduce((sum, val) => sum + val, 0) / earlierCycles.length;

    const difference = recentAvg - earlierAvg;

    if (Math.abs(difference) < 1) return 'stable';
    return difference > 0 ? 'increasing' : 'decreasing';
  }

  function predictNextPeriod(records: PeriodRecords[], avgCycleLength: number): string {
    if (records.length === 0) return '';

    const lastRecord = records[records.length - 1];
    const lastPeriodStart = new Date(lastRecord.startDate);
    const nextPeriodDate = new Date(lastPeriodStart);
    nextPeriodDate.setDate(nextPeriodDate.getDate() + avgCycleLength);

    return nextPeriodDate.toISOString().split('T')[0];
  }

  function calculateOvulationDate(nextPeriodDate: string, _cycleLength: number): string {
    if (!nextPeriodDate) return '';

    const nextPeriod = new Date(nextPeriodDate);
    const ovulationDate = new Date(nextPeriod);
    ovulationDate.setDate(ovulationDate.getDate() - 14); // 排卵期通常在经期前14天

    return ovulationDate.toISOString().split('T')[0];
  }

  function calculateFertilityWindow(ovulationDate: string): {
    start: string;
    end: string;
  } {
    if (!ovulationDate) return { start: '', end: '' };

    const ovulation = new Date(ovulationDate);
    const start = new Date(ovulation);
    const end = new Date(ovulation);

    start.setDate(start.getDate() - 5); // 排卵前5天
    end.setDate(end.getDate() + 1); // 排卵后1天

    return {
      start: start.toISOString().split('T')[0],
      end: end.toISOString().split('T')[0],
    };
  }

  function calculateHealthScore(
    cycles: number[],
    periods: number[],
    dailyRecords: PeriodDailyRecords[],
  ): number {
    let score = 100;

    // 周期规律性 (40分)
    const cycleVariation = calculateVariationCoefficient(cycles);
    score -= Math.min(40, cycleVariation * 200);

    // 经期长度合理性 (30分)
    const avgPeriodLength = periods.reduce((sum, val) => sum + val, 0) / periods.length;
    if (avgPeriodLength < 3 || avgPeriodLength > 7) {
      score -= 15;
    }

    // 症状严重程度 (30分)
    const symptomsScore = calculateSymptomsScore(dailyRecords);
    score -= Math.min(30, symptomsScore);

    return Math.max(0, score);
  }

  function calculateSymptomsScore(_dailyRecords: PeriodDailyRecords[]): number {
    // 基于症状频率和严重程度计算分数
    // 这里简化处理，实际应该根据具体症状数据
    return 0;
  }

  function identifyRiskFactors(
    cycles: number[],
    periods: number[],
    _dailyRecords: PeriodDailyRecords[],
  ): string[] {
    const risks: string[] = [];

    // 周期不规律
    const cycleVariation = calculateVariationCoefficient(cycles);
    if (cycleVariation > 0.15) {
      risks.push('周期不规律');
    }

    // 周期过长或过短
    const avgCycleLength = cycles.reduce((sum, val) => sum + val, 0) / cycles.length;
    if (avgCycleLength < 21) {
      risks.push('周期过短');
    } else if (avgCycleLength > 35) {
      risks.push('周期过长');
    }

    // 经期过长或过短
    const avgPeriodLength = periods.reduce((sum, val) => sum + val, 0) / periods.length;
    if (avgPeriodLength < 3) {
      risks.push('经期过短');
    } else if (avgPeriodLength > 7) {
      risks.push('经期过长');
    }

    return risks;
  }

  function generateRecommendations(
    regularity: number,
    healthScore: number,
    riskFactors: string[],
  ): string[] {
    const recommendations: string[] = [];

    if (regularity < 70) {
      recommendations.push('建议咨询医生了解周期不规律的原因');
      recommendations.push('保持规律的作息时间');
      recommendations.push('减少压力，尝试放松技巧');
    }

    if (healthScore < 70) {
      recommendations.push('关注生活方式，改善饮食和运动习惯');
      recommendations.push('记录症状变化，便于就医时提供详细信息');
    }

    if (riskFactors.length > 0) {
      recommendations.push('定期体检，关注妇科健康');
    }

    // 通用建议
    recommendations.push('保持均衡饮食，适量运动');
    recommendations.push('充足睡眠，管理压力');

    return recommendations;
  }

  function getCurrentPhase(record: PeriodRecords, currentDate: Date): PeriodPhase {
    const periodStart = new Date(record.startDate);
    const periodEnd = new Date(record.endDate);
    const daysSinceStart = Math.floor(
      (currentDate.getTime() - periodStart.getTime()) / (1000 * 60 * 60 * 24),
    );

    if (currentDate >= periodStart && currentDate <= periodEnd) {
      return 'Menstrual';
    } else if (daysSinceStart < 14) {
      return 'Follicular';
    } else if (daysSinceStart < 17) {
      return 'Ovulation';
    } else {
      return 'Luteal';
    }
  }

  function extractSymptoms(dailyRecords: PeriodDailyRecords[]): string[] {
    // 从日常记录中提取症状信息
    const symptoms = new Set<string>();

    dailyRecords.forEach(record => {
      if (record.notes) {
        // 简单的关键词匹配，实际应该更复杂
        if (record.notes.includes('疼痛') || record.notes.includes('痛')) {
          symptoms.add('疼痛');
        }
        if (record.notes.includes('头痛')) {
          symptoms.add('头痛');
        }
        if (record.notes.includes('疲劳') || record.notes.includes('累')) {
          symptoms.add('疲劳');
        }
      }
    });

    return Array.from(symptoms);
  }

  function calculateAverageFlow(dailyRecords: PeriodDailyRecords[]): string {
    const flowLevels = dailyRecords.map(record => record.flowLevel).filter(level => level !== null);

    if (flowLevels.length === 0) return '未记录';

    const flowValues = { Light: 1, Medium: 2, Heavy: 3 };
    const average =
      flowLevels.reduce(
        (sum, level) => sum + (flowValues[level as keyof typeof flowValues] || 0),
        0,
      ) / flowLevels.length;

    if (average <= 1.3) return '轻量';
    if (average <= 2.3) return '中等';
    return '大量';
  }

  function extractMoodData(dailyRecords: PeriodDailyRecords[]): string[] {
    const moods = dailyRecords.map(record => record.mood).filter(mood => mood !== null) as string[];

    return Array.from(new Set(moods));
  }

  // 生成日历事件
  function generateCalendarEvents(startDate: string, endDate: string): PeriodCalendarEvent[] {
    const events: PeriodCalendarEvent[] = [];

    // 添加已记录的经期
    sortedRecords.value.forEach(record => {
      const periodStart = new Date(record.startDate);
      const periodEnd = new Date(record.endDate);
      const dayCount = Math.ceil(
        (periodEnd.getTime() - periodStart.getTime()) / (1000 * 60 * 60 * 24),
      );

      for (let i = 0; i <= dayCount; i++) {
        const currentDate = new Date(periodStart);
        currentDate.setDate(currentDate.getDate() + i);
        const dateStr = currentDate.toISOString().split('T')[0];
        if (dateStr >= startDate && dateStr <= endDate) {
          events.push({
            date: dateStr,
            type: 'period',
            intensity: 'Medium',
          });
        }
      }
    });

    // 添加预测的排卵期
    const avgCycleLength = analytics.value.averageCycleLength;
    sortedRecords.value.forEach(record => {
      const ovulationDate = new Date(record.startDate);
      ovulationDate.setDate(ovulationDate.getDate() + Math.floor(avgCycleLength / 2));
      const dateStr = ovulationDate.toISOString().split('T')[0];
      if (dateStr >= startDate && dateStr <= endDate) {
        events.push({
          date: dateStr,
          type: 'ovulation',
        });
      }
    });

    return events;
  }

  return {
    analytics,
    cycleAnalysis,
    monthlyStats,
    cycleLengths,
    periodLengths,
    sortedRecords,
    generateCalendarEvents,
  };
}
