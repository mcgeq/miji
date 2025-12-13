/**
 * 经期工具函数统一导出
 *
 * 组织结构：
 * - 日期工具：PeriodDateUtils
 * - 格式化：PeriodFormatter
 * - 验证：PeriodValidator
 * - 数据管理：PeriodDataManager
 * - 健康提示：HealthTipsManager
 * - 计算工具：PeriodCalculator
 * - 分析工具：PeriodAnalyzer
 *
 * @example
 * // 使用工具类
 * import { PeriodCalculator, PeriodAnalyzer } from './utils';
 * const cycleLength = PeriodCalculator.calculateCycleLength(records);
 *
 * @example
 * // 计算持续天数
 * import { DateUtils } from '@/utils/date';
 * const duration = DateUtils.daysBetweenInclusive(startDate, endDate);
 */

export {
  type AnalysisResult,
  // 类型定义
  type HealthTip,
  HealthTipsManager,
  PeriodAnalyzer,
  PeriodCalculator,
  PeriodDataManager,
  // 工具类
  PeriodDateUtils,
  PeriodFormatter,
  PeriodValidator,
  type PredictionResult,
} from './periodUtils';
