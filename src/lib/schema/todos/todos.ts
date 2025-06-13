export interface Todo {
  serial_num: string;
  title: string;
  description?: string | null;
  created_at: string;
  updated_at?: string | null;
  due_at: string;
  priority: number;
  status: number;
  repeat?: string | null;
  completed_at?: string | null;
  assignee_id?: string | null;
  progress: number;
  location?: string | null;
  owner_id?: string | null;
  is_archived: boolean;
  is_pinned: boolean;
  estimate_minutes?: number | null;
  reminder_count: number;
  parent_id?: string | null;
  subtask_order?: number | null;
}
