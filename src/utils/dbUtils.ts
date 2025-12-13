import Database from '@tauri-apps/plugin-sql';
import { LRUCache } from 'lru-cache';
import { AppErrorSeverity } from '../errors/appError';
import { Lg } from './debugLog';
import { throwAppError } from './errorHandler';

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
  data: unknown;
  timestamp: number;
}

// Extend Window interface for Tauri
declare global {
  interface Window {
    __TAURI__?: unknown;
  }
}

/**
 * Connection wrapper for better lifecycle management
 */
interface PooledConnection {
  connection: Database;
  inUse: boolean;
  createdAt: number;
  lastUsed: number;
  id: string;
}

/**
 * DataBase Management Singleton
 */
export class DatabaseManager {
  private static instance: DatabaseManager;
  private connectionPool: PooledConnection[] = [];
  private readonly POOL_SIZE = 5; // 目标连接池大小
  private readonly MAX_POOL_SIZE = 8; // 最大连接池大小
  private queryCache: LRUCache<string, QueryCache>;

  // Cache statistics
  private cacheHits = 0;
  private cacheMisses = 0;

  // Connection management
  private connectionCounter = 0;
  private pendingConnections = 0;
  private readonly CONNECTION_TIMEOUT = 10000; // 10秒连接超时
  private readonly CONNECTION_MAX_AGE = 30 * 60 * 1000; // 30分钟连接最大生存时间
  private readonly CONNECTION_IDLE_TIMEOUT = 5 * 60 * 1000; // 5分钟空闲超时

  // config
  private readonly DB_PATH = 'sqlite:miji.db';
  private readonly CACHE_TTL = 5 * 60 * 1000;
  private readonly MAX_CACHE_SIZE = 100;
  private readonly MAX_RETRIES = 3; // 减少重试次数，避免长时间等待
  private readonly BASE_DELAY = 100; // 增加基础延迟
  private readonly TRANSACTION_TIMEOUT = 8000; // 8秒超时

  // Environment flag (Tauri doesn't have process.env)
  private readonly isProduction: boolean;

  // Connection cleanup timer
  private cleanupTimer?: NodeJS.Timeout;

  private constructor() {
    // Initialize cache with explicit types
    this.queryCache = new LRUCache<string, QueryCache>({
      max: this.MAX_CACHE_SIZE,
      ttl: this.CACHE_TTL,
    });

    // Detect environment - in Tauri we can use window.__TAURI__ to check
    this.isProduction = typeof window !== 'undefined' && !!window.__TAURI__;

    // Start connection cleanup timer
    this.startCleanupTimer();
  }

  // Get Singleton Instance
  public static getInstance(): DatabaseManager {
    if (!DatabaseManager.instance) {
      DatabaseManager.instance = new DatabaseManager();
    }
    return DatabaseManager.instance;
  }

  /**
   * Start connection cleanup timer
   */
  private startCleanupTimer(): void {
    this.cleanupTimer = setInterval(() => {
      this.cleanupStaleConnections();
    }, 60000); // 每分钟清理一次
  }

  /**
   * Clean up stale connections
   */
  private async cleanupStaleConnections(): Promise<void> {
    const now = Date.now();
    const connectionsToClose: PooledConnection[] = [];

    for (let i = this.connectionPool.length - 1; i >= 0; i--) {
      const pooledConn = this.connectionPool[i];

      // 检查是否超过最大生存时间或空闲超时
      const isExpired = now - pooledConn.createdAt > this.CONNECTION_MAX_AGE;
      const isIdle = !pooledConn.inUse && now - pooledConn.lastUsed > this.CONNECTION_IDLE_TIMEOUT;

      // 保持最小连接数，只清理超出目标池大小的连接
      const shouldCleanup =
        (isExpired || isIdle) && (this.connectionPool.length > this.POOL_SIZE || isExpired);

      if (shouldCleanup && !pooledConn.inUse) {
        connectionsToClose.push(pooledConn);
        this.connectionPool.splice(i, 1);
      }
    }

    // 关闭过期连接
    for (const pooledConn of connectionsToClose) {
      try {
        await pooledConn.connection.close();
        Lg.d('DatabaseManager', `Closed stale connection: ${pooledConn.id}`);
      } catch (error) {
        Lg.w('DatabaseManager', `Failed to close stale connection: ${pooledConn.id}`, error);
      }
    }

    if (connectionsToClose.length > 0) {
      Lg.i('DatabaseManager', `Cleaned up ${connectionsToClose.length} stale connections`);
    }
  }

