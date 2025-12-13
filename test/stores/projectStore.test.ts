/**
 * ProjectStore 单元测试
 * 测试 Store actions、错误处理和 $reset 方法
 */

import { describe, it, expect, beforeEach, vi } from 'vitest';
import { setActivePinia, createPinia } from 'pinia';
import { useProjectStore } from '@/stores/projectStore';
import { projectService } from '@/services/projectsService';
import type { Projects } from '@/schema/todos';
import type { ProjectCreate, ProjectUpdate } from '@/services/projects';

// Mock projectService
vi.mock('@/services/projectsService', () => ({
  projectService: {
    list: vi.fn(),
    getById: vi.fn(),
    create: vi.fn(),
    update: vi.fn(),
    delete: vi.fn(),
    findByName: vi.fn(),
    search: vi.fn(),
  },
}));

describe('ProjectStore', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
  });

  const mockProject: Projects = {
    serialNum: 'project-1',
    name: 'Test Project',
    description: 'Test Description',
    ownerId: 'user-1',
    color: '#ff0000',
    isArchived: false,
    createdAt: '2025-01-01T00:00:00Z',
    updatedAt: '2025-01-01T00:00:00Z',
  };

  const mockProject2: Projects = {
    serialNum: 'project-2',
    name: 'Another Project',
    description: 'Another Description',
    ownerId: 'user-2',
    color: '#00ff00',
    isArchived: false,
    createdAt: '2025-01-02T00:00:00Z',
    updatedAt: '2025-01-02T00:00:00Z',
  };

  describe('fetchProjects', () => {
    it('should fetch and store projects', async () => {
      const store = useProjectStore();
      vi.mocked(projectService.list).mockResolvedValue([mockProject, mockProject2]);

      await store.fetchProjects();

      expect(projectService.list).toHaveBeenCalledOnce();
      expect(store.projects).toEqual([mockProject, mockProject2]);
      expect(store.projectCount).toBe(2);
      expect(store.error).toBeNull();
    });

    it('should handle fetch error', async () => {
      const store = useProjectStore();
      const mockError = new Error('Fetch failed');
      vi.mocked(projectService.list).mockRejectedValue(mockError);

      await expect(store.fetchProjects()).rejects.toThrow();
      expect(store.error).not.toBeNull();
      expect(store.error?.code).toBe('FETCH_FAILED');
    });
  });

  describe('fetchProjectById', () => {
    it('should fetch project by id and set currentProject', async () => {
      const store = useProjectStore();
      vi.mocked(projectService.getById).mockResolvedValue(mockProject);

      const result = await store.fetchProjectById('project-1');

      expect(projectService.getById).toHaveBeenCalledWith('project-1');
      expect(result).toEqual(mockProject);
      expect(store.currentProject).toEqual(mockProject);
    });

    it('should handle project not found', async () => {
      const store = useProjectStore();
      vi.mocked(projectService.getById).mockResolvedValue(null);

      const result = await store.fetchProjectById('non-existent');

      expect(result).toBeNull();
      expect(store.currentProject).toBeNull();
    });
  });

  describe('createProject', () => {
    it('should create a new project', async () => {
      const store = useProjectStore();
      const createData: ProjectCreate = {
        name: 'New Project',
        description: 'New Description',
        ownerId: 'user-1',
        color: '#0000ff',
        isArchived: false,
      };
      vi.mocked(projectService.create).mockResolvedValue(mockProject);

      const result = await store.createProject(createData);

      expect(projectService.create).toHaveBeenCalledWith(createData);
      expect(result).toEqual(mockProject);
      expect(store.projects).toHaveLength(1);
      expect(store.projects[0]).toEqual(mockProject);
    });

    it('should handle create error', async () => {
      const store = useProjectStore();
      const createData: ProjectCreate = {
        name: 'New Project',
        isArchived: false,
      };
      const mockError = new Error('Create failed');
      vi.mocked(projectService.create).mockRejectedValue(mockError);

      await expect(store.createProject(createData)).rejects.toThrow();
      expect(store.error).not.toBeNull();
      expect(store.error?.code).toBe('CREATE_FAILED');
    });
  });

  describe('updateProject', () => {
    it('should update an existing project', async () => {
      const store = useProjectStore();
      store.projects = [mockProject, mockProject2];

      const updateData: ProjectUpdate = { name: 'Updated Project' };
      const updatedProject = { ...mockProject, name: 'Updated Project' };
      vi.mocked(projectService.update).mockResolvedValue(updatedProject);

      const result = await store.updateProject('project-1', updateData);

      expect(projectService.update).toHaveBeenCalledWith('project-1', updateData);
      expect(result).toEqual(updatedProject);
      expect(store.projects[0]).toEqual(updatedProject);
    });

    it('should update currentProject if it matches', async () => {
      const store = useProjectStore();
      store.projects = [mockProject];
      store.currentProject = mockProject;

      const updateData: ProjectUpdate = { name: 'Updated Project' };
      const updatedProject = { ...mockProject, name: 'Updated Project' };
      vi.mocked(projectService.update).mockResolvedValue(updatedProject);

      await store.updateProject('project-1', updateData);

      expect(store.currentProject).toEqual(updatedProject);
    });

    it('should handle update error', async () => {
      const store = useProjectStore();
      const updateData: ProjectUpdate = { name: 'Updated Project' };
      const mockError = new Error('Update failed');
      vi.mocked(projectService.update).mockRejectedValue(mockError);

      await expect(store.updateProject('project-1', updateData)).rejects.toThrow();
      expect(store.error).not.toBeNull();
      expect(store.error?.code).toBe('UPDATE_FAILED');
    });
  });

  describe('deleteProject', () => {
    it('should delete a project', async () => {
      const store = useProjectStore();
      store.projects = [mockProject, mockProject2];
      vi.mocked(projectService.delete).mockResolvedValue();

      await store.deleteProject('project-1');

      expect(projectService.delete).toHaveBeenCalledWith('project-1');
      expect(store.projects).toEqual([mockProject2]);
      expect(store.projects).not.toContain(mockProject);
    });

    it('should clear currentProject if it matches deleted project', async () => {
      const store = useProjectStore();
      store.projects = [mockProject];
      store.currentProject = mockProject;
      vi.mocked(projectService.delete).mockResolvedValue();

      await store.deleteProject('project-1');

      expect(store.currentProject).toBeNull();
    });

    it('should handle delete error', async () => {
      const store = useProjectStore();
      const mockError = new Error('Delete failed');
      vi.mocked(projectService.delete).mockRejectedValue(mockError);

      await expect(store.deleteProject('project-1')).rejects.toThrow();
      expect(store.error).not.toBeNull();
      expect(store.error?.code).toBe('DELETE_FAILED');
    });
  });

  describe('findProjectsByName', () => {
    it('should find projects by name', async () => {
      const store = useProjectStore();
      vi.mocked(projectService.findByName).mockResolvedValue([mockProject]);

      const result = await store.findProjectsByName('Test Project');

      expect(projectService.findByName).toHaveBeenCalledWith('Test Project');
      expect(result).toEqual([mockProject]);
    });
  });

  describe('searchProjects', () => {
    it('should search projects by keyword', async () => {
      const store = useProjectStore();
      vi.mocked(projectService.search).mockResolvedValue([mockProject]);

      const result = await store.searchProjects('test');

      expect(projectService.search).toHaveBeenCalledWith('test');
      expect(result).toEqual([mockProject]);
    });
  });

  describe('filterAndSortProjects', () => {
    beforeEach(() => {
      const store = useProjectStore();
      store.projects = [mockProject, mockProject2];
    });

    it('should filter projects by keyword', () => {
      const store = useProjectStore();
      const result = store.filterAndSortProjects({ keyword: 'Test' });

      expect(result.results).toEqual([mockProject]);
      expect(result.total).toBe(1);
    });

    it('should filter projects by exact name', () => {
      const store = useProjectStore();
      const result = store.filterAndSortProjects({ name: 'Test Project' });

      expect(result.results).toEqual([mockProject]);
    });

    it('should filter projects by ownerId', () => {
      const store = useProjectStore();
      const result = store.filterAndSortProjects({ ownerId: 'user-1' });

      expect(result.results).toEqual([mockProject]);
    });

    it('should filter projects by isArchived', () => {
      const store = useProjectStore();
      const archivedProject = { ...mockProject2, isArchived: true };
      store.projects = [mockProject, archivedProject];

      const result = store.filterAndSortProjects({ isArchived: false });

      expect(result.results).toEqual([mockProject]);
    });

    it('should sort projects by name ascending', () => {
      const store = useProjectStore();
      const result = store.filterAndSortProjects({ sortBy: 'name', order: 'asc' });

      expect(result.results[0].name).toBe('Another Project');
      expect(result.results[1].name).toBe('Test Project');
    });

    it('should sort projects by name descending', () => {
      const store = useProjectStore();
      const result = store.filterAndSortProjects({ sortBy: 'name', order: 'desc' });

      expect(result.results[0].name).toBe('Test Project');
      expect(result.results[1].name).toBe('Another Project');
    });

    it('should paginate results', () => {
      const store = useProjectStore();
      const result = store.filterAndSortProjects({ offset: 0, limit: 1 });

      expect(result.results.length).toBe(1);
      expect(result.total).toBe(2);
    });
  });

  describe('getProject', () => {
    it('should get project from cache', () => {
      const store = useProjectStore();
      store.projects = [mockProject, mockProject2];

      const result = store.getProject('project-1');

      expect(result).toEqual(mockProject);
    });

    it('should return undefined for non-existent project', () => {
      const store = useProjectStore();
      store.projects = [mockProject];

      const result = store.getProject('non-existent');

      expect(result).toBeUndefined();
    });
  });

  describe('hasProject', () => {
    it('should return true if project exists', () => {
      const store = useProjectStore();
      store.projects = [mockProject];

      expect(store.hasProject('project-1')).toBe(true);
    });

    it('should return false if project does not exist', () => {
      const store = useProjectStore();
      store.projects = [mockProject];

      expect(store.hasProject('non-existent')).toBe(false);
    });
  });

  describe('$reset', () => {
    it('should reset store to initial state', () => {
      const store = useProjectStore();
      store.projects = [mockProject, mockProject2];
      store.currentProject = mockProject;
      store.isLoading = true;
      store.error = { code: 'TEST_ERROR' } as any;

      store.$reset();

      expect(store.projects).toEqual([]);
      expect(store.currentProject).toBeNull();
      expect(store.isLoading).toBe(false);
      expect(store.error).toBeNull();
    });
  });

  describe('computed properties', () => {
    it('should compute projectCount correctly', () => {
      const store = useProjectStore();
      expect(store.projectCount).toBe(0);

      store.projects = [mockProject, mockProject2];
      expect(store.projectCount).toBe(2);
    });

    it('should compute projectsMap correctly', () => {
      const store = useProjectStore();
      store.projects = [mockProject, mockProject2];

      expect(store.projectsMap.size).toBe(2);
      expect(store.projectsMap.get('project-1')).toEqual(mockProject);
      expect(store.projectsMap.get('project-2')).toEqual(mockProject2);
    });
  });
});
