// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           projectStore.ts
// Description:    Project Store - 项目状态管理
// Create   Date:  2025-06-23 23:29:52
// Last Modified:  2025-12-13 22:00:00
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

import { defineStore } from 'pinia';
import { computed, ref } from 'vue';
import type { AppError } from '@/errors/appError';
import type { Projects } from '@/schema/todos';
import type { ProjectCreate, ProjectUpdate } from '@/services/projects';
import { projectService } from '@/services/projectsService';
import { wrapError } from '@/utils/errorHandler';
import { withLoadingSafe } from './utils/withLoadingSafe';

type SortByField = 'createdAt' | 'name';
type SortOrder = 'asc' | 'desc';

interface ProjectFilterOptions {
  keyword?: string;
  name?: string;
  description?: string;
  ownerId?: string;
  isArchived?: boolean;
  sortBy?: SortByField;
  order?: SortOrder;
  offset?: number;
  limit?: number;
}

/**
 * 项目 Store
 * 使用 Composition API 风格，遵循新的架构模式
 */
export const useProjectStore = defineStore('project', () => {
  // ============ 状态 ============
  const projects = ref<Projects[]>([]);
  const currentProject = ref<Projects | null>(null);
  const isLoading = ref(false);
  const error = ref<AppError | null>(null);

  // ============ 计算属性 ============
  const projectCount = computed(() => projects.value.length);

  const projectsMap = computed(() => {
    const map = new Map<string, Projects>();
    projects.value.forEach(project => map.set(project.serialNum, project));
    return map;
  });

  // ============ Actions ============

  /**
   * 加载所有项目
   */
  const fetchProjects = withLoadingSafe(
    async () => {
      try {
        projects.value = await projectService.list();
      } catch (err) {
        error.value = wrapError('ProjectStore', err, 'FETCH_FAILED', '获取项目列表失败');
        throw error.value;
      }
    },
    isLoading,
    error,
  );

  /**
   * 根据 ID 获取项目
   */
  const fetchProjectById = withLoadingSafe(
    async (serialNum: string) => {
      try {
        const project = await projectService.getById(serialNum);
        if (project) {
          currentProject.value = project;
        }
        return project;
      } catch (err) {
        error.value = wrapError(
          'ProjectStore',
          err,
          'FETCH_BY_ID_FAILED',
          `获取项目失败: ${serialNum}`,
        );
        throw error.value;
      }
    },
    isLoading,
    error,
  );

  /**
   * 创建项目
   */
  const createProject = withLoadingSafe(
    async (data: ProjectCreate) => {
      try {
        const newProject = await projectService.create(data);
        projects.value.push(newProject);
        return newProject;
      } catch (err) {
        error.value = wrapError('ProjectStore', err, 'CREATE_FAILED', '创建项目失败');
        throw error.value;
      }
    },
    isLoading,
    error,
  );

  /**
   * 更新项目
   */
  const updateProject = withLoadingSafe(
    async (serialNum: string, data: ProjectUpdate) => {
      try {
        const updatedProject = await projectService.update(serialNum, data);
        const index = projects.value.findIndex(p => p.serialNum === serialNum);
        if (index !== -1) {
          projects.value[index] = updatedProject;
        }
        if (currentProject.value?.serialNum === serialNum) {
          currentProject.value = updatedProject;
        }
        return updatedProject;
      } catch (err) {
        error.value = wrapError('ProjectStore', err, 'UPDATE_FAILED', `更新项目失败: ${serialNum}`);
        throw error.value;
      }
    },
    isLoading,
    error,
  );

  /**
   * 删除项目
   */
  const deleteProject = withLoadingSafe(
    async (serialNum: string) => {
      try {
        await projectService.delete(serialNum);
        projects.value = projects.value.filter(p => p.serialNum !== serialNum);
        if (currentProject.value?.serialNum === serialNum) {
          currentProject.value = null;
        }
      } catch (err) {
        error.value = wrapError('ProjectStore', err, 'DELETE_FAILED', `删除项目失败: ${serialNum}`);
        throw error.value;
      }
    },
    isLoading,
    error,
  );

  /**
   * 根据名称查找项目
   */
  const findProjectsByName = withLoadingSafe(
    async (name: string) => {
      try {
        return await projectService.findByName(name);
      } catch (err) {
        error.value = wrapError(
          'ProjectStore',
          err,
          'FIND_BY_NAME_FAILED',
          `根据名称查找项目失败: ${name}`,
        );
        throw error.value;
      }
    },
    isLoading,
    error,
  );

  /**
   * 搜索项目
   */
  const searchProjects = withLoadingSafe(
    async (keyword: string) => {
      try {
        return await projectService.search(keyword);
      } catch (err) {
        error.value = wrapError('ProjectStore', err, 'SEARCH_FAILED', `搜索项目失败: ${keyword}`);
        throw error.value;
      }
    },
    isLoading,
    error,
  );

  /**
   * 本地过滤和排序项目（用于客户端过滤）
   */
  function filterAndSortProjects(options: ProjectFilterOptions = {}) {
    const {
      keyword,
      name,
      description,
      ownerId,
      isArchived,
      sortBy = 'createdAt',
      order = 'desc',
      offset = 0,
      limit = Number.POSITIVE_INFINITY,
    } = options;

    let results = [...projects.value];

    // 关键词搜索
    if (keyword?.trim()) {
      const lower = keyword.toLowerCase();
      results = results.filter(
        project =>
          project.name.toLowerCase().includes(lower) ||
          project.description?.toLowerCase().includes(lower),
      );
    }

    // 精确匹配
    if (name) {
      results = results.filter(project => project.name === name);
    }
    if (description) {
      results = results.filter(project => project.description === description);
    }
    if (ownerId) {
      results = results.filter(project => project.ownerId === ownerId);
    }
    if (typeof isArchived === 'boolean') {
      results = results.filter(project => project.isArchived === isArchived);
    }

    // 排序
    results.sort((a, b) => {
      const fieldA = a[sortBy];
      const fieldB = b[sortBy];

      if (typeof fieldA === 'string' && typeof fieldB === 'string') {
        const cmp = fieldA.localeCompare(fieldB);
        return order === 'asc' ? cmp : -cmp;
      }
      return 0;
    });

    // 分页
    const total = results.length;
    const paged = results.slice(offset, offset + limit);

    return { total, results: paged };
  }

  /**
   * 获取项目（从缓存）
   */
  function getProject(serialNum: string): Projects | undefined {
    return projectsMap.value.get(serialNum);
  }

  /**
   * 检查项目是否存在（从缓存）
   */
  function hasProject(serialNum: string): boolean {
    return projectsMap.value.has(serialNum);
  }

  /**
   * 重置 Store 状态
   */
  function $reset() {
    projects.value = [];
    currentProject.value = null;
    isLoading.value = false;
    error.value = null;
  }

  return {
    // 状态
    projects,
    currentProject,
    isLoading,
    error,
    // 计算属性
    projectCount,
    projectsMap,
    // Actions
    fetchProjects,
    fetchProjectById,
    createProject,
    updateProject,
    deleteProject,
    findProjectsByName,
    searchProjects,
    filterAndSortProjects,
    getProject,
    hasProject,
    // 重置
    $reset,
  };
});

