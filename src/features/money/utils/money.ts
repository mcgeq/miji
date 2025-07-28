import { CURRENCY_CNY } from '@/constants/moneyConst';
import { MoneyDb } from '@/services/money/money';
import type { Currency } from '@/schema/common';

export function formatCurrency(amount: string | number) {
  const num = typeof amount === 'string' ? Number.parseFloat(amount) : amount;
  const locale = getCurrentLocale();
  return num.toLocaleString(locale, {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
}

export async function getLocalCurrencyInfo(): Promise<Currency> {
  const locale = getCurrentLocale();
  const currencies: Currency[] = await MoneyDb.listCurrencies();
  const cny = currencies.filter(v => v.locale === locale).pop();
  return cny ?? CURRENCY_CNY;
}
