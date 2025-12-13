/**
 * FamilyLedgerService 单元测试
 */

import { describe, it, expect, vi, beforeEach } from 'vitest';
import type { FamilyLedger, FamilyLedgerCreate, FamilyLedgerUpdate } from '@/schema/money';

// Mock the mappers
vi.mock('@/services/money/family', () => {
  return {
    FamilyLedgerMapper: vi.fn().mockImplementation(() => ({
      create: vi.fn(),
      getById: vi.fn(),
      list: vi.fn(),
      update: vi.fn(),
      deleteById: vi.fn(),
      getDetail: vi.fn(),
      getStats: vi.fn(),
      listPaged: vi.fn(),
    })),
    FamilyLedgerAccountMapper: vi.fn().mockImplementation(() => ({
      create: vi.fn(),
      getById: vi.fn(),
      list: vi.fn(),
      update: vi.fn(),
      deleteById: vi.fn(),
      listByLedger: vi.fn(),
      listByAccount: vi.fn(),
      delete: vi.fn(),
    })),
    FamilyLedgerMemberMapper: vi.fn().mockImplementation(() => ({
      create: vi.fn(),
      getById: vi.fn(),
      list: vi.fn(),
      update: vi.fn(),
      deleteById: vi.fn(),
    })),
    FamilyLedgerTransactionMapper: vi.fn().mockImplementation(() => ({
      create: vi.fn(),
      getById: vi.fn(),
      list: vi.fn(),
      update: vi.fn(),
      deleteById: vi.fn(),
      listByLedger: vi.fn(),
      listByTransaction: vi.fn(),
      batchCreate: vi.fn(),
      batchDelete: vi.fn(),
      updateTransactionLedgers: vi.fn(),
    })),
  };
});

// Mock error handler
vi.mock('@/utils/errorHandler', () => ({
  wrapError: vi.fn((module, error, code, message) => {
    const err = new Error(message);
    (err as any).code = code;
    (err as any).module = module;
    (err as any).originalError = error;
    return err;
  }),
}));

// Import after mocks
import { familyLedgerService } from '@/services/family/familyLedgerService';
import type { Currency } from '@/schema/common';

// Helper to create mock currency
const createMockCurrency = (code: string): Currency => ({
  code,
  locale: 'zh-CN',
  symbol: '¥',
  isDefault: true,
  isActive: true,
  createdAt: new Date().toISOString(),
});

