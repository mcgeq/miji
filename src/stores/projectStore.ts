// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           projects.svelte.ts
// Description:    About Project Store
// Create   Date:  2025-06-23 23:29:52
// Last Modified:  2025-06-28 12:43:08
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

import { ref } from 'vue';
import { getLocalISODateTimeWithOffset } from '../utils/date';
import { uuid } from '../utils/uuid';
import { createWithDefaults } from '../utils/zodFactory';
import { ProjectSchema, type Projects } from '../schema/todos';

type ProjectSortByField = 'createdAt' | 'name';
type SortOrder = 'asc' | 'desc';

interface ProjectFilterOptions {
  keyword?: string;
  name?: string;
  description?: string;
  ownerId?: string;
  isArchived?: boolean;
  sortBy?: ProjectSortByField;
  order?: SortOrder;
  offset?: number;
  limit?: number;
}

// 响应式 Map 存储项目
const projects = ref(new Map<string, Projects>());

// 创建项目
const createProject = (input?: Partial<Projects>): Projects =>
  createWithDefaults(
    ProjectSchema,
    {
      serialNum: () => uuid(38),
      name: 'Untitled Project',
      description: null,
      ownerId: () => uuid(38),
      color: '#ffffff',
      isArchived: false,
      createdAt: getLocalISODateTimeWithOffset,
      updatedAt: null,
    },
    input,
  );

// 新增项目
const addProject = (input?: Partial<Projects>): Projects => {
  const project = createProject(input);
  if (projects.value.has(project.serialNum)) {
    throw new Error(
      `Project with serialNum ${project.serialNum} already exists.`,
    );
  }
  projects.value.set(project.serialNum, project);
  return project;
};

// 更新项目
const updateProject = (
  serialNum: string,
  input: Partial<Omit<Projects, 'serialNum' | 'createdAt'>>,
): Projects => {
  const existing = projects.value.get(serialNum);
  if (!existing) {
    throw new Error(`Project with serialNum ${serialNum} not found.`);
  }
  const updated = createProject({
    ...existing,
    ...input,
    serialNum,
    createdAt: existing.createdAt,
    updatedAt: getLocalISODateTimeWithOffset(),
  });
  projects.value.set(serialNum, updated);
  return updated;
};

// 删除项目
const removeProject = (serialNum: string): boolean => {
  return projects.value.delete(serialNum);
};

// 清空所有项目
const clearAllProjects = (): void => {
  projects.value.clear();
};

// 获取单个项目
const getProject = (serialNum: string): Projects | undefined => {
  return projects.value.get(serialNum);
};

// 判断是否存在某项目
const hasProject = (serialNum: string): boolean => {
  return projects.value.has(serialNum);
};

// 按名称查找项目
const findProjectsByName = (name: string): Projects[] => {
  return Array.from(projects.value.values()).filter((p) => p.name === name);
};

// 搜索项目
const searchProjects = (options: ProjectFilterOptions = {}) => {
  const {
    keyword,
    name,
    description,
    ownerId,
    isArchived,
    sortBy = 'createdAt',
    order = 'desc',
    offset = 0,
    limit = Infinity,
  } = options;

  let results = Array.from(projects.value.values());

  if (keyword?.trim()) {
    const lower = keyword.toLowerCase();
    results = results.filter(
      (p) =>
        p.name.toLowerCase().includes(lower) ||
        p.description?.toLowerCase().includes(lower),
    );
  }
  if (name) results = results.filter((p) => p.name === name);
  if (description)
    results = results.filter((p) => p.description === description);
  if (ownerId) results = results.filter((p) => p.ownerId === ownerId);
  if (typeof isArchived === 'boolean')
    results = results.filter((p) => p.isArchived === isArchived);

  results.sort((a, b) => {
    const valA = a[sortBy];
    const valB = b[sortBy];
    if (typeof valA === 'string' && typeof valB === 'string') {
      const cmp = valA.localeCompare(valB);
      return order === 'asc' ? cmp : -cmp;
    }
    return 0;
  });

  const total = results.length;
  const paged = results.slice(offset, offset + limit);

  return { total, results: paged };
};

export const projectsStore = {
  projects,
  createProject,
  addProject,
  updateProject,
  removeProject,
  clearAllProjects,
  getProject,
  hasProject,
  findProjectsByName,
  searchProjects,
};
