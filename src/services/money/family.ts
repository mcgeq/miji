import { invokeCommand } from '@/types/api';
import { Lg } from '@/utils/debugLog';
import { BaseMapper } from './baseManager';
import type { PagedResult } from './baseManager';
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
  FamilyLedgerTransaction,
  FamilyLedgerTransactionCreate,
  FamilyLedgerTransactionUpdate,
  FamilyLedgerUpdate,
  FamilyMember,
  FamilyMemberCreate,
  FamilyMemberUpdate,
} from '@/schema/money';

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
    } catch (error) {
      this.handleError('list', error);
    }
  }

  async update(
    serialNum: string,
    member: FamilyMemberUpdate,
  ): Promise<FamilyMember> {
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
      const result = await invokeCommand<PagedResult<FamilyMember>>(
        'family_member_list_paged',
        { query },
      );
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

  async list(): Promise<FamilyLedger[]> {
    try {
      const result = await invokeCommand<FamilyLedger[]>('family_ledger_list', {
        filter: {},
      });
      return result;
    } catch (error) {
      this.handleError('list', error);
    }
  }

  async update(
    serialNum: string,
    ledger: FamilyLedgerUpdate,
  ): Promise<FamilyLedger> {
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
      const result = await invokeCommand<PagedResult<FamilyLedger>>(
        'family_ledger_list_paged',
        { query },
      );
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
      const result = await invokeCommand<FamilyLedgerAccount>(
        'family_ledger_account_create',
        { data: assoc },
      );
      Lg.d('MoneyDb', `FamilyLedgerAccount created:, ${result.serialNum}`);
      return result;
    } catch (error) {
      this.handleError('create', error);
    }
  }

  async getById(serialNum: string): Promise<FamilyLedgerAccount | null> {
    try {
      return await invokeCommand<FamilyLedgerAccount>(
        'family_ledger_account_get',
        { serialNum },
      );
    } catch (error) {
      this.handleError('getById', error);
    }
  }

  async list(): Promise<FamilyLedgerAccount[]> {
    try {
      const result = await invokeCommand<FamilyLedgerAccount[]>(
        'family_ledger_account_list',
        { filter: {} },
      );
      return result;
    } catch (error) {
      this.handleError('list', error);
    }
  }

  async update(
    serialNum: string,
    assoc: FamilyLedgerAccountUpdate,
  ): Promise<FamilyLedgerAccount> {
    try {
      const result = await invokeCommand<FamilyLedgerAccount>(
        'family_ledger_account_update',
        { serialNum, data: assoc },
      );
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
  async create(
    assoc: FamilyLedgerTransactionCreate,
  ): Promise<FamilyLedgerTransaction> {
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
      const result = await invokeCommand<FamilyLedgerTransaction>(
        'family_ledger_transaction_get',
        { serialNum },
      );
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
    } catch (error) {
      this.handleError('list', error);
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
    query: PageQuery<FamilyMemberFilters> = {
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
      const result = await invokeCommand<FamilyLedgerMember>(
        'family_ledger_member_create',
        { data: assoc },
      );
      Lg.d('MoneyDb', `FamilyLedgerMember created:, ${result.serialNum}`);
      return result;
    } catch (error) {
      this.handleError('create', error);
    }
  }

  async getById(serialNum: string): Promise<FamilyLedgerMember | null> {
    try {
      const result = await invokeCommand<FamilyLedgerMember>(
        'family_ledger_member_get',
        { serialNum },
      );
      return result;
    } catch (error) {
      this.handleError('getById', error);
    }
  }

  async list(): Promise<FamilyLedgerMember[]> {
    try {
      const result = await invokeCommand<FamilyLedgerMember[]>(
        'family_ledger_member_list',
        { filter: {} },
      );
      return result;
    } catch (error) {
      this.handleError('list', error);
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

  async update(
    serialNum: string,
    assoc: FamilyLedgerMember,
  ): Promise<FamilyLedgerMember> {
    try {
      const result = await invokeCommand<FamilyLedgerMember>(
        'family_ledger_member_update',
        { serialNum, data: assoc },
      );
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
