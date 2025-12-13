import type { DateRange, PageQuery } from '@/schema/common';
import type {
  FamilyLedger,
  FamilyLedgerAccount,
  FamilyLedgerAccountCreate,
  FamilyLedgerAccountUpdate,
  FamilyLedgerCreate,
  FamilyLedgerMember,
  FamilyLedgerMemberCreate,
  FamilyLedgerMemberUpdate,
  FamilyLedgerStats,
  FamilyLedgerTransaction,
  FamilyLedgerTransactionCreate,
  FamilyLedgerTransactionUpdate,
  FamilyLedgerUpdate,
  FamilyMember,
  FamilyMemberCreate,
  FamilyMemberUpdate,
} from '@/schema/money';
import { invokeCommand } from '@/types/api';
import { Lg } from '@/utils/debugLog';
import type { PagedResult } from './baseManager';
import { BaseMapper } from './baseManager';

// 查询过滤器接口
export interface FamilyMemberFilters {
  role?: string;
  isPrimary?: boolean;
  createdAtRange?: DateRange;
  updatedAtRange?: DateRange;
}

export interface FamilyLedgerFilters {
  baseCurrency?: string;
  createdAtRange?: DateRange;
  updatedAtRange?: DateRange;
}

export interface FamilyLedgerAccountFilters {
  familyLedgerSerialNum?: string;
  accountSerialNum?: string;
}

export interface FamilyLedgerTransactionFilters {
  familyLedgerSerialNum?: string;
  transactionSerialNum?: string;
}

export interface FamilyLedgerMemberFilters {
  familyLedgerSerialNum?: string;
  familyMemberSerialNum?: string;
}

/**
 * 家庭成员数据映射器
 */
export class FamilyMemberMapper extends BaseMapper<
  FamilyMemberCreate,
  FamilyMemberUpdate,
  FamilyMember
> {
  protected entityName = 'family_member';
  async create(member: FamilyMemberCreate): Promise<FamilyMember> {
    try {
      const result = await invokeCommand<FamilyMember>('family_member_create', {
        data: member,
      });
      return result;
    } catch (error) {
      this.handleError('create', error);
    }
  }

  async getById(serialNum: string): Promise<FamilyMember | null> {
    try {
      const result = await invokeCommand<FamilyMember>('family_member_get', {
        serialNum,
      });
      return result;
    } catch (error) {
      this.handleError('getById', error);
    }
  }

  async list(): Promise<FamilyMember[]> {
    try {
      const result = await invokeCommand<FamilyMember[]>('family_member_list', {
        filter: {},
      });
      return result;
    } catch (_error) {
      // 如果命令不存在，返回空数组而不是抛出错误
      Lg.w('MoneyDb', 'family_member_list command not found, returning empty array');
      return [];
    }
  }

  async update(serialNum: string, member: FamilyMemberUpdate): Promise<FamilyMember> {
    try {
      const result = await invokeCommand<FamilyMember>('family_member_update', {
        serialNum,
        data: member,
      });
      Lg.d('MoneyDb', 'FamilyMember updated:', { serialNum });
      return result;
    } catch (error) {
      this.handleError('update', error);
    }
  }

  async deleteById(serialNum: string): Promise<void> {
    try {
      await invokeCommand('family_member_delete', { serialNum });
      Lg.d('MoneyDb', 'FamilyMember deleted:', { serialNum });
    } catch (error) {
      this.handleError('deleteById', error);
    }
  }

  async listPaged(
    query: PageQuery<FamilyMemberFilters> = {
      currentPage: 1,
      pageSize: 10,
      sortOptions: {},
      filter: {},
    },
  ): Promise<PagedResult<FamilyMember>> {
    try {
      const result = await invokeCommand<PagedResult<FamilyMember>>('family_member_list_paged', {
        query,
      });
      return result;
    } catch (err) {
      this.handleError('listPaged', err);
    }
  }
}

