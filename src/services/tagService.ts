/**
 * Tag Service
 * 标签服务层，负责标签的数据访问和业务逻辑
 * @module services/tagService
 */

import type { Tags } from '@/schema/tags';
import { wrapError } from '@/utils/errorHandler';
import { BaseService } from './base/BaseService';
import { type TagCreate, TagMapper, type TagUpdate } from './tags';

/**
 * 标签服务类
 * 继承 BaseService，提供标签的 CRUD 操作和自定义业务方法
 */
class TagService extends BaseService<Tags, TagCreate, TagUpdate> {
  constructor() {
    super(
      'tag', // Tauri 命令前缀
      new TagMapper(), // 本地数据库访问
    );
  }

  /**
   * 根据名称查找标签
   * @param name - 标签名称
   * @returns 匹配的标签列表
   */
  async findByName(name: string): Promise<Tags[]> {
    try {
      const allTags = await this.list();
      return allTags.filter(tag => tag.name === name);
    } catch (error) {
      throw wrapError('TagService', error, 'FIND_BY_NAME_FAILED', `根据名称查找标签失败: ${name}`);
    }
  }

  /**
   * 搜索标签
   * @param keyword - 搜索关键词（在名称和描述中搜索）
   * @returns 匹配的标签列表
   */
  async search(keyword: string): Promise<Tags[]> {
    try {
      const allTags = await this.list();
      const lowerKeyword = keyword.toLowerCase();
      return allTags.filter(
        tag =>
          tag.name.toLowerCase().includes(lowerKeyword) ||
          tag.description?.toLowerCase().includes(lowerKeyword),
      );
    } catch (error) {
      throw wrapError('TagService', error, 'SEARCH_FAILED', `搜索标签失败: ${keyword}`);
    }
  }

  /**
   * 检查标签名称是否已存在
   * @param name - 标签名称
   * @param excludeId - 排除的标签 ID（用于更新时检查）
   * @returns 是否存在
   */
  async isNameExists(name: string, excludeId?: string): Promise<boolean> {
    try {
      const tags = await this.findByName(name);
      if (excludeId) {
        return tags.some(tag => tag.serialNum !== excludeId);
      }
      return tags.length > 0;
    } catch (error) {
      throw wrapError(
        'TagService',
        error,
        'CHECK_NAME_EXISTS_FAILED',
        `检查标签名称是否存在失败: ${name}`,
      );
    }
  }
}

/**
 * 标签服务单例实例
 * 导出单例以便在整个应用中使用
 */
export const tagService = new TagService();
