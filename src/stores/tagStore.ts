// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           tags.svelte.ts
// Description:    About Tags Store and State
// Create   Date:  2025-06-23 22:38:59
// Last Modified:  2025-06-28 12:43:50
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

import { ref } from 'vue';
import { TagsSchema } from '../schema/tags';
import { DateUtils } from '../utils/date';
import { uuid } from '../utils/uuid';
import { createWithDefaults } from '../utils/zodFactory';
import type { Tags } from '../schema/tags';

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

// 响应式 Map 存储标签
const tags = ref(new Map<string, Tags>());

// 创建标签
function createTag(input?: Partial<Tags>): Tags {
  return createWithDefaults(
    TagsSchema,
    {
      serialNum: () => uuid(38),
      name: 'Untitled',
      description: null,
      createdAt: DateUtils.getLocalISODateTimeWithOffset,
      updatedAt: DateUtils.getLocalISODateTimeWithOffset,
    },
    input,
  );
}

// 添加标签
function addTag(input?: Partial<Tags>): Tags {
  const tag = createTag(input);
  if (tags.value.has(tag.serialNum)) {
    throw new Error(`Tag with serialNum ${tag.serialNum} already exists.`);
  }
  tags.value.set(tag.serialNum, tag);
  return tag;
}

// 更新标签（不可修改 serialNum 与 createdAt）
function updateTag(serialNum: string, input: Partial<Omit<Tags, 'serialNum' | 'createdAt'>>): Tags {
  const existing = tags.value.get(serialNum);
  if (!existing) {
    throw new Error(`Tag with serialNum ${serialNum} not found.`);
  }
  const updatedTag = createTag({
    ...existing,
    ...input,
    serialNum,
    createdAt: existing.createdAt,
    updatedAt: DateUtils.getLocalISODateTimeWithOffset(),
  });
  tags.value.set(serialNum, updatedTag);
  return updatedTag;
}

// 删除标签
function removeTag(serialNum: string): boolean {
  return tags.value.delete(serialNum);
}

// 清空所有标签
function clearAllTags(): void {
  tags.value.clear();
}

// 获取全部标签
function getAllTags(): Map<string, Tags> {
  return tags.value;
}

// 根据 serialNum 获取标签
function getTag(serialNum: string): Tags | undefined {
  return tags.value.get(serialNum);
}

// 判断标签是否存在
function hasTag(serialNum: string): boolean {
  return tags.value.has(serialNum);
}

// 根据名称查找标签
function findTagsByName(name: string): Tags[] {
  return Array.from(tags.value.values()).filter(tag => tag.name === name);
}

// 综合搜索标签
function searchTags(options: TagFilterOptions = {}) {
  const {
    keyword,
    name,
    description,
    sortBy = 'createdAt',
    order = 'desc',
    offset = 0,
    limit = Infinity,
  } = options;

  let results = Array.from(tags.value.values());

  if (keyword?.trim()) {
    const lower = keyword.toLowerCase();
    results = results.filter(
      tag =>
        tag.name.toLowerCase().includes(lower) || tag.description?.toLowerCase().includes(lower),
    );
  }
  if (name) results = results.filter(tag => tag.name === name);
  if (description) results = results.filter(tag => tag.description === description);

  results.sort((a, b) => {
    const fieldA = a[sortBy];
    const fieldB = b[sortBy];

    if (typeof fieldA === 'string' && typeof fieldB === 'string') {
      const cmp = fieldA.localeCompare(fieldB);
      return order === 'asc' ? cmp : -cmp;
    }
    return 0;
  });

  const total = results.length;
  const paged = results.slice(offset, offset + limit);

  return { total, results: paged };
}

export const tagsStore = {
  tags,
  createTag,
  addTag,
  updateTag,
  removeTag,
  clearAllTags,
  getAllTags,
  getTag,
  hasTag,
  findTagsByName,
  searchTags,
};
