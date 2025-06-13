import type { RepeatPeriod } from '@/types/enum/reminder';

export interface Budget {
  serial_num: string;
  account_serial_num: string;
  name: string;
  category: string;
  amount: string;
  repeat_period: RepeatPeriod;
  start_date: string;
  end_date: string;
  used_amount: string;
  is_active: boolean;
  created_at: string;
  updated_at: string | null;
}
