/**
 * Service 基类
 * 提供标准的 CRUD 操作和错误处理
 * @module services/base/BaseService
 */

import { wrapError } from '@/utils/errorHandler';
import { defaultTauriClient, type TauriClient } from '@/utils/tauriClient';
import type { CrudService, PagedResult, PagedService, PageQuery } from './types';

/**
 * Mapper 接口（简化版，用于 BaseService）
 */
export interface IMapper<T, CreateDto = Partial<T>, UpdateDto = Partial<T>> {
  create(data: CreateDto): Promise<T>;
  getById(id: string): Promise<T | null>;
  list(filters?: Record<string, unknown>): Promise<T[]>;
  update(id: string, data: UpdateDto): Promise<T>;
  delete(id: string): Promise<void>;
}

/**
 * Service 基类
 *
 * @template T - 实体类型
 * @template CreateDto - 创建 DTO 类型
 * @template UpdateDto - 更新 DTO 类型
 */
export abstract class BaseService<T, CreateDto = Partial<T>, UpdateDto = Partial<T>>
  implements CrudService<T, CreateDto, UpdateDto>, PagedService<T>
{
  protected tauriClient: TauriClient;
  protected mapper: IMapper<T, CreateDto, UpdateDto>;
  protected commandPrefix: string;

  /**
   * 构造函数
   *
   * @param commandPrefix - Tauri 命令前缀
   * @param mapper - 数据映射器（用于本地数据库访问）
   * @param tauriClient - Tauri 客户端（可选）
   */
  constructor(
    commandPrefix: string,
    mapper: IMapper<T, CreateDto, UpdateDto>,
    tauriClient?: TauriClient,
  ) {
    this.commandPrefix = commandPrefix;
    this.mapper = mapper;
    this.tauriClient = tauriClient || defaultTauriClient;
  }

  /**
   * 创建实体
   */
  async create(data: CreateDto): Promise<T> {
    try {
      return await this.mapper.create(data);
    } catch (error) {
      throw wrapError(
        this.constructor.name,
        error,
        'CREATE_FAILED',
        `创建${this.commandPrefix}失败`,
      );
    }
  }

  /**
   * 根据 ID 获取实体
   */
  async getById(id: string): Promise<T | null> {
    try {
      return await this.mapper.getById(id);
    } catch (error) {
      throw wrapError(this.constructor.name, error, 'GET_FAILED', `获取${this.commandPrefix}失败`);
    }
  }

  /**
   * 获取实体列表
   */
  async list(filters?: Record<string, unknown>): Promise<T[]> {
    try {
      return await this.mapper.list(filters);
    } catch (error) {
      throw wrapError(
        this.constructor.name,
        error,
        'LIST_FAILED',
        `获取${this.commandPrefix}列表失败`,
      );
    }
  }

  /**
   * 更新实体
   */
  async update(id: string, data: UpdateDto): Promise<T> {
    try {
      return await this.mapper.update(id, data);
    } catch (error) {
      throw wrapError(
        this.constructor.name,
        error,
        'UPDATE_FAILED',
        `更新${this.commandPrefix}失败`,
      );
    }
  }

  /**
   * 删除实体
   */
  async delete(id: string): Promise<void> {
    try {
      await this.mapper.delete(id);
    } catch (error) {
      throw wrapError(
        this.constructor.name,
        error,
        'DELETE_FAILED',
        `删除${this.commandPrefix}失败`,
      );
    }
  }

  /**
   * 分页查询
   */
  async listPaged(query: PageQuery): Promise<PagedResult<T>> {
    try {
      const items = await this.mapper.list();
      const total = items.length;
      const start = (query.page - 1) * query.pageSize;
      const end = start + query.pageSize;
      const pagedItems = items.slice(start, end);

      return {
        items: pagedItems,
        total,
        page: query.page,
        pageSize: query.pageSize,
        totalPages: Math.ceil(total / query.pageSize),
      };
    } catch (error) {
      throw wrapError(
        this.constructor.name,
        error,
        'LIST_PAGED_FAILED',
        `分页查询${this.commandPrefix}失败`,
      );
    }
  }

  /**
   * 调用 Rust 后端命令
   * 用于复杂的业务逻辑
   */
  protected async invokeCommand<R>(command: string, args?: unknown): Promise<R> {
    try {
      return await this.tauriClient.invoke<R>(`${this.commandPrefix}_${command}`, args);
    } catch (error) {
      throw wrapError(this.constructor.name, error, 'COMMAND_FAILED', `执行命令失败: ${command}`);
    }
  }
}