describe('FamilyLedgerService', () => {
  let mockMapper: any;

  beforeEach(() => {
    vi.clearAllMocks();
    // Get the mocked mapper instance
    mockMapper = (familyLedgerService as any).familyLedgerMapper;
  });

  describe('CRUD Operations', () => {
    it('should create a family ledger', async () => {
      const createData: FamilyLedgerCreate = {
        name: '测试家庭账本',
        description: '这是一个测试账本',
        baseCurrency: 'CNY',
        memberList: [],
        ledgerType: 'FAMILY',
        settlementCycle: 'MONTHLY',
        autoSettlement: false,
        settlementDay: 1,
      };

      const mockLedger: FamilyLedger = {
        serialNum: 'ledger_123',
        name: createData.name,
        description: createData.description,
        baseCurrency: createMockCurrency('CNY'),
        memberList: [],
        ledgerType: createData.ledgerType,
        settlementCycle: createData.settlementCycle,
        autoSettlement: createData.autoSettlement,
        settlementDay: createData.settlementDay,
        auditLogs: '',
        totalIncome: 0,
        totalExpense: 0,
        sharedExpense: 0,
        personalExpense: 0,
        pendingSettlement: 0,
        createdAt: new Date().toISOString(),
      };

      mockMapper.create.mockResolvedValueOnce(mockLedger);

      const ledger = await familyLedgerService.create(createData);

      expect(ledger).toBeDefined();
      expect(ledger.name).toBe(createData.name);
      expect(ledger.ledgerType).toBe(createData.ledgerType);
      expect(mockMapper.create).toHaveBeenCalledWith(createData);
    });

    it('should get ledger by id', async () => {
      const mockLedger: FamilyLedger = {
        serialNum: 'ledger_123',
        name: '测试账本2',
        description: '测试描述',
        baseCurrency: createMockCurrency('CNY'),
        memberList: [],
        ledgerType: 'FAMILY',
        settlementCycle: 'MONTHLY',
        autoSettlement: false,
        settlementDay: 1,
        auditLogs: '',
        totalIncome: 0,
        totalExpense: 0,
        sharedExpense: 0,
        personalExpense: 0,
        pendingSettlement: 0,
        createdAt: new Date().toISOString(),
      };

      mockMapper.getById.mockResolvedValueOnce(mockLedger);

      const ledger = await familyLedgerService.getById('ledger_123');

      expect(ledger).toBeDefined();
      expect(ledger?.serialNum).toBe('ledger_123');
      expect(mockMapper.getById).toHaveBeenCalledWith('ledger_123');
    });

    it('should list ledgers', async () => {
      const mockLedgers: FamilyLedger[] = [
        {
          serialNum: 'ledger_1',
          name: '账本1',
          description: '描述1',
          baseCurrency: createMockCurrency('CNY'),
          memberList: [],
          ledgerType: 'FAMILY',
          settlementCycle: 'MONTHLY',
          autoSettlement: false,
          settlementDay: 1,
          auditLogs: '',
          totalIncome: 0,
          totalExpense: 0,
          sharedExpense: 0,
          personalExpense: 0,
          pendingSettlement: 0,
          createdAt: new Date().toISOString(),
        },
      ];

      mockMapper.list.mockResolvedValueOnce(mockLedgers);

      const ledgers = await familyLedgerService.list();

      expect(Array.isArray(ledgers)).toBe(true);
      expect(ledgers).toHaveLength(1);
      expect(mockMapper.list).toHaveBeenCalled();
    });

    it('should update a ledger', async () => {
      const updateData: FamilyLedgerUpdate = {
        name: '已更新账本',
        description: '更新后的描述',
      };

      const mockUpdatedLedger: FamilyLedger = {
        serialNum: 'ledger_123',
        name: '已更新账本',
        description: '更新后的描述',
        baseCurrency: createMockCurrency('CNY'),
        memberList: [],
        ledgerType: 'FAMILY',
        settlementCycle: 'MONTHLY',
        autoSettlement: false,
        settlementDay: 1,
        auditLogs: '',
        totalIncome: 0,
        totalExpense: 0,
        sharedExpense: 0,
        personalExpense: 0,
        pendingSettlement: 0,
        createdAt: new Date().toISOString(),
      };

      mockMapper.update.mockResolvedValueOnce(mockUpdatedLedger);

      const updated = await familyLedgerService.update('ledger_123', updateData);

      expect(updated.name).toBe(updateData.name);
      expect(updated.description).toBe(updateData.description);
      expect(mockMapper.update).toHaveBeenCalledWith('ledger_123', updateData);
    });

    it('should delete a ledger', async () => {
      mockMapper.deleteById.mockResolvedValueOnce(undefined);

      await familyLedgerService.delete('ledger_123');

      expect(mockMapper.deleteById).toHaveBeenCalledWith('ledger_123');
    });
  });

  describe('Business Methods', () => {
    it('should get ledger detail', async () => {
      const mockDetail: FamilyLedger = {
        serialNum: 'ledger_123',
        name: '详情测试账本',
        description: '测试获取详情',
        baseCurrency: createMockCurrency('CNY'),
        ledgerType: 'FAMILY',
        settlementCycle: 'MONTHLY',
        autoSettlement: false,
        settlementDay: 1,
        auditLogs: '',
        totalIncome: 0,
        totalExpense: 0,
        sharedExpense: 0,
        personalExpense: 0,
        pendingSettlement: 0,
        memberList: [],
        createdAt: new Date().toISOString(),
      };

      mockMapper.getDetail.mockResolvedValueOnce(mockDetail);

      const detail = await familyLedgerService.getDetail('ledger_123');

      expect(detail).toBeDefined();
      expect(detail.serialNum).toBe('ledger_123');
      expect(mockMapper.getDetail).toHaveBeenCalledWith('ledger_123');
    });

    it('should get ledger stats', async () => {
      const mockStats = {
        familyLedgerSerialNum: 'ledger_123',
        totalIncome: 1000,
        totalExpense: 500,
        sharedExpense: 300,
        personalExpense: 200,
        pendingSettlement: 100,
        memberCount: 3,
        activeTransactionCount: 10,
        memberStats: [],
      };

      mockMapper.getStats.mockResolvedValueOnce(mockStats);

      const stats = await familyLedgerService.getStats('ledger_123');

      expect(stats).toBeDefined();
      expect(stats?.familyLedgerSerialNum).toBe('ledger_123');
      expect(mockMapper.getStats).toHaveBeenCalledWith('ledger_123');
    });
  });

  describe('Member Management', () => {
    it('should add member to ledger', async () => {
      const mockMemberAssoc = {
        familyLedgerSerialNum: 'ledger_123',
        familyMemberSerialNum: 'member_456',
        createdAt: new Date().toISOString(),
      };

      const mockMemberMapper = (familyLedgerService as any).familyLedgerMemberMapper;
      mockMemberMapper.create.mockResolvedValueOnce(mockMemberAssoc);

      const result = await familyLedgerService.addMember('ledger_123', 'member_456');

      expect(result).toBeDefined();
      expect(result.familyLedgerSerialNum).toBe('ledger_123');
      expect(result.familyMemberSerialNum).toBe('member_456');
    });
  });

  describe('Account Management', () => {
    it('should get ledger accounts', async () => {
      const mockAccounts = [
        {
          serialNum: 'assoc_1',
          familyLedgerSerialNum: 'ledger_123',
          accountSerialNum: 'account_1',
          createdAt: new Date().toISOString(),
        },
      ];

      const mockAccountMapper = (familyLedgerService as any).familyLedgerAccountMapper;
      mockAccountMapper.listByLedger.mockResolvedValueOnce(mockAccounts);

      const accounts = await familyLedgerService.getAccounts('ledger_123');

      expect(Array.isArray(accounts)).toBe(true);
      expect(accounts).toHaveLength(1);
      expect(mockAccountMapper.listByLedger).toHaveBeenCalledWith('ledger_123');
    });
  });

  describe('Transaction Management', () => {
    it('should get ledger transactions', async () => {
      const mockTransactions = [
        {
          serialNum: 'assoc_1',
          familyLedgerSerialNum: 'ledger_123',
          transactionSerialNum: 'txn_1',
          createdAt: new Date().toISOString(),
        },
      ];

      const mockTransactionMapper = (familyLedgerService as any).familyLedgerTransactionMapper;
      mockTransactionMapper.listByLedger.mockResolvedValueOnce(mockTransactions);

      const transactions = await familyLedgerService.getTransactions('ledger_123');

      expect(Array.isArray(transactions)).toBe(true);
      expect(transactions).toHaveLength(1);
      expect(mockTransactionMapper.listByLedger).toHaveBeenCalledWith('ledger_123');
    });
  });
});
