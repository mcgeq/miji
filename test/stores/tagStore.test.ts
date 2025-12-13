/**
 * TagStore 单元测试
 * 测试 Store actions、错误处理和 $reset 方法
 */

import { describe, it, expect, beforeEach, vi } from 'vitest';
import { setActivePinia, createPinia } from 'pinia';
import { useTagStore } from '@/stores/tagStore';
import { tagService } from '@/services/tagService';
import type { Tags } from '@/schema/tags';
import type { TagCreate, TagUpdate } from '@/services/tags';

// Mock tagService
vi.mock('@/services/tagService', () => ({
  tagService: {
    list: vi.fn(),
    getById: vi.fn(),
    create: vi.fn(),
    update: vi.fn(),
    delete: vi.fn(),
    findByName: vi.fn(),
    search: vi.fn(),
  },
}));

describe('TagStore', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
  });

  const mockTag: Tags = {
    serialNum: 'tag-1',
    name: 'Test Tag',
    description: 'Test Description',
    createdAt: '2025-01-01T00:00:00Z',
    updatedAt: '2025-01-01T00:00:00Z',
  };

  const mockTag2: Tags = {
    serialNum: 'tag-2',
    name: 'Another Tag',
    description: 'Another Description',
    createdAt: '2025-01-02T00:00:00Z',
    updatedAt: '2025-01-02T00:00:00Z',
  };

  describe('fetchTags', () => {
    it('should fetch and store tags', async () => {
      const store = useTagStore();
      vi.mocked(tagService.list).mockResolvedValue([mockTag, mockTag2]);

      await store.fetchTags();

      expect(tagService.list).toHaveBeenCalledOnce();
      expect(store.tags).toEqual([mockTag, mockTag2]);
      expect(store.tagCount).toBe(2);
      expect(store.error).toBeNull();
    });

    it('should handle fetch error', async () => {
      const store = useTagStore();
      const mockError = new Error('Fetch failed');
      vi.mocked(tagService.list).mockRejectedValue(mockError);

      await expect(store.fetchTags()).rejects.toThrow();
      expect(store.error).not.toBeNull();
      expect(store.error?.code).toBe('FETCH_FAILED');
    });
  });

  describe('fetchTagById', () => {
    it('should fetch tag by id and set currentTag', async () => {
      const store = useTagStore();
      vi.mocked(tagService.getById).mockResolvedValue(mockTag);

      const result = await store.fetchTagById('tag-1');

      expect(tagService.getById).toHaveBeenCalledWith('tag-1');
      expect(result).toEqual(mockTag);
      expect(store.currentTag).toEqual(mockTag);
    });

    it('should handle tag not found', async () => {
      const store = useTagStore();
      vi.mocked(tagService.getById).mockResolvedValue(null);

      const result = await store.fetchTagById('non-existent');

      expect(result).toBeNull();
      expect(store.currentTag).toBeNull();
    });
  });

  describe('createTag', () => {
    it('should create a new tag', async () => {
      const store = useTagStore();
      const createData: TagCreate = {
        name: 'New Tag',
        description: 'New Description',
      };
      vi.mocked(tagService.create).mockResolvedValue(mockTag);

      const result = await store.createTag(createData);

      expect(tagService.create).toHaveBeenCalledWith(createData);
      expect(result).toEqual(mockTag);
      expect(store.tags).toHaveLength(1);
      expect(store.tags[0]).toEqual(mockTag);
    });

    it('should handle create error', async () => {
      const store = useTagStore();
      const createData: TagCreate = { name: 'New Tag' };
      const mockError = new Error('Create failed');
      vi.mocked(tagService.create).mockRejectedValue(mockError);

      await expect(store.createTag(createData)).rejects.toThrow();
      expect(store.error).not.toBeNull();
      expect(store.error?.code).toBe('CREATE_FAILED');
    });
  });

  describe('updateTag', () => {
    it('should update an existing tag', async () => {
      const store = useTagStore();
      store.tags = [mockTag, mockTag2];
      
      const updateData: TagUpdate = { name: 'Updated Tag' };
      const updatedTag = { ...mockTag, name: 'Updated Tag' };
      vi.mocked(tagService.update).mockResolvedValue(updatedTag);

      const result = await store.updateTag('tag-1', updateData);

      expect(tagService.update).toHaveBeenCalledWith('tag-1', updateData);
      expect(result).toEqual(updatedTag);
      expect(store.tags[0]).toEqual(updatedTag);
    });

    it('should update currentTag if it matches', async () => {
      const store = useTagStore();
      store.tags = [mockTag];
      store.currentTag = mockTag;
      
      const updateData: TagUpdate = { name: 'Updated Tag' };
      const updatedTag = { ...mockTag, name: 'Updated Tag' };
      vi.mocked(tagService.update).mockResolvedValue(updatedTag);

      await store.updateTag('tag-1', updateData);

      expect(store.currentTag).toEqual(updatedTag);
    });

    it('should handle update error', async () => {
      const store = useTagStore();
      const updateData: TagUpdate = { name: 'Updated Tag' };
      const mockError = new Error('Update failed');
      vi.mocked(tagService.update).mockRejectedValue(mockError);

      await expect(store.updateTag('tag-1', updateData)).rejects.toThrow();
      expect(store.error).not.toBeNull();
      expect(store.error?.code).toBe('UPDATE_FAILED');
    });
  });

  describe('deleteTag', () => {
    it('should delete a tag', async () => {
      const store = useTagStore();
      store.tags = [mockTag, mockTag2];
      vi.mocked(tagService.delete).mockResolvedValue();

      await store.deleteTag('tag-1');

      expect(tagService.delete).toHaveBeenCalledWith('tag-1');
      expect(store.tags).toEqual([mockTag2]);
      expect(store.tags).not.toContain(mockTag);
    });

    it('should clear currentTag if it matches deleted tag', async () => {
      const store = useTagStore();
      store.tags = [mockTag];
      store.currentTag = mockTag;
      vi.mocked(tagService.delete).mockResolvedValue();

      await store.deleteTag('tag-1');

      expect(store.currentTag).toBeNull();
    });

    it('should handle delete error', async () => {
      const store = useTagStore();
      const mockError = new Error('Delete failed');
      vi.mocked(tagService.delete).mockRejectedValue(mockError);

      await expect(store.deleteTag('tag-1')).rejects.toThrow();
      expect(store.error).not.toBeNull();
      expect(store.error?.code).toBe('DELETE_FAILED');
    });
  });

  describe('findTagsByName', () => {
    it('should find tags by name', async () => {
      const store = useTagStore();
      vi.mocked(tagService.findByName).mockResolvedValue([mockTag]);

      const result = await store.findTagsByName('Test Tag');

      expect(tagService.findByName).toHaveBeenCalledWith('Test Tag');
      expect(result).toEqual([mockTag]);
    });
  });

  describe('searchTags', () => {
    it('should search tags by keyword', async () => {
      const store = useTagStore();
      vi.mocked(tagService.search).mockResolvedValue([mockTag]);

      const result = await store.searchTags('test');

      expect(tagService.search).toHaveBeenCalledWith('test');
      expect(result).toEqual([mockTag]);
    });
  });

  describe('filterAndSortTags', () => {
    beforeEach(() => {
      const store = useTagStore();
      store.tags = [mockTag, mockTag2];
    });

    it('should filter tags by keyword', () => {
      const store = useTagStore();
      const result = store.filterAndSortTags({ keyword: 'Test' });

      expect(result.results).toEqual([mockTag]);
      expect(result.total).toBe(1);
    });

    it('should filter tags by exact name', () => {
      const store = useTagStore();
      const result = store.filterAndSortTags({ name: 'Test Tag' });

      expect(result.results).toEqual([mockTag]);
    });

    it('should sort tags by name ascending', () => {
      const store = useTagStore();
      const result = store.filterAndSortTags({ sortBy: 'name', order: 'asc' });

      expect(result.results[0].name).toBe('Another Tag');
      expect(result.results[1].name).toBe('Test Tag');
    });

    it('should sort tags by name descending', () => {
      const store = useTagStore();
      const result = store.filterAndSortTags({ sortBy: 'name', order: 'desc' });

      expect(result.results[0].name).toBe('Test Tag');
      expect(result.results[1].name).toBe('Another Tag');
    });

    it('should paginate results', () => {
      const store = useTagStore();
      const result = store.filterAndSortTags({ offset: 0, limit: 1 });

      expect(result.results.length).toBe(1);
      expect(result.total).toBe(2);
    });
  });

  describe('getTag', () => {
    it('should get tag from cache', () => {
      const store = useTagStore();
      store.tags = [mockTag, mockTag2];

      const result = store.getTag('tag-1');

      expect(result).toEqual(mockTag);
    });

    it('should return undefined for non-existent tag', () => {
      const store = useTagStore();
      store.tags = [mockTag];

      const result = store.getTag('non-existent');

      expect(result).toBeUndefined();
    });
  });

  describe('hasTag', () => {
    it('should return true if tag exists', () => {
      const store = useTagStore();
      store.tags = [mockTag];

      expect(store.hasTag('tag-1')).toBe(true);
    });

    it('should return false if tag does not exist', () => {
      const store = useTagStore();
      store.tags = [mockTag];

      expect(store.hasTag('non-existent')).toBe(false);
    });
  });

  describe('$reset', () => {
    it('should reset store to initial state', () => {
      const store = useTagStore();
      store.tags = [mockTag, mockTag2];
      store.currentTag = mockTag;
      store.isLoading = true;
      store.error = { code: 'TEST_ERROR' } as any;

      store.$reset();

      expect(store.tags).toEqual([]);
      expect(store.currentTag).toBeNull();
      expect(store.isLoading).toBe(false);
      expect(store.error).toBeNull();
    });
  });

  describe('computed properties', () => {
    it('should compute tagCount correctly', () => {
      const store = useTagStore();
      expect(store.tagCount).toBe(0);

      store.tags = [mockTag, mockTag2];
      expect(store.tagCount).toBe(2);
    });

    it('should compute tagsMap correctly', () => {
      const store = useTagStore();
      store.tags = [mockTag, mockTag2];

      expect(store.tagsMap.size).toBe(2);
      expect(store.tagsMap.get('tag-1')).toEqual(mockTag);
      expect(store.tagsMap.get('tag-2')).toEqual(mockTag2);
    });
  });
});