/**
 * 家庭账本数据映射器
 */
export class FamilyLedgerMapper extends BaseMapper<
  FamilyLedgerCreate,
  FamilyLedgerUpdate,
  FamilyLedger
> {
  protected entityName = 'family_ledger';
  async create(ledger: FamilyLedgerCreate): Promise<FamilyLedger> {
    try {
      const result = await invokeCommand<FamilyLedger>('family_ledger_create', {
        data: ledger,
      });
      Lg.d('MoneyDb', `FamilyLedger created:, ${result.serialNum}`);
      return result;
    } catch (error) {
      this.handleError('create', error);
    }
  }

  async getById(serialNum: string): Promise<FamilyLedger | null> {
    try {
      const result = await invokeCommand<FamilyLedger>('family_ledger_get', {
        serialNum,
      });
      return result;
    } catch (error) {
      this.handleError('getById', error);
    }
  }

  /**
   * 获取账本详情（包含成员和账户列表）
   */
  async getDetail(serialNum: string): Promise<FamilyLedger> {
    try {
      const result = await invokeCommand<FamilyLedger>('family_ledger_detail', {
        serialNum,
      });
      Lg.d('MoneyDb', `FamilyLedger detail loaded: ${result.serialNum}`);
      return result;
    } catch (error) {
      this.handleError('getDetail', error);
    }
  }

  async list(): Promise<FamilyLedger[]> {
    try {
      const result = await invokeCommand<FamilyLedger[]>('family_ledger_list');
      return result;
    } catch (error) {
      Lg.e('MoneyDb', 'Failed to fetch family ledgers:', error);
      throw error;
    }
  }

  async update(serialNum: string, ledger: FamilyLedgerUpdate): Promise<FamilyLedger> {
    try {
      const result = await invokeCommand<FamilyLedger>('family_ledger_update', {
        serialNum,
        data: ledger,
      });
      Lg.d('MoneyDb', `FamilyLedger updated:, ${result.serialNum}`);
      return result;
    } catch (error) {
      this.handleError('update', error);
    }
  }

  /**
   * 获取账本统计信息
   */
  async getStats(serialNum: string): Promise<FamilyLedgerStats | null> {
    try {
      const result = await invokeCommand<FamilyLedgerStats | null>('family_ledger_stats', {
        serialNum,
      });
      Lg.d('MoneyDb', `FamilyLedger stats loaded: ${serialNum}`);
      return result;
    } catch (error) {
      this.handleError('getStats', error);
    }
  }

  async deleteById(serialNum: string): Promise<void> {
    try {
      await invokeCommand('family_ledger_delete', { serialNum });
      Lg.d('MoneyDb', 'FamilyLedger deleted:', { serialNum });
    } catch (error) {
      this.handleError('deleteById', error);
    }
  }

  async listPaged(
    query: PageQuery<FamilyMemberFilters> = {
      currentPage: 1,
      pageSize: 10,
      sortOptions: {},
      filter: {},
    },
  ): Promise<PagedResult<FamilyLedger>> {
    try {
      const result = await invokeCommand<PagedResult<FamilyLedger>>('family_ledger_list_paged', {
        query,
      });
      return result;
    } catch (error) {
      this.handleError('listPaged', error);
    }
  }
}

/**
 * 家庭账本账户关联数据映射器
 */
export class FamilyLedgerAccountMapper extends BaseMapper<
  FamilyLedgerAccountCreate,
  FamilyLedgerAccountUpdate,
  FamilyLedgerAccount
