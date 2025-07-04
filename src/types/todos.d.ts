import type { Priority } from '@/schema/common';
import type { Todo, TodoRemain } from '@/schema/todos';

export interface TodoListProps {
  todos: Map<string, Todo>;
  onToggle: (serialNum: string) => void;
  onRemove: (serialNum: string) => void;
  onEdit: (serialNum: string, todo: TodoRemain) => void;
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
  completed: boolean;
  onChangePriority: (serialNum: string, priority: Priority) => void;
}
