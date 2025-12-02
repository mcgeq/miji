import { invokeCommand } from '@/types/api';
import type { Tags } from '@/schema/tags';

/**
 * 标签数据映射器
 */
export class TagMapper {
  protected entityName = 'Tag';

  async list(): Promise<Tags[]> {
    try {
      return await invokeCommand<Tags[]>('tag_list');
    } catch (error) {
      console.error(`[${this.entityName}] 列表查询失败:`, error);
      throw error;
    }
  }

  async getById(serialNum: string): Promise<Tags | null> {
    try {
      return await invokeCommand<Tags>('tag_get', { serialNum });
    } catch (error) {
      console.error(`[${this.entityName}] 获取失败:`, error);
      return null;
    }
  }
}

/**
 * 标签数据库操作类
 */
export class TagDb {
  private static tagMapper = new TagMapper();

  static async listTags(): Promise<Tags[]> {
    return this.tagMapper.list();
  }

  static async getTag(serialNum: string): Promise<Tags | null> {
    return this.tagMapper.getById(serialNum);
  }
}
