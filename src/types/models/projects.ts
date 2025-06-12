export interface Project {
  serial_num: string;
  name: string;
  description?: string | null;
  owner_id?: string | null;
  color?: string | null;
  is_archived: boolean;
  created_at: string;
  updated_at?: string | null;
}