  /**
   * Create a new database connection
   */
  private async createConnection(): Promise<PooledConnection> {
    try {
      const conn = await Database.load(this.DB_PATH);
      await this.optimizeDatabase(conn);

      const pooledConn: PooledConnection = {
        connection: conn,
        inUse: false,
        createdAt: Date.now(),
        lastUsed: Date.now(),
        id: `conn_${++this.connectionCounter}`,
      };

      Lg.d('DatabaseManager', `Created new connection: ${pooledConn.id}`);
      return pooledConn;
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
   * 尝试获取空闲连接
   */
  private async tryGetIdleConnection(): Promise<PooledConnection | null> {
    for (const pooledConn of this.connectionPool) {
      if (!pooledConn.inUse && (await this.checkConnectionHealth(pooledConn.connection))) {
        pooledConn.inUse = true;
        pooledConn.lastUsed = Date.now();
        return pooledConn;
      }
    }
    return null;
  }

  /**
   * 尝试创建新连接
   */
  private async tryCreateNewConnection(): Promise<PooledConnection | null> {
    if (this.connectionPool.length + this.pendingConnections < this.MAX_POOL_SIZE) {
      this.pendingConnections++;
      try {
        const pooledConn = await this.createConnection();
        pooledConn.inUse = true;
        this.connectionPool.push(pooledConn);
        this.pendingConnections--;
        return pooledConn;
      } catch (error) {
        this.pendingConnections--;
        throw error;
      }
    }
    return null;
  }

  /**
   * Get a database connection from pool (优化版本，解决死锁问题)
   */
  public async getConnection(): Promise<Database> {
    return new Promise((resolve, reject) => {
      const timeoutId = setTimeout(() => {
        reject(new DatabaseError('Connection timeout', 'DB_CONN_TIMEOUT', 'getConnection'));
      }, this.CONNECTION_TIMEOUT);

      const handleConnection = async () => {
        try {
          // 首先尝试获取空闲连接
          const idleConn = await this.tryGetIdleConnection();
          if (idleConn) {
            clearTimeout(timeoutId);
            resolve(this.wrapConnection(idleConn));
            return;
          }

          // 如果没有空闲连接且池未满，创建新连接
          const newConn = await this.tryCreateNewConnection();
          if (newConn) {
            clearTimeout(timeoutId);
            resolve(this.wrapConnection(newConn));
            return;
          }

          // 等待空闲连接
          this.waitForAvailableConnection()
            .then(pooledConn => {
              clearTimeout(timeoutId);
              resolve(this.wrapConnection(pooledConn));
            })
            .catch(error => {
              clearTimeout(timeoutId);
              reject(error);
            });
        } catch (error) {
          clearTimeout(timeoutId);
          reject(error);
        }
      };

      handleConnection();
    });
  }

  /**
   * 智能等待空闲连接
   */
  private async waitForAvailableConnection(): Promise<PooledConnection> {
    return new Promise((resolve, reject) => {
      const maxWaitTime = this.CONNECTION_TIMEOUT;
      const startTime = Date.now();

      const checkInterval = setInterval(() => {
        // 检查超时
        if (Date.now() - startTime > maxWaitTime) {
          clearInterval(checkInterval);
          reject(
            new DatabaseError(
              'No available connections within timeout',
              'DB_CONN_POOL_EXHAUSTED',
              'waitForAvailableConnection',
            ),
          );
          return;
        }

        // 查找空闲连接
        for (const pooledConn of this.connectionPool) {
          if (!pooledConn.inUse) {
            clearInterval(checkInterval);
            pooledConn.inUse = true;
            pooledConn.lastUsed = Date.now();
            resolve(pooledConn);
            return;
          }
        }
      }, 50); // 每50ms检查一次
    });
  }

  /**
   * 包装连接，添加自动释放功能
   */
  private wrapConnection(pooledConn: PooledConnection): Database {
    const originalConn = pooledConn.connection;

    // 创建代理对象，拦截close方法
    return new Proxy(originalConn, {
      get: (target, prop) => {
        if (prop === 'close') {
          // 重写close方法为释放到池中
          return () => {
            this.releaseConnection(pooledConn);
            return Promise.resolve();
          };
        }
        return Reflect.get(target, prop);
      },
    }) as Database;
  }

  /**
   * Release connection back to pool (内部方法)
   */
  private releaseConnection(pooledConn: PooledConnection): void {
    pooledConn.inUse = false;
    pooledConn.lastUsed = Date.now();
    Lg.d('DatabaseManager', `Released connection: ${pooledConn.id}`);
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
      const walResult = await db.select<{ journal_mode: string }[]>('PRAGMA journal_mode=WAL');

      if (walResult[0]?.journal_mode !== 'wal') {
        throwAppError(
          'DatabaseManager',
          'WAL_MODE_FAILED',
          'Failed to enable WAL mode',
          AppErrorSeverity.HIGH,
        );
      }

      // Other optimizations
      await db.execute('PRAGMA synchronous=NORMAL');
      await db.execute('PRAGMA cache_size=10000');
      await db.execute('PRAGMA foreign_keys=ON');
      await db.execute('PRAGMA temp_store=memory');
      await db.execute('PRAGMA busy_timeout=5000'); // 5秒忙等待超时

      Lg.i('DatabaseManager', 'Database optimization applied');
    } catch (error) {
      Lg.e('DatabaseManager', 'Database optimization failed: ', error);

      // Fallback to default settings
      try {
        await db.execute('PRAGMA journal_mode=DELETE');
        await db.execute('PRAGMA synchronous=FULL');
        await db.execute('PRAGMA busy_timeout=5000');
      } catch (fallbackError) {
        Lg.w('DatabaseManager', 'Fallback optimization failed: ', fallbackError);
      }
    }
  }

  /**
   * Execute Query (自动管理连接)
   */
  public async select<T = unknown>(
    sql: string,
    params: unknown[] = [],
    useCache = false,
  ): Promise<T> {
    // 参数验证
    this.validateQuery(sql, params);

    if (!useCache) {
      const conn = await this.getConnection();
      try {
        return (await this.executeQuery(conn, 'select', sql, params)) as T;
      } finally {
        await conn.close(); // 使用包装后的close方法
      }
    }

    const cacheKey = this.getCacheKey(sql, params);
    const cached = this.queryCache.get(cacheKey);

    // Check cache
    if (cached) {
      Lg.d('DatabaseManager', 'Cache hit query: ', sql);
      this.cacheHits++;
      return cached.data as T;
    }

    this.cacheMisses++;
    const conn = await this.getConnection();
    try {
      const result = (await this.executeQuery(conn, 'select', sql, params)) as T;
      this.queryCache.set(cacheKey, {
        data: result,
        timestamp: Date.now(),
      });
      return result;
    } finally {
      await conn.close();
    }
  }

  /**
   * Execute update (自动管理连接)
   */
  public async execute(sql: string, params: unknown[] = []): Promise<unknown> {
    // 参数验证
    this.validateQuery(sql, params);

    const conn = await this.getConnection();
    try {
      this.invalidateCache();
      return await this.executeQuery(conn, 'execute', sql, params);
    } finally {
      await conn.close();
    }
  }

  /**
   * 查询参数验证
   */
  private validateQuery(sql: string, params: unknown[]): void {
    if (!sql || typeof sql !== 'string') {
      throw new DatabaseError(
        'SQL query must be a non-empty string',
        'DB_INVALID_SQL',
        'validateQuery',
      );
    }

    if (!Array.isArray(params)) {
      throw new DatabaseError('Parameters must be an array', 'DB_INVALID_PARAMS', 'validateQuery');
    }

    // 检查参数中的特殊值
    for (let i = 0; i < params.length; i++) {
      const param = params[i];
      if (param === undefined) {
        Lg.w('DatabaseManager', `Parameter at index ${i} is undefined, converting to null`, {
          sql: sql.slice(0, 100),
          paramIndex: i,
          allParams: params,
        });
        params[i] = null; // 将undefined转换为null
      }
    }

    // 检查SQL中的占位符数量是否匹配参数数量
    const placeholderCount = (sql.match(/\?/g) || []).length;
    if (placeholderCount !== params.length) {
      throw new DatabaseError(
        `SQL placeholder count (${placeholderCount}) does not match parameter count (${params.length})`,
        'DB_PARAM_MISMATCH',
        'validateQuery',
      );
    }
  }

  /**
   * Execute transaction (优化版本，改进重试策略)
   */
  public async transaction<T>(callback: (db: Database) => Promise<T>): Promise<T> {
    let lastError: Error | undefined;

    for (let attempt = 1; attempt <= this.MAX_RETRIES; attempt++) {
      const conn = await this.getConnection();

      try {
        // 使用更安全的事务开始方式
        await this.executeQuery(conn, 'execute', 'BEGIN IMMEDIATE TRANSACTION', []);

        // Execute callback with timeout
        const result = await Promise.race<T>([
          callback(conn),
          new Promise<never>((_, reject) =>
            setTimeout(
              () => reject(new DatabaseError('Transaction timeout', 'DB_TIMEOUT', 'transaction')),
              this.TRANSACTION_TIMEOUT,
            ),
          ),
        ]);

        // Commit transaction
        await this.executeQuery(conn, 'execute', 'COMMIT', []);

        // Invalidate cache on successful transaction
        this.invalidateCache();

        return result;
      } catch (error) {
        lastError = error as Error;

        // Always attempt rollback on error
        try {
          await this.executeQuery(conn, 'execute', 'ROLLBACK', []);
        } catch (rollbackError) {
          Lg.w('DatabaseManager', 'Rollback failed: ', rollbackError);
        }

        // 判断是否应该重试
        const shouldRetry = this.shouldRetryTransaction(error as Error, attempt);

        if (shouldRetry && attempt < this.MAX_RETRIES) {
          // 智能退避策略
          const delay = this.calculateBackoffDelay(attempt);
          Lg.w(
            'DatabaseManager',
            `Transaction failed (attempt ${attempt}/${this.MAX_RETRIES}), retrying in ${delay}ms: ${(error as Error).message}`,
          );

          await conn.close();
          await new Promise(resolve => setTimeout(resolve, delay));
          continue;
        }

        await conn.close();
        throw error;
      }
    }

    // Should not reach here, but just in case
    throw new DatabaseError(
      `Transaction failed after ${this.MAX_RETRIES} attempts: ${lastError?.message}`,
      'DB_TRANSACTION_FAILED',
      'transaction',
      lastError,
    );
  }

  /**
   * 判断事务是否应该重试
   */
  private shouldRetryTransaction(error: Error, attempt: number): boolean {
    const errorMessage = error.message.toLowerCase();

    // 可重试的错误类型
    const retryableErrors = [
      'database is locked',
      'busy',
      'timeout',
      'deadlock',
      'db_locked',
      'db_timeout',
    ];

    return (
      retryableErrors.some(errType => errorMessage.includes(errType)) && attempt < this.MAX_RETRIES
    );
  }

  /**
   * 计算智能退避延迟
   */
  private calculateBackoffDelay(attempt: number): number {
    // 指数退避 + 随机抖动
    const baseDelay = this.BASE_DELAY * 2 ** (attempt - 1);
    const jitter = Math.random() * 0.3 + 0.7; // 70%-100%的随机因子
    return Math.min(baseDelay * jitter, 2000); // 最大2秒
  }

  /**
   * Batch Execute (优化版本，更好的错误处理)
   */
  public async executeBatch(operations: Array<{ sql: string; params: unknown[] }>): Promise<void> {
    if (operations.length === 0) return;

    await this.transaction(async conn => {
      // 分批执行，避免过长的事务
      const batchSize = 50;

      for (let i = 0; i < operations.length; i += batchSize) {
        const batch = operations.slice(i, i + batchSize);

        // 并发执行独立操作
        const independentOps = batch.filter(op => !op.sql.toLowerCase().includes('update account'));
        const dependentOps = batch.filter(op => op.sql.toLowerCase().includes('update account'));

        // Execute independent operations in parallel
        if (independentOps.length > 0) {
          await Promise.all(
            independentOps.map(op => this.executeQuery(conn, 'execute', op.sql, op.params)),
          );
        }

        // Execute dependent operations sequentially
        for (const op of dependentOps) {
          await this.executeQuery(conn, 'execute', op.sql, op.params);
        }
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
    params: unknown[],
  ): Promise<unknown> {
    try {
      // Log level based on environment
      const logLevel = this.isProduction ? 'd' : 'i';

      // Log query details
      if (logLevel === 'd') {
        Lg.d('DatabaseManager', `Executing ${method}: `, { sql, params });
      } else if (!this.isProduction) {
        Lg.i('DatabaseManager', `Executing ${method}: `, {
          sql: sql.slice(0, 100) + (sql.length > 100 ? '...' : ''),
          paramCount: params.length,
        });
      }

      const startTime = Date.now();
      const result =
        method === 'select' ? await conn.select(sql, params) : await conn.execute(sql, params);
      const duration = Date.now() - startTime;

      // Log performance for slow queries
      if (duration > 1000 || !this.isProduction) {
        Lg.i('DatabaseManager', `Query completed in ${duration}ms`, {
          sql: sql.slice(0, 100) + (sql.length > 100 ? '...' : ''),
          duration,
          slow: duration > 1000,
        });
      }

      return result;
    } catch (error) {
      // 更好的错误信息提取
      const errorMessage = this.extractErrorMessage(error);
      const errorCode = this.extractErrorCode(error);

      const dbError = new DatabaseError(
        `Database ${method} operation failed: ${errorMessage}`,
        errorCode,
        method,
        error as Error,
      );

      // 详细的错误日志
      Lg.e('DatabaseManager', `Database ${method} failed: `, {
        sql: sql.slice(0, 200),
        params: params.slice(0, 10), // 限制参数日志长度
        errorMessage,
        errorCode,
        originalError: error,
        errorType: typeof error,
        errorConstructor: error?.constructor?.name,
      });

      throw dbError;
    }
  }

  /**
   * 从错误对象中提取标准字段
   */
  private extractStandardErrorFields(err: Record<string, unknown>): string | null {
    const fields = ['message', 'msg', 'error', 'description'];
    for (const field of fields) {
      if (err[field] && typeof err[field] === 'string') {
        return err[field] as string;
      }
    }

    // Tauri特定错误格式
    if (err.kind && err.message) {
      return `${err.kind}: ${err.message}`;
    }

    return null;
  }

  /**
   * 尝试序列化错误对象
   */
  private trySerializeError(error: unknown): string | null {
    try {
      const serialized = JSON.stringify(error);
      if (serialized && serialized !== '{}') {
        return `Error object: ${serialized}`;
      }
    } catch {
      return null;
    }
    return null;
  }

  /**
   * 从对象属性提取错误信息
   */
  private extractFromObjectProperties(err: Record<string, unknown>): string | null {
    const keys = Object.keys(err);
    if (keys.length > 0) {
      const errorDetails = keys.map(key => `${key}: ${err[key]}`).join(', ');
      return `Error details: ${errorDetails}`;
    }

    // 使用toString方法
    if ('toString' in err && typeof err.toString === 'function') {
      const toStringResult = String(err.toString());
      if (toStringResult && toStringResult !== '[object Object]') {
        return toStringResult;
      }
    }

    return null;
  }

  /**
   * 提取错误信息
   */
  private extractErrorMessage(error: unknown): string {
    if (!error) {
      return 'Unknown error occurred';
    }

    if (typeof error === 'string') {
      return error;
    }

    if (typeof error === 'object' && error !== null) {
      const err = error as Record<string, unknown>;

      return (
        this.extractStandardErrorFields(err) ||
        this.trySerializeError(error) ||
        this.extractFromObjectProperties(err) ||
        `Unidentifiable error (type: ${typeof error})`
      );
    }

    return `Unidentifiable error (type: ${typeof error})`;
  }

  /**
   * 从错误对象中提取代码字段
   */
  private extractCodeFields(err: Record<string, unknown>): string | null {
    if (err.code && typeof err.code === 'string') {
      return `DB_${err.code.toUpperCase()}`;
    }
    if (err.errno && typeof err.errno === 'number') {
      return `DB_ERRNO_${err.errno}`;
    }
    if (err.kind && typeof err.kind === 'string') {
      return `DB_${err.kind.toUpperCase()}`;
    }
    return null;
  }

  /**
   * 根据错误消息推断错误代码
   */
  private inferErrorCodeFromMessage(message: string): string {
    const errorMap: Record<string, string> = {
      constraint: 'DB_CONSTRAINT_VIOLATION',
      locked: 'DB_LOCKED',
      busy: 'DB_LOCKED',
      timeout: 'DB_TIMEOUT',
      'no such table': 'DB_TABLE_NOT_FOUND',
      'no such column': 'DB_COLUMN_NOT_FOUND',
      'syntax error': 'DB_SYNTAX_ERROR',
      'foreign key': 'DB_FOREIGN_KEY_ERROR',
      unique: 'DB_UNIQUE_VIOLATION',
    };

    for (const [key, code] of Object.entries(errorMap)) {
      if (message.includes(key)) {
        return code;
      }
    }

    return 'DB_QUERY_FAILED';
  }

  /**
   * 提取错误代码
   */
  private extractErrorCode(error: unknown): string {
    if (!error) {
      return 'DB_UNKNOWN_ERROR';
    }

    if (typeof error === 'object' && error !== null) {
      const err = error as Record<string, unknown>;
      const codeField = this.extractCodeFields(err);
      if (codeField) {
        return codeField;
      }
    }

    // 检查SQLite特定错误
    const message = this.extractErrorMessage(error).toLowerCase();
    return this.inferErrorCodeFromMessage(message);
  }

  /**
   * Generate cache key
   */
  private getCacheKey(sql: string, params: unknown[]): string {
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
    totalConnections: number;
    activeConnections: number;
    pendingConnections: number;
  }> {
    const activeConnections = this.connectionPool.filter(conn => conn.inUse).length;

    return {
      cacheSize: this.queryCache.size,
      dbPath: this.DB_PATH,
      isConnected: this.connectionPool.length > 0,
      cacheHits: this.cacheHits,
      cacheMisses: this.cacheMisses,
      totalConnections: this.connectionPool.length,
      activeConnections,
      pendingConnections: this.pendingConnections,
    };
  }

  /**
   * Close all database connections
   */
  public async closeAll(): Promise<void> {
    // 停止清理定时器
    if (this.cleanupTimer) {
      clearInterval(this.cleanupTimer);
      this.cleanupTimer = undefined;
    }

    // Close all connections in pool
    const closePromises = this.connectionPool.map(async pooledConn => {
      try {
        await pooledConn.connection.close();
      } catch (error) {
        Lg.w('DatabaseManager', `Error closing connection ${pooledConn.id}:`, error);
      }
    });

    await Promise.allSettled(closePromises);
    this.connectionPool = [];

    // Reset statistics
    this.cacheHits = 0;
    this.cacheMisses = 0;
    this.pendingConnections = 0;

    Lg.i('DatabaseManager', 'All database connections closed');
  }

  /**
   * Reset connection pool
   */
  public async resetPool(): Promise<void> {
    await this.closeAll();
    this.startCleanupTimer(); // 重新启动清理定时器
    Lg.i('DatabaseManager', 'Connection pool reset');
  }

  /**
   * Force close a specific connection (for emergency cleanup)
   */
  public async forceCloseConnection(connectionId?: string): Promise<void> {
    if (!connectionId) {
      // Close oldest idle connection
      const idleConn = this.connectionPool.find(conn => !conn.inUse);
      if (idleConn) {
        await this.closeSpecificConnection(idleConn);
      }
    } else {
      const conn = this.connectionPool.find(c => c.id === connectionId);
      if (conn) {
        await this.closeSpecificConnection(conn);
      }
    }
  }

  private async closeSpecificConnection(pooledConn: PooledConnection): Promise<void> {
    const index = this.connectionPool.indexOf(pooledConn);
    if (index !== -1) {
      this.connectionPool.splice(index, 1);
      try {
        await pooledConn.connection.close();
        Lg.i('DatabaseManager', `Force closed connection: ${pooledConn.id}`);
      } catch (error) {
        Lg.w('DatabaseManager', `Error force closing connection ${pooledConn.id}:`, error);
      }
    }
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
  select: <T = unknown>(sql: string, params: unknown[] = [], useCache = false): Promise<T> => {
    return DatabaseManager.getInstance().select<T>(sql, params, useCache);
  },

  /**
   * Execute update
   */
  execute: (sql: string, params: unknown[] = []): Promise<unknown> => {
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
  executeBatch: (operations: Array<{ sql: string; params: unknown[] }>): Promise<void> => {
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
    totalConnections: number;
    activeConnections: number;
    pendingConnections: number;
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

  /**
   * Force close connection (emergency use)
   */
  forceCloseConnection: (connectionId?: string): Promise<void> => {
    return DatabaseManager.getInstance().forceCloseConnection(connectionId);
  },
};

// Periodically clean expired cache and stale connections
if (typeof window !== 'undefined') {
  setInterval(
    () => {
      DatabaseManager.getInstance().cleanExpiredCache();
    },
    5 * 60 * 1000, // 每5分钟清理缓存
  );
}
