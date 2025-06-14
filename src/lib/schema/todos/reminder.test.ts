import { describe, it, expect } from 'vitest';
import { ReminderSchema } from './reminder'; // 根据实际路径调整

const validReminder = {
  serial_num: 'abcdefghijklmnopqrstuvwxyz123456782145',
  todo_serial_num: 'abcdefghijklmnopqrstuvwxyz123456782145',
  remind_at: '2025-06-14T12:00:00.000000Z',
  type: null,
  is_sent: false,
  created_at: '2025-06-14T11:00:00.000000Z',
  updated_at: null,
};

describe('ReminderSchema', () => {
  it('should validate a valid reminder', () => {
    const result = ReminderSchema.safeParse(validReminder);
    expect(result.success).toBe(true);
  });

  it('should allow optional fields to be omitted', () => {
    // 省略 type 和 updated_at
    const { type, updated_at, ...partialReminder } = validReminder;
    const result = ReminderSchema.safeParse(partialReminder);
    expect(result.success).toBe(true);
  });

  it('should allow nullable fields to be null', () => {
    const reminderWithNulls = {
      ...validReminder,
      type: null,
      updated_at: null,
    };
    const result = ReminderSchema.safeParse(reminderWithNulls);
    expect(result.success).toBe(true);
  });

  it('should fail if serial_num is invalid', () => {
    const invalid = { ...validReminder, serial_num: 'bad!' };
    const result = ReminderSchema.safeParse(invalid);
    expect(result.success).toBe(false);
    if (!result.success) {
      expect(result.error.issues[0].path).toContain('serial_num');
    }
  });

  it('should fail if is_sent is not boolean', () => {
    const invalid = { ...validReminder, is_sent: 'yes' };
    const result = ReminderSchema.safeParse(invalid);
    expect(result.success).toBe(false);
  });

  it('should fail if remind_at is invalid datetime', () => {
    const invalid = { ...validReminder, remind_at: 'invalid-date' };
    const result = ReminderSchema.safeParse(invalid);
    expect(result.success).toBe(false);
  });
});
