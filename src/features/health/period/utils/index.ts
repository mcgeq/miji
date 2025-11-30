/**
 * 经期工具函数统一导出
 * 
 * 组织结构：
 * - 基础计算：calculatePeriodDuration
 * - 日期工具：PeriodDateUtils
 * - 格式化：PeriodFormatter
 * - 验证：PeriodValidator
 * - 数据管理：PeriodDataManager
 * - 健康提示：HealthTipsManager
 * - 计算工具：PeriodCalculator
 * - 分析工具：PeriodAnalyzer
 * 
 * @example
 * // 基础计算
 * import { calculatePeriodDuration } from './utils';
 * 
 * @example
 * // 使用工具类
 * import { PeriodCalculator, PeriodAnalyzer } from './utils';
 * const cycleLength = PeriodCalculator.calculateCycleLength(records);
 */

export {
  // 基础函数
  calculatePeriodDuration,
  
  // 类型定义
  type HealthTip,
  type AnalysisResult,
  type PredictionResult,
  
  // 工具类
  PeriodDateUtils,
  PeriodFormatter,
  PeriodValidator,
  PeriodDataManager,
  HealthTipsManager,
  PeriodCalculator,
  PeriodAnalyzer,
} from './periodUtils';
