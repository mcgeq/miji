import {ExerciseIntensity, FlowLevel, Intensity} from '@/schema/common';
import type {
  Mood,
  PeriodDailyRecords,
  PeriodPhase,
  PeriodRecords,
} from '@/schema/health/period';

/**
 * 日期相关工具函数
 */
export class DateUtils {
  /**
   * 格式化日期为中文
   */
  static formatChineseDate(dateStr: string): string {
    const date = new Date(dateStr);
    const year = date.getFullYear();
    const month = date.getMonth() + 1;
    const day = date.getDate();
    const weekDay = ['日', '一', '二', '三', '四', '五', '六'][date.getDay()];

    return `${year}年${month}月${day}日 星期${weekDay}`;
  }

  /**
   * 格式化日期范围
   */
  static formatDateRange(startDate: string, endDate: string): string {
    const start = new Date(startDate);
    const end = new Date(endDate);

    if (start.getFullYear() !== end.getFullYear()) {
      return `${start.getFullYear()}年${start.getMonth() + 1}月${start.getDate()}日 - ${end.getFullYear()}年${end.getMonth() + 1}月${end.getDate()}日`;
    }

    if (start.getMonth() !== end.getMonth()) {
      return `${start.getMonth() + 1}月${start.getDate()}日 - ${end.getMonth() + 1}月${end.getDate()}日`;
    }

    return `${start.getMonth() + 1}月${start.getDate()}日 - ${end.getDate()}日`;
  }

  /**
   * 计算两个日期之间的天数
   */
  static daysBetween(startDate: string, endDate: string): number {
    const start = new Date(startDate);
    const end = new Date(endDate);
    return Math.ceil((end.getTime() - start.getTime()) / (1000 * 60 * 60 * 24));
  }

  /**
   * 获取今天的日期字符串
   */
  static today(): string {
    return new Date().toISOString().split('T')[0];
  }

  /**
   * 添加天数到日期
   */
  static addDays(dateStr: string, days: number): string {
    const date = new Date(dateStr);
    date.setDate(date.getDate() + days);
    return date.toISOString().split('T')[0];
  }

  /**
   * 获取月份的第一天和最后一天
   */
  static getMonthRange(
    year: number,
    month: number,
  ): {start: string; end: string} {
    const start = new Date(year, month - 1, 1);
    const end = new Date(year, month, 0);

    return {
      start: start.toISOString().split('T')[0],
      end: end.toISOString().split('T')[0],
    };
  }

  /**
   * 判断是否为同一天
   */
  static isSameDay(date1: string, date2: string): boolean {
    return date1 === date2;
  }

  /**
   * 获取相对日期描述
   */
  static getRelativeDate(dateStr: string): string {
    const today = new Date();
    const yesterday = new Date(today);
    yesterday.setDate(yesterday.getDate() - 1);
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);

    if (this.isSameDay(dateStr, today.toISOString().split('T')[0])) {
      return '今天';
    } else if (this.isSameDay(dateStr, yesterday.toISOString().split('T')[0])) {
      return '昨天';
    } else if (this.isSameDay(dateStr, tomorrow.toISOString().split('T')[0])) {
      return '明天';
    }

    const daysDiff = this.daysBetween(
      today.toISOString().split('T')[0],
      dateStr,
    );
    if (daysDiff > 0) {
      return `${daysDiff}天后`;
    } else {
      return `${Math.abs(daysDiff)}天前`;
    }
  }
}

/**
 * 经期计算工具函数
 */
export class PeriodCalculator {
  /**
   * 计算经期长度
   */
  static calculatePeriodLength(record: PeriodRecords): number {
    return DateUtils.daysBetween(record.startDate, record.endDate) + 1;
  }

  /**
   * 计算周期长度
   */
  static calculateCycleLength(
    current: PeriodRecords,
    previous: PeriodRecords,
  ): number {
    return DateUtils.daysBetween(previous.startDate, current.startDate);
  }

