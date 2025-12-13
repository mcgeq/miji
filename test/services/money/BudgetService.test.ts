/**
 * BudgetService 单元测试
 */

import { describe, it, expect } from 'vitest';
import { budgetService } from '@/services/money/budgetService';
import type { BudgetCreate, BudgetUpdate } from '@/schema/money';
import type { BudgetOverviewRequest } from '@/services/money/budgetStats';

describe('BudgetService', () => {
  describe('CRUD Operations', () => {
    it('should create a budget', async () => {
      const createData: BudgetCreate = {
        name: '测试预算',
        description: '这是一个测试预算',
        amount: 1000.00,
        currency: 'CNY',
        repeatPeriodType: 'Monthly',
        repeatPeriod: { type: 'Monthly', interval: 1, day: 1 },
        startDate: new Date().toISOString(),
        endDate: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
        usedAmount: 0.00,
        isActive: true,
        alertEnabled: false,
        color: '#FF5733',
        budgetScopeType: 'Category',
        categoryScope: ['食品'],
      };

      const budget = await budgetService.create(createData);

      expect(budget).toBeDefined();
      expect(budget.name).toBe(createData.name);
      expect(budget.amount).toBe(createData.amount);
    });

    it('should get budget by id', async () => {
      // First create a budget
      const createData: BudgetCreate = {
        name: '测试预算2',
        description: '获取测试',
        amount: 2000.00,
        currency: 'CNY',
        repeatPeriodType: 'Monthly',
        repeatPeriod: { type: 'Monthly', interval: 1, day: 1 },
        startDate: new Date().toISOString(),
        endDate: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
        usedAmount: 0.00,
        isActive: true,
        alertEnabled: false,
        color: '#33FF57',
        budgetScopeType: 'Category',
        categoryScope: ['交通'],
      };

      const created = await budgetService.create(createData);

      // Then get it
      const budget = await budgetService.getById(created.serialNum);

      expect(budget).toBeDefined();
      expect(budget?.serialNum).toBe(created.serialNum);
    });

    it('should list budgets', async () => {
      const budgets = await budgetService.list();

      expect(Array.isArray(budgets)).toBe(true);
    });

    it('should update a budget', async () => {
      // First create a budget
      const createData: BudgetCreate = {
        name: '待更新预算',
        description: '更新测试',
        amount: 500.00,
        currency: 'CNY',
        repeatPeriodType: 'Monthly',
        repeatPeriod: { type: 'Monthly', interval: 1, day: 1 },
        startDate: new Date().toISOString(),
        endDate: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
        usedAmount: 0.00,
        isActive: true,
        alertEnabled: false,
        color: '#5733FF',
        budgetScopeType: 'Category',
        categoryScope: ['娱乐'],
      };

      const created = await budgetService.create(createData);

      // Then update it
      const updateData: BudgetUpdate = {
        name: '已更新预算',
        amount: 800.00,
      };

      const updated = await budgetService.update(created.serialNum, updateData);

      expect(updated.name).toBe(updateData.name);
      expect(updated.amount).toBe(updateData.amount);
      expect(updated.serialNum).toBe(created.serialNum);
    });

    it('should delete a budget', async () => {
      // First create a budget
      const createData: BudgetCreate = {
        name: '待删除预算',
        description: '删除测试',
        amount: 100.00,
        currency: 'CNY',
        repeatPeriodType: 'Monthly',
        repeatPeriod: { type: 'Monthly', interval: 1, day: 1 },
        startDate: new Date().toISOString(),
        endDate: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
        usedAmount: 0.00,
        isActive: true,
        alertEnabled: false,
        color: '#FF33A1',
        budgetScopeType: 'Category',
        categoryScope: ['其他'],
      };

      const created = await budgetService.create(createData);

      // Then delete it
      await budgetService.delete(created.serialNum);

      // Verify it's deleted
      const budget = await budgetService.getById(created.serialNum);
      expect(budget).toBeNull();
    });
  });

  describe('Business Methods', () => {
    it('should update budget active status', async () => {
      const createData: BudgetCreate = {
        name: '状态测试预算',
        description: '状态测试',
        amount: 1000.00,
        currency: 'CNY',
        repeatPeriodType: 'Monthly',
        repeatPeriod: { type: 'Monthly', interval: 1, day: 1 },
        startDate: new Date().toISOString(),
        endDate: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
        usedAmount: 0.00,
        isActive: true,
        alertEnabled: false,
        color: '#A133FF',
        budgetScopeType: 'Category',
        categoryScope: ['购物'],
      };

      const created = await budgetService.create(createData);
      const updated = await budgetService.updateActive(created.serialNum, false);

      expect(updated.isActive).toBe(false);
    });
  });

  describe('Statistics Methods', () => {
    it('should get budget overview', async () => {
      const request: BudgetOverviewRequest = {
        baseCurrency: 'CNY',
        includeInactive: false,
      };

      const overview = await budgetService.getBudgetOverview(request);

      expect(overview).toBeDefined();
      expect(overview.currency).toBe('CNY');
      expect(typeof overview.totalBudgetAmount).toBe('number');
      expect(typeof overview.usedAmount).toBe('number');
      expect(typeof overview.budgetCount).toBe('number');
    });

    it('should get budget stats by type', async () => {
      const request: BudgetOverviewRequest = {
        baseCurrency: 'CNY',
        includeInactive: false,
      };

      const stats = await budgetService.getBudgetStatsByType(request);

      expect(stats).toBeDefined();
      expect(typeof stats).toBe('object');
    });

    it('should get budget stats by scope', async () => {
      const request: BudgetOverviewRequest = {
        baseCurrency: 'CNY',
        includeInactive: false,
      };

      const stats = await budgetService.getBudgetStatsByScope(request);

      expect(stats).toBeDefined();
      expect(typeof stats).toBe('object');
    });

    it('should get budget trends', async () => {
      const startDate = new Date(Date.now() - 90 * 24 * 60 * 60 * 1000).toISOString();
      const endDate = new Date().toISOString();

      const trends = await budgetService.getBudgetTrends(startDate, endDate, 'month');

      expect(Array.isArray(trends)).toBe(true);
    });

    it('should get budget category stats', async () => {
      const stats = await budgetService.getBudgetCategoryStats();

      expect(Array.isArray(stats)).toBe(true);
    });
  });
});
