// src/routes/api/accounting/+server.ts
import { json } from '@sveltejs/kit';
import { getTransactions } from '$lib/api/money';
import type { Transaction } from '@/types';
import type { RequestHandler } from '@sveltejs/kit';

export const GET: RequestHandler = async () => {
  try {
    const transactions: Transaction[] = await getTransactions();
    return json(transactions);
  } catch (error) {
    return json({ error: 'Failed to fetch transactions' }, { status: 500 });
  }
};
