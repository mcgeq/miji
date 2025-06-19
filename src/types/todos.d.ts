import type { Todo } from '@/lib/schema/todos';

export interface TodoListProps {
  todos: Todo[];
  onToggle: (serialNum: string) => void;
  onRemove: (serialNum: string) => void;
  onEdit: (serialNum: string, todo: Todo) => void;
}

export interface TodoItemProps {
  serialNum: string;
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
