import type { Priority } from '@/lib/schema/common';
import type { Todo } from '@/lib/schema/todos';

export interface TodoListProps {
  todos: Map<string, Todo>;
  onToggle: (serialNum: string) => void;
  onRemove: (serialNum: string) => void;
  onEdit: (serialNum: string, todo: Todo) => void;
  onChangePriority: (serialNum: string, priority: Priority) => void;
}

export interface TodoItemProps {
  serialNum: string;
  todo: Todo;
  onToggle: () => void;
  onRemove: () => void;
  onEdit: () => void;
  onChangePriority: () => void;
}

export interface TodoInputProps {
  newT: string;
  handleAdd: (text: string) => void;
}

export interface TodoPriorityProps {
  serialNum: string;
  priority: Priority;
  onChangePriority: (serialNum: string, priority: Priority) => void;
}
