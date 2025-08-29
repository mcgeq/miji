import { invokeCommand } from '@/types/api';
import { Lg } from '@/utils/debugLog';
import { BaseMapper } from './baseManager';
import type { Currency, CurrencyCrate, CurrencyUpdate } from '@/schema/common';

/**
 * 货币数据映射器
 */
export class CurrencyMapper extends BaseMapper<
  CurrencyCrate,
  CurrencyUpdate,
  Currency
> {
  protected entityName = 'currency';

  async create(currency: CurrencyCrate): Promise<Currency> {
    try {
      const cny = await invokeCommand<Currency>('currency_create', {
        data: currency,
      });
      Lg.d('MoneyDb', 'Currency created:', { cny });
      return cny;
    } catch (error) {
      this.handleError('create', error);
    }
  }

  async update(code: string, currency: CurrencyUpdate): Promise<Currency> {
    try {
      const cny = await invokeCommand<Currency>('currency_update', {
        id: code,
        data: currency,
      });
      Lg.d('MoneyDb', 'Currency updated:', { cny });
      return cny;
    } catch (error) {
      this.handleError('update', error);
    }
  }

  async getById(code: string): Promise<Currency | null> {
    try {
      const cny = await invokeCommand<Currency>('currency_get', { id: code });
      return cny;
    } catch (error) {
      this.handleError('getById', error);
    }
  }

  async list(): Promise<Currency[]> {
    try {
      const tauriCurrencies = await invokeCommand<Currency[]>(
        'currencies_list',
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
      await invokeCommand('currency_delete', { id: code });
      Lg.d('MoneyDb', 'Currency deleted:', { code });
    } catch (error) {
      this.handleError('deleteById', error);
    }
  }
}
