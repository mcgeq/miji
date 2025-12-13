// src/stores/money/currency-store.ts
import { defineStore } from 'pinia';
import { AppErrorSeverity } from '@/errors/appError';
import type { Currency, CurrencyCrate, CurrencyUpdate } from '@/schema/common';
import { MoneyDb } from '@/services/money/money';
import { assertExists } from '@/utils/errorHandler';
import { emitStoreEvent } from './store-events';

interface CurrencyStoreState {
  currencies: Currency[];
  defaultCurrency: Currency | null;
  lastFetchedCurrencies: Date | null;
  currenciesCacheExpiry: number; // 缓存过期时间（毫秒）
  loading: boolean;
  error: string | null;
}

/**
 * 货币管理 Store
 * 负责货币的CRUD操作和缓存管理
 */
export const useCurrencyStore = defineStore('money-currencies', {
  state: (): CurrencyStoreState => ({
    currencies: [],
    defaultCurrency: null,
    lastFetchedCurrencies: null,
    currenciesCacheExpiry: 30 * 60 * 1000, // 30分钟（货币数据变化较少）
    loading: false,
    error: null,
  }),

  getters: {
    /**
     * 检查货币缓存是否过期
     */
    isCurrenciesCacheExpired: state => {
      if (!state.lastFetchedCurrencies) return true;
      return Date.now() - state.lastFetchedCurrencies.getTime() > state.currenciesCacheExpiry;
    },

    /**
     * 根据货币代码获取货币
     */
    getCurrencyByCode: state => (code: string) => {
      return state.currencies.find(c => c.code === code);
    },

    /**
     * 获取所有激活的货币
     */
    activeCurrencies: state => {
      return state.currencies.filter(c => c.isActive !== false);
    },

    /**
     * 获取默认货币或第一个货币
     */
    primaryCurrency: state => {
      return state.defaultCurrency || state.currencies[0] || null;
    },
  },

  actions: {
    /**
     * 获取货币列表（带缓存）
     */
    async fetchCurrencies(force = false) {
      if (!(force || this.isCurrenciesCacheExpired) && this.currencies.length > 0) {
        return;
      }

      this.loading = true;
      this.error = null;

      try {
        this.currencies = await MoneyDb.listCurrencies();
        this.lastFetchedCurrencies = new Date();

        // 设置默认货币（如果有标记为默认的）
        const defaultCurrency = this.currencies.find(c => c.isDefault === true);
        if (defaultCurrency) {
          this.defaultCurrency = defaultCurrency;
        }
      } catch (error: unknown) {
        this.error = error instanceof Error ? error.message : '获取货币列表失败';
        throw error;
      } finally {
        this.loading = false;
      }
    },

    /**
     * 创建货币
     */
    async createCurrency(data: CurrencyCrate): Promise<Currency> {
      this.loading = true;
      this.error = null;

      try {
        const currency = await MoneyDb.createCurrency(data);
        this.currencies.push(currency);

        // 如果是默认货币，更新 defaultCurrency
        if (currency.isDefault) {
          this.defaultCurrency = currency;
        }

        // 发送货币创建事件
        emitStoreEvent('currency:created', { code: currency.code });

        return currency;
      } catch (error: unknown) {
        this.error = error instanceof Error ? error.message : '创建货币失败';
        throw error;
      } finally {
        this.loading = false;
      }
    },

    /**
     * 更新货币
     */
    async updateCurrency(code: string, data: CurrencyUpdate): Promise<Currency> {
      this.loading = true;
      this.error = null;

      try {
        const updatedCurrency = await MoneyDb.updateCurrency(code, data);

        const index = this.currencies.findIndex(c => c.code === code);
        if (index !== -1) {
          this.currencies[index] = updatedCurrency;
        }

        // 如果更新的是默认货币
        if (updatedCurrency.isDefault) {
          this.defaultCurrency = updatedCurrency;
        } else if (this.defaultCurrency?.code === code) {
          // 如果取消了默认货币标记
          this.defaultCurrency = null;
        }

        // 发送货币更新事件
        emitStoreEvent('currency:updated', { code });

        return updatedCurrency;
      } catch (error: unknown) {
        this.error = error instanceof Error ? error.message : '更新货币失败';
        throw error;
      } finally {
        this.loading = false;
      }
    },

    /**
     * 删除货币
     */
    async deleteCurrency(code: string): Promise<void> {
      this.loading = true;
      this.error = null;

      try {
        await MoneyDb.deleteCurrency(code);
        this.currencies = this.currencies.filter(c => c.code !== code);

        // 如果删除的是默认货币，清空默认货币
        if (this.defaultCurrency?.code === code) {
          this.defaultCurrency = null;
        }

        // 发送货币删除事件
        emitStoreEvent('currency:deleted', { code });
      } catch (error: unknown) {
        this.error = error instanceof Error ? error.message : '删除货币失败';
        throw error;
      } finally {
        this.loading = false;
      }
    },

    /**
     * 设置默认货币
     */
    async setDefaultCurrency(code: string): Promise<void> {
      const currency = this.getCurrencyByCode(code);
      assertExists(
        currency,
        'CurrencyStore',
        'CURRENCY_NOT_FOUND',
        '货币不存在',
        AppErrorSeverity.MEDIUM,
      );

      // 更新为默认货币
      await this.updateCurrency(code, { isDefault: true });

      // 将其他货币的默认标记取消
      const otherCurrencies = this.currencies.filter(c => c.code !== code && c.isDefault);
      await Promise.all(
        otherCurrencies.map(c => this.updateCurrency(c.code, { isDefault: false })),
      );
    },

    /**
     * 清除货币缓存
     */
    clearCurrenciesCache() {
      this.lastFetchedCurrencies = null;
    },

    /**
     * 清除错误
     */
    clearError() {
      this.error = null;
    },

    /**
     * 重置 store 状态
     */
    reset() {
      this.currencies = [];
      this.defaultCurrency = null;
      this.lastFetchedCurrencies = null;
      this.loading = false;
      this.error = null;
    },
  },
});
