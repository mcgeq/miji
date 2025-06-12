import type { UserRole, UserStatus } from '../enum/user';

export interface User {
  serial_num: string;
  name: string;
  email: string;
  phone?: string | null;
  password_hash: string;
  avatar_url?: string | null;
  last_login_at?: string | null;
  is_verified: boolean;
  role: UserRole;
  status: UserStatus;
  email_verified_at?: string | null;
  phone_verified_at?: string | null;
  bio?: string | null;
  language?: string | null;
  timezone?: string | null;
  last_active_at?: string | null;
  deleted_at?: string | null;
  created_at: string;
  updated_at?: string | null;
}
