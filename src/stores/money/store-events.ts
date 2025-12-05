// src/stores/money/store-events.ts

/**
 * Store 事件类型定义
 * 用于跨 Store 的数据同步和响应式更新
 */
export interface StoreEvents {
  // 账户事件
  'account:created': { serialNum: string };
  'account:updated': { serialNum: string };
  'account:deleted': { serialNum: string };

  // 交易事件（包含关联的账户信息）
  'transaction:created': {
    transactionSerialNum: string;
    accountSerialNum: string;
    relatedAccountSerialNum?: string; // 转账时的目标账户
  };
  'transaction:updated': {
    transactionSerialNum: string;
    accountSerialNum: string;
    relatedAccountSerialNum?: string;
  };
  'transaction:deleted': {
    transactionSerialNum: string;
    accountSerialNum: string;
    relatedAccountSerialNum?: string;
  };

  // 批量交易事件（避免事件风暴）
  'transactions:batch-created': {
    transactionSerialNums: string[];
    accountSerialNums: string[];  // 受影响的账户列表（去重）
  };
  'transactions:batch-updated': {
    transactionSerialNums: string[];
    accountSerialNums: string[];
  };
  'transactions:batch-deleted': {
    transactionSerialNums: string[];
    accountSerialNums: string[];
  };

  // 转账事件（同时影响两个账户）
  'transfer:created': {
    fromAccountSerialNum: string;
    toAccountSerialNum: string;
    fromTransactionSerialNum: string;
    toTransactionSerialNum: string;
  };
  'transfer:updated': {
    fromAccountSerialNum: string;
    toAccountSerialNum: string;
    fromTransactionSerialNum: string;
    toTransactionSerialNum: string;
  };
  'transfer:deleted': {
    fromAccountSerialNum: string;
    toAccountSerialNum: string;
    fromTransactionSerialNum: string;
    toTransactionSerialNum: string;
  };

  // 分类事件
  'category:created': { name: string };
  'category:updated': { name: string };
  'category:deleted': { name: string };

  // 子分类事件
  'subcategory:created': { name: string; categoryName: string };
  'subcategory:updated': { name: string; categoryName: string };
  'subcategory:deleted': { name: string; categoryName: string };

  // 货币事件
  'currency:created': { code: string };
  'currency:updated': { code: string };
  'currency:deleted': { code: string };

  // 预算事件
  'budget:created': { serialNum: string };
  'budget:updated': { serialNum: string };
  'budget:deleted': { serialNum: string };

  // 批量预算事件
  'budgets:batch-created': { serialNums: string[] };
  'budgets:batch-deleted': { serialNums: string[] };

  // 家庭账本事件
  'ledger:created': { serialNum: string };
  'ledger:updated': { serialNum: string };
  'ledger:deleted': { serialNum: string };
  'ledger:switched': { serialNum: string };

  // 家庭成员事件
  'member:created': { serialNum: string; ledgerSerialNum?: string };
  'member:updated': { serialNum: string };
  'member:deleted': { serialNum: string; ledgerSerialNum?: string };
}

/**
 * 事件监听器清理函数类型
 */
export type EventCleanup = () => void;

/**
 * 简单的事件总线实现
 * 用于 Store 之间的通信
 */
class StoreEventBus {
  private handlers: Map<keyof StoreEvents, Set<(data: any) => void | Promise<void>>> = new Map();

  on<K extends keyof StoreEvents>(
    event: K,
    handler: (data: StoreEvents[K]) => void | Promise<void>,
  ): void {
    if (!this.handlers.has(event)) {
      this.handlers.set(event, new Set());
    }
    this.handlers.get(event)!.add(handler);
  }

  off<K extends keyof StoreEvents>(
    event: K,
    handler: (data: StoreEvents[K]) => void | Promise<void>,
  ): void {
    const handlers = this.handlers.get(event);
    if (handlers) {
      handlers.delete(handler);
    }
  }

  emit<K extends keyof StoreEvents>(event: K, data: StoreEvents[K]): void {
    const handlers = this.handlers.get(event);
    if (handlers) {
      handlers.forEach(handler => {
        try {
          handler(data);
        } catch (error) {
          // 使用简单的 console.error 避免循环依赖
          // 事件总线是底层模块，不应依赖其他模块
          console.error(`[StoreEventBus] Error in handler for ${String(event)}:`, error);
        }
      });
    }
  }

  clear(): void {
    this.handlers.clear();
  }
}

/**
 * 全局事件总线实例
 */
export const storeEventBus = new StoreEventBus();

/**
 * 辅助函数：创建事件监听器并返回清理函数
 */
export function onStoreEvent<K extends keyof StoreEvents>(
  event: K,
  handler: (data: StoreEvents[K]) => void | Promise<void>,
): EventCleanup {
  storeEventBus.on(event, handler);
  return () => storeEventBus.off(event, handler);
}

/**
 * 辅助函数：发送 Store 事件
 */
export function emitStoreEvent<K extends keyof StoreEvents>(event: K, data: StoreEvents[K]): void {
  storeEventBus.emit(event, data);
}