> {
  protected entityName = 'family_ledger_account';
  async create(assoc: FamilyLedgerAccountCreate): Promise<FamilyLedgerAccount> {
    try {
      const result = await invokeCommand<FamilyLedgerAccount>('family_ledger_account_create', {
        data: assoc,
      });
      Lg.d('MoneyDb', `FamilyLedgerAccount created:, ${result.serialNum}`);
      return result;
    } catch (error) {
      this.handleError('create', error);
    }
  }

  async getById(serialNum: string): Promise<FamilyLedgerAccount | null> {
    try {
      return await invokeCommand<FamilyLedgerAccount>('family_ledger_account_get', { serialNum });
    } catch (error) {
      this.handleError('getById', error);
    }
  }

  async list(): Promise<FamilyLedgerAccount[]> {
    try {
      const result = await invokeCommand<FamilyLedgerAccount[]>('family_ledger_account_list', {
        filter: {},
      });
      return result;
    } catch (_error) {
      Lg.w('MoneyDb', 'family_ledger_account_list command not found, returning empty array');
      return [];
    }
  }

  async update(serialNum: string, assoc: FamilyLedgerAccountUpdate): Promise<FamilyLedgerAccount> {
    try {
      const result = await invokeCommand<FamilyLedgerAccount>('family_ledger_account_update', {
        serialNum,
        data: assoc,
      });
      Lg.d('MoneyDb', `FamilyLedgerAccount updated:, ${result.serialNum}`);
      return result;
    } catch (error) {
      this.handleError('update', error);
    }
  }

  async deleteById(serialNum: string): Promise<void> {
    try {
      await invokeCommand('family_ledger_account_delete', { serialNum });
      Lg.d('MoneyDb', 'FamilyLedgerAccount deleted:', { serialNum });
    } catch (error) {
      this.handleError('deleteById', error);
    }
  }

  async listByLedger(ledgerSerialNum: string): Promise<FamilyLedgerAccount[]> {
    try {
      return await invokeCommand<FamilyLedgerAccount[]>('family_ledger_account_list_by_ledger', {
        ledgerSerialNum,
      });
    } catch (_error) {
      Lg.w(
        'MoneyDb',
        'family_ledger_account_list_by_ledger command not found, returning empty array',
      );
      return [];
    }
  }

  async listByAccount(accountSerialNum: string): Promise<FamilyLedgerAccount[]> {
    try {
      return await invokeCommand<FamilyLedgerAccount[]>('family_ledger_account_list_by_account', {
        accountSerialNum,
      });
    } catch (_error) {
      Lg.w(
        'MoneyDb',
        'family_ledger_account_list_by_account command not found, returning empty array',
      );
      return [];
    }
  }

  async delete(ledgerSerialNum: string, accountSerialNum: string): Promise<void> {
    try {
      await invokeCommand('family_ledger_account_delete', {
        ledgerSerialNum,
        accountSerialNum,
      });
      Lg.d('MoneyDb', 'FamilyLedgerAccount deleted:', { ledgerSerialNum, accountSerialNum });
    } catch (error) {
      this.handleError('delete', error);
    }
  }

  async listPaged(
    query: PageQuery<FamilyMemberFilters> = {
      currentPage: 1,
      pageSize: 10,
      sortOptions: {},
      filter: {},
    },
  ): Promise<PagedResult<FamilyLedgerAccount>> {
    try {
      return await invokeCommand<PagedResult<FamilyLedgerAccount>>(
        'family_ledger_account_list_paged',
        { query },
      );
    } catch (error) {
      this.handleError('listPaged', error);
    }
  }
}

/**
 * 家庭账本交易关联数据映射器
 */
export class FamilyLedgerTransactionMapper extends BaseMapper<
  FamilyLedgerTransactionCreate,
  FamilyLedgerTransactionUpdate,
  FamilyLedgerTransaction
