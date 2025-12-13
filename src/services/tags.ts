import type { Tags } from '@/schema/tags';
import { invokeCommand } from '@/types/api';

export interface TagCreate {
  name: string;
  description?: string | null;
}

export interface TagUpdate {
  name?: string;
  description?: string | null;
}

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

  async create(data: TagCreate): Promise<Tags> {
    try {
      return await invokeCommand<Tags>('tag_create', { data });
    } catch (error) {
      console.error(`[${this.entityName}] 创建失败:`, error);
      throw error;
    }
  }

  async update(serialNum: string, data: TagUpdate): Promise<Tags> {
    try {
      return await invokeCommand<Tags>('tag_update', { serialNum, data });
    } catch (error) {
      console.error(`[${this.entityName}] 更新失败:`, error);
      throw error;
    }
  }

  async delete(serialNum: string): Promise<void> {
    try {
      await invokeCommand<void>('tag_delete', { serialNum });
    } catch (error) {
      console.error(`[${this.entityName}] 删除失败:`, error);
      throw error;
    }
  }
}
