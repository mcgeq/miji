export interface FamilyMember {
  serial_num: string;
  name: string;
  role: string;
  is_primary: boolean;
  permissions: any; // or a structured Permissions type
  created_at: string;
  updated_at: string | null;
}

export interface FamilyLedger {
  serial_num: string;
  description: string;
  base_currency: string;
  members: any; // or define FamilyMember[]
  accounts: any; // or define Account[]
  transactions: any;
  budgets: any;
  audit_logs: any;
  created_at: string;
  updated_at: string | null;
}
