import { describe, it, expect } from 'vitest';
import { ReminderSchema } from './reminder'; // 根据实际路径调整

const validReminder = {
  serialNum: 'abcdefghijklmnopqrstuvwxyz123456782145',
  todoSerialNum: 'abcdefghijklmnopqrstuvwxyz123456782145',
  remindAt: '2025-06-14T12:00:00.000000Z',
  type: null,
  isSent: false,
  createdAt: '2025-06-14T11:00:00.000000Z',
  updatedAt: null,
};

describe('ReminderSchema', () => {
  it('should validate a valid reminder', () => {
    const result = ReminderSchema.safeParse(validReminder);
    expect(result.success).toBe(true);
  });

  it('should allow optional fields to be omitted', () => {
    // 省略 type 和 updated_at
    const { type, updatedAt: updated_at, ...partialReminder } = validReminder;
    const result = ReminderSchema.safeParse(partialReminder);
    expect(result.success).toBe(true);
  });

  it('should allow nullable fields to be null', () => {
    const reminderWithNulls = {
      ...validReminder,
      type: null,
      updatedAt: null,
    };
    const result = ReminderSchema.safeParse(reminderWithNulls);
    expect(result.success).toBe(true);
  });

  it('should fail if serial_num is invalid', () => {
    const invalid = { ...validReminder, serialNum: 'bad!' };
    const result = ReminderSchema.safeParse(invalid);
    expect(result.success).toBe(false);
    if (!result.success) {
      expect(result.error.issues[0].path).toContain('serialNum');
    }
  });

  it('should fail if is_sent is not boolean', () => {
    const invalid = { ...validReminder, isSent: 'yes' };
    const result = ReminderSchema.safeParse(invalid);
    expect(result.success).toBe(false);
  });

  it('should fail if remind_at is invalid datetime', () => {
    const invalid = { ...validReminder, remindAt: 'invalid-date' };
    const result = ReminderSchema.safeParse(invalid);
    expect(result.success).toBe(false);
  });
});
