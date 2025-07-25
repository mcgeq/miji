import { getDb } from '@/db';
import type Database from '@tauri-apps/plugin-sql';

export class MoneyDb {
  private static db: Database;
  private static initializing: boolean = false;
  private static initPromise: Promise<void> | null = null;

  private static async init() {
    if (MoneyDb.db || MoneyDb.initializing) return;
    MoneyDb.initializing = true;
    try {
      MoneyDb.db = await getDb();
    }
    finally {
      MoneyDb.initializing = false;
    }
  }

  public static async list_account() {
    if (!MoneyDb.db) {
      await MoneyDb.init();
    }
  }
}
