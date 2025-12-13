/**
 * 货币服务
 * 提供货币的 CRUD 操作和业务逻辑
 * @module services/money/CurrencyService
 */

import type { Currency, CurrencyCrate, CurrencyUpdate } from '@/schema/common';
import { wrapError } from '@/utils/errorHandler';
import { BaseService, type IMapper } from '../base/BaseService';
import { CurrencyMapper } from './currencys';

/**
 * 货币服务类
 * 继承 BaseService，提供货币相关的业务逻辑
 */
class CurrencyService extends BaseService<Currency, CurrencyCrate, CurrencyUpdate> {
  private currencyMapper: CurrencyMapper;

  constructor() {
    const mapper = new CurrencyMapper();
    // Create an adapter to match IMapper interface
    const mapperAdapter: IMapper<Currency, CurrencyCrate, CurrencyUpdate> = {
      create: data => mapper.create(data),
      getById: id => mapper.getById(id),
      list: () => mapper.list(),
      update: (id, data) => mapper.update(id, data),
      delete: id => mapper.deleteById(id),
    };
    super('currency', mapperAdapter);
    this.currencyMapper = mapper;
  }

  /**
   * 删除货币（覆盖基类方法以使用正确的 Mapper 方法）
   */
  async delete(id: string): Promise<void> {
    try {
      await this.currencyMapper.deleteById(id);
    } catch (error) {
      throw wrapError('CurrencyService', error, 'DELETE_FAILED', `删除${this.commandPrefix}失败`);
    }
  }

  /**
   * 根据货币代码获取货币
   * @param code - 货币代码（如 CNY, USD）
   * @returns 货币信息或 null
   */
  async getByCode(code: string): Promise<Currency | null> {
    return await this.getById(code);
  }

  /**
   * 检查货币是否存在
   * @param code - 货币代码
   * @returns 是否存在
   */
  async exists(code: string): Promise<boolean> {
    try {
      const currency = await this.getByCode(code);
      return currency !== null;
    } catch (error) {
      throw wrapError('CurrencyService', error, 'CHECK_EXISTS_FAILED', '检查货币是否存在失败');
    }
  }

  /**
   * 获取所有货币代码列表
   * @returns 货币代码数组
   */
  async listCodes(): Promise<string[]> {
    try {
      const currencies = await this.list();
      return currencies.map(currency => currency.code);
    } catch (error) {
      throw wrapError('CurrencyService', error, 'LIST_CODES_FAILED', '获取货币代码列表失败');
    }
  }

  /**
   * 获取活跃的货币列表
   * @returns 活跃货币列表
   */
  async listActive(): Promise<Currency[]> {
    try {
      const currencies = await this.list();
      return currencies.filter(currency => currency.isActive);
    } catch (error) {
      throw wrapError('CurrencyService', error, 'LIST_ACTIVE_FAILED', '获取活跃货币列表失败');
    }
  }
}

/**
 * 导出 CurrencyService 单例
 */
export const currencyService = new CurrencyService();
