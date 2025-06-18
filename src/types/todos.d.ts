import type { Todo } from '@/lib/schema/todos';

export interface TodoListProps {
  todos: Todo[];
  onToggle: (serial_num: string) => void;
  onRemove: (serial_num: string) => void;
  onEdit: (serial_num: string, todo: Todo) => void;
}

export interface TodoItemProps {
  serial_num: string;
  text: string;
  completed: boolean;
  dueAt: string;
  onToggle: () => void;
  onRemove: () => void;
  onEdit: () => void;
}

export interface TodoInputProps {
  newT: string;
  handleAdd: (text: string) => void;
}
