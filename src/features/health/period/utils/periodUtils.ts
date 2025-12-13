import type { LucideIcon } from 'lucide-vue-next';
import {
  Activity,
  Apple,
  Bath,
  Battery,
  Bed,
  BedSingle,
  Bike,
  Brain,
  Cookie,
  CupSoda,
  Droplet,
  Drumstick,
  Dumbbell,
  Fish,
  Flame,
  Flower,
  Frown,
  HandHeart,
  Heart,
  Leaf,
  Moon,
  Move,
  Music,
  Pill,
  Salad,
  Soup,
  Sun,
  Thermometer,
  ThermometerSun,
  Users,
  Wheat,
  WheatOff,
} from 'lucide-vue-next';
import type { ExerciseIntensity, FlowLevel, Intensity } from '@/schema/common';
import type { Mood, PeriodDailyRecords, PeriodPhase, PeriodRecords } from '@/schema/health/period';
import { DateUtils } from '@/utils/date';

type PeriodCategory = 'Diet' | 'Exercise' | 'Sleep' | 'Care' | 'Mood';

// Define tip structure
export interface HealthTip {
  id: number;
  icon: LucideIcon; // lucide-vue-next icon component
  text: string;
  priority?: number;
  category?: PeriodCategory;
}

/**
 * 分析结果接口
 */
export interface AnalysisResult {
  regularityScore: number;
  healthScore: number;
  averageCycleLength: number;
  averagePeriodLength: number;
  cycleStdDev: number;
  periodStdDev: number;
  trend: 'stable' | 'increasing' | 'decreasing';
  outliers: number[];
  recommendations: string[];
}

/**
 * 预测结果接口
 */
export interface PredictionResult {
  nextPeriodDate: string;
  ovulationDate: string;
  fertileWindowStart: string;
  fertileWindowEnd: string;
  confidence: number;
  daysUntilNext: number;
}

/**
 * 分析报告的返回类型
 */
export interface AnalysisResult {
  regularityScore: number; // 规律性评分
  healthScore: number; // 健康评分
  averageCycleLength: number; // 平均周期长度
  averagePeriodLength: number; // 平均经期长度
  trend: 'stable' | 'increasing' | 'decreasing'; // 变化趋势
  trendSlope: number; // 趋势斜率
  outliers: number[]; // 异常周期
  symptomFrequency: Record<string, Record<string, number>>; // 症状频率
  recommendations: string[]; // 健康建议
}

/**
 * 日期相关工具函数
 */
export const PeriodDateUtils = {
  /**
   * 格式化日期为中文
   */
  formatChineseDate(dateStr: string): string {
    const date = new Date(dateStr);
    const year = date.getFullYear();
    const month = date.getMonth() + 1;
    const day = date.getDate();
    const weekDay = ['日', '一', '二', '三', '四', '五', '六'][date.getDay()];

    return `${year}年${month}月${day}日 星期${weekDay}`;
  },

  /**
   * 格式化日期范围
   */
  formatDateRange(startDate: string, endDate: string): string {
    const start = new Date(startDate);
    const end = new Date(endDate);

    if (start.getFullYear() !== end.getFullYear()) {
      return `${start.getFullYear()}年${start.getMonth() + 1}月${start.getDate()}日 - ${end.getFullYear()}年${end.getMonth() + 1}月${end.getDate()}日`;
    }

    if (start.getMonth() !== end.getMonth()) {
      return `${start.getMonth() + 1}月${start.getDate()}日 - ${end.getMonth() + 1}月${end.getDate()}日`;
    }

    return `${start.getMonth() + 1}月${start.getDate()}日 - ${end.getDate()}日`;
  },

  /**
   * 获取月份的第一天和最后一天
   */
  getMonthRange(year: number, month: number): { start: string; end: string } {
    const start = new Date(year, month - 1, 1);
    const end = new Date(year, month, 0);

    return {
      start: start.toISOString().split('T')[0],
      end: end.toISOString().split('T')[0],
    };
  },

  /**
   * 判断是否为同一天
   */
  isSameDay(date1: string, date2: string): boolean {
    return date1 === date2;
  },

  /**
   * 获取相对日期描述
   */
  getRelativeDate(dateStr: string): string {
    const today = new Date();
    const yesterday = new Date(today);
    yesterday.setDate(yesterday.getDate() - 1);
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);

    if (PeriodDateUtils.isSameDay(dateStr, today.toISOString().split('T')[0])) {
      return '今天';
    }
    if (PeriodDateUtils.isSameDay(dateStr, yesterday.toISOString().split('T')[0])) {
      return '昨天';
    }
    if (PeriodDateUtils.isSameDay(dateStr, tomorrow.toISOString().split('T')[0])) {
      return '明天';
    }

    const daysDiff = DateUtils.daysBetween(today.toISOString().split('T')[0], dateStr);
    if (daysDiff > 0) {
      return `${daysDiff}天后`;
    }
    return `${Math.abs(daysDiff)}天前`;
  },

  /**
   * 获取日期范围内的所有日期
   */
  getDateRange(startDate: string, endDate: string): string[] {
    const dates: string[] = [];
    const start = new Date(startDate);
    const end = new Date(endDate);

    let current = new Date(start);
    while (current <= end) {
      dates.push(current.toISOString().split('T')[0]);
      current = new Date(current);
      current.setDate(current.getDate() + 1);
    }

    return dates;
  },

  /**
   * 检查日期是否在范围内
   */
  isDateInRange(date: string, startDate: string, endDate: string): boolean {
    const target = new Date(date);
    const start = new Date(startDate);
    const end = new Date(endDate);
    return target >= start && target <= end;
  },
} as const;

