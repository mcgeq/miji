import type { Tags } from '@/schema/tags';
import { invokeCommand } from '@/types/api';

/**
 * 项目标签服务
 */
export class ProjectTagsDb {
  /**
   * 获取项目的所有标签
   */
  static async getProjectTags(projectSerialNum: string): Promise<Tags[]> {
    return invokeCommand<Tags[]>('project_tags_get', { projectSerialNum });
  }

  /**
   * 更新项目标签
   */
  static async updateProjectTags(projectSerialNum: string, tagSerialNums: string[]): Promise<void> {
    return invokeCommand<void>('project_tags_update', {
      projectSerialNum,
      tagSerialNums,
    });
  }
}
