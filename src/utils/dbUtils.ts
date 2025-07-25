import Database from '@tauri-apps/plugin-sql';
import { Lg } from './debugLog';

/**
 * DataBase Error
 */
export class DatabaseError extends Error {
  constructor(
    message: string,
    public code: string,
    public operation: string,
    public originalError?: Error,
  ) {
    super(message);
    this.name = 'DatabaseError';
  }
}

/**
 * Query cache Interface
 */
interface QueryCache {
  data: any;
  timestamp: number;
}

/**
 * DataBase Management Singleton
 */
export class DatabaseManager {
  private static instance: DatabaseManager;
  private db: Database | null = null;
  private dbPromise: Promise<Database> | null = null;
  private queryCache = new Map<string, QueryCache>();

  // config
  private readonly DB_PATH = 'sqlite:miji.db';
  private readonly CACHE_TTL = 5 * 60 * 1000;
  private readonly MAX_CACHE_SIZE = 100;

  private constructor() {}

  // Get Singleton Instance
  public static getInstance(): DatabaseManager {
    if (!DatabaseManager.instance) {
      DatabaseManager.instance = new DatabaseManager();
    }
    return DatabaseManager.instance;
  }

  /**
   * Get Database connection
   */
  public async getDatabase(): Promise<Database> {
    if (this.db) {
      return this.db;
    }

    if (!this.dbPromise) {
      this.dbPromise = this.initializeDatabase();
    }

    try {
      this.db = await this.dbPromise;
      return this.db;
    }
    catch (error) {
      this.dbPromise = null;
      throw error;
    }
  }

  /**
   * Initialize Database Connection
   */
  private async initializeDatabase(): Promise<Database> {
    try {
      Lg.i('DatabaseManager', 'Initializing database connection...');
      const db = await Database.load(this.DB_PATH);
      Lg.i('DatabaseManager', 'Database connection established successfully');
      await this.optimizeDatabase(db);
      return db;
    }
    catch (error) {
      const dbError = new DatabaseError(
        'Failed to initialize database connection',
        'DB_INIT_FAILED',
        'initialize',
        error as Error,
      );
      Lg.e('DatabaseManager', 'Database initialization failed: ', error);
      throw dbError;
    }
  }

  /**
   * Database config
   */
  private async optimizeDatabase(db: Database): Promise<void> {
    try {
      // WAL mode
      await db.execute('PRAGMA journal_mode=WAL');
      // Synchronous mode
      await db.execute('PRAGMA synchronous=NORMAL');
      await db.execute('PRAGMA cache_size=10000');
      await db.execute('PRAGMA foreign_keys=ON');
      Lg.i('DatabaseManager', 'Database optimization settings applied');
    }
    catch (error) {
      Lg.w(
        'DatabaseManager',
        'Failed to apply database optimizations: ',
        error,
      );
    }
  }

  /**
   * Execute Query
   */
  public async select<T = any>(
    sql: string,
    params: any[] = [],
    useCache = false,
  ): Promise<T> {
    const db = await this.getDatabase();

    if (!useCache) {
      return this.executeQuery(db, 'select', sql, params);
    }

    const cacheKey = this.getCacheKey(sql, params);
    const cached = this.queryCache.get(cacheKey);

    // check cache
    if (cached && this.isCacheValid(cached)) {
      Lg.d('DatabaseManager', 'Cache hit query: ', sql);
      return cached.data;
    }

    const result = await this.executeQuery(db, 'select', sql, params);
    this.setCache(cacheKey, result);
    return result;
  }

  /**
   * Execute
   */
  public async execute(sql: string, params: any[] = []): Promise<any> {
    const db = await this.getDatabase();
    this.invalidateCache();
    return this.executeQuery(db, 'execute', sql, params);
  }

  /**
   * Execute transaction
   */
  public async transaction<T>(
    callback: (db: Database) => Promise<T>,
  ): Promise<T> {
    const db = await this.getDatabase();

    await this.executeQuery(db, 'execute', 'BEGIN TRANSACTION', []);
    try {
      const result = await callback(db);
      await this.executeQuery(db, 'execute', 'COMMIT', []);

      this.invalidateCache();
      return result;
    }
    catch (error) {
      await this.executeQuery(db, 'execute', 'ROLLBACK', []);
      throw error;
    }
  }

  /**
   * Batch Execute
   */
  public async executeBatch(
    operations: Array<{ sql: string; params: any[] }>,
  ): Promise<void> {
    await this.transaction(async db => {
      for (const { sql, params } of operations) {
        await db.execute(sql, params);
      }
    });
  }