/**
 * 显示格式化工具函数
 */
export const PeriodFormatter = {
  /**
   * 格式化流量等级
   */
  formatFlowLevel(level: FlowLevel | null): string {
    const levels = {
      Light: '轻量',
      Medium: '中等',
      Heavy: '大量',
    };
    return level ? levels[level] : '未记录';
  },

  /**
   * 格式化心情
   */
  formatMood(mood: Mood | null): string {
    const moods = {
      Happy: '开心',
      Sad: '难过',
      Angry: '愤怒',
      Anxious: '焦虑',
      Calm: '平静',
      Irritable: '易怒',
    };
    return mood ? moods[mood] : '未记录';
  },

  /**
   * 格式化运动强度
   */
  formatExerciseIntensity(intensity: ExerciseIntensity): string {
    const intensities = {
      None: '无运动',
      Light: '轻度运动',
      Medium: '中度运动',
      Heavy: '高强度运动',
    };
    return intensities[intensity];
  },

  /**
   * 格式化强度等级
   */
  formatIntensity(intensity: Intensity): string {
    const intensities = {
      Light: '轻度',
      Medium: '中度',
      Heavy: '重度',
    };
    return intensities[intensity];
  },

  /**
   * 格式化经期阶段
   */
  formatPhase(phase: PeriodPhase): string {
    const phases = {
      Menstrual: '经期',
      Follicular: '卵泡期',
      Ovulation: '排卵期',
      Luteal: '黄体期',
    };
    return phases[phase];
  },

  /**
   * 格式化持续时间
   */
  formatDuration(days: number): string {
    if (days === 1) return '1天';
    return `${days}天`;
  },

  /**
   * 格式化周期描述
   */
  formatCycleDescription(cycleLength: number): string {
    if (cycleLength === 0) return '首次记录';
    if (cycleLength < 21) return `${cycleLength}天 (偏短)`;
    if (cycleLength > 35) return `${cycleLength}天 (偏长)`;
    return `${cycleLength}天`;
  },

  /**
   * 格式化规律性评分
   */
  formatRegularityScore(score: number): string {
    if (score >= 90) return '非常规律';
    if (score >= 80) return '很规律';
    if (score >= 70) return '比较规律';
    if (score >= 60) return '一般规律';
    if (score >= 50) return '不太规律';
    return '不规律';
  },

  /**
   * 格式化健康评分
   */
  formatHealthScore(score: number): {
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
    }
    if (score >= 80) {
      return {
        level: '良好',
        color: 'blue',
        description: '经期健康状况良好，注意保持规律',
      };
    }
    if (score >= 70) {
      return {
        level: '一般',
        color: 'yellow',
        description: '经期健康状况一般，建议关注生活习惯',
      };
    }
    if (score >= 60) {
      return {
        level: '需要改善',
        color: 'orange',
        description: '经期健康需要改善，建议调整生活方式',
      };
    }
    return {
      level: '需要关注',
      color: 'red',
      description: '经期健康需要关注，建议咨询医生',
    };
  },
} as const;

/**
 * 数据验证工具函数
 */
