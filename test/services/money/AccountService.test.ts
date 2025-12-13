/**
 * AccountService 单元测试
 */

import { describe, it, expect, beforeEach, vi } from 'vitest';
import { accountService } from '@/services/money/AccountService';
import type { Account, CreateAccountRequest, UpdateAccountRequest } from '@/schema/money';

describe('AccountService', () => {
  describe('CRUD Operations', () => {
    it('should create an account', async () => {
      const createData: CreateAccountRequest = {
        name: '测试账户',
        type: 'CASH',
        currency: 'CNY',
        balance: 1000,
        isActive: true,
      };

      const account = await accountService.create(createData);
      
      expect(account).toBeDefined();
      expect(account.name).toBe(createData.name);
      expect(account.type).toBe(createData.type);
    });

    it('should get account by id', async () => {
      // First create an account
      const createData: CreateAccountRequest = {
        name: '测试账户2',
        type: 'BANK',
        currency: 'CNY',
        balance: 2000,
        isActive: true,
      };

      const created = await accountService.create(createData);
      
      // Then get it
      const account = await accountService.getById(created.serialNum);
      
      expect(account).toBeDefined();
      expect(account?.serialNum).toBe(created.serialNum);
    });

    it('should list accounts', async () => {
      const accounts = await accountService.list();
      
      expect(Array.isArray(accounts)).toBe(true);
    });

    it('should update an account', async () => {
      // First create an account
      const createData: CreateAccountRequest = {
        name: '待更新账户',
        type: 'CASH',
        currency: 'CNY',
        balance: 500,
        isActive: true,
      };

      const created = await accountService.create(createData);
      
      // Then update it
      const updateData: UpdateAccountRequest = {
        name: '已更新账户',
      };

      const updated = await accountService.update(created.serialNum, updateData);
      
      expect(updated.name).toBe(updateData.name);
      expect(updated.serialNum).toBe(created.serialNum);
    });

    it('should delete an account', async () => {
      // First create an account
      const createData: CreateAccountRequest = {
        name: '待删除账户',
        type: 'CASH',
        currency: 'CNY',
        balance: 100,
        isActive: true,
      };

      const created = await accountService.create(createData);
      
      // Then delete it
      await accountService.delete(created.serialNum);
      
      // Verify it's deleted
      const account = await accountService.getById(created.serialNum);
      expect(account).toBeNull();
    });
  });

  describe('Business Methods', () => {
    it('should get account balance', async () => {
      const createData: CreateAccountRequest = {
        name: '余额测试账户',
        type: 'CASH',
        currency: 'CNY',
        balance: 1500,
        isActive: true,
      };

      const created = await accountService.create(createData);
      const balance = await accountService.getBalance(created.serialNum);
      
      expect(balance).toBe(1500);
    });

    it('should update account active status', async () => {
      const createData: CreateAccountRequest = {
        name: '状态测试账户',
        type: 'CASH',
        currency: 'CNY',
        balance: 1000,
        isActive: true,
      };

      const created = await accountService.create(createData);
      const updated = await accountService.updateActive(created.serialNum, false);
      
      expect(updated.isActive).toBe(false);
    });
  });
});
