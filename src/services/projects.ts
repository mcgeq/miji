import { invokeCommand } from '@/types/api';
import type { Projects } from '@/schema/todos';

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
}

/**
 * 项目数据库操作类
 */
export class ProjectDb {
  private static projectMapper = new ProjectMapper();

  static async listProjects(): Promise<Projects[]> {
    return this.projectMapper.list();
  }

  static async getProject(serialNum: string): Promise<Projects | null> {
    return this.projectMapper.getById(serialNum);
  }
}
