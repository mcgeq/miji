import { Lg } from '@/utils/debugLog';

export interface PagedResult<T> {
  rows: T[];
  totalCount: number;
  currentPage: number;
  pageSize: number;
  totalPages: number;
}

export interface PagedMapResult<T> {
  rows: Map<string, T>;
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
export abstract class BaseMapper<C, U, R> {
  protected abstract entityName: string;
  /**
   * 处理数据库错误
   */
  protected handleError(operation: string, error: unknown): never {
    const dbError = new MoneyDbError(
      `${operation} operation failed`,
      operation,
      this.entityName,
      error as Error,
    );
    Lg.e('MoneyDb', `${operation} failed:`, error);
    throw dbError;
  }

  /**
   * 通用的创建、读取、删除操作
   */
  abstract create(entity: C): Promise<R>;
  abstract getById(serialNum: string): Promise<R | null>;
  abstract list(): Promise<R[]>;
  abstract update(serialNum: string, entity: U): Promise<R>;
  abstract deleteById(serialNum: string): Promise<void>;
}
