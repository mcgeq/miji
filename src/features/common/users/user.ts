export type UserRole = 'Admin' | 'User' | 'Guest';
export type UserStatus = 'Active' | 'Inactive' | 'Pending';

export interface UserDto {
  serial_num: string;
  name: string;
  email: string;
  avatar_url?: string | null;
  role: UserRole;
  status: UserStatus;
  is_verified: boolean;
  language?: string | null;
  timezone?: string | null;
  token: string;
  created_at: string;
  updated_at?: string | null;
}