export const PeriodValidator = {
  /**
   * 验证日期格式
   */
  isValidDate(dateStr: string): boolean {
    const dateObj = new Date(dateStr);
    const isValidDateObj = dateObj instanceof Date && !Number.isNaN(dateObj.getTime());
    const matchesFormat = /^\d{4}-\d{2}-\d{2}$/.test(dateStr);
    return isValidDateObj && matchesFormat;
  },

  /**
   * 验证日期范围
   */
  isValidDateRange(startDate: string, endDate: string): boolean {
    if (!(PeriodValidator.isValidDate(startDate) && PeriodValidator.isValidDate(endDate))) {
      return false;
    }
    return new Date(startDate) <= new Date(endDate);
  },

  /**
   * 验证经期长度
   */
  isValidPeriodLength(startDate: string, endDate: string): boolean {
    if (!PeriodValidator.isValidDateRange(startDate, endDate)) return false;

    const days = DateUtils.daysBetween(startDate, endDate) + 1;
    return days >= 1 && days <= 14;
  },

  /**
   * 验证周期长度
   */
  isValidCycleLength(days: number): boolean {
    return days >= 15 && days <= 60;
  },

  /**
   * 验证经期记录重叠
   */
  hasOverlap(
    newRecord: { startDate: string; endDate: string },
    existingRecords: PeriodRecords[],
  ): boolean {
    const newStart = new Date(newRecord.startDate);
    const newEnd = new Date(newRecord.endDate);

    return existingRecords.some(record => {
      const existingStart = new Date(record.startDate);
      const existingEnd = new Date(record.endDate);

      return newStart <= existingEnd && newEnd >= existingStart;
    });
  },

  /**
   * 验证数据完整性
   */
  validatePeriodRecord(record: Partial<PeriodRecords>): {
    valid: boolean;
    errors: string[];
  } {
    const errors: string[] = [];

    if (!record.startDate) {
      errors.push('开始日期不能为空');
    } else if (!PeriodValidator.isValidDate(record.startDate)) {
      errors.push('开始日期格式不正确');
    }

    if (!record.endDate) {
      errors.push('结束日期不能为空');
    } else if (!PeriodValidator.isValidDate(record.endDate)) {
      errors.push('结束日期格式不正确');
    }

    if (record.startDate && record.endDate) {
      if (!PeriodValidator.isValidDateRange(record.startDate, record.endDate)) {
        errors.push('结束日期不能早于开始日期');
      }
      if (!PeriodValidator.isValidPeriodLength(record.startDate, record.endDate)) {
        errors.push('经期长度不合理（应在1-14天之间）');
      }
    }

    return {
      valid: errors.length === 0,
      errors,
    };
  },

  /**
   * 验证日常记录
   */
  validateDailyRecord(record: Partial<PeriodDailyRecords>): {
    valid: boolean;
    errors: string[];
  } {
    const errors: string[] = [];

    if (!record.date) {
      errors.push('日期不能为空');
    } else if (!PeriodValidator.isValidDate(record.date)) {
      errors.push('日期格式不正确');
    } else if (new Date(record.date) > new Date()) {
      errors.push('日期不能超过今天');
    }

    if (!record.diet || record.diet.trim() === '') {
      errors.push('饮食记录不能为空');
    }

    if (record.waterIntake !== undefined && (record.waterIntake < 0 || record.waterIntake > 5000)) {
      errors.push('饮水量应在0-5000ml之间');
    }

    if (record.sleepHours !== undefined && (record.sleepHours < 0 || record.sleepHours > 24)) {
      errors.push('睡眠时间应在0-24小时之间');
    }

    if (record.notes && record.notes.length > 500) {
      errors.push('备注不能超过500个字符');
    }

    return {
      valid: errors.length === 0,
      errors,
    };
  },
} as const;

/**
 * 导入导出工具函数
 */
