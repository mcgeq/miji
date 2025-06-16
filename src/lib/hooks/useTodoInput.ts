// src/lib/hooks/useTodoInput.ts

import type { TodoInputEvents } from '@/types/events';
import type { createTypedEmit } from '../utils/typedEmit';

type Emit = ReturnType<typeof createTypedEmit<TodoInputEvents>>;

export function useTodoInput(emit: Emit) {
  let value = '';
  const handleAdd = (root: HTMLElement) => {
    const text = value.trim();
    if (text) {
      emit(root, 'add', { text });
      value = '';
    }
  };
  return { value, setValue: (v: string) => (value = v), handleAdd };
}