  /**
   * 预测下次经期开始日期
   */
  static predictNextPeriod(
    lastPeriod: PeriodRecords,
    averageCycleLength: number,
  ): string {
    return DateUtils.addDays(lastPeriod.startDate, averageCycleLength);
  }

  /**
   * 计算排卵日
   */
  static calculateOvulationDate(
    nextPeriodDate: string,
    cycleLength: number = 28,
  ): string {
    console.log(cycleLength);
    return DateUtils.addDays(nextPeriodDate, -14);
  }

  /**
   * 计算易孕期
   */
  static calculateFertileWindow(ovulationDate: string): {
    start: string;
    end: string;
  } {
    return {
      start: DateUtils.addDays(ovulationDate, -5),
      end: DateUtils.addDays(ovulationDate, 1),
    };
  }

  /**
   * 获取当前月经周期阶段
   */
  static getCurrentPhase(
    lastPeriod: PeriodRecords,
    averageCycleLength: number,
    averagePeriodLength: number,
    currentDate: string = DateUtils.today(),
  ): PeriodPhase {
    const daysSinceLastPeriod = DateUtils.daysBetween(
      lastPeriod.startDate,
      currentDate,
    );

    if (daysSinceLastPeriod <= averagePeriodLength) {
      return 'Menstrual';
    } else if (daysSinceLastPeriod <= averageCycleLength / 2 - 3) {
      return 'Follicular';
    } else if (daysSinceLastPeriod <= averageCycleLength / 2 + 3) {
      return 'Ovulation';
    } else {
      return 'Luteal';
    }
  }

  /**
   * 计算到下次经期的天数
   */
  static daysUntilNextPeriod(
    nextPeriodDate: string,
    currentDate: string = DateUtils.today(),
  ): number {
    return DateUtils.daysBetween(currentDate, nextPeriodDate);
  }

  /**
   * 判断指定日期是否在经期内
   */
  static isInPeriod(date: string, periods: PeriodRecords[]): boolean {
    return periods.some((period) => {
      const targetDate = new Date(date);
      const startDate = new Date(period.startDate);
      const endDate = new Date(period.endDate);
      return targetDate >= startDate && targetDate <= endDate;
    });
  }

  /**
   * 获取指定日期的经期记录
   */
  static getPeriodForDate(
    date: string,
    periods: PeriodRecords[],
  ): PeriodRecords | null {
    return (
      periods.find((period) => {
        const targetDate = new Date(date);
        const startDate = new Date(period.startDate);
        const endDate = new Date(period.endDate);
        return targetDate >= startDate && targetDate <= endDate;
      }) || null
    );
  }
}

/**
 * 数据分析工具函数
 */
export class PeriodAnalyzer {
  /**
   * 计算平均值
   */
  static calculateAverage(values: number[]): number {
    if (values.length === 0) return 0;
    return values.reduce((sum, value) => sum + value, 0) / values.length;
  }

  /**
   * 计算标准差
   */
  static calculateStandardDeviation(values: number[]): number {
    if (values.length < 2) return 0;

    const mean = this.calculateAverage(values);
    const variance =
      values.reduce((sum, value) => sum + Math.pow(value - mean, 2), 0) /
      values.length;
    return Math.sqrt(variance);
  }

  /**
   * 计算变异系数
   */
  static calculateVariationCoefficient(values: number[]): number {
    const mean = this.calculateAverage(values);
    const stdDev = this.calculateStandardDeviation(values);
    return mean > 0 ? stdDev / mean : 0;
  }

  /**
   * 计算周期规律性评分 (0-100)
   */
  static calculateRegularityScore(cycleLengths: number[]): number {
    if (cycleLengths.length < 2) return 100;

    const variation = this.calculateVariationCoefficient(cycleLengths);
    return Math.max(0, Math.round(100 - variation * 200));
  }