// 向后兼容的导出（保留旧接口）
/** @deprecated 使用 useProjectStore() 代替 */
export const projectsStore = {
  get projects() {
    const store = useProjectStore();
    return computed(() => {
      const map = new Map<string, Projects>();
      store.projects.forEach(project => map.set(project.serialNum, project));
      return map;
    });
  },
  createProject: (input?: Partial<Projects>) => {
    const store = useProjectStore();
    return store.createProject({
      name: input?.name || 'Untitled Project',
      description: input?.description || null,
      ownerId: input?.ownerId || null,
      color: input?.color || '#ffffff',
      isArchived: input?.isArchived,
    });
  },
  addProject: (input?: Partial<Projects>) => {
    const store = useProjectStore();
    return store.createProject({
      name: input?.name || 'Untitled Project',
      description: input?.description || null,
      ownerId: input?.ownerId || null,
      color: input?.color || '#ffffff',
      isArchived: input?.isArchived,
    });
  },
  updateProject: (serialNum: string, input: Partial<Omit<Projects, 'serialNum' | 'createdAt'>>) => {
    const store = useProjectStore();
    return store.updateProject(serialNum, input);
  },
  removeProject: (serialNum: string) => {
    const store = useProjectStore();
    return store.deleteProject(serialNum).then(() => true);
  },
  clearAllProjects: () => {
    const store = useProjectStore();
    store.$reset();
  },
  getProject: (serialNum: string) => {
    const store = useProjectStore();
    return store.getProject(serialNum);
  },
  hasProject: (serialNum: string) => {
    const store = useProjectStore();
    return store.hasProject(serialNum);
  },
  findProjectsByName: (name: string) => {
    const store = useProjectStore();
    return store.findProjectsByName(name);
  },
  searchProjects: (options: ProjectFilterOptions = {}) => {
    const store = useProjectStore();
    return store.filterAndSortProjects(options);
  },
};
