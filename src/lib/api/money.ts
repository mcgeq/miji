// src/lib/api/accounting.ts
import type { Transaction } from '@/types';
import { invoke } from '@tauri-apps/api/core';

export async function getTransactions(): Promise<Transaction[]> {
  return await invoke('get_transactions');
}