  /**
   * 分析趋势方向
   */
  static analyzeTrend(
    values: number[],
    windowSize: number = 6,
  ): 'stable' | 'increasing' | 'decreasing' {
    if (values.length < windowSize * 2) return 'stable';

    const recent = values.slice(-windowSize);
    const earlier = values.slice(-windowSize * 2, -windowSize);

    const recentAvg = this.calculateAverage(recent);
    const earlierAvg = this.calculateAverage(earlier);
    const difference = recentAvg - earlierAvg;

    if (Math.abs(difference) < 1) return 'stable';
    return difference > 0 ? 'increasing' : 'decreasing';
  }

  /**
   * 识别异常值
   */
  static identifyOutliers(values: number[], threshold: number = 2): number[] {
    const mean = this.calculateAverage(values);
    const stdDev = this.calculateStandardDeviation(values);

    return values.filter(
      (value) => Math.abs(value - mean) > threshold * stdDev,
    );
  }

  /**
   * 计算健康评分
   */
  static calculateHealthScore(
    cycleLengths: number[],
    periodLengths: number[],
    // eslint-disable-next-line @typescript-eslint/no-unused-vars
    _dailyRecords: PeriodDailyRecords[],
  ): number {
    let score = 100;

    // 周期规律性 (40%)
    const cycleRegularity = this.calculateRegularityScore(cycleLengths);
    score = score * 0.6 + cycleRegularity * 0.4;

    // 经期长度合理性 (30%)
    const avgPeriodLength = this.calculateAverage(periodLengths);
    if (avgPeriodLength < 3 || avgPeriodLength > 7) {
      score -= 20;
    }

    // 平均周期长度合理性 (30%)
    const avgCycleLength = this.calculateAverage(cycleLengths);
    if (avgCycleLength < 21 || avgCycleLength > 35) {
      score -= 20;
    }

    return Math.max(0, Math.round(score));
  }
}

/**
 * 显示格式化工具函数
 */
export class PeriodFormatter {
  /**
   * 格式化流量等级
   */
  static formatFlowLevel(level: FlowLevel | null): string {
    const levels = {
      Light: '轻量',
      Medium: '中等',
      Heavy: '大量',
    };
    return level ? levels[level] : '未记录';
  }

  /**
   * 格式化心情
   */
  static formatMood(mood: Mood | null): string {
    const moods = {
      Happy: '开心',
      Sad: '难过',
      Angry: '愤怒',
      Anxious: '焦虑',
      Calm: '平静',
      Irritable: '易怒',
    };
    return mood ? moods[mood] : '未记录';
  }

  /**
   * 格式化运动强度
   */
  static formatExerciseIntensity(intensity: ExerciseIntensity): string {
    const intensities = {
      None: '无运动',
      Light: '轻度运动',
      Medium: '中度运动',
      Heavy: '高强度运动',
    };
    return intensities[intensity];
  }

  /**
   * 格式化强度等级
   */
  static formatIntensity(intensity: Intensity): string {
    const intensities = {
      Light: '轻度',
      Medium: '中度',
      Heavy: '重度',
    };
    return intensities[intensity];
  }

  /**
   * 格式化经期阶段
   */
  static formatPhase(phase: PeriodPhase): string {
    const phases = {
      Menstrual: '经期',
      Follicular: '卵泡期',
      Ovulation: '排卵期',
      Luteal: '黄体期',
    };
    return phases[phase];
  }

  /**
   * 格式化持续时间
   */
  static formatDuration(days: number): string {
    if (days === 1) return '1天';
    return `${days}天`;
  }

  /**
   * 格式化周期描述
   */
  static formatCycleDescription(cycleLength: number): string {
    if (cycleLength === 0) return '首次记录';
    if (cycleLength < 21) return `${cycleLength}天 (偏短)`;
    if (cycleLength > 35) return `${cycleLength}天 (偏长)`;
    return `${cycleLength}天`;
  }

  /**
   * 格式化规律性评分
   */
  static formatRegularityScore(score: number): string {
    if (score >= 90) return '非常规律';
    if (score >= 80) return '很规律';
    if (score >= 70) return '比较规律';
    if (score >= 60) return '一般规律';
    if (score >= 50) return '不太规律';
    return '不规律';
  }

