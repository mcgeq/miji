/**
 * 分类服务
 * 提供分类的 CRUD 操作和业务逻辑
 * @module services/money/CategoryService
 */

import type { Category, CategoryCreate, CategoryUpdate } from '@/schema/money/category';
import { wrapError } from '@/utils/errorHandler';
import { BaseService, type IMapper } from '../base/BaseService';
import { CategoryMapper } from './categories';

/**
 * 分类服务类
 * 继承 BaseService，提供分类相关的业务逻辑
 */
class CategoryService extends BaseService<Category, CategoryCreate, CategoryUpdate> {
  private categoryMapper: CategoryMapper;

  constructor() {
    const mapper = new CategoryMapper();
    // Create an adapter to match IMapper interface
    const mapperAdapter: IMapper<Category, CategoryCreate, CategoryUpdate> = {
      create: data => mapper.create(data),
      getById: id => mapper.getById(id),
      list: () => mapper.list(),
      update: (id, data) => mapper.update(id, data),
      delete: id => mapper.deleteById(id),
    };
    super('category', mapperAdapter);
    this.categoryMapper = mapper;
  }

  /**
   * 删除分类（覆盖基类方法以使用正确的 Mapper 方法）
   */
  async delete(id: string): Promise<void> {
    try {
      await this.categoryMapper.deleteById(id);
    } catch (error) {
      throw wrapError('CategoryService', error, 'DELETE_FAILED', `删除${this.commandPrefix}失败`);
    }
  }

  /**
   * 根据名称获取分类
   * @param name - 分类名称
   * @returns 分类信息或 null
   */
  async getByName(name: string): Promise<Category | null> {
    try {
      const categories = await this.list();
      return categories.find(cat => cat.name === name) || null;
    } catch (error) {
      throw wrapError('CategoryService', error, 'GET_BY_NAME_FAILED', '根据名称获取分类失败');
    }
  }

  /**
   * 检查分类是否存在
   * @param name - 分类名称
   * @returns 是否存在
   */
  async exists(name: string): Promise<boolean> {
    try {
      const category = await this.getByName(name);
      return category !== null;
    } catch (error) {
      throw wrapError('CategoryService', error, 'CHECK_EXISTS_FAILED', '检查分类是否存在失败');
    }
  }

  /**
   * 获取所有分类名称列表
   * @returns 分类名称数组
   */
  async listNames(): Promise<string[]> {
    try {
      const categories = await this.list();
      return categories.map(cat => cat.name);
    } catch (error) {
      throw wrapError('CategoryService', error, 'LIST_NAMES_FAILED', '获取分类名称列表失败');
    }
  }
}

/**
 * 导出 CategoryService 单例
 */
export const categoryService = new CategoryService();
