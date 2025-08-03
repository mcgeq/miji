import Database from '@tauri-apps/plugin-sql';
import { LRUCache } from 'lru-cache';
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
  private connectionPool: Database[] = [];
  private POOL_SIZE = 5; // 连接池大小
  private queryCache: LRUCache<string, QueryCache>;

  // Cache statistics
  private cacheHits = 0;
  private cacheMisses = 0;

  // config
  private readonly DB_PATH = 'sqlite:miji.db';
  private readonly CACHE_TTL = 5 * 60 * 1000;
  private readonly MAX_CACHE_SIZE = 100;
  private readonly MAX_RETRIES = 5;
  private readonly BASE_DELAY = 50;
  private readonly TRANSACTION_TIMEOUT = 8000; // 8秒超时

  // Environment flag (Tauri doesn't have process.env)
  private readonly isProduction: boolean;

  private constructor() {
    // Initialize cache with explicit types
    this.queryCache = new LRUCache<string, QueryCache>({
      max: this.MAX_CACHE_SIZE,
      ttl: this.CACHE_TTL,
    });

    // Detect environment - in Tauri we can use window.__TAURI__ to check
    this.isProduction =
      typeof window !== 'undefined' && !!(window as any).__TAURI__;
  }

  // Get Singleton Instance
  public static getInstance(): DatabaseManager {
    if (!DatabaseManager.instance) {
      DatabaseManager.instance = new DatabaseManager();
    }
    return DatabaseManager.instance;
  }

  /**
   * Create a new database connection
   */
  private async createConnection(): Promise<Database> {
    try {
      const conn = await Database.load(this.DB_PATH);
      await this.optimizeDatabase(conn);
      return conn;
    } catch (error) {
      const dbError = new DatabaseError(
        'Failed to create database connection',
        'DB_CONN_FAILED',
        'createConnection',
        error as Error,
      );
      Lg.e('DatabaseManager', 'Connection creation failed: ', dbError);
      throw dbError;
    }
  }

  /**
   * Get a database connection from pool
   */
  public async getConnection(): Promise<Database> {
    // Check for available connections in pool
    while (this.connectionPool.length > 0) {
      const conn = this.connectionPool.pop()!;
      if (await this.checkConnectionHealth(conn)) {
        return conn;
      } else {
        // Close unhealthy connection
        try {
          await conn.close();
        } catch (error) {
          Lg.w(
            'DatabaseManager',
            'Failed to close unhealthy connection',
            error,
          );
        }
      }
    }

    // Create new connection if pool is not full
    if (this.connectionPool.length < this.POOL_SIZE) {
      return this.createConnection();
    }

    // Wait for available connection
    return new Promise(resolve => {
      const checkInterval = setInterval(() => {
        if (this.connectionPool.length > 0) {
          clearInterval(checkInterval);
          resolve(this.connectionPool.pop()!);
        }
      }, 100);
    });
  }

  /**
   * Release connection back to pool
   */
  public releaseConnection(conn: Database): void {
    if (this.connectionPool.length < this.POOL_SIZE) {
      this.connectionPool.push(conn);
    } else {
      // Close extra connection
      conn.close().catch(error => {
        Lg.w('DatabaseManager', 'Failed to close extra connection', error);
      });
    }
  }

  /**
   * Check if connection is healthy
   */
  private async checkConnectionHealth(conn: Database): Promise<boolean> {
    try {
      await conn.execute('SELECT 1');
      return true;
    } catch (_error) {
      return false;
    }
  }

  /**
   * Database optimization
   */
  private async optimizeDatabase(db: Database): Promise<void> {
    try {
      // Enable WAL mode
      const walResult = await db.select<{ journal_mode: string }[]>(
        'PRAGMA journal_mode=WAL',
      );

      if (walResult[0]?.journal_mode !== 'wal') {
        throw new Error('Failed to enable WAL mode');
      }

      // Other optimizations
      await db.execute('PRAGMA synchronous=NORMAL');
      await db.execute('PRAGMA cache_size=10000');
      await db.execute('PRAGMA foreign_keys=ON');

      Lg.i('DatabaseManager', 'Database optimization applied');
    } catch (error) {
      Lg.e('DatabaseManager', 'Database optimization failed: ', error);

      // Fallback to default settings
      try {
        await db.execute('PRAGMA journal_mode=DELETE');
        await db.execute('PRAGMA synchronous=FULL');
      } catch (fallbackError) {
        Lg.w(
          'DatabaseManager',
          'Fallback optimization failed: ',
          fallbackError,
        );
      }
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
    const conn = await this.getConnection();
    try {
      if (!useCache) {
        return this.executeQuery(conn, 'select', sql, params);
      }

      const cacheKey = this.getCacheKey(sql, params);
      const cached = this.queryCache.get(cacheKey);

      // Check cache
      if (cached) {
        Lg.d('DatabaseManager', 'Cache hit query: ', sql);
        this.cacheHits++;
        return cached.data;
      }

      this.cacheMisses++;
      const result = await this.executeQuery(conn, 'select', sql, params);
      this.queryCache.set(cacheKey, {
        data: result,
        timestamp: Date.now(),
      });
      return result;
    } finally {
      this.releaseConnection(conn);
    }
  }

  /**
   * Execute update
   */
  public async execute(sql: string, params: any[] = []): Promise<any> {
    const conn = await this.getConnection();
    try {
      this.invalidateCache();
      return this.executeQuery(conn, 'execute', sql, params);
    } finally {
      this.releaseConnection(conn);
    }
  }

  /**
   * Execute transaction (Optimized with IMMEDIATE locking and retry strategy)
   */
  public async transaction<T>(
    callback: (db: Database) => Promise<T>,
  ): Promise<T> {
    const conn = await this.getConnection();
    let retries = 0;
    const randomFactor = 0.1; // Random jitter factor

    try {
      while (retries < this.MAX_RETRIES) {
        try {
          // Start IMMEDIATE transaction
          await this.executeQuery(
            conn,
            'execute',
            'BEGIN IMMEDIATE TRANSACTION',
            [],
          );

          // Execute callback with timeout
          const result = await Promise.race<T>([
            callback(conn),
            new Promise((_, reject) =>
              setTimeout(
                () =>
                  reject(
                    new DatabaseError(
                      'Transaction timeout',
                      'DB_TIMEOUT',
                      'transaction',
                    ),
                  ),
                this.TRANSACTION_TIMEOUT,
              ),
            ),
          ]);

          // Commit transaction
          await this.executeQuery(conn, 'execute', 'COMMIT', []);

          // Invalidate cache
          this.invalidateCache();

          return result;
        } catch (error) {
          // Always attempt rollback on error
          try {
            await this.executeQuery(conn, 'execute', 'ROLLBACK', []);
          } catch (rollbackError) {
            Lg.w('DatabaseManager', 'Rollback failed: ', rollbackError);
          }

          // Handle lock errors with exponential backoff
          if (
            error instanceof DatabaseError &&
            (error.message.includes('database is locked') ||
              error.code === 'DB_LOCKED') &&
            retries < this.MAX_RETRIES
          ) {
            retries++;

            // Calculate backoff with jitter
            const jitter = 1 + Math.random() * randomFactor;
            const delay = Math.min(
              this.BASE_DELAY * 2 ** retries * jitter,
              5000, // Max delay 5s
            );

            Lg.w(
              'DatabaseManager',
              `Lock detected, retrying (${retries}/${this.MAX_RETRIES}) in ${delay.toFixed(0)}ms`,
            );
            await new Promise(resolve => setTimeout(resolve, delay));
            continue;
          }

          // Handle timeout
          if (error instanceof DatabaseError && error.code === 'DB_TIMEOUT') {
            Lg.e('DatabaseManager', 'Transaction timed out', error);
            throw new DatabaseError(
              `Transaction timed out after ${this.TRANSACTION_TIMEOUT}ms`,
              'DB_TIMEOUT',
              'transaction',
            );
          }

          // Re-throw other errors
          throw error;
        }
      }

      // Max retries reached
      throw new DatabaseError(
        `Transaction failed after ${this.MAX_RETRIES} retries`,
        'DB_LOCK_TIMEOUT',
        'transaction',
      );
    } finally {
      this.releaseConnection(conn);
    }
  }

  /**
   * Batch Execute (Optimized for parallel execution)
   */
  public async executeBatch(
    operations: Array<{ sql: string; params: any[] }>,
  ): Promise<void> {
    await this.transaction(async conn => {
      // Group operations by dependency
      const independentOps = operations.filter(
        op => !op.sql.includes('UPDATE account'),
      );
      const dependentOps = operations.filter(op =>
        op.sql.includes('UPDATE account'),
      );

      // Execute independent operations in parallel
      await Promise.all(
        independentOps.map(op =>
          this.executeQuery(conn, 'execute', op.sql, op.params),
        ),
      );

      // Execute dependent operations sequentially
      for (const op of dependentOps) {
        await this.executeQuery(conn, 'execute', op.sql, op.params);
      }
    });
  }

  /**
   * Execute Query Helper
   */
  private async executeQuery(
    conn: Database,
    method: 'select' | 'execute',
    sql: string,
    params: any[],
  ): Promise<any> {
    try {
      // Log level based on environment
      const logLevel = this.isProduction ? 'd' : 'i';

      // Log query details
      if (logLevel === 'd') {
        Lg.d('DatabaseManager', `Executing ${method}: `, { sql, params });
      } else {
        Lg.i('DatabaseManager', `Executing ${method}: `, { sql, params });
      }

      const startTime = Date.now();
      const result =
        method === 'select'
          ? await conn.select(sql, params)
          : await conn.execute(sql, params);
      const duration = Date.now() - startTime;

      // Log performance
      if (logLevel === 'd') {
        Lg.d('DatabaseManager', `Query completed in ${duration}ms`, {
          sql,
          duration,
        });
      } else {
        Lg.i('DatabaseManager', `Query completed in ${duration}ms`, {
          sql,
          duration,
        });
      }

      return result;
    } catch (error) {
      const dbError = new DatabaseError(
        `Database ${method} operation failed: ${(error as Error).message}`,
        'DB_QUERY_FAILED',
        method,
        error as Error,
      );
      Lg.e('DatabaseManager', `Database ${method} failed: `, {
        sql,
        params,
        error: dbError,
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
    const cleanedCount = this.queryCache.purgeStale();
    if (cleanedCount) {
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
    cacheHits: number;
    cacheMisses: number;
    poolSize: number;
  }> {
    return {
      cacheSize: this.queryCache.size,
      dbPath: this.DB_PATH,
      isConnected: this.connectionPool.length > 0,
      cacheHits: this.cacheHits,
      cacheMisses: this.cacheMisses,
      poolSize: this.connectionPool.length,
    };
  }

  /**
   * Close all database connections
   */
  public async closeAll(): Promise<void> {
    // Close all connections in pool
    for (const conn of this.connectionPool) {
      try {
        await conn.close();
      } catch (error) {
        Lg.w('DatabaseManager', 'Error closing connection:', error);
      }
    }
    this.connectionPool = [];

    // Reset statistics
    this.cacheHits = 0;
    this.cacheMisses = 0;

    Lg.i('DatabaseManager', 'All database connections closed');
  }

  /**
   * Reset connection pool
   */
  public async resetPool(): Promise<void> {
    await this.closeAll();
    Lg.i('DatabaseManager', 'Connection pool reset');
  }
}

/**
 * Convenience export function (for backward compatibility)
 */
export async function getDb(): Promise<Database> {
  return DatabaseManager.getInstance().getConnection();
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
    cacheHits: number;
    cacheMisses: number;
    poolSize: number;
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
   * Close all connections
   */
  closeAll: (): Promise<void> => {
    return DatabaseManager.getInstance().closeAll();
  },

  /**
   * Reset connection pool
   */
  resetPool: (): Promise<void> => {
    return DatabaseManager.getInstance().resetPool();
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
