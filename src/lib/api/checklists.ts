// src/lib/api/checklists.ts
import type { Checklist } from '@/types';
import { invoke } from '@tauri-apps/api/core';

export async function getChecklists(): Promise<Checklist[]> {
  return await invoke('get_checklists');
}
