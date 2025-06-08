// src/routes/api/checklists/+server.ts
import { json } from '@sveltejs/kit';
import { getChecklists } from '$lib/api/checklists';
import type { Checklist } from '@/types';
import type { RequestHandler } from '@sveltejs/kit';

export const GET: RequestHandler = async () => {
  try {
    const checklists: Checklist[] = await getChecklists();
    return json(checklists);
  } catch (error) {
    return json({ error: 'Failed to fetch checklists' }, { status: 500 });
  }
};
