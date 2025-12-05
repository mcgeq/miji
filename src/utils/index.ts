/**
 * 工具函数统一导出
 *
 * 提供统一的导入入口，方便使用工具函数
 *
 * @example
 * // 推荐：从专门的模块导入
 * import { deepClone } from '@/utils/objectUtils';
 * import { globalCache } from '@/utils/cache';
 *
 * @example
 * // 也可以：从统一入口导入
 * import { deepClone, globalCache } from '@/utils';
 */

// ==================== 数据处理 ====================

/**
 * 数组操作工具
 *
 * 完整导出请使用: import * as ArrayUtils from '@/utils/arrayUtils'
 */
export {
  // 集合操作
  arrayDifference,
  arrayIntersection,
  averageArray,
  averageBy,
  // 其他
  chunkArray,
  // 过滤
  compactArray,
  flattenArray,
  getPaginationInfo,
  // 分组和分区
  groupArrayBy,
  maxBy,
  maxValue,
  minBy,
  minValue,
  paginateArray,
  partitionArray,
  randomElement,
  shuffleArray,
  // 截取
  skipFirst,
  // 排序
  sortArray,
  // 统计
  sumArray,
  sumBy,
  takeFirst,
  // 去重
  uniqueArray,
  uniqueArrayBy,
  // 合并
  zipArrays,
} from './arrayUtils';
/**
 * 差异比较工具
 */
export {
  type DiffOptions,
  type DiffResult,
  deepDiff,
  UNCHANGED,
} from './diff';
/**
 * 对象操作工具
 *
 * 完整导出请使用: import * as ObjectUtils from '@/utils/objectUtils'
 */
export {
  // 深拷贝和合并
  deepClone,
  // 深度比较
  deepEqual,
  deepMerge,
  // 对象扁平化
  flattenObject,
  // 对象差异
  getObjectDiff,
  // 空值检查
  isEmptyValue,
  omitFields,
  // 字段选择
  pickFields,
  // 安全更新
  safeUpdate,
  // 对象转换
  transformKeys,
  transformValues,
  // 反扁平化
  unflattenObject,
} from './objectUtils';

// ==================== 字符串处理 ====================

/**
 * 文本清理工具
 */
export {
  escapeHTML,
  sanitizeInput,
  unescapeHTML,
} from './sanitize';
/**
 * 字符串转换工具
 */
export {
  lowercaseFirstLetter,
  toCamelCase,
  toSnakeCase,
  toSnakeCaseObject,
} from './string';

// ==================== 缓存系统 ====================

/**
 * 缓存系统
 *
 * 完整导出请使用: import * as Cache from '@/utils/cache'
 */
export {
  apiCache,
  type CacheEntry,
  CacheResult,
  cacheKeys,
  createLRUCache,
  createRefreshableCache,
  createTTLCache,
  // 全局实例
  globalCache,
  invalidateCaches,
  // 函数缓存
  memoizeFunction,
  onceFunction,
  stopCacheCleanup,
  // 缓存类
  TTLCache,
  // 类型
  type TTLCacheOptions,
} from './cache';

// ==================== 业务逻辑 ====================

/**
 * 重复周期工具
 */
export {
  buildRepeatPeriod,
  getRepeatTypeName,
} from './business/repeat';

/**
 * 交易相关
 */
export { isInstallmentTransaction } from './transaction';

/**
 * 用户相关
 */
export { toAuthUser } from './user';

// ==================== 数据导出 ====================

/**
 * 导出工具
 */
export {
  exportSplitRecords,
  exportToCSV,
  exportToCSVWithMapping,
  exportToExcel,
  exportTransactions,
  formatAmountForExport,
  formatDateForExport,
} from './export';

// ==================== API和网络 ====================

/**
 * API 辅助工具
 */
export {
  type ApiError,
  cachedApiCall,
  handleApiError,
  type LoadingState,
  requestDeduplicator,
  safeApiCall,
  useLoadingState,
} from './apiHelper';

// ==================== 日期时间 ====================

/**
 * 日期工具
 */
export { DateUtils } from './date';

// ==================== 通用工具 ====================

/**
 * 调试日志
 */
export { Lg } from './debugLog';
/**
 * 平台检测
 */
export {
  isDesktop,
  isMobile,
  isTauri,
} from './platform';
/**
 * Toast 提示
 */
export { toast } from './toast';
/**
 * UUID 生成
 */
export { uuid } from './uuid';

// ==================== 注意事项 ====================

/**
 * 使用建议：
 *
 * 1. 优先从专门的模块导入，避免打包冗余代码
 *    ✅ import { deepClone } from '@/utils/objectUtils'
 *    ⚠️ import { deepClone } from '@/utils'
 *
 * 2. 需要多个相关函数时，使用命名空间导入
 *    ✅ import * as ObjectUtils from '@/utils/objectUtils'
 *    ✅ ObjectUtils.deepClone(obj)
 *
 * 3. 使用全局缓存和工具时，推荐直接导入
 *    ✅ import { globalCache, toast, Lg } from '@/utils'
 *
 * 4. Tree-shaking 友好：所有导出都支持按需引入
 */
