/**
 * Service 层核心类型定义
 * @module services/base/types
 */

import type { AppError } from '@/errors/appError';

/**
 * 分页查询参数
 */
export interface PageQuery {
  page: number;
  pageSize: number;
  sortBy?: string;
  sortOrder?: 'asc' | 'desc';
}

/**
 * 分页结果
 */
export interface PagedResult<T> {
  items: T[];
  total: number;
  page: number;
  pageSize: number;
  totalPages: number;
}

/**
 * CRUD Service 接口
 */
export interface CrudService<T, CreateDto = Partial<T>, UpdateDto = Partial<T>> {
  create(data: CreateDto): Promise<T>;
  getById(id: string): Promise<T | null>;
  list(filters?: Record<string, unknown>): Promise<T[]>;
  update(id: string, data: UpdateDto): Promise<T>;
  delete(id: string): Promise<void>;
}

/**
 * 分页 Service 接口
 */
export interface PagedService<T> {
  listPaged(query: PageQuery): Promise<PagedResult<T>>;
}

/**
 * Service 配置
 */
export interface ServiceConfig {
  /**
   * 是否启用缓存
   */
  cacheEnabled?: boolean;

  /**
   * 缓存过期时间（毫秒）
   */
  cacheTTL?: number;
}

/**
 * Service 错误上下文
 */
export interface ServiceErrorContext {
  service: string;
  method: string;
  args?: unknown;
  error: AppError;
}
