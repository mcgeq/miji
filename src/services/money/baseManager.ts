import { DateUtils } from '@/utils/date';
import { db } from '@/utils/dbUtils';
import { Lg } from '@/utils/debugLog';
import { uuid } from '@/utils/uuid';
import type {
  Currency,
  DateRange,
  OperationLog,
  OperationType,
  SortOptions,
} from '@/schema/common';

/**
 * 实体基础接口
 */
interface BaseEntity {
  serialNum?: string;
  createdAt?: string | null | undefined;
  updatedAt?: string | null | undefined;
}

export interface PagedResult<T> {
  rows: T[];
  totalCount: number;
  currentPage: number;
  pageSize: number;
  totalPages: number;
}

/**
 * 数据库操作错误类
 */
export class MoneyDbError extends Error {
  constructor(
    message: string,
    public operation: string,
    public entity: string,
    public originalError?: Error,
  ) {
    super(message);
    this.name = 'MoneyDbError';
  }
}

/**
 * 数据映射器抽象基类
 */
export abstract class BaseMapper<T extends BaseEntity> {
  protected abstract tableName: string;
  protected abstract entityName: string;

  // Convert boolean to SQLite-compatible 0/1
  protected toDbBoolean(value: boolean | undefined | null): number | undefined {
    if (value === undefined || value === null) return undefined;
    return value ? 1 : 0;
  }

  // Convert SQLite 0/1 to boolean
  protected fromDbBoolean(
    value: number | null | undefined,
  ): boolean | undefined {
    if (value === undefined || value === null) return undefined;
    return value === 1;
  }

  // List of boolean fields that need conversion
  protected getBooleanFields(): string[] {
    return [];
  }

  /**
   * 将对象字段转换为数据库字段格式
   */
  protected toSnakeCase(str: string): string {
    return str.replace(/[A-Z]/g, letter => `_${letter.toLowerCase()}`);
  }

  /**
   * 比较两个值是否相等
   */
  protected isEqual(a: any, b: any): boolean {
    if ((a === null && b === undefined) || (a === undefined && b === null)) {
      return true;
    }
    if (
      typeof a === 'object' &&
      typeof b === 'object' &&
      a !== null &&
      b !== null
    ) {
      return JSON.stringify(a) === JSON.stringify(b);
    }
    return a === b;
  }

  /**
   * 规范化值（null -> undefined）
   */
  protected normalizeValue<V>(value: V): V extends null ? undefined : V {
    return (value === null ? undefined : value) as V extends null
      ? undefined
      : V;
  }

  /**
   * 处理数据库错误
   */
  protected handleError(operation: string, error: unknown): never {
    const dbError = new MoneyDbError(
      `${this.entityName} ${operation} operation failed`,
      operation,
      this.entityName,
      error as Error,
    );
    Lg.e('MoneyDb', `${this.entityName} ${operation} failed:`, error);
    throw dbError;
  }

  /**
   * 构建WHERE子句和参数
   */
  protected buildWhereClause(filters: Record<string, any>): {
    clause: string;
    params: any[];
  } {
    const whereParts: string[] = [];
    const params: any[] = [];

    for (const [key, value] of Object.entries(filters)) {
      if (value !== undefined && value !== null) {
        if (key.includes('Range')) {
          this.appendRangeFilter(key, value, whereParts, params);
        } else {
          const dbField = this.toSnakeCase(key);
          whereParts.push(`${dbField} = ?`);
          params.push(value);
        }
      }
    }

    return {
      clause: whereParts.length > 0 ? `WHERE ${whereParts.join(' AND ')}` : '',
      params,
    };
  }

  protected keyBy<T>(array: T[], key: keyof T): Record<string, T> {
    return array.reduce(
      (acc, item) => {
        const keyValue = String(item[key]);
        acc[keyValue] = item;
        return acc;
      },
      {} as Record<string, T>,
    );
  }

  protected async getCurrencies(
    entiry: any[],
  ): Promise<Record<string, Currency>> {
    // 批量获取货币信息以提高性能
    const currencyCodes = [...new Set(entiry.map(a => a.currency))];
    const currencies = await db.select<Currency[]>(
      `SELECT * FROM currency WHERE code IN (${currencyCodes.map(() => '?').join(',')})`,
      currencyCodes,
      true,
    );

    return this.keyBy(currencies, 'code');
  }

