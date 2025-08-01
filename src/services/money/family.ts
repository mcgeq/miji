import { CURRENCY_CNY } from '@/constants/moneyConst';
import {
  FamilyLedgerAccountSchema,
  FamilyLedgerMemberSchema,
  FamilyLedgerSchema,
  FamilyLedgerTransactionSchema,
  FamilyMemberSchema,
} from '@/schema/money';
import { toCamelCase } from '@/utils/common';
import { db } from '@/utils/dbUtils';
import { Lg } from '@/utils/debugLog';
import { BaseMapper, MoneyDbError } from './baseManager';
import { MoneyDb } from './money';
import type { PagedResult } from './baseManager';
import type { DateRange, SortOptions } from '@/schema/common';
import type {
  FamilyLedger,
  FamilyLedgerMember,
  FamilyLedgerTransaction,
  FamilyMember,
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
export class FamilyMemberMapper extends BaseMapper<FamilyMember> {
  protected tableName = 'family_member';
  protected entityName = 'FamilyMember';
  protected schema = FamilyMemberSchema;

  protected getBooleanFields(): string[] {
    return ['isPrimary'];
  }

  async create(member: FamilyMember): Promise<void> {
    try {
      const validated = this.schema.parse(member);
      const {
        serialNum,
        name,
        role,
        isPrimary,
        permissions,
        createdAt,
        updatedAt,
      } = validated;
      await db.execute(
        `INSERT INTO ${this.tableName} (serial_num, name, role, is_primary, permissions, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
        [
          serialNum,
          name,
          role,
          this.toDbBoolean(isPrimary),
          permissions,
          createdAt,
          updatedAt,
        ],
      );
      Lg.d('MoneyDb', 'FamilyMember created:', { serialNum });
    } catch (error) {
      this.handleError('create', error);
    }
  }

  async getById(serialNum: string): Promise<FamilyMember | null> {
    try {
      const result = await db.select<any[]>(
        `SELECT * FROM ${this.tableName} WHERE serial_num = ?`,
        [serialNum],
        true,
      );
      if (result.length === 0) return null;
      const member = this.transformFamilyMemberRow(result[0]);
      return this.schema.parse(member);
    } catch (error) {
      this.handleError('getById', error);
    }
  }

  async list(): Promise<FamilyMember[]> {
    try {
      const result = await db.select<any[]>(
        `SELECT * FROM ${this.tableName}`,
        [],
        true,
      );
      const members = result.map(row => this.transformFamilyMemberRow(row));
      const m = toCamelCase<FamilyMember[]>(members);
      return m.map(member => this.schema.parse(member));
    } catch (error) {
      this.handleError('list', error);
    }
  }

  async update(member: FamilyMember): Promise<void> {
    try {
      const validated = this.schema.parse(member);
      const { serialNum, name, role, isPrimary, permissions, updatedAt } =
        validated;
      await db.execute(
        `UPDATE ${this.tableName} SET name = ?, role = ?, is_primary = ?, permissions = ?, updated_at = ?
         WHERE serial_num = ?`,
        [
          name,
          role,
          this.toDbBoolean(isPrimary),
          permissions,
          updatedAt,
          serialNum,
        ],
      );
      Lg.d('MoneyDb', 'FamilyMember updated:', { serialNum });
    } catch (error) {
      this.handleError('update', error);
    }
  }

  async deleteById(serialNum: string): Promise<void> {
    try {
      await db.execute(`DELETE FROM ${this.tableName} WHERE serial_num = ?`, [
        serialNum,
      ]);
      Lg.d('MoneyDb', 'FamilyMember deleted:', { serialNum });
    } catch (error) {
      this.handleError('deleteById', error);
    }
  }

  async updateSmart(newMember: FamilyMember): Promise<void> {
    try {
      const validated = this.schema.parse(newMember);
      const oldMember = await this.getById(validated.serialNum);
      if (!oldMember) {
        throw new MoneyDbError(
          'FamilyMember not found',
          'updateSmart',
          'FamilyMember',
        );
      }
      await this.doSmartUpdate(validated.serialNum, validated, oldMember);
    } catch (error) {
      this.handleError('updateSmart', error);
    }
  }

  async updateFamilyMemberPartial(
    serialNum: string,
    updates: Partial<FamilyMember>,
  ): Promise<void> {
    try {
      const validatedUpdates = this.schema.partial().parse(updates);
      await this.updatePartial(serialNum, validatedUpdates);
    } catch (error) {
      this.handleError('updatePartial', error);
    }
  }

  async listPaged(
    filters: FamilyMemberFilters = {},
    page = 1,
    pageSize = 10,
    sortOptions: SortOptions = {},
  ): Promise<PagedResult<FamilyMember>> {
    try {
      const baseQuery = `SELECT * FROM ${this.tableName}`;
      const result = await this.queryPaged(
        baseQuery,
        filters,
        page,
        pageSize,
        sortOptions,
        'created_at DESC',
        row => this.transformFamilyMemberRow(row),
      );
      return {
        ...result,
        rows: result.rows.map(row => this.schema.parse(row)),
      };
    } catch (error) {
      this.handleError('listPaged', error);
    }
  }

  private transformFamilyMemberRow(row: any): FamilyMember {
    return {
      ...row,
      isPrimary: this.fromDbBoolean(row.is_primary),
      createdAt: this.normalizeValue(row.created_at),
      updatedAt: this.normalizeValue(row.updated_at),
    } as FamilyMember;
  }
}

/**
 * 家庭账本数据映射器
 */
export class FamilyLedgerMapper extends BaseMapper<FamilyLedger> {
  protected tableName = 'family_ledger';
  protected entityName = 'FamilyLedger';
  protected schema = FamilyLedgerSchema;

  async create(ledger: FamilyLedger): Promise<void> {
    try {
      const validated = this.schema.parse(ledger);
      const {
        serialNum,
        name,
        description,
        baseCurrency,
        members,
        accounts,
        transactions,
        budgets,
        auditLogs,
        createdAt,
        updatedAt,
      } = validated;
      await db.execute(
        `INSERT INTO ${this.tableName} (serial_num, name, description, base_currency, members, accounts, transactions, budgets, audit_logs, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          serialNum,
          name,
          description,
          baseCurrency.code,
          JSON.stringify(members),
          JSON.stringify(accounts),
          JSON.stringify(transactions),
          JSON.stringify(budgets),
          JSON.stringify(auditLogs),
          createdAt,
          updatedAt,
        ],
      );
      Lg.d('MoneyDb', 'FamilyLedger created:', { serialNum });
    } catch (error) {
      this.handleError('create', error);
    }
  }

  async getById(serialNum: string): Promise<FamilyLedger | null> {
    try {
      const result = await db.select<any[]>(
        `SELECT * FROM ${this.tableName} WHERE serial_num = ?`,
        [serialNum],
        true,
      );
      if (result.length === 0) return null;
      const ledger = await this.transformFamilyLedgerRow(result[0]);
      return this.schema.parse(ledger);
    } catch (error) {
      this.handleError('getById', error);
    }
  }

  async list(): Promise<FamilyLedger[]> {
    try {
      const result = await db.select<any[]>(
        `SELECT * FROM ${this.tableName}`,
        [],
        true,
      );
      const ledgers = await Promise.all(
        result.map(row => this.transformFamilyLedgerRow(row)),
      );
      return ledgers.map(ledger => this.schema.parse(ledger));
    } catch (error) {
      this.handleError('list', error);
    }
  }

  async update(ledger: FamilyLedger): Promise<void> {
    try {
      const validated = this.schema.parse(ledger);
      const {
        serialNum,
        name,
        description,
        baseCurrency,
        members,
        accounts,
        transactions,
        budgets,
        auditLogs,
        updatedAt,
      } = validated;
      await db.execute(
        `UPDATE ${this.tableName} SET name = ?, description = ?, base_currency = ?, members = ?, accounts = ?, transactions = ?, budgets = ?, audit_logs = ?, updated_at = ?
         WHERE serial_num = ?`,
        [
          name,
          description,
          baseCurrency.code,
          JSON.stringify(members),
          JSON.stringify(accounts),
          JSON.stringify(transactions),
          JSON.stringify(budgets),
          JSON.stringify(auditLogs),
          updatedAt,
          serialNum,
        ],
      );
      Lg.d('MoneyDb', 'FamilyLedger updated:', { serialNum });
    } catch (error) {
      this.handleError('update', error);
    }
  }

  async deleteById(serialNum: string): Promise<void> {
    try {
      await db.execute(`DELETE FROM ${this.tableName} WHERE serial_num = ?`, [
        serialNum,
      ]);
      Lg.d('MoneyDb', 'FamilyLedger deleted:', { serialNum });
    } catch (error) {
      this.handleError('deleteById', error);
    }
  }

  async updateSmart(newLedger: FamilyLedger): Promise<void> {
    try {
      const validated = this.schema.parse(newLedger);
      const oldLedger = await this.getById(validated.serialNum);
      if (!oldLedger) {
        throw new MoneyDbError(
          'FamilyLedger not found',
          'updateSmart',
          'FamilyLedger',
        );
      }
      await this.doSmartUpdate(validated.serialNum, validated, oldLedger);
    } catch (error) {
      this.handleError('updateSmart', error);
    }
  }

  async updateFamilyLedgerPartial(
    serialNum: string,
    updates: Partial<FamilyLedger>,
  ): Promise<void> {
    try {
      const validatedUpdates = this.schema.partial().parse(updates);
      await this.updatePartial(serialNum, validatedUpdates);
    } catch (error) {
      this.handleError('updatePartial', error);
    }
  }

  async listPaged(
    filters: FamilyLedgerFilters = {},
    page = 1,
    pageSize = 10,
    sortOptions: SortOptions = {},
  ): Promise<PagedResult<FamilyLedger>> {
    try {
      const baseQuery = `SELECT * FROM ${this.tableName}`;
      const result = await this.queryPaged(
        baseQuery,
        filters,
        page,
        pageSize,
        sortOptions,
        'created_at DESC',
        row => this.transformFamilyLedgerRow(row),
      );
      return {
        ...result,
        rows: await Promise.all(result.rows.map(row => this.schema.parse(row))),
      };
    } catch (error) {
      this.handleError('listPaged', error);
    }
  }

  private async transformFamilyLedgerRow(row: any): Promise<FamilyLedger> {
    const currency =
      (await MoneyDb.getCurrencyByCode(row.base_currency)) ?? CURRENCY_CNY;
    return {
      ...row,
      baseCurrency: currency,
      members: JSON.parse(row.members || '[]'),
      accounts: JSON.parse(row.accounts || '[]'),
      transactions: JSON.parse(row.transactions || '[]'),
      budgets: JSON.parse(row.budgets || '[]'),
      auditLogs: JSON.parse(row.audit_logs || '[]'),
      createdAt: this.normalizeValue(row.created_at),
      updatedAt: this.normalizeValue(row.updated_at),
    } as FamilyLedger;
  }
}

/**
 * 家庭账本账户关联数据映射器
 */
export class FamilyLedgerAccountMapper extends BaseMapper<{
  serialNum: string;
  familyLedgerSerialNum: string;
  accountSerialNum: string;
}> {
  protected tableName = 'family_ledger_account';
  protected entityName = 'FamilyLedgerAccount';
  protected schema = FamilyLedgerAccountSchema;

  async create(assoc: {
    serialNum: string;
    familyLedgerSerialNum: string;
    accountSerialNum: string;
  }): Promise<void> {
    try {
      const validated = this.schema.parse(assoc);
      const {
        serialNum,
        familyLedgerSerialNum,
        accountSerialNum,
        createdAt,
        updatedAt,
      } = validated;
      await db.execute(
        `INSERT INTO ${this.tableName} (serial_num, family_ledger_serial_num, account_serial_num, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?)`,
        [
          serialNum,
          familyLedgerSerialNum,
          accountSerialNum,
          createdAt,
          updatedAt,
        ],
      );
      Lg.d('MoneyDb', 'FamilyLedgerAccount created:', { serialNum });
    } catch (error) {
      this.handleError('create', error);
    }
  }

  async getById(serialNum: string): Promise<{
    serialNum: string;
    familyLedgerSerialNum: string;
    accountSerialNum: string;
  } | null> {
    try {
      const result = await db.select<any[]>(
        `SELECT * FROM ${this.tableName} WHERE serial_num = ?`,
        [serialNum],
        true,
      );
      if (result.length === 0) return null;
      return this.schema.parse(result[0]);
    } catch (error) {
      this.handleError('getById', error);
    }
  }

  async list(): Promise<
    {
      serialNum: string;
      familyLedgerSerialNum: string;
      accountSerialNum: string;
    }[]
  > {
    try {
      const result = await db.select<any[]>(
        `SELECT * FROM ${this.tableName}`,
        [],
        true,
      );
      return result.map(row => this.schema.parse(row));
    } catch (error) {
      this.handleError('list', error);
    }
  }

  async update(assoc: {
    serialNum: string;
    familyLedgerSerialNum: string;
    accountSerialNum: string;
  }): Promise<void> {
    try {
      const validated = this.schema.parse(assoc);
      const { serialNum, familyLedgerSerialNum, accountSerialNum, updatedAt } =
        validated;
      await db.execute(
        `UPDATE ${this.tableName} SET family_ledger_serial_num = ?, account_serial_num = ?, updated_at = ?
         WHERE serial_num = ?`,
        [familyLedgerSerialNum, accountSerialNum, updatedAt, serialNum],
      );
      Lg.d('MoneyDb', 'FamilyLedgerAccount updated:', { serialNum });
    } catch (error) {
      this.handleError('update', error);
    }
  }

  async deleteById(serialNum: string): Promise<void> {
    try {
      await db.execute(`DELETE FROM ${this.tableName} WHERE serial_num = ?`, [
        serialNum,
      ]);
      Lg.d('MoneyDb', 'FamilyLedgerAccount deleted:', { serialNum });
    } catch (error) {
      this.handleError('deleteById', error);
    }
  }

  async listPaged(
    filters: FamilyLedgerAccountFilters = {},
    page = 1,
    pageSize = 10,
    sortOptions: SortOptions = {},
  ): Promise<
    PagedResult<{
      serialNum: string;
      familyLedgerSerialNum: string;
      accountSerialNum: string;
    }>
  > {
    try {
      const baseQuery = `SELECT * FROM ${this.tableName}`;
      return await this.queryPaged(
        baseQuery,
        filters,
        page,
        pageSize,
        sortOptions,
        'created_at DESC',
        row => this.schema.parse(row),
      );
    } catch (error) {
      this.handleError('listPaged', error);
    }
  }
}

/**
 * 家庭账本交易关联数据映射器
 */
export class FamilyLedgerTransactionMapper extends BaseMapper<FamilyLedgerTransaction> {
  protected tableName = 'family_ledger_transaction';
  protected entityName = 'FamilyLedgerTransaction';
  protected schema = FamilyLedgerTransactionSchema;

  async create(assoc: FamilyLedgerTransaction): Promise<void> {
    try {
      const validated = this.schema.parse(assoc);
      const {
        serialNum,
        familyLedgerSerialNum,
        transactionSerialNum,
        createdAt,
        updatedAt,
      } = validated;
      await db.execute(
        `INSERT INTO ${this.tableName} (serial_num,family_ledger_serial_num, transaction_serial_num, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?)`,
        [
          serialNum,
          familyLedgerSerialNum,
          transactionSerialNum,
          createdAt,
          updatedAt,
        ],
      );
      Lg.d('MoneyDb', 'FamilyLedgerTransaction created:', { serialNum });
    } catch (error) {
      this.handleError('create', error);
    }
  }

  async getById(serialNum: string): Promise<FamilyLedgerTransaction | null> {
    try {
      const result = await db.select<any[]>(
        `SELECT * FROM ${this.tableName} WHERE serial_num = ?`,
        [serialNum],
        true,
      );
      if (result.length === 0) return null;
      return this.schema.parse(result[0]);
    } catch (error) {
      this.handleError('getById', error);
    }
  }

  async list(): Promise<FamilyLedgerTransaction[]> {
    try {
      const result = await db.select<any[]>(
        `SELECT * FROM ${this.tableName}`,
        [],
        true,
      );
      return result.map(row => this.schema.parse(row));
    } catch (error) {
      this.handleError('list', error);
    }
  }

  async deleteById(serialNum: string): Promise<void> {
    try {
      await db.execute(`DELETE FROM ${this.tableName} WHERE serial_num = ?`, [
        serialNum,
      ]);
      Lg.d('MoneyDb', 'FamilyLedgerTransaction deleted:', {
        serialNum,
      });
    } catch (error) {
      this.handleError('deleteById', error);
    }
  }

  async update(assoc: FamilyLedgerTransaction): Promise<void> {
    try {
      const validated = this.schema.parse(assoc);
      const {
        serialNum,
        familyLedgerSerialNum,
        transactionSerialNum,
        updatedAt,
      } = validated;
      await db.execute(
        `UPDATE ${this.tableName} SET family_ledger_serial_num = ?, transaction_serial_num = ?, updated_at = ?
         WHERE serial_num = ?`,
        [familyLedgerSerialNum, transactionSerialNum, updatedAt, serialNum],
      );
      Lg.d('MoneyDb', 'FamilyLedgerTransaction updated:', { serialNum });
    } catch (error) {
      this.handleError('update', error);
    }
  }

  async listPaged(
    filters: FamilyLedgerTransactionFilters = {},
    page = 1,
    pageSize = 10,
    sortOptions: SortOptions = {},
  ): Promise<PagedResult<FamilyLedgerTransaction>> {
    try {
      const baseQuery = `SELECT * FROM ${this.tableName}`;
      return await this.queryPaged(
        baseQuery,
        filters,
        page,
        pageSize,
        sortOptions,
        'created_at DESC',
        row => this.schema.parse(row),
      );
    } catch (error) {
      this.handleError('listPaged', error);
    }
  }
}

/**
 * 家庭账本成员关联数据映射器
 */
export class FamilyLedgerMemberMapper extends BaseMapper<FamilyLedgerMember> {
  protected tableName = 'family_ledger_member';
  protected entityName = 'FamilyLedgerMember';
  protected schema = FamilyLedgerMemberSchema;
  async create(assoc: FamilyLedgerMember): Promise<void> {
    try {
      const validated = this.schema.parse(assoc);
      const {
        serialNum,
        familyLedgerSerialNum,
        familyMemberSerialNum,
        createdAt,
        updatedAt,
      } = validated;

      await db.execute(
        `INSERT INTO ${this.tableName} (serial_num, family_ledger_serial_num, family_member_serial_num, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?)`,
        [
          serialNum,
          familyLedgerSerialNum,
          familyMemberSerialNum,
          createdAt,
          updatedAt,
        ],
      );
      Lg.d('MoneyDb', 'FamilyLedgerMember created:', { serialNum });
    } catch (error) {
      this.handleError('create', error);
    }
  }

  async getById(serialNum: string): Promise<FamilyLedgerMember | null> {
    try {
      const result = await db.select<any[]>(
        `SELECT * FROM ${this.tableName} WHERE serial_num = ?`,
        [serialNum],
        true,
      );
      if (result.length === 0) return null;
      return this.schema.parse(result[0]);
    } catch (error) {
      this.handleError('getById', error);
    }
  }

  async list(): Promise<FamilyLedgerMember[]> {
    try {
      const result = await db.select<any[]>(
        `SELECT * FROM ${this.tableName}`,
        [],
        true,
      );
      return result.map(row => this.schema.parse(row));
    } catch (error) {
      this.handleError('list', error);
    }
  }

  async deleteById(serialNum: string): Promise<void> {
    try {
      await db.execute(`DELETE FROM ${this.tableName} WHERE serial_num = ?`, [
        serialNum,
      ]);
      Lg.d('MoneyDb', 'FamilyLedgerMember deleted:', { serialNum });
    } catch (error) {
      this.handleError('deleteById', error);
    }
  }

  async update(assoc: FamilyLedgerMember): Promise<void> {
    try {
      const validated = this.schema.parse(assoc);
      const {
        serialNum,
        familyLedgerSerialNum,
        familyMemberSerialNum,
        updatedAt,
      } = validated;
      await db.execute(
        `UPDATE ${this.tableName} SET family_ledger_serial_num = ?, family_member_serial_num = ?, updated_at = ?
         WHERE serial_num = ?`,
        [familyLedgerSerialNum, familyMemberSerialNum, updatedAt, serialNum],
      );
      Lg.d('MoneyDb', 'FamilyLedgerMember updated:', { serialNum });
    } catch (error) {
      this.handleError('update', error);
    }
  }

  async listPaged(
    filters: FamilyLedgerMemberFilters = {},
    page = 1,
    pageSize = 10,
    sortOptions: SortOptions = {},
  ): Promise<PagedResult<FamilyLedgerMember>> {
    try {
      const baseQuery = `SELECT * FROM ${this.tableName}`;
      return await this.queryPaged(
        baseQuery,
        filters,
        page,
        pageSize,
        sortOptions,
        'created_at DESC',
        row => this.schema.parse(row),
      );
    } catch (error) {
      this.handleError('listPaged', error);
    }
  }
}
