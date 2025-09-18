import { invokeCommand } from '@/types/api';
import { Lg } from '@/utils/debugLog';
import { BaseMapper } from './baseManager';
import type { SubCategory, SubCategoryCreate, SubCategoryUpdate } from '@/schema/money/category';

/**
 * 货币数据映射器
 */
export class SubCategoryMapper extends BaseMapper<
  SubCategoryCreate,
  SubCategoryUpdate,
  SubCategory
> {
  protected entityName = 'sub_categories';

  async create(subCategory: SubCategoryCreate): Promise<SubCategory> {
    try {
      const cny = await invokeCommand<SubCategory>('sub_category_create', {
        data: subCategory,
      });
      Lg.d('MoneyDb', 'SubCategory created:', { cny });
      return cny;
    } catch (error) {
      this.handleError('create', error);
    }
  }

  async update(code: string, subCategory: SubCategoryUpdate): Promise<SubCategory> {
    try {
      const cny = await invokeCommand<SubCategory>('sub_category_update', {
        id: code,
        data: subCategory,
      });
      Lg.d('MoneyDb', 'SubCategory updated:', { cny });
      return cny;
    } catch (error) {
      this.handleError('update', error);
    }
  }

  async getById(id: string): Promise<SubCategory | null> {
    try {
      const cny = await invokeCommand<SubCategory>('sub_category_get', { id });
      return cny;
    } catch (error) {
      this.handleError('getById', error);
    }
  }

  async list(): Promise<SubCategory[]> {
    try {
      const tauriCurrencies = await invokeCommand<SubCategory[]>(
        'sub_category_list',
      );
      return tauriCurrencies;
    } catch (error) {
      this.handleError('list', error);
    }
  }

  async deleteById(id: string): Promise<void> {
    try {
      await invokeCommand('sub_category_delete', { id });
      Lg.d('MoneyDb', 'SubCategory deleted:', id);
    } catch (error) {
      this.handleError('deleteById', error);
    }
  }
}
