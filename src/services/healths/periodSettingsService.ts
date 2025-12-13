/**
 * 经期设置服务
 * 提供经期设置的 CRUD 操作
 * @module services/healths/PeriodSettingsService
 */

import type {
  PeriodSettings,
  PeriodSettingsCreate,
  PeriodSettingsUpdate,
} from '@/schema/health/period';
import { wrapError } from '@/utils/errorHandler';
import { BaseService, type IMapper } from '../base/BaseService';
import { PeriodSettingsMapper } from './period_settings';

/**
 * 经期设置服务类
 * 继承 BaseService，提供经期设置相关的业务逻辑
 */
class PeriodSettingsService extends BaseService<
  PeriodSettings,
  PeriodSettingsCreate,
  PeriodSettingsUpdate
> {
  private periodSettingsMapper: PeriodSettingsMapper;

  constructor() {
    const mapper = new PeriodSettingsMapper();
    // Create an adapter to match IMapper interface
    const mapperAdapter: IMapper<PeriodSettings, PeriodSettingsCreate, PeriodSettingsUpdate> = {
      create: data => mapper.create(data),
      getById: id => mapper.getById(id),
      list: () => mapper.list(),
      update: (id, data) => mapper.update(id, data),
      delete: id => mapper.deleteById(id),
    };
    super('period_settings', mapperAdapter);
    this.periodSettingsMapper = mapper;
  }

  /**
   * 删除经期设置（覆盖基类方法以使用正确的 Mapper 方法）
   */
  async delete(id: string): Promise<void> {
    try {
      await this.periodSettingsMapper.deleteById(id);
    } catch (error) {
      throw wrapError(
        'PeriodSettingsService',
        error,
        'DELETE_FAILED',
        `删除${this.commandPrefix}失败`,
      );
    }
  }

  /**
   * 获取当前用户的设置
   * @returns 经期设置或 null
   */
  async getCurrentUserSettings(): Promise<PeriodSettings | null> {
    try {
      const allSettings = await this.list();
      // 假设每个用户只有一个设置，返回第一个
      return allSettings.length > 0 ? allSettings[0] : null;
    } catch (error) {
      throw wrapError(
        'PeriodSettingsService',
        error,
        'GET_CURRENT_USER_SETTINGS_FAILED',
        '获取当前用户设置失败',
      );
    }
  }

  /**
   * 创建或更新设置
   * @param data - 设置数据
   * @returns 设置信息
   */
  async createOrUpdate(data: PeriodSettingsCreate): Promise<PeriodSettings> {
    try {
      const existing = await this.getCurrentUserSettings();
      if (existing) {
        return await this.update(existing.serialNum, data as PeriodSettingsUpdate);
      }
      return await this.create(data);
    } catch (error) {
      throw wrapError(
        'PeriodSettingsService',
        error,
        'CREATE_OR_UPDATE_FAILED',
        '创建或更新设置失败',
      );
    }
  }
}

/**
 * 导出 PeriodSettingsService 单例
 */
export const periodSettingsService = new PeriodSettingsService();
