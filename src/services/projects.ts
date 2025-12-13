import type { Projects } from '@/schema/todos';
import { invokeCommand } from '@/types/api';

export interface ProjectCreate {
  name: string;
  description?: string | null;
  ownerId?: string | null;
  color?: string | null;
  isArchived: boolean;
}

export interface ProjectUpdate {
  name?: string;
  description?: string | null;
  ownerId?: string | null;
  color?: string | null;
  isArchived?: boolean;
}

/**
 * 项目数据映射器
 */
export class ProjectMapper {
  protected entityName = 'Project';

  async list(): Promise<Projects[]> {
    try {
      return await invokeCommand<Projects[]>('project_list');
    } catch (error) {
      console.error(`[${this.entityName}] 列表查询失败:`, error);
      throw error;
    }
  }

  async getById(serialNum: string): Promise<Projects | null> {
    try {
      return await invokeCommand<Projects>('project_get', { serialNum });
    } catch (error) {
      console.error(`[${this.entityName}] 获取失败:`, error);
      return null;
    }
  }

  async create(data: ProjectCreate): Promise<Projects> {
    try {
      return await invokeCommand<Projects>('project_create', { data });
    } catch (error) {
      console.error(`[${this.entityName}] 创建失败:`, error);
      throw error;
    }
  }

  async update(serialNum: string, data: ProjectUpdate): Promise<Projects> {
    try {
      return await invokeCommand<Projects>('project_update', { serialNum, data });
    } catch (error) {
      console.error(`[${this.entityName}] 更新失败:`, error);
      throw error;
    }
  }

  async delete(serialNum: string): Promise<void> {
    try {
      await invokeCommand<void>('project_delete', { serialNum });
    } catch (error) {
      console.error(`[${this.entityName}] 删除失败:`, error);
      throw error;
    }
  }
}
