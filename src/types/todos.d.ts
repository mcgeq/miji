import type { Todo } from '@/lib/schema/todos';

export interface TodoListProps {
  todos: Todo[];
  onToggle: (serial_num: string) => void;
  onRemove: (serial_num: string) => void;
}

export interface TodoItemProps {
  serial_num: string;
  text: string;
  completed: boolean;
  onToggle: () => void;
  onRemove: () => void;
}

export interface TodoInputProps {
  newT: string;
  handleAdd: (text: string) => void;
}