  protected async recordOperationLog(
    operation: OperationType,
    recordId: string,
    changes?: Record<string, any>,
    snapshot?: any,
  ): Promise<void> {
    try {
      const actorId = '当前用户ID'; // 实际应从上下文中获取
      const deviceId = '设备ID'; // 实际应从设备信息获取
      const compressSnapshot = snapshot
        ? this.compressSnapshot(snapshot)
        : undefined;

      const log: OperationLog = {
        serial_num: uuid(38),
        recorded_at: DateUtils.getLocalISODateTimeWithOffset(),
        operation,
        table_name: this.tableName,
        record_id: recordId,
        actor_id: actorId,
        changes_json: changes ? JSON.stringify(changes) : undefined,
        snapshot_json: compressSnapshot
          ? JSON.stringify(compressSnapshot)
          : undefined,
        device_id: deviceId,
      };

      // 插入日志表（假设有operation_log表）
      await db.execute(
        `INSERT INTO operation_log 
      (serial_num, recorded_at, operation, target_table, record_id, actor_id, changes_json, snapshot_json, device_id)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          log.serial_num,
          log.recorded_at,
          log.operation,
          log.table_name,
          log.record_id,
          log.actor_id,
          log.changes_json,
          log.snapshot_json,
          log.device_id,
        ],
      );
    } catch (logError) {
      this.handleError('recordOperationLog', logError);
    }
  }

  protected detectChanges<T extends Record<string, any>>(
    oldObj: T | null | undefined,
    newObj: T | null | undefined,
  ): Partial<T> {
    const changes: Partial<T> = {};

    const safeOldObj = oldObj || ({} as T);
    const safeNewObj = newObj || ({} as T);

    const allKeys = new Set([
      ...Object.keys(safeOldObj),
      ...Object.keys(safeNewObj),
    ]) as Set<keyof T>;

    for (const key of allKeys) {
      const oldVal = safeOldObj[key];
      const newVal = safeNewObj[key];

      if (!this.isEqual(oldVal, newVal)) {
        if (key in safeNewObj) {
          changes[key] = newVal;
        } else {
          // 对于删除的键，使用 undefined
          changes[key] = undefined as any;
        }
      }
    }

    return changes;
  }

  /**
   * 压缩快照 - 保留所有字段但优化存储
   * @param snapshot 原始快照对象
   * @returns 优化后的快照
   */
  protected compressSnapshot(snapshot: any): any {
    // 1. 深拷贝对象避免修改原始数据
    const compressed = { ...snapshot };

    // 2. 处理大型文本字段
    this.truncateLargeFields(compressed);

    // 3. 过滤敏感信息
    this.filterSensitiveFields(compressed);

    // 4. 移除未定义和空值
    this.removeEmptyValues(compressed);

    return compressed;
  }

  /**
   * 截断大型文本字段
   */
  private truncateLargeFields(obj: any): void {
    const MAX_SIZE = 2000; // 2KB
    for (const key in obj) {
      if (typeof obj[key] === 'string' && obj[key].length > MAX_SIZE) {
        obj[key] =
          `[TRUNCATED ${obj[key].length} chars] ${obj[key].substring(0, 100)}...`;
      }
    }
  }

  /**
   * 过滤敏感字段
   */
  private filterSensitiveFields(obj: any): void {
    const SENSITIVE_FIELDS = ['password', 'token', 'secret', 'apiKey'];
    SENSITIVE_FIELDS.forEach(field => {
      if (obj[field] !== undefined) {
        obj[field] = '******';
      }
    });
  }

  /**
   * 移除空值
   */
  private removeEmptyValues(obj: any): void {
    for (const key in obj) {
      if (obj[key] === undefined || obj[key] === null) {
        delete obj[key];
      }
    }
  }

  /**
   * 添加范围过滤器
   */
  private appendRangeFilter(
    key: string,
    range: any,
    whereParts: string[],
    params: any[],
  ): void {
    if (key === 'createdAtRange' || key === 'updatedAtRange') {
      const field = key.replace('Range', '');
      const dbField = this.toSnakeCase(field);
      this.appendDateRange(dbField, range, whereParts, params);
    } else if (key === 'amountRange') {
      this.appendAmountRange('amount', range, whereParts, params);
    } else if (key === 'dateRange') {
      this.appendDateRange('date', range, whereParts, params);
    } else if (key === 'dueDateRange') {
      this.appendDateRange('due_date', range, whereParts, params);
    }
  }

  /**
   * 构建日期范围查询
   */
  protected appendDateRange(
    field: string,
    range: DateRange | undefined,
    whereParts: string[],
    params: any[],
  ): void {
    if (!range) return;
    if (range.start) {
      whereParts.push(`${field} >= ?`);
      params.push(range.start);
    }
    if (range.end) {
      whereParts.push(`${field} <= ?`);
      params.push(range.end);
    }
  }

  /**
   * 构建数值范围查询
   */
  protected appendAmountRange(
    field: string,
    range: { min?: number; max?: number } | undefined,
    whereParts: string[],
    params: any[],
  ): void {
    if (!range) return;
    if (range.min !== undefined) {
      whereParts.push(`${field} >= ?`);
      params.push(range.min);
    }
    if (range.max !== undefined) {
      whereParts.push(`${field} <= ?`);
      params.push(range.max);
    }
  }

  /**
   * 构建排序子句
   */
  protected buildOrderClause(
    sortOptions: SortOptions,
    defaultSort: string = 'created_at DESC',
  ): string {
    if (sortOptions.customOrderBy) {
      return `ORDER BY ${sortOptions.customOrderBy}`;
    }
    if (sortOptions.sortBy) {
      return `ORDER BY ${sortOptions.sortBy} ${sortOptions.sortDir ?? 'ASC'}`;
    }
    return `ORDER BY ${defaultSort}`;
  }

  /**
   * 通用分页查询
   */
  protected async queryPaged<R>(
    baseQuery: string,
    filters: Record<string, any>,
    page: number,
    pageSize: number,
    sortOptions: SortOptions,
    defaultSort?: string,
    transform?: (row: any) => Promise<R> | R,
  ): Promise<PagedResult<R>> {
    try {
      const offset = (page - 1) * pageSize;
      const { clause: whereClause, params } = this.buildWhereClause(filters);
      const orderClause = this.buildOrderClause(sortOptions, defaultSort);

      // 查询数据
      const dataQuery = `${baseQuery} ${whereClause} ${orderClause} LIMIT ? OFFSET ?`;
      const rows = await db.select<any[]>(
        dataQuery,
        [...params, pageSize, offset],
        true,
      );

      // 查询总数
      const countQuery = baseQuery.replace(
        /SELECT .* FROM/,
        'SELECT COUNT(*) as cnt FROM',
      );
      const totalRes = await db.select<{ cnt: number }[]>(
        `${countQuery} ${whereClause}`,
        params,
        true,
      );

      const totalCount = totalRes.length;
      const totalPages = Math.ceil(totalCount / pageSize);
      const transformedRows = transform
        ? await Promise.all(rows.map(transform))
        : rows;
      return {
        rows: transformedRows,
        totalCount,
        currentPage: page,
        pageSize,
        totalPages,
      };
    } catch (error) {
      this.handleError('queryPaged', error);
    }
  }

  /**
   * 智能更新：只更新有变化的字段
   */
  protected async doSmartUpdate(
    serialNum: string,
    newEntity: T,
    oldEntity: T,
  ): Promise<void> {
    const updates: Partial<T> = {};

    for (const key in newEntity) {
      const k = key as keyof T;
      if (!this.isEqual(newEntity[k], oldEntity[k])) {
        updates[k] = this.normalizeValue(newEntity[k]) as any;
      }
    }

    if (Object.keys(updates).length === 0) {
      Lg.d('MoneyDb', `No changes detected for ${this.entityName}`);
      return;
    }

    await this.updatePartial(serialNum, updates);
  }

  /**
   * 部分字段更新
   */
  protected async updatePartial(
    serialNum: string,
    updates: Partial<T>,
  ): Promise<void> {
    try {
      const fields: string[] = [];
      const values: any[] = [];

      for (const [key, value] of Object.entries(updates)) {
        const snakeKey = this.toSnakeCase(key);
        fields.push(`${snakeKey} = ?`);

        // 处理特殊字段的序列化
        if (this.needsSerialization(key)) {
          values.push(JSON.stringify(value));
        } else if (key === 'currency' && typeof value === 'object') {
          values.push((value as Currency).code);
        } else {
          values.push(value);
        }
      }

      if (fields.length === 0) return;

      values.push(serialNum);
      const sql = `UPDATE ${this.tableName} SET ${fields.join(', ')} WHERE serial_num = ?`;
      await db.execute(sql, values);

      Lg.d('MoneyDb', `${this.entityName} updated:`, {
        serialNum,
        fields: Object.keys(updates),
      });
    } catch (error) {
      this.handleError('updatePartial', error);
    }
  }

  /**
   * 判断字段是否需要JSON序列化
   */
  protected needsSerialization(key: string): boolean {
    const serializationFields = [
      'tags',
      'splitMembers',
      'members',
      'repeatPeriod',
      'baseCurrency',
    ];
    return serializationFields.includes(key);
  }

  /**
   * 通用的创建、读取、删除操作
   */
  abstract create(entity: T): Promise<void>;
  abstract getById(serialNum: string): Promise<T | null>;
  abstract list(): Promise<T[]>;
  abstract update(entity: T): Promise<void>;
  abstract deleteById(serialNum: string): Promise<void>;
}