  /**
   * Execute Query Helper
   */
  private async executeQuery(
    db: Database,
    method: 'select' | 'execute',
    sql: string,
    params: any[],
  ): Promise<any> {
    try {
      Lg.d('DatabaseManager', `Executing ${method}: `, { sql, params });

      const startTime = Date.now();
      const result =
        method === 'select'
          ? await db.select(sql, params)
          : await db.execute(sql, params);
      const duration = Date.now() - startTime;
      Lg.d('DatabaseManager', `Query completed in ${duration}ms`);
      return result;
    }
    catch (error) {
      const dbError = new DatabaseError(
        `Database ${method} operation failed: ${(error as Error).message}`,
        'DB_QUERY_FAILED',
        method,
        error as Error,
      );
      Lg.e('DatabaseManager', `Database ${method} failed: `, {
        sql,
        params,
        error,
      });
      throw dbError;
    }
  }

  /**
   * Generate cache key
   */
  private getCacheKey(sql: string, params: any[]): string {
    return `${sql}:${JSON.stringify(params)}`;
  }

  /**
   * Check cache validity
   */
  private isCacheValid(cache: QueryCache): boolean {
    return Date.now() - cache.timestamp < this.CACHE_TTL;
  }

  /**
   * Set Cache
   */
  private setCache(key: string, data: any): void {
    if (this.queryCache.size >= this.MAX_CACHE_SIZE) {
      const firstKey = this.queryCache.keys().next().value;
      this.queryCache.delete(firstKey);
    }
    this.queryCache.set(key, {
      data,
      timestamp: Date.now(),
    });
  }

  /**
   * Clear cache
   */
  private invalidateCache(): void {
    this.queryCache.clear();
    Lg.d('DatabaseManager', 'Query cache cleared');
  }

  /**
   * Clean expired cache entries
   */
  public cleanExpiredCache(): void {
    const now = Date.now();
    let cleanedCount = 0;

    for (const [key, cache] of this.queryCache.entries()) {
      if (now - cache.timestamp >= this.CACHE_TTL) {
        this.queryCache.delete(key);
        cleanedCount++;
      }
    }

    if (cleanedCount > 0) {
      Lg.d('DatabaseManager', `Cleaned ${cleanedCount} expired cache entries`);
    }
  }

  /**
   * Get database statistics
   */
  public async getStats(): Promise<{
    cacheSize: number;
    dbPath: string;
    isConnected: boolean;
  }> {
    return {
      cacheSize: this.queryCache.size,
      dbPath: this.DB_PATH,
      isConnected: this.db !== null,
    };
  }

  /**
   * Close database connection (for cleanup on app exit)
   */
  public async close(): Promise<void> {
    if (this.db) {
      try {
        await this.db.close();
        this.db = null;
        this.dbPromise = null;
        this.invalidateCache();
        Lg.i('DatabaseManager', 'Database connection closed');
      }
      catch (error) {
        Lg.e('DatabaseManager', 'Error closing database:', error);
      }
    }
  }
}

/**
 * Convenience export function (for backward compatibility)
 */
export async function getDb(): Promise<Database> {
  return DatabaseManager.getInstance().getDatabase();
}

/**
 * Convenience functions for database operations
 */
export const db = {
  /**
   * Execute query
   */
  select: <T = any>(
    sql: string,
    params: any[] = [],
    useCache = false,
  ): Promise<T> => {
    return DatabaseManager.getInstance().select<T>(sql, params, useCache);
  },

  /**
   * Execute update
   */
  execute: (sql: string, params: any[] = []): Promise<any> => {
    return DatabaseManager.getInstance().execute(sql, params);
  },

  /**
   * Execute transaction
   */
  transaction: <T>(callback: (db: Database) => Promise<T>): Promise<T> => {
    return DatabaseManager.getInstance().transaction(callback);
  },

  /**
   * Batch execute
   */
  executeBatch: (
    operations: Array<{ sql: string; params: any[] }>,
  ): Promise<void> => {
    return DatabaseManager.getInstance().executeBatch(operations);
  },

  /**
   * Get statistics
   */
  getStats: (): Promise<{
    cacheSize: number;
    dbPath: string;
    isConnected: boolean;
  }> => {
    return DatabaseManager.getInstance().getStats();
  },

  /**
   * Clean expired cache
   */
  cleanCache: (): void => {
    DatabaseManager.getInstance().cleanExpiredCache();
  },

  /**
   * Close connection
   */
  close: (): Promise<void> => {
    return DatabaseManager.getInstance().close();
  },
};

// Periodically clean expired cache (every 5 minutes)
if (typeof window !== 'undefined') {
  setInterval(
    () => {
      DatabaseManager.getInstance().cleanExpiredCache();
    },
    5 * 60 * 1000,
  );
}
