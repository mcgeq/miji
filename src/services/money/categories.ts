import { invokeCommand } from '@/types/api';
import { Lg } from '@/utils/debugLog';
import { BaseMapper } from './baseManager';
import type { Category, CategoryCreate, CategoryUpdate } from '@/schema/money/category';

/**
 * 货币数据映射器
 */
export class CategoryMapper extends BaseMapper<CategoryCreate, CategoryUpdate, Category> {
  protected entityName = 'categories';

  async create(subCategory: CategoryCreate): Promise<Category> {
    try {
      const cny = await invokeCommand<Category>('category_create', {
        data: subCategory,
      });
      Lg.d('MoneyDb', 'Category created:', { cny });
      return cny;
    } catch (error) {
      this.handleError('create', error);
    }
  }

  async update(code: string, subCategory: CategoryUpdate): Promise<Category> {
    try {
      const cny = await invokeCommand<Category>('category_update', {
        id: code,
        data: subCategory,
      });
      Lg.d('MoneyDb', 'Category updated:', { cny });
      return cny;
    } catch (error) {
      this.handleError('update', error);
    }
  }

  async getById(id: string): Promise<Category | null> {
    try {
      const cny = await invokeCommand<Category>('category_get', { id });
      return cny;
    } catch (error) {
      this.handleError('getById', error);
    }
  }

  async list(): Promise<Category[]> {
    try {
      const tauriCurrencies = await invokeCommand<Category[]>('category_list');
      return tauriCurrencies;
    } catch (error) {
      this.handleError('list', error);
    }
  }

  async deleteById(id: string): Promise<void> {
    try {
      await invokeCommand('category_delete', { id });
      Lg.d('MoneyDb', 'Category deleted:', id);
    } catch (error) {
      this.handleError('deleteById', error);
    }
  }
}