  /**
   * 格式化健康评分
   */
  static formatHealthScore(score: number): {
    level: string;
    color: string;
    description: string;
  } {
    if (score >= 90) {
      return {
        level: '优秀',
        color: 'green',
        description: '经期健康状况很好，请继续保持',
      };
    } else if (score >= 80) {
      return {
        level: '良好',
        color: 'blue',
        description: '经期健康状况良好，注意保持规律',
      };
    } else if (score >= 70) {
      return {
        level: '一般',
        color: 'yellow',
        description: '经期健康状况一般，建议关注生活习惯',
      };
    } else if (score >= 60) {
      return {
        level: '需要改善',
        color: 'orange',
        description: '经期健康需要改善，建议调整生活方式',
      };
    } else {
      return {
        level: '需要关注',
        color: 'red',
        description: '经期健康需要关注，建议咨询医生',
      };
    }
  }
}

/**
 * 数据验证工具函数
 */
export class PeriodValidator {
  /**
   * 验证日期格式
   */
  static isValidDate(dateStr: string): boolean {
    const dateObj = new Date(dateStr);
    const isValidDateObj = dateObj instanceof Date && !isNaN(dateObj.getTime());
    const matchesFormat = /^\d{4}-\d{2}-\d{2}$/.test(dateStr);
    return isValidDateObj && matchesFormat;
  }

  /**
   * 验证日期范围
   */
  static isValidDateRange(startDate: string, endDate: string): boolean {
    if (!this.isValidDate(startDate) || !this.isValidDate(endDate)) {
      return false;
    }
    return new Date(startDate) <= new Date(endDate);
  }

  /**
   * 验证经期长度
   */
  static isValidPeriodLength(startDate: string, endDate: string): boolean {
    if (!this.isValidDateRange(startDate, endDate)) return false;

    const days = DateUtils.daysBetween(startDate, endDate) + 1;
    return days >= 1 && days <= 14;
  }

  /**
   * 验证周期长度
   */
  static isValidCycleLength(days: number): boolean {
    return days >= 15 && days <= 60;
  }

  /**
   * 验证经期记录重叠
   */
  static hasOverlap(
    newRecord: {startDate: string; endDate: string},
    existingRecords: PeriodRecords[],
  ): boolean {
    const newStart = new Date(newRecord.startDate);
    const newEnd = new Date(newRecord.endDate);

    return existingRecords.some((record) => {
      const existingStart = new Date(record.startDate);
      const existingEnd = new Date(record.endDate);

      return newStart <= existingEnd && newEnd >= existingStart;
    });
  }

  /**
   * 验证数据完整性
   */
  static validatePeriodRecord(record: Partial<PeriodRecords>): {
    valid: boolean;
    errors: string[];
  } {
    const errors: string[] = [];

    if (!record.startDate) {
      errors.push('开始日期不能为空');
    } else if (!this.isValidDate(record.startDate)) {
      errors.push('开始日期格式不正确');
    }

    if (!record.endDate) {
      errors.push('结束日期不能为空');
    } else if (!this.isValidDate(record.endDate)) {
      errors.push('结束日期格式不正确');
    }

    if (record.startDate && record.endDate) {
      if (!this.isValidDateRange(record.startDate, record.endDate)) {
        errors.push('结束日期不能早于开始日期');
      }
      if (!this.isValidPeriodLength(record.startDate, record.endDate)) {
        errors.push('经期长度不合理（应在1-14天之间）');
      }
    }

    return {
      valid: errors.length === 0,
      errors,
    };
  }

