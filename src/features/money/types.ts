// Shared enum types (assumed from context)
type RepeatPeriod = 'Daily' | 'Weekly' | 'Monthly' | 'Quarterly' | 'Yearly';
type TransactionType =
  | 'Income'
  | 'Expense'
  | 'Transfer'
  | 'Reimbursement'
  | 'Gift';
type TransactionStatus = 'Pending' | 'Completed' | 'Reversed';
type Category =
  | 'Food'
  | 'Transport'
  | 'Entertainment'
  | 'Utilities'
  | 'Shopping'
  | 'Salary'
  | 'Investment'
  | 'Others';
type PaymentMethod =
  | 'Cash'
  | 'BankTransfer'
  | 'CreditCard'
  | 'WeChat'
  | 'Alipay'
  | 'Other';
type AccountType = 'Cash' | 'Bank' | 'CreditCard' | 'Investment';

// Helper types to replace `any`
type Tag = string;
type SplitMember = { member_id: string; amount: number };
type Permission = { can_view: boolean; can_edit: boolean };
type Member = { member_id: string; name: string };
type Account = { account_id: string; balance: number };
type Transaction = { transaction_id: string; amount: number; date: string };
type Budget = { budget_id: string; category: string; amount: number };
type AuditLog = { log_id: string; action: string; timestamp: string };

// Transaction interface (lines 82-83)
interface TransactionCore {
  transaction_type: TransactionType;
  transaction_status: TransactionStatus;
  date: string;
  amount: number;
  currency: string;
  description: string;
  notes?: string;
  account_serial_num: string;
  category: Category;
  sub_category?: string;
  tags?: Tag[]; // Replaced `any` with `Tag[]` (string[])
  split_members?: SplitMember[]; // Replaced `any` with `SplitMember[]`
  payment_method: PaymentMethod;
  actual_payer_account: AccountType;
}

type TransactionDto = TransactionCore;

interface TransactionResDto extends TransactionCore {
  serial_num: string;
}

// FamilyMember interface (line 115)
interface FamilyMemberCore {
  name: string;
  role: string;
  is_primary: boolean;
  permissions: Permission; // Replaced `any` with `Permission`
}

type FamilyMemberDto = FamilyMemberCore;

interface FamilyMemberResDto extends FamilyMemberCore {
  serial_num: string;
  created_at: string;
  updated_at?: string;
}

// FamilyLedger interface (lines 130-134)
interface FamilyLedgerCore {
  description: string;
  base_currency: string;
  members: Member[]; // Replaced `any` with `Member[]`
  accounts: Account[]; // Replaced `any` with `Account[]`
  transactions: Transaction[]; // Replaced `any` with `Transaction[]`
  budgets: Budget[]; // Replaced `any` with `Budget[]`
  audit_logs: AuditLog[]; // Replaced `any` with `AuditLog[]`
}

type FamilyLedgerDto = FamilyLedgerCore;

interface FamilyLedgerResDto extends FamilyLedgerCore {
  serial_num: string;
  created_at: string;
  updated_at?: string;
}
