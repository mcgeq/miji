export interface Account {
  serial_num: string;
  name: string;
  description: string;
  balance: string;
  currency: Currency;
  is_shared: boolean;
  owner_id: string;
  is_active: boolean;
  created_at: string;
  updated_at: string | null;
}

export interface Currency {
  code: string;
  symbol: string;
}
