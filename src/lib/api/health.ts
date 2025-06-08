// src/lib/api/period.ts
import type { Period } from '@/types';
import { invoke } from '@tauri-apps/api/core';

export async function getPeriods(): Promise<Period[]> {
  return await invoke('get_periods');
}