  /**
   * 验证日常记录
   */
  static validateDailyRecord(record: Partial<PeriodDailyRecords>): {
    valid: boolean;
    errors: string[];
  } {
    const errors: string[] = [];

    if (!record.date) {
      errors.push('日期不能为空');
    } else if (!this.isValidDate(record.date)) {
      errors.push('日期格式不正确');
    } else if (new Date(record.date) > new Date()) {
      errors.push('日期不能超过今天');
    }

    if (!record.diet || record.diet.trim() === '') {
      errors.push('饮食记录不能为空');
    }

    if (
      record.waterIntake !== undefined &&
      (record.waterIntake < 0 || record.waterIntake > 5000)
    ) {
      errors.push('饮水量应在0-5000ml之间');
    }

    if (
      record.sleepHours !== undefined &&
      (record.sleepHours < 0 || record.sleepHours > 24)
    ) {
      errors.push('睡眠时间应在0-24小时之间');
    }

    if (record.notes && record.notes.length > 500) {
      errors.push('备注不能超过500个字符');
    }

    return {
      valid: errors.length === 0,
      errors,
    };
  }
}

/**
 * 导入导出工具函数
 */
export class PeriodDataManager {
  /**
   * 导出数据为JSON
   */
  static exportToJSON(data: {
    periodRecords: PeriodRecords[];
    dailyRecords: PeriodDailyRecords[];
    settings: any;
  }): void {
    const exportData = {
      ...data,
      exportDate: new Date().toISOString(),
      version: '1.0',
    };

    const blob = new Blob([JSON.stringify(exportData, null, 2)], {
      type: 'application/json',
    });

    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `period-data-${DateUtils.today()}.json`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  }

  /**
   * 验证导入数据格式
   */
  static validateImportData(data: any): {valid: boolean; errors: string[]} {
    const errors: string[] = [];

    if (typeof data !== 'object' || data === null) {
      errors.push('数据格式不正确');
      return {valid: false, errors};
    }

    if (!Array.isArray(data.periodRecords)) {
      errors.push('经期记录数据格式不正确');
    }

    if (!Array.isArray(data.dailyRecords)) {
      errors.push('日常记录数据格式不正确');
    }

    // 验证记录格式
    if (data.periodRecords && Array.isArray(data.periodRecords)) {
      data.periodRecords.forEach((record: any, index: number) => {
        const validation = PeriodValidator.validatePeriodRecord(record);
        if (!validation.valid) {
          errors.push(`经期记录${index + 1}: ${validation.errors.join(', ')}`);
        }
      });
    }

    return {
      valid: errors.length === 0,
      errors,
    };
  }

  /**
   * 生成统计报告
   */
  static generateReport(
    periodRecords: PeriodRecords[],
    dailyRecords: PeriodDailyRecords[],
  ): string {
    const sortedRecords = [...periodRecords].sort(
      (a, b) =>
        new Date(a.startDate).getTime() - new Date(b.startDate).getTime(),
    );

    const cycleLengths = sortedRecords
      .slice(1)
      .map((record, index) =>
        PeriodCalculator.calculateCycleLength(record, sortedRecords[index]),
      );

    const periodLengths = sortedRecords.map((record) =>
      PeriodCalculator.calculatePeriodLength(record),
    );

    const avgCycleLength = PeriodAnalyzer.calculateAverage(cycleLengths);
    const avgPeriodLength = PeriodAnalyzer.calculateAverage(periodLengths);
    const regularity = PeriodAnalyzer.calculateRegularityScore(cycleLengths);
    const healthScore = PeriodAnalyzer.calculateHealthScore(
      cycleLengths,
      periodLengths,
      dailyRecords,
    );

    return `
经期健康报告
============

基础统计
--------
总记录数: ${sortedRecords.length}
平均周期长度: ${avgCycleLength.toFixed(1)}天
平均经期长度: ${avgPeriodLength.toFixed(1)}天
周期规律性: ${PeriodFormatter.formatRegularityScore(regularity)} (${regularity}%)
健康评分: ${PeriodFormatter.formatHealthScore(healthScore).level} (${healthScore}分)

最近记录
--------
${sortedRecords
  .slice(-5)
  .map(
    (record) =>
      `${DateUtils.formatDateRange(record.startDate, record.endDate)} (${PeriodCalculator.calculatePeriodLength(record)}天)`,
  )
  .join('\n')}

生成时间: ${DateUtils.formatChineseDate(DateUtils.today())}
    `.trim();
  }
}
