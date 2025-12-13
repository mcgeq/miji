// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           tagStore.ts
// Description:    Tag Store - 标签状态管理
// Create   Date:  2025-06-23 22:38:59
// Last Modified:  2025-12-13 18:00:00
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

import { defineStore } from 'pinia';
import { computed, ref } from 'vue';
import type { AppError } from '@/errors/appError';
import type { Tags } from '@/schema/tags';
import { tagService } from '@/services/tagService';
import type { TagCreate, TagUpdate } from '@/services/tags';
import { wrapError } from '@/utils/errorHandler';
import { withLoadingSafe } from './utils/withLoadingSafe';

type SortByField = 'createdAt' | 'name';
type SortOrder = 'asc' | 'desc';

interface TagFilterOptions {
  keyword?: string;
  name?: string;
  description?: string;
  sortBy?: SortByField;
  order?: SortOrder;
  offset?: number;
  limit?: number;
}

/**
 * 标签 Store
 * 使用 Composition API 风格，遵循新的架构模式
 */
export const useTagStore = defineStore('tag', () => {
  // ============ 状态 ============
  const tags = ref<Tags[]>([]);
  const currentTag = ref<Tags | null>(null);
  const isLoading = ref(false);
  const error = ref<AppError | null>(null);

  // ============ 计算属性 ============
  const tagCount = computed(() => tags.value.length);

  const tagsMap = computed(() => {
    const map = new Map<string, Tags>();
    tags.value.forEach(tag => map.set(tag.serialNum, tag));
    return map;
  });

  // ============ Actions ============

  /**
   * 加载所有标签
   */
  const fetchTags = withLoadingSafe(
    async () => {
      try {
        tags.value = await tagService.list();
      } catch (err) {
        error.value = wrapError('TagStore', err, 'FETCH_FAILED', '获取标签列表失败');
        throw error.value;
      }
    },
    isLoading,
    error,
  );

  /**
   * 根据 ID 获取标签
   */
  const fetchTagById = withLoadingSafe(
    async (serialNum: string) => {
      try {
        const tag = await tagService.getById(serialNum);
        if (tag) {
          currentTag.value = tag;
        }
        return tag;
      } catch (err) {
        error.value = wrapError(
          'TagStore',
          err,
          'FETCH_BY_ID_FAILED',
          `获取标签失败: ${serialNum}`,
        );
        throw error.value;
      }
    },
    isLoading,
    error,
  );

  /**
   * 创建标签
   */
  const createTag = withLoadingSafe(
    async (data: TagCreate) => {
      try {
        const newTag = await tagService.create(data);
        tags.value.push(newTag);
        return newTag;
      } catch (err) {
        error.value = wrapError('TagStore', err, 'CREATE_FAILED', '创建标签失败');
        throw error.value;
      }
    },
    isLoading,
    error,
  );

  /**
   * 更新标签
   */
  const updateTag = withLoadingSafe(
    async (serialNum: string, data: TagUpdate) => {
      try {
        const updatedTag = await tagService.update(serialNum, data);
        const index = tags.value.findIndex(t => t.serialNum === serialNum);
        if (index !== -1) {
          tags.value[index] = updatedTag;
        }
        if (currentTag.value?.serialNum === serialNum) {
          currentTag.value = updatedTag;
        }
        return updatedTag;
      } catch (err) {
        error.value = wrapError('TagStore', err, 'UPDATE_FAILED', `更新标签失败: ${serialNum}`);
        throw error.value;
      }
    },
    isLoading,
    error,
  );

  /**
   * 删除标签
   */
  const deleteTag = withLoadingSafe(
    async (serialNum: string) => {
      try {
        await tagService.delete(serialNum);
        tags.value = tags.value.filter(t => t.serialNum !== serialNum);
        if (currentTag.value?.serialNum === serialNum) {
          currentTag.value = null;
        }
      } catch (err) {
        error.value = wrapError('TagStore', err, 'DELETE_FAILED', `删除标签失败: ${serialNum}`);
        throw error.value;
      }
    },
    isLoading,
    error,
  );

  /**
   * 根据名称查找标签
   */
  const findTagsByName = withLoadingSafe(
    async (name: string) => {
      try {
        return await tagService.findByName(name);
      } catch (err) {
        error.value = wrapError(
          'TagStore',
          err,
          'FIND_BY_NAME_FAILED',
          `根据名称查找标签失败: ${name}`,
        );
        throw error.value;
      }
    },
    isLoading,
    error,
  );

  /**
   * 搜索标签
   */
  const searchTags = withLoadingSafe(
    async (keyword: string) => {
      try {
        return await tagService.search(keyword);
      } catch (err) {
        error.value = wrapError('TagStore', err, 'SEARCH_FAILED', `搜索标签失败: ${keyword}`);
        throw error.value;
      }
    },
    isLoading,
    error,
  );

  /**
   * 本地过滤和排序标签（用于客户端过滤）
   */
  function filterAndSortTags(options: TagFilterOptions = {}) {
    const {
      keyword,
      name,
      description,
      sortBy = 'createdAt',
      order = 'desc',
      offset = 0,
      limit = Number.POSITIVE_INFINITY,
    } = options;

    let results = [...tags.value];

    // 关键词搜索
    if (keyword?.trim()) {
      const lower = keyword.toLowerCase();
      results = results.filter(
        tag =>
          tag.name.toLowerCase().includes(lower) || tag.description?.toLowerCase().includes(lower),
      );
    }

    // 精确匹配
    if (name) {
      results = results.filter(tag => tag.name === name);
    }
    if (description) {
      results = results.filter(tag => tag.description === description);
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
   * 获取标签（从缓存）
   */
  function getTag(serialNum: string): Tags | undefined {
    return tagsMap.value.get(serialNum);
  }

  /**
   * 检查标签是否存在（从缓存）
   */
  function hasTag(serialNum: string): boolean {
    return tagsMap.value.has(serialNum);
  }

  /**
   * 重置 Store 状态
   */
  function $reset() {
    tags.value = [];
    currentTag.value = null;
    isLoading.value = false;
    error.value = null;
  }

  return {
    // 状态
    tags,
    currentTag,
    isLoading,
    error,
    // 计算属性
    tagCount,
    tagsMap,
    // Actions
    fetchTags,
    fetchTagById,
    createTag,
    updateTag,
    deleteTag,
    findTagsByName,
    searchTags,
    filterAndSortTags,
    getTag,
    hasTag,
    // 重置
    $reset,
  };
});
