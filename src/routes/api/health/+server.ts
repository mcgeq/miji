// src/routes/api/period/+server.ts
import { json } from '@sveltejs/kit';
import { getPeriods } from '$lib/api/period';
import type { Period } from '@/types';
import type { RequestHandler } from '@sveltejs/kit';

export const GET: RequestHandler = async () => {
  try {
    const periods: Period[] = await getPeriods();
    return json(periods);
  } catch (error) {
    return json({ error: 'Failed to fetch periods' }, { status: 500 });
  }
};
