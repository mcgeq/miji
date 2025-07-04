import { describe, it, expect } from 'vitest';
import { TodoSchema } from './todos';
import { Lg } from '@/utils/debugLog';

const validTodo = {
  serialNum: 'abcdefghijklmnopqrstuvwxyz123456782145', // 38位小写+数字
  title: 'Buy groceries',
  description: 'Milk, eggs, bread',
  createdAt: '2025-06-14T12:00:00.000000Z',
  updatedAt: '2025-06-14T12:30:00.000000Z',
  dueAt: '2025-06-15T10:00:00.000000Z',
  priority: 'Medium',
  status: 'InProgress',
  repeat: null,
  completedAt: null,
  assigneeId: null,
  progress: 50,
  location: null,
  ownerId: 'abcdefghijklmnopqrstuvwxyz123456782145',
  isArchived: false,
  isPinned: true,
  estimateMinutes: 30,
  reminderCount: 2,
  parentId: null,
  subtaskOrder: null,
};

describe('TodoSchema', () => {
  it('should pass validation with valid data', () => {
    const result = TodoSchema.safeParse(validTodo);
    expect(result.success).toBe(true);
  });

  it('should fail if serial_num is invalid', () => {
    const invalidTodo = { ...validTodo, serialNum: 'abc!' };
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
      updatedAt: null,
      completedAt: null,
      assigneeId: null,
      location: null,
      estimateMinutes: null,
      parentId: null,
      subtaskOrder: null,
    };
    const result = TodoSchema.safeParse(partialTodo);

    if (!result.success) {
      Lg.e('Todo Test', result.error.message);
    }
    expect(result.success).toBe(true);
  });

  it('should allow optional fields to be omitted', () => {
    const {
      updatedAt: updated_at,
      completedAt: completed_at,
      estimateMinutes: estimate_minutes,
      parentId: parent_id,
      subtaskOrder: subtask_order,
      ownerId: owner_id,
      ...minimalTodo
    } = validTodo;

    const result = TodoSchema.safeParse(minimalTodo);
    expect(result.success).toBe(true);
  });

  it('should fail if estimate_minutes is negative', () => {
    const invalidTodo = { ...validTodo, estimateMinutes: -5 };
    const result = TodoSchema.safeParse(invalidTodo);
    expect(result.success).toBe(false);
  });

  it('should fail if reminder_count is negative', () => {
    const invalidTodo = { ...validTodo, reminderCount: -1 };
    const result = TodoSchema.safeParse(invalidTodo);
    expect(result.success).toBe(false);
  });
});
