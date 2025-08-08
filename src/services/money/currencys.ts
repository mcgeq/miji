import { invokeCommand } from '@/types/api';
import { Lg } from '@/utils/debugLog';
import { BaseMapper } from './baseManager';
import type {
  CreateCurrencyRequest,
  Currency,
  UpdateCurrencyRequest,
} from '@/schema/common';

/**
 * 货币数据映射器
 */
export class CurrencyMapper extends BaseMapper<Currency> {
  protected tableName = 'currency';
  protected entityName = 'Currency';

  async create(currency: CreateCurrencyRequest): Promise<void> {
    try {
      const cny = await invokeCommand<Currency>('create_currency', {
        data: currency,
      });
      Lg.d('MoneyDb', 'Currency created:', { cny });
    } catch (error) {
      this.handleError('create', error);
    }
  }

  async update(currency: UpdateCurrencyRequest): Promise<void> {
    try {
      const cny = await invokeCommand<Currency>('update_currency', {
        id: currency.code,
        data: currency,
      });
      Lg.d('MoneyDb', 'Currency updated:', { cny });
    } catch (error) {
      this.handleError('update', error);
    }
  }

  async getById(code: string): Promise<Currency | null> {
    try {
      const cny = await invokeCommand<Currency>('get_currency', { id: code });
      return cny;
    } catch (error) {
      this.handleError('getById', error);
    }
  }

  async list(): Promise<Currency[]> {
    try {
      const tauriCurrencies = await invokeCommand<Currency[]>(
        'list_currencies',
        {
          filter: {},
        },
      );
      return tauriCurrencies;
    } catch (error) {
      this.handleError('list', error);
    }
  }

  async deleteById(code: string): Promise<void> {
    try {
      await invokeCommand('delete_currency', { id: code });
      Lg.d('MoneyDb', 'Currency deleted:', { code });
    } catch (error) {
      this.handleError('deleteById', error);
    }
  }
}