export const PeriodDataManager = {
  /**
   * 导出数据为JSON
   */
  exportToJSON(data: {
    periodRecords: PeriodRecords[];
    dailyRecords: PeriodDailyRecords[];
    settings: Record<string, unknown>;
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
    a.download = `period-data-${DateUtils.getTodayDate()}.json`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  },

  /**
   * 验证导入数据格式
   */
  validateImportData(data: unknown): { valid: boolean; errors: string[] } {
    const errors: string[] = [];

    if (typeof data !== 'object' || data === null) {
      errors.push('数据格式不正确');
      return { valid: false, errors };
    }

    const importData = data as Record<string, unknown>;

    if (!Array.isArray(importData.periodRecords)) {
      errors.push('经期记录数据格式不正确');
    }

    if (!Array.isArray(importData.dailyRecords)) {
      errors.push('日常记录数据格式不正确');
    }

    // 验证记录格式
    if (importData.periodRecords && Array.isArray(importData.periodRecords)) {
      importData.periodRecords.forEach((record: unknown, index: number) => {
        const validation = PeriodValidator.validatePeriodRecord(record as Partial<PeriodRecords>);
        if (!validation.valid) {
          errors.push(`经期记录${index + 1}: ${validation.errors.join(', ')}`);
        }
      });
    }

    return {
      valid: errors.length === 0,
      errors,
    };
  },

  /**
   * 生成统计报告
   */
  generateReport(periodRecords: PeriodRecords[], dailyRecords: PeriodDailyRecords[]): string {
    const sortedRecords = [...periodRecords].sort(
      (a, b) => new Date(a.startDate).getTime() - new Date(b.startDate).getTime(),
    );

    const cycleLengths = sortedRecords
      .slice(1)
      .map((record, index) => PeriodCalculator.calculateCycleLength(record, sortedRecords[index]));

    const periodLengths = sortedRecords.map(record =>
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
    record =>
      `${PeriodDateUtils.formatDateRange(record.startDate, record.endDate)} (${PeriodCalculator.calculatePeriodLength(record)}天)`,
  )
  .join('\n')}

生成时间: ${PeriodDateUtils.formatChineseDate(DateUtils.getTodayDate())}
    `.trim();
  },
} as const;

/**
 * 健康提示管理工具类
 */
// 通用健康提示
const GENERAL_TIPS: HealthTip[] = [
  {
    id: 1,
    icon: Droplet,
    text: '每天喝足够的水有助于缓解经期不适',
    priority: 1,
    category: 'Diet',
  },
  {
    id: 2,
    icon: Moon,
    text: '保持规律的睡眠时间对月经周期很重要',
    priority: 2,
    category: 'Sleep',
  },
  {
    id: 3,
    icon: Apple,
    text: '富含铁质的食物有助于补充经期流失的营养',
    priority: 3,
    category: 'Diet',
  },
  {
    id: 4,
    icon: Activity,
    text: '适度的运动可以缓解经期症状',
    priority: 4,
    category: 'Exercise',
  },
  {
    id: 5,
    icon: Heart,
    text: '保持良好的心情有助于缓解经期不适',
    priority: 5,
    category: 'Mood',
  },
  {
    id: 6,
    icon: Sun,
    text: '适当的阳光照射有助于维生素D的合成',
    priority: 6,
    category: 'Care',
  },
];

// 经期阶段特定提示
const PHASE_SPECIFIC_TIPS: Record<PeriodPhase, HealthTip[]> = {
  Menstrual: [
    {
      id: 101,
      icon: CupSoda,
      text: '多喝温水，避免冷饮',
      priority: 1,
      category: 'Diet',
    },
    {
      id: 102,
      icon: Bed,
      text: '充分休息，避免剧烈运动',
      priority: 2,
      category: 'Exercise',
    },
    {
      id: 103,
      icon: Flame,
      text: '注意保暖，特别是腹部和腰部',
      priority: 3,
      category: 'Care',
    },
    {
      id: 104,
      icon: BedSingle,
      text: '可以做一些轻柔的瑜伽或伸展运动',
      priority: 4,
      category: 'Exercise',
    },
    {
      id: 105,
      icon: Soup,
      text: '多吃温热的食物，少吃生冷食品',
      priority: 5,
      category: 'Diet',
    },
    {
      id: 106,
      icon: Bath,
      text: '温水泡脚或热敷可以缓解疼痛',
      priority: 6,
      category: 'Care',
    },
  ],
  Follicular: [
    {
      id: 201,
      icon: Dumbbell,
      text: '这是运动的好时机，可以进行有氧运动',
      priority: 1,
      category: 'Exercise',
    },
    {
      id: 202,
      icon: Salad,
      text: '多吃新鲜蔬菜和水果，补充维生素',
      priority: 2,
      category: 'Diet',
    },
    {
      id: 203,
      icon: Brain,
      text: '精力充沛的时期，适合学习和工作',
      priority: 3,
      category: 'Mood',
    },
    {
      id: 204,
      icon: Dumbbell,
      text: '可以进行力量训练，提高肌肉力量',
      priority: 4,
      category: 'Exercise',
    },
    {
      id: 205,
      icon: Fish,
      text: '适当摄入蛋白质，支持身体恢复',
      priority: 5,
      category: 'Diet',
    },
  ],
  Ovulation: [
    {
      id: 301,
      icon: HandHeart,
      text: '排卵期是受孕的最佳时机',
      priority: 1,
      category: 'Care',
    },
    {
      id: 302,
      icon: Droplet,
      text: '注意观察分泌物变化，了解身体状态',
      priority: 2,
      category: 'Care',
    },
    {
      id: 303,
      icon: Thermometer,
      text: '可以测量基础体温来确认排卵',
      priority: 3,
      category: 'Care',
    },
    {
      id: 304,
      icon: Bike,
      text: '保持适度运动，但避免过度疲劳',
      priority: 4,
      category: 'Exercise',
    },
    {
      id: 305,
      icon: Leaf,
      text: '多摄入叶酸和维生素E',
      priority: 5,
      category: 'Diet',
    },
  ],
  Luteal: [
    {
      id: 401,
      icon: Frown,
      text: '注意情绪变化，保持心情愉悦',
      priority: 1,
      category: 'Mood',
    },
    {
      id: 402,
      icon: Cookie,
      text: '可能会有食欲增加，注意控制饮食',
      priority: 2,
      category: 'Diet',
    },
    {
      id: 403,
      icon: Bed,
      text: '保证充足的睡眠，缓解疲劳',
      priority: 3,
      category: 'Sleep',
    },
    {
      id: 404,
      icon: Move,
      text: '进行轻度运动，如散步或慢跑',
      priority: 4,
      category: 'Exercise',
    },
    {
      id: 405,
      icon: Wheat,
      text: '减少盐分摄入，避免水肿',
      priority: 5,
      category: 'Diet',
    },
    {
      id: 406,
      icon: Flower,
      text: '可以尝试冥想或深呼吸来放松',
      priority: 6,
      category: 'Mood',
    },
  ],
};

// 基于症状的特殊提示
const SYMPTOM_TIPS: Record<string, HealthTip[]> = {
  heavyFlow: [
    {
      id: 501,
      icon: Drumstick,
      text: '增加铁质摄入，预防贫血',
      priority: 1,
      category: 'Diet',
    },
    {
      id: 502,
      icon: Bed,
      text: '避免剧烈运动，多休息',
      priority: 2,
      category: 'Exercise',
    },
  ],
  cramps: [
    {
      id: 511,
      icon: ThermometerSun,
      text: '热敷腹部可以缓解痉挛',
      priority: 1,
      category: 'Care',
    },
    {
      id: 512,
      icon: Pill,
      text: '适量补充镁元素有助于肌肉放松',
      priority: 2,
      category: 'Diet',
    },
  ],
  moodSwings: [
    {
      id: 521,
      icon: Users,
      text: '与朋友交流，寻求情感支持',
      priority: 1,
      category: 'Mood',
    },
    {
      id: 522,
      icon: Music,
      text: '听音乐或做喜欢的事情来调节心情',
      priority: 2,
      category: 'Mood',
    },
  ],
  fatigue: [
    {
      id: 531,
      icon: Moon,
      text: '保证充足的睡眠，早睡早起',
      priority: 1,
      category: 'Sleep',
    },
    {
      id: 532,
      icon: Battery,
      text: '补充B族维生素，提升精力',
      priority: 2,
      category: 'Diet',
    },
  ],
  bloating: [
    {
      id: 541,
      icon: WheatOff,
      text: '减少盐分和糖分摄入',
      priority: 1,
      category: 'Diet',
    },
    {
      id: 542,
      icon: Move,
      text: '轻柔的散步有助于缓解腹胀',
      priority: 2,
      category: 'Exercise',
    },
  ],
};

export const HealthTipsManager = {
  /**
   * 根据当前阶段获取健康提示
   */
  getTipsForPhase(phase: PeriodPhase, maxTips = 3, includeGeneral = false): HealthTip[] {
    const phaseTips = PHASE_SPECIFIC_TIPS[phase] || [];
    const tips = [...phaseTips];

    // 如果需要包含通用提示
    if (includeGeneral) {
      tips.push(...GENERAL_TIPS);
    }

    // 按优先级排序并返回指定数量的提示
    return tips.sort((a, b) => (a.priority || 999) - (b.priority || 999)).slice(0, maxTips);
  },

  /**
   * 根据症状获取特殊提示
   */
  getTipsForSymptoms(symptoms: string[]): HealthTip[] {
    const tips: HealthTip[] = [];

    symptoms.forEach(symptom => {
      const symptomTips = SYMPTOM_TIPS[symptom];
      if (symptomTips) {
        tips.push(...symptomTips);
      }
    });

    return tips.sort((a, b) => (a.priority || 999) - (b.priority || 999));
  },

  /**
   * 根据分类获取提示
   */
  getTipsByCategory(category: HealthTip['category'], phase?: PeriodPhase): HealthTip[] {
    const allTips = [...GENERAL_TIPS];

    if (phase) {
      allTips.push(...(PHASE_SPECIFIC_TIPS[phase] || []));
    } else {
      // 包含所有阶段的提示
      Object.values(PHASE_SPECIFIC_TIPS).forEach(phaseTips => {
        allTips.push(...phaseTips);
      });
    }

    return allTips
      .filter(tip => tip.category === category)
      .sort((a, b) => (a.priority || 999) - (b.priority || 999));
  },

  /**
   * 获取个性化提示
   */
  getPersonalizedTips(
    phase: PeriodPhase,
    dailyRecord?: PeriodDailyRecords,
    preferences?: {
      categories?: HealthTip['category'][];
      excludeSymptoms?: string[];
      maxTips?: number;
    },
  ): HealthTip[] {
    const { categories, excludeSymptoms = [], maxTips = 3 } = preferences || {};

    // 获取阶段相关提示
    let tips = HealthTipsManager.getTipsForPhase(phase, 10, true);

    // 根据日常记录添加症状相关提示
    if (dailyRecord) {
      const symptoms: string[] = [];

      // 根据记录推断症状
      if (dailyRecord.flowLevel === 'Heavy') {
        symptoms.push('heavyFlow');
      }
      if (dailyRecord.mood === 'Sad' || dailyRecord.mood === 'Irritable') {
        symptoms.push('moodSwings');
      }
      if (dailyRecord.exerciseIntensity === 'None') {
        symptoms.push('fatigue');
      }
      // 可以根据其他字段推断更多症状

      const symptomTips = HealthTipsManager.getTipsForSymptoms(
        symptoms.filter(s => !excludeSymptoms.includes(s)),
      );
      tips.push(...symptomTips);
    }

    // 按分类过滤
    if (categories && categories.length > 0) {
      tips = tips.filter(tip => categories.includes(tip.category));
    }

    // 去重并按优先级排序
    const uniqueTips = tips.filter(
      (tip, index, arr) => arr.findIndex(t => t.id === tip.id) === index,
    );

    return uniqueTips.sort((a, b) => (a.priority || 999) - (b.priority || 999)).slice(0, maxTips);
  },

  /**
   * 获取随机提示
   */
  getRandomTips(count = 3): HealthTip[] {
    const allTips = [...GENERAL_TIPS, ...Object.values(PHASE_SPECIFIC_TIPS).flat()];

    const shuffled = [...allTips].sort(() => Math.random() - 0.5);
    return shuffled.slice(0, count);
  },

  /**
   * 添加自定义提示
   */
  addCustomTip(tip: Omit<HealthTip, 'id'>): HealthTip {
    const newTip: HealthTip = {
      ...tip,
      id: Date.now(), // 简单的ID生成
    };

    // 这里可以添加持久化逻辑
    return newTip;
  },
} as const;

/**
 * 经期计算工具函数
 */
export const PeriodCalculator = {
  /**
   * 计算经期长度
   */
  calculatePeriodLength(record: PeriodRecords): number {
    return DateUtils.daysBetween(record.startDate, record.endDate) + 1;
  },

  /**
   * 计算周期长度
   */
  calculateCycleLength(current: PeriodRecords, previous: PeriodRecords): number {
    return DateUtils.daysBetween(previous.startDate, current.startDate);
  },

  /**
   * 预测下次经期开始日期
   */
  predictNextPeriod(lastPeriod: PeriodRecords, averageCycleLength: number): string {
    return DateUtils.addDays(lastPeriod.startDate, averageCycleLength);
  },

  /**
   * 计算排卵日和相关信息
   */
  calculateOvulationInfo(
    nextPeriodDate: string,
    cycleLength = 28,
  ): {
    ovulationDate: string;
    fertileStart: string;
    fertileEnd: string;
    isValid: boolean;
    message?: string;
  } {
    // 初始化返回结果
    const result = {
      ovulationDate: '',
      fertileStart: '',
      fertileEnd: '',
      isValid: true,
      message: '',
    };

    // 验证输入有效性
    if (!DateUtils.isValidDate(nextPeriodDate)) {
      result.isValid = false;
      result.message = '无效的下次月经日期';
      return result;
    }

    if (typeof cycleLength !== 'number' || cycleLength < 14) {
      result.isValid = false;
      result.message = '周期长度必须为 ≥14 的整数';
      return result;
    }

    if (!Number.isInteger(cycleLength)) {
      result.isValid = false;
      result.message = '周期长度必须为整数';
      return result;
    }

    // 计算排卵日
    result.ovulationDate = DateUtils.addDays(nextPeriodDate, -14);

    // 计算排卵期范围（排卵日前5天到后1天）
    result.fertileStart = DateUtils.addDays(result.ovulationDate, -5);
    result.fertileEnd = DateUtils.addDays(result.ovulationDate, 1);

    return result;
  },

  /**
   * 计算易孕期
   */
  calculateFertileWindow(ovulationDate: string): {
    start: string;
    end: string;
  } {
    return {
      start: DateUtils.addDays(ovulationDate, -5),
      end: DateUtils.addDays(ovulationDate, 1),
    };
  },

  /**
   * 获取当前月经周期阶段
   */
  getCurrentPhase(
    lastPeriod: PeriodRecords,
    averageCycleLength: number,
    averagePeriodLength: number,
    currentDate: string = DateUtils.getTodayDate(),
  ): PeriodPhase {
    const daysSinceLastPeriod = DateUtils.daysBetween(lastPeriod.startDate, currentDate);

    if (daysSinceLastPeriod <= averagePeriodLength) {
      return 'Menstrual';
    }
    if (daysSinceLastPeriod <= averageCycleLength / 2 - 3) {
      return 'Follicular';
    }
    if (daysSinceLastPeriod <= averageCycleLength / 2 + 3) {
      return 'Ovulation';
    }
    return 'Luteal';
  },

  /**
   * 计算到下次经期的天数
   */
  daysUntilNextPeriod(
    nextPeriodDate: string,
    currentDate: string = DateUtils.getTodayDate(),
  ): number {
    return DateUtils.daysBetween(currentDate, nextPeriodDate);
  },

  /**
   * 判断指定日期是否在经期内
   */
  isInPeriod(date: string, periods: PeriodRecords[]): boolean {
    return periods.some(period => {
      const targetDate = new Date(date);
      const startDate = new Date(period.startDate);
      const endDate = new Date(period.endDate);
      return targetDate >= startDate && targetDate <= endDate;
    });
  },

  /**
   * 获取指定日期的经期记录
   */
  getPeriodForDate(date: string, periods: PeriodRecords[]): PeriodRecords | null {
    return (
      periods.find(period => {
        const targetDate = new Date(date);
        const startDate = new Date(period.startDate);
        const endDate = new Date(period.endDate);
        return targetDate >= startDate && targetDate <= endDate;
      }) || null
    );
  },

  /**
   * 生成完整的预测结果
   */
  generatePrediction(
    periods: PeriodRecords[],
    currentDate: string = DateUtils.getTodayDate(),
  ): PredictionResult {
    if (periods.length === 0) {
      return {
        nextPeriodDate: '',
        ovulationDate: '',
        fertileWindowStart: '',
        fertileWindowEnd: '',
        confidence: 0,
        daysUntilNext: 0,
      };
    }

    // 计算平均周期长度
    const cycleLengths = [];
    for (let i = 1; i < periods.length; i++) {
      cycleLengths.push(PeriodCalculator.calculateCycleLength(periods[i], periods[i - 1]));
    }

    const averageCycleLength =
      cycleLengths.length > 0
        ? Math.round(cycleLengths.reduce((sum, len) => sum + len, 0) / cycleLengths.length)
        : 28;

    const lastPeriod = periods[periods.length - 1];
    const nextPeriodDate = PeriodCalculator.predictNextPeriod(lastPeriod, averageCycleLength);
    const ovulationInfo = PeriodCalculator.calculateOvulationInfo(
      nextPeriodDate,
      averageCycleLength,
    );

    // 计算预测置信度
    const confidence = PeriodCalculator.calculatePredictionConfidence(cycleLengths);

    return {
      nextPeriodDate,
      ovulationDate: ovulationInfo.ovulationDate,
      fertileWindowStart: ovulationInfo.fertileStart,
      fertileWindowEnd: ovulationInfo.fertileEnd,
      confidence,
      daysUntilNext: PeriodCalculator.daysUntilNextPeriod(nextPeriodDate, currentDate),
    };
  },

  /**
   * 计算预测置信度
   */
  calculatePredictionConfidence(cycleLengths: number[]): number {
    if (cycleLengths.length < 2) return 50;

    const avg = cycleLengths.reduce((sum, len) => sum + len, 0) / cycleLengths.length;
    const variance =
      cycleLengths.reduce((sum, len) => sum + (len - avg) ** 2, 0) / cycleLengths.length;
    const standardDeviation = Math.sqrt(variance);

    // 标准差越小，置信度越高
    const confidence = Math.max(50, 100 - standardDeviation * 10);
    return Math.round(confidence);
  },
} as const;

/**
 * 数据分析工具函数
 */
export const PeriodAnalyzer = {
  /**
   * 计算周期规律性评分 (0-100)
   */
  calculateRegularityScore(cycleLengths: number[]): number {
    if (cycleLengths.length < 2) return 100;

    const variation = PeriodAnalyzer.calculateVariationCoefficient(cycleLengths);
    return Math.max(0, Math.round(100 - variation * 200));
  },

  /**
   * 分析趋势方向
   */
  analyzeTrend(values: number[], windowSize = 6): 'stable' | 'increasing' | 'decreasing' {
    if (values.length < windowSize * 2) return 'stable';

    const recent = values.slice(-windowSize);
    const earlier = values.slice(-windowSize * 2, -windowSize);

    const recentAvg = PeriodAnalyzer.calculateAverage(recent);
    const earlierAvg = PeriodAnalyzer.calculateAverage(earlier);
    const difference = recentAvg - earlierAvg;

    if (Math.abs(difference) < 1) return 'stable';
    return difference > 0 ? 'increasing' : 'decreasing';
  },

  /**
   * 识别异常值
   */
  identifyOutliers(values: number[], threshold = 2): number[] {
    const mean = PeriodAnalyzer.calculateAverage(values);
    const stdDev = PeriodAnalyzer.calculateStandardDeviation(values);

    return values.filter(value => Math.abs(value - mean) > threshold * stdDev);
  },

  /**
   * 计算健康评分
   */
  calculateHealthScore(
    cycleLengths: number[],
    periodLengths: number[],
    _dailyRecords: PeriodDailyRecords[],
  ): number {
    let score = 100;

    // 周期规律性 (40%)
    const cycleRegularity = PeriodAnalyzer.calculateRegularityScore(cycleLengths);
    score = score * 0.6 + cycleRegularity * 0.4;

    // 经期长度合理性 (30%)
    const avgPeriodLength = PeriodAnalyzer.calculateAverage(periodLengths);
    if (avgPeriodLength < 3 || avgPeriodLength > 7) {
      score -= 20;
    }

    // 平均周期长度合理性 (30%)
    const avgCycleLength = PeriodAnalyzer.calculateAverage(cycleLengths);
    if (avgCycleLength < 21 || avgCycleLength > 35) {
      score -= 20;
    }

    return Math.max(0, Math.round(score));
  },

  /**
   * 计算平均值
   */
  calculateAverage(values: number[]): number {
    if (values.length === 0) return 0;
    return values.reduce((sum, val) => sum + val, 0) / values.length;
  },

  /**
   * 计算标准差
   */
  calculateStandardDeviation(values: number[]): number {
    if (values.length === 0) return 0;
    const mean = PeriodAnalyzer.calculateAverage(values);
    const variance = values.reduce((sum, val) => sum + (val - mean) ** 2, 0) / values.length;
    return Math.sqrt(variance);
  },

  /**
   * 计算变异系数（标准差与平均值的比率）
   */
  calculateVariationCoefficient(values: number[]): number {
    if (values.length === 0) return 0;
    const mean = PeriodAnalyzer.calculateAverage(values);
    if (mean === 0) return 0; // 避免除以零
    const stdDev = PeriodAnalyzer.calculateStandardDeviation(values);
    return Number((stdDev / mean).toFixed(2));
  },

  /**
   * 检测异常周期（与平均值相差超过一个标准差）
   */
  detectOutliers(cycleLengths: number[]): number[] {
    const mean = PeriodAnalyzer.calculateAverage(cycleLengths);
    const stdDev = PeriodAnalyzer.calculateStandardDeviation(cycleLengths);
    return cycleLengths.filter(length => Math.abs(length - mean) > stdDev);
  },

  /**
   * 分析周期趋势（使用线性回归）
   */
  analyzeCycleTrend(cycleLengths: number[]): {
    slope: number;
    trend: 'stable' | 'increasing' | 'decreasing';
  } {
    if (cycleLengths.length < 2) return { slope: 0, trend: 'stable' };

    const n = cycleLengths.length;
    const xMean = (n * (n + 1)) / (2 * n);
    const yMean = PeriodAnalyzer.calculateAverage(cycleLengths);

    let numerator = 0;
    let denominator = 0;
    for (let i = 1; i <= n; i++) {
      numerator += (i - xMean) * (cycleLengths[i - 1] - yMean);
      denominator += (i - xMean) ** 2;
    }

    const slope = denominator !== 0 ? numerator / denominator : 0;

    let trend: 'stable' | 'increasing' | 'decreasing' = 'stable';
    if (slope > 0.5) trend = 'increasing';
    else if (slope < -0.5) trend = 'decreasing';

    return { slope: Number(slope.toFixed(2)), trend };
  },

  // /**
  //  * 分析症状与经期阶段的关系
  //  */
  // analyzeSymptomsByPhase(
  //   dailyRecords: PeriodDailyRecords[],
  //   stats: PeriodStats,
  // ): Record<string, Record<string, number>> {
  //   const symptomFrequency: Record<string, Record<string, number>> = {};
  //
  //   dailyRecords.forEach(record => {
  //     const phase = stats; // 假设 dailyRecords 中有 phase 字段
  //     if (!symptomFrequency[phase]) {
  //       symptomFrequency[phase] = {};
  //     }
  //     record.symptoms?.forEach(symptom => {
  //       symptomFrequency[phase][symptom]
  //         = (symptomFrequency[phase][symptom] || 0) + 1;
  //     });
  //   });
  //
  //   return symptomFrequency;
  // }

  /**
   * 评估健康风险
   */
  assessHealthRisk(cycleLengths: number[], periodLengths: number[]): string[] {
    const risks: string[] = [];
    const cycleVariation = PeriodAnalyzer.calculateVariationCoefficient(cycleLengths);
    const periodVariation = PeriodAnalyzer.calculateVariationCoefficient(periodLengths);

    if (cycleVariation > 0.2) {
      risks.push('周期变化较大，可能存在内分泌失调的风险。');
    }
    if (PeriodAnalyzer.calculateAverage(periodLengths) > 7) {
      risks.push('经期持续时间较长，建议咨询医生。');
    }
    if (PeriodAnalyzer.detectOutliers(cycleLengths).length > 2) {
      risks.push('存在多个异常周期，建议进行健康检查。');
    }

    if (periodVariation > 0.2) {
      risks.push('经期长度波动较大，建议注意生活规律并咨询医生。');
    }

    return risks;
  },

  /**
   * 生成经期数据分析报告
   */
  generateAnalysisReport(
    periods: PeriodRecords[],
    _dailyRecords: PeriodDailyRecords[],
  ): AnalysisResult {
    const cycleLengths = PeriodAnalyzer.calculateCycleLengths(periods);
    const periodLengths = periods.map(p => DateUtils.daysBetween(p.startDate, p.endDate) + 1);

    const cycleMean = PeriodAnalyzer.calculateAverage(cycleLengths);
    const cycleStdDev = PeriodAnalyzer.calculateStandardDeviation(cycleLengths);
    const cycleVariation = PeriodAnalyzer.calculateVariationCoefficient(cycleLengths);

    const periodMean = PeriodAnalyzer.calculateAverage(periodLengths);
    const periodStdDev = PeriodAnalyzer.calculateStandardDeviation(periodLengths);

    const outliers = PeriodAnalyzer.detectOutliers(cycleLengths);
    const trendAnalysis = PeriodAnalyzer.analyzeCycleTrend(cycleLengths);
    // const symptomAnalysis = this.analyzeSymptomsByPhase(dailyRecords);
    const healthRisks = PeriodAnalyzer.assessHealthRisk(cycleLengths, periodLengths);

    const recommendations: string[] = [];
    if (cycleVariation > 0.1) {
      recommendations.push('您的周期变化较大，建议关注生活规律。');
    }
    if (outliers.length > 0) {
      recommendations.push('存在异常周期，建议记录更多数据以确认趋势。');
    }
    if (healthRisks.length > 0) {
      recommendations.push(...healthRisks);
    }

    return {
      regularityScore: Math.max(0, 100 - cycleVariation * 100),
      healthScore: Math.max(0, 100 - outliers.length * 10),
      averageCycleLength: cycleMean,
      averagePeriodLength: periodMean,
      cycleStdDev,
      periodStdDev,
      trend: trendAnalysis.trend,
      trendSlope: trendAnalysis.slope,
      outliers,
      symptomFrequency: {},
      recommendations,
    };
  },

  /**
   * 计算周期长度
   */
  calculateCycleLengths(periods: PeriodRecords[]): number[] {
    const cycleLengths: number[] = [];
    for (let i = 1; i < periods.length; i++) {
      const currentStart = new Date(periods[i].startDate);
      const previousStart = new Date(periods[i - 1].startDate);
      const cycleLength = Math.ceil(
        (currentStart.getTime() - previousStart.getTime()) / (1000 * 60 * 60 * 24),
      );
      cycleLengths.push(cycleLength);
    }
    return cycleLengths;
  },
} as const;