> {
  protected entityName = 'family_ledger_transaction';
  async create(assoc: FamilyLedgerTransactionCreate): Promise<FamilyLedgerTransaction> {
    try {
      const result = await invokeCommand<FamilyLedgerTransaction>(
        'family_ledger_transaction_create',
        { data: assoc },
      );
      Lg.d('MoneyDb', `FamilyLedgerTransaction created:, ${result.serialNum}`);
      return result;
    } catch (error) {
      this.handleError('create', error);
    }
  }

  async getById(serialNum: string): Promise<FamilyLedgerTransaction | null> {
    try {
      const result = await invokeCommand<FamilyLedgerTransaction>('family_ledger_transaction_get', {
        serialNum,
      });
      return result;
    } catch (error) {
      this.handleError('getById', error);
    }
  }

  async list(): Promise<FamilyLedgerTransaction[]> {
    try {
      const result = await invokeCommand<FamilyLedgerTransaction[]>(
        'family_ledger_transaction_list',
        { filter: {} },
      );
      return result;
    } catch (_error) {
      Lg.w('MoneyDb', 'family_ledger_transaction_list command not found, returning empty array');
      return [];
    }
  }

  async deleteById(serialNum: string): Promise<void> {
    try {
      await invokeCommand('family_ledger_transaction_delete', { serialNum });
      Lg.d('MoneyDb', 'FamilyLedgerTransaction deleted:', {
        serialNum,
      });
    } catch (error) {
      this.handleError('deleteById', error);
    }
  }

  async update(
    serialNum: string,
    assoc: FamilyLedgerTransaction,
  ): Promise<FamilyLedgerTransaction> {
    try {
      const result = await invokeCommand<FamilyLedgerTransaction>(
        'family_ledger_transaction_update',
        { serialNum, data: assoc },
      );
      Lg.d('MoneyDb', `FamilyLedgerTransaction updated:, ${result.serialNum}`);
      return result;
    } catch (error) {
      this.handleError('update', error);
    }
  }

  async listPaged(
    query: PageQuery<FamilyLedgerTransactionFilters> = {
      currentPage: 1,
      pageSize: 10,
      sortOptions: {},
      filter: {},
    },
  ): Promise<PagedResult<FamilyLedgerTransaction>> {
    try {
      const result = await invokeCommand<PagedResult<FamilyLedgerTransaction>>(
        'family_ledger_transaction_list_paged',
        { query },
      );
      return result;
    } catch (error) {
      this.handleError('listPaged', error);
    }
  }

  /**
   * 根据账本ID查询所有关联的交易
   */
  async listByLedger(ledgerSerialNum: string): Promise<FamilyLedgerTransaction[]> {
    try {
      const result = await invokeCommand<FamilyLedgerTransaction[]>(
        'family_ledger_transaction_list',
        { filter: { familyLedgerSerialNum: ledgerSerialNum } },
      );
      return result;
    } catch (error) {
      this.handleError('listByLedger', error);
    }
  }

  /**
   * 根据交易ID查询所有关联的账本
   */
  async listByTransaction(transactionSerialNum: string): Promise<FamilyLedgerTransaction[]> {
    try {
      const result = await invokeCommand<FamilyLedgerTransaction[]>(
        'family_ledger_transaction_list',
        { filter: { transactionSerialNum } },
      );
      return result;
    } catch (error) {
      this.handleError('listByTransaction', error);
    }
  }

  /**
   * 批量创建交易与账本的关联
   */
  async batchCreate(
    associations: FamilyLedgerTransactionCreate[],
  ): Promise<FamilyLedgerTransaction[]> {
    try {
      const result = await invokeCommand<FamilyLedgerTransaction[]>(
        'family_ledger_transaction_batch_create',
        { data: associations },
      );
      Lg.d('MoneyDb', `Batch created ${result.length} FamilyLedgerTransaction associations`);
      return result;
    } catch (error) {
      this.handleError('batchCreate', error);
    }
  }

  /**
   * 批量删除交易与账本的关联
   */
  async batchDelete(serialNums: string[]): Promise<void> {
    try {
      await invokeCommand('family_ledger_transaction_batch_delete', { serialNums });
      Lg.d('MoneyDb', `Batch deleted ${serialNums.length} FamilyLedgerTransaction associations`);
    } catch (error) {
      this.handleError('batchDelete', error);
    }
  }

  /**
   * 更新交易的账本关联（先删除旧的，再创建新的）
   */
  async updateTransactionLedgers(
    transactionSerialNum: string,
    ledgerSerialNums: string[],
  ): Promise<FamilyLedgerTransaction[]> {
    try {
      // 1. 查询现有关联
      const existing = await this.listByTransaction(transactionSerialNum);
      const existingLedgerIds = existing.map(e => e.familyLedgerSerialNum);

      // 2. 计算需要删除和新增的
      const toDelete = existing.filter(e => !ledgerSerialNums.includes(e.familyLedgerSerialNum));
      const toAdd = ledgerSerialNums.filter(id => !existingLedgerIds.includes(id));

      // 3. 执行删除
      if (toDelete.length > 0) {
        await this.batchDelete(toDelete.map(e => e.serialNum));
      }

      // 4. 执行新增
      if (toAdd.length > 0) {
        const newAssociations = toAdd.map(ledgerSerialNum => ({
          familyLedgerSerialNum: ledgerSerialNum,
          transactionSerialNum,
        }));
        await this.batchCreate(newAssociations);
      }

      // 5. 返回最新的关联列表
      return await this.listByTransaction(transactionSerialNum);
    } catch (error) {
      this.handleError('updateTransactionLedgers', error);
    }
  }
}

