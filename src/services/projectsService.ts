/**
 * Project Service
 * 项目服务层，负责项目的数据访问和业务逻辑
 * @module services/projectsService
 */

import type { Projects } from '@/schema/todos';
import { BaseService } from './base/BaseService';
import { type ProjectCreate, ProjectMapper, type ProjectUpdate } from './projects';

/**
 * 项目服务类
 * 继承 BaseService，提供项目的 CRUD 操作和自定义业务方法
 */
class ProjectsService extends BaseService<Projects, ProjectCreate, ProjectUpdate> {
  constructor() {
    super('project', new ProjectMapper());
  }

  /**
   * 根据名称查找项目
   */
  async findByName(name: string): Promise<Projects[]> {
    try {
      const allProjects = await this.list();
      return allProjects.filter(p => p.name === name);
    } catch (error) {
      throw this.wrapServiceError(error, 'FIND_BY_NAME_FAILED', `根据名称查找项目失败: ${name}`);
    }
  }

  /**
   * 搜索项目（根据关键词）
   */
  async search(keyword: string): Promise<Projects[]> {
    try {
      const allProjects = await this.list();
      const lower = keyword.toLowerCase();
      return allProjects.filter(
        p => p.name.toLowerCase().includes(lower) || p.description?.toLowerCase().includes(lower),
      );
    } catch (error) {
      throw this.wrapServiceError(error, 'SEARCH_FAILED', `搜索项目失败: ${keyword}`);
    }
  }

  /**
   * 包装服务错误
   */
  private wrapServiceError(error: unknown, code: string, message: string) {
    const { wrapError } = require('@/utils/errorHandler');
    return wrapError('ProjectsService', error, code, message);
  }
}

/**
 * 导出项目服务单例
 */
export const projectService = new ProjectsService();
