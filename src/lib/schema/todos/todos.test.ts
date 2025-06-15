import { describe, it, expect } from 'vitest';
import { TodoSchema } from './todos';
import { Lg } from '@/lib/utils/debugLog';

const validTodo = {
  serial_num: 'abcdefghijklmnopqrstuvwxyz123456782145', // 38位小写+数字
  title: 'Buy groceries',
  description: 'Milk, eggs, bread',
  created_at: '2025-06-14T12:00:00.000000Z',
  updated_at: '2025-06-14T12:30:00.000000Z',
  due_at: '2025-06-15T10:00:00.000000Z',
  priority: 'Medium',
  status: 'InProgress',
  repeat: null,
  completed_at: null,
  assignee_id: null,
  progress: 50,
  location: null,
  owner_id: 'abcdefghijklmnopqrstuvwxyz123456782145',
  is_archived: false,
  is_pinned: true,
  estimate_minutes: 30,
  reminder_count: 2,
  parent_id: null,
  subtask_order: null,
};

describe('TodoSchema', () => {
  it('should pass validation with valid data', () => {
    const result = TodoSchema.safeParse(validTodo);
    expect(result.success).toBe(true);
  });

  it('should fail if serial_num is invalid', () => {
    const invalidTodo = { ...validTodo, serial_num: 'abc!' };
    const result = TodoSchema.safeParse(invalidTodo);
    expect(result.success).toBe(false);
    if (!result.success) {
      expect(result.error.issues[0].path).toContain('serial_num');
    }
  });

  it('should fail if title is empty', () => {
    const invalidTodo = { ...validTodo, title: '' };
    const result = TodoSchema.safeParse(invalidTodo);
    expect(result.success).toBe(false);
  });

  it('should fail if progress is over 100', () => {
    const invalidTodo = { ...validTodo, progress: 120 };
    const result = TodoSchema.safeParse(invalidTodo);
    expect(result.success).toBe(false);
  });

  it('should allow nullable and optional fields to be null', () => {
    const partialTodo = {
      ...validTodo,
      description: null,
      updated_at: null,
      completed_at: null,
      assignee_id: null,
      location: null,
      estimate_minutes: null,
      parent_id: null,
      subtask_order: null,
    };
    const result = TodoSchema.safeParse(partialTodo);

    if (!result.success) {
      Lg.e('Todo Test', result.error.message);
    }
    expect(result.success).toBe(true);
  });

  it('should allow optional fields to be omitted', () => {
    const {
      updated_at,
      completed_at,
      estimate_minutes,
      parent_id,
      subtask_order,
      owner_id,
      ...minimalTodo
    } = validTodo;

    const result = TodoSchema.safeParse(minimalTodo);
    expect(result.success).toBe(true);
  });

  it('should fail if estimate_minutes is negative', () => {
    const invalidTodo = { ...validTodo, estimate_minutes: -5 };
    const result = TodoSchema.safeParse(invalidTodo);
    expect(result.success).toBe(false);
  });

  it('should fail if reminder_count is negative', () => {
    const invalidTodo = { ...validTodo, reminder_count: -1 };
    const result = TodoSchema.safeParse(invalidTodo);
    expect(result.success).toBe(false);
  });
});