/**
 * 家庭账本成员关联数据映射器
 */
export class FamilyLedgerMemberMapper extends BaseMapper<
  FamilyLedgerMemberCreate,
  FamilyLedgerMemberUpdate,
  FamilyLedgerMember
> {
  protected entityName = 'family_ledger_member';
  async create(assoc: FamilyLedgerMemberCreate): Promise<FamilyLedgerMember> {
    try {
      const result = await invokeCommand<FamilyLedgerMember>('family_ledger_member_create', {
        data: assoc,
      });
      Lg.d(
        'MoneyDb',
        `FamilyLedgerMember created: ${result.familyLedgerSerialNum} - ${result.familyMemberSerialNum}`,
      );
      return result;
    } catch (error) {
      this.handleError('create', error);
    }
  }

  async getById(serialNum: string): Promise<FamilyLedgerMember | null> {
    try {
      const result = await invokeCommand<FamilyLedgerMember>('family_ledger_member_get', {
        serialNum,
      });
      return result;
    } catch (error) {
      this.handleError('getById', error);
    }
  }

  async list(): Promise<FamilyLedgerMember[]> {
    try {
      const result = await invokeCommand<FamilyLedgerMember[]>('family_ledger_member_list', {
        filter: {},
      });
      return result;
    } catch (_error) {
      Lg.w('MoneyDb', 'family_ledger_member_list command not found, returning empty array');
      return [];
    }
  }

  async deleteById(serialNum: string): Promise<void> {
    try {
      await invokeCommand('family_ledger_member_delete', { serialNum });
      Lg.d('MoneyDb', 'FamilyLedgerMember deleted:', { serialNum });
    } catch (error) {
      this.handleError('deleteById', error);
    }
  }

  async update(serialNum: string, assoc: FamilyLedgerMember): Promise<FamilyLedgerMember> {
    try {
      const result = await invokeCommand<FamilyLedgerMember>('family_ledger_member_update', {
        serialNum,
        data: assoc,
      });
      Lg.d('MoneyDb', 'FamilyLedgerMember updated:', { serialNum });
      return result;
    } catch (error) {
      this.handleError('update', error);
    }
  }

  async listPaged(
    query: PageQuery<FamilyMemberFilters> = {
      currentPage: 1,
      pageSize: 10,
      sortOptions: {},
      filter: {},
    },
  ): Promise<PagedResult<FamilyLedgerMember>> {
    try {
      const result = await invokeCommand<PagedResult<FamilyLedgerMember>>(
        'family_ledger_member_list_paged',
        { query },
      );
      return result;
    } catch (error) {
      this.handleError('listPaged', error);
    }
  }
}
