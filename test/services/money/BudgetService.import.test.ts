/**
 * BudgetService 导入验证测试
 */

import { describe, it, expect } from 'vitest';
import { budgetService } from '@/services/money/budgetService';

describe('BudgetService Import', () => {
  it('should export budgetService singleton', () => {
    expect(budgetService).toBeDefined();
    expect(typeof budgetService).toBe('object');
  });

  it('should have CRUD methods', () => {
    expect(typeof budgetService.create).toBe('function');
    expect(typeof budgetService.getById).toBe('function');
    expect(typeof budgetService.list).toBe('function');
    expect(typeof budgetService.update).toBe('function');
    expect(typeof budgetService.delete).toBe('function');
  });

  it('should have business methods', () => {
    expect(typeof budgetService.updateActive).toBe('function');
    expect(typeof budgetService.listPagedWithFilters).toBe('function');
  });

  it('should have statistics methods', () => {
    expect(typeof budgetService.getBudgetOverview).toBe('function');
    expect(typeof budgetService.getBudgetStatsByType).toBe('function');
    expect(typeof budgetService.getBudgetStatsByScope).toBe('function');
    expect(typeof budgetService.getBudgetTrends).toBe('function');
    expect(typeof budgetService.getBudgetCategoryStats).toBe('function');
  });
});
