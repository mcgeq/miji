import {DEFAULT_CURRENCY} from '@/constants/moneyConst';
import {Currency} from '@/schema/common';

export const formatCurrency = (amount: string | number) => {
  const num = typeof amount === 'string' ? parseFloat(amount) : amount;
  const locale = getCurrentLocale();
  return num.toLocaleString(locale, {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
};

export const getLocalCurrencyInfo = (): Currency => {
  const locale = getCurrentLocale();
  const cny = DEFAULT_CURRENCY.filter((v) => v.locale === locale).pop();
  return cny ?? DEFAULT_CURRENCY[1];
};
