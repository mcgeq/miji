/**
 * 子分类服务
 * 提供子分类的 CRUD 操作和业务逻辑
 * @module services/money/SubCategoryService
 */

import type { SubCategory, SubCategoryCreate, SubCategoryUpdate } from '@/schema/money/category';
import { wrapError } from '@/utils/errorHandler';
import { BaseService, type IMapper } from '../base/BaseService';
import { SubCategoryMapper } from './sub_categories';

/**
 * 子分类服务类
 * 继承 BaseService，提供子分类相关的业务逻辑
 */
class SubCategoryService extends BaseService<SubCategory, SubCategoryCreate, SubCategoryUpdate> {
  private subCategoryMapper: SubCategoryMapper;

  constructor() {
    const mapper = new SubCategoryMapper();
    // Create an adapter to match IMapper interface
    const mapperAdapter: IMapper<SubCategory, SubCategoryCreate, SubCategoryUpdate> = {
      create: data => mapper.create(data),
      getById: id => mapper.getById(id),
      list: () => mapper.list(),
      update: (id, data) => mapper.update(id, data),
      delete: id => mapper.deleteById(id),
    };
    super('sub_category', mapperAdapter);
    this.subCategoryMapper = mapper;
  }

  /**
   * 删除子分类（覆盖基类方法以使用正确的 Mapper 方法）
   */
  async delete(id: string): Promise<void> {
    try {
      await this.subCategoryMapper.deleteById(id);
    } catch (error) {
      throw wrapError(
        'SubCategoryService',
        error,
        'DELETE_FAILED',
        `删除${this.commandPrefix}失败`,
      );
    }
  }

  /**
   * 根据分类名称获取子分类列表
   * @param categoryName - 分类名称
   * @returns 子分类列表
   */
  async listByCategory(categoryName: string): Promise<SubCategory[]> {
    try {
      const allSubCategories = await this.list();
      return allSubCategories.filter(sub => sub.categoryName === categoryName);
    } catch (error) {
      throw wrapError(
        'SubCategoryService',
        error,
        'LIST_BY_CATEGORY_FAILED',
        '根据分类获取子分类失败',
      );
    }
  }

  /**
   * 根据名称和分类获取子分类
   * @param name - 子分类名称
   * @param categoryName - 分类名称
   * @returns 子分类信息或 null
   */
  async getByNameAndCategory(name: string, categoryName: string): Promise<SubCategory | null> {
    try {
      const subCategories = await this.listByCategory(categoryName);
      return subCategories.find(sub => sub.name === name) || null;
    } catch (error) {
      throw wrapError(
        'SubCategoryService',
        error,
        'GET_BY_NAME_CATEGORY_FAILED',
        '根据名称和分类获取子分类失败',
      );
    }
  }

  /**
   * 检查子分类是否存在
   * @param name - 子分类名称
   * @param categoryName - 分类名称
   * @returns 是否存在
   */
  async exists(name: string, categoryName: string): Promise<boolean> {
    try {
      const subCategory = await this.getByNameAndCategory(name, categoryName);
      return subCategory !== null;
    } catch (error) {
      throw wrapError('SubCategoryService', error, 'CHECK_EXISTS_FAILED', '检查子分类是否存在失败');
    }
  }

  /**
   * 获取指定分类下的所有子分类名称
   * @param categoryName - 分类名称
   * @returns 子分类名称数组
   */
  async listNamesByCategory(categoryName: string): Promise<string[]> {
    try {
      const subCategories = await this.listByCategory(categoryName);
      return subCategories.map(sub => sub.name);
    } catch (error) {
      throw wrapError(
        'SubCategoryService',
        error,
        'LIST_NAMES_BY_CATEGORY_FAILED',
        '获取子分类名称列表失败',
      );
    }
  }
}

/**
 * 导出 SubCategoryService 单例
 */
export const subCategoryService = new SubCategoryService();
