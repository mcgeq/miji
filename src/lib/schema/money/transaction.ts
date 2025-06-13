import type { AccountType, PaymentMethod } from '../enum/account';
import type {
  Category,
  TransactionStatus,
  TransactionType,
} from '../enum/transaction';

export interface Transaction {
  serial_num: string;
  transaction_type: TransactionType;
  transaction_status: TransactionStatus;
  date: string; // ISO date string (e.g., "2025-06-12")
  amount: string; // decimal as string, e.g., "1234.56"
  currency: string; // currency code (e.g., "USD", "CNY")
  description: string;
  notes?: string | null;
  account_serial_num: string;
  category: Category;
  sub_category?: string | null;
  tags?: any | null; // JSON value, recommend defining more strictly if needed
  split_members?: any | null; // JSON value, can be array of { member: string, amount: string } etc.
  payment_method: PaymentMethod;
  actual_payer_account: AccountType;
  created_at: string;
  updated_at?: string | null;
}
