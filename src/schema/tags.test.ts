// tags.test.ts
import { describe, it, expect } from 'vitest';
import { TagsSchema } from './tags';

describe('TagsSchema', () => {
  const validTag = {
    serialNum: 'abcdefghijklmnopqrstuvwxyz123456782357', // 38 chars
    name: 'Health',
    description: 'Tag for health-related activities.',
    createdAt: '2025-06-14T12:34:56.123456+08:00',
    updatedAt: '2025-06-14T12:34:56.123456+08:00',
  };

  it('should pass validation with valid data', () => {
    const parsed = TagsSchema.parse(validTag);
    expect(parsed.name).toBe('Health');
  });

  it('should fail if serial_num is invalid', () => {
    const tag = { ...validTag, serial_num: 'INVALID_SERIAL' };
    expect(() => TagsSchema.parse(tag)).toThrow(
      /Serial number must be 38 character/,
    );
  });

  it('should fail if name is too short', () => {
    const tag = { ...validTag, name: 'Hi' };
    expect(() => TagsSchema.parse(tag)).toThrow();
  });

  it('should fail if description exceeds max length', () => {
    const tag = { ...validTag, description: 'a'.repeat(1001) };
    expect(() => TagsSchema.parse(tag)).toThrow();
  });

  it('should fail if created_at is not ISO datetime', () => {
    const tag = { ...validTag, created_at: 'invalid-date' };
    expect(() => TagsSchema.parse(tag)).toThrow();
  });
});
