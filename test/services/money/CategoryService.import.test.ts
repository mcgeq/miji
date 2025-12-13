/**
 * CategoryService 和 SubCategoryService 导入验证测试
 */

import { describe, it, expect } from 'vitest';
import { categoryService } from '@/services/money/categoryService';
import { subCategoryService } from '@/services/money/subCategoryService';

describe('CategoryService Import', () => {
  it('should export categoryService singleton', () => {
    expect(categoryService).toBeDefined();
    expect(typeof categoryService).toBe('object');
  });

  it('should have CRUD methods', () => {
    expect(typeof categoryService.create).toBe('function');
    expect(typeof categoryService.getById).toBe('function');
    expect(typeof categoryService.list).toBe('function');
    expect(typeof categoryService.update).toBe('function');
    expect(typeof categoryService.delete).toBe('function');
  });

  it('should have business methods', () => {
    expect(typeof categoryService.getByName).toBe('function');
    expect(typeof categoryService.exists).toBe('function');
    expect(typeof categoryService.listNames).toBe('function');
  });
});

describe('SubCategoryService Import', () => {
  it('should export subCategoryService singleton', () => {
    expect(subCategoryService).toBeDefined();
    expect(typeof subCategoryService).toBe('object');
  });

  it('should have CRUD methods', () => {
    expect(typeof subCategoryService.create).toBe('function');
    expect(typeof subCategoryService.getById).toBe('function');
    expect(typeof subCategoryService.list).toBe('function');
    expect(typeof subCategoryService.update).toBe('function');
    expect(typeof subCategoryService.delete).toBe('function');
  });

  it('should have business methods', () => {
    expect(typeof subCategoryService.listByCategory).toBe('function');
    expect(typeof subCategoryService.getByNameAndCategory).toBe('function');
    expect(typeof subCategoryService.exists).toBe('function');
    expect(typeof subCategoryService.listNamesByCategory).toBe('function');
  });
});
