import type { RepeatPeriod } from '@/types/enum/reminder';

export interface BilReminder {
  serial_num: string;
  name: string;
  amount: string;
  due_date: string;
  repeat_period: RepeatPeriod;
  is_paid: boolean;
  related_transaction_serial_num: string | null;
  created_at: string;
  updated_at: string | null;
}
