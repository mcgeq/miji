import { describe, it, expect } from 'vitest';
import { UserSchema } from './user';
import type { User } from './user';

// 创建基础有效用户数据模板
const baseUser: User = {
  serialNum: 'abcdefghijklmnopqrstuvwxyz123456782145', // 38 字符
  name: 'John Doe',
  email: 'john@example.com',
  phone: '12345678901',
  password: 'Password1!',
  avatarUrl: 'https://example.com/avatar.jpg',
  lastLoginAt: '2023-01-01T12:00:00.000000Z',
  isVerified: true,
  role: 'User',
  status: 'Active',
  emailVerifiedAt: '2023-01-01T12:00:00.000000Z',
  phoneVerifiedAt: '2023-01-01T12:00:00.000000Z',
  bio: 'Hello, I am John.',
  language: 'en',
  timezone: 'America/New_York',
  lastActiveAt: '2023-01-01T12:00:00.000000Z',
  createdAt: '2023-01-01T12:00:00.000000Z',
  updatedAt: '2023-01-01T12:00:00.000000Z',
};

describe('UserSchema', () => {
  it('should validate valid user data', () => {
    const result = UserSchema.safeParse(baseUser);
    expect(result.success).toBe(true);
  });

  it('should fail if serial_num is not 38 characters', () => {
    const result = UserSchema.safeParse({
      ...baseUser,
      serial_num: 'abc',
    });
    expect(result.success).toBe(false);
    if (!result.success) {
      expect(result.error.issues[0].message).toBe(
        'Serial number must be 38 character.',
      );
    }
  });

  it('should fail if serial_num contains non-alphanumeric characters', () => {
    const result = UserSchema.safeParse({
      ...baseUser,
      serial_num: 'abc!@#def456789012345678901234567890123456',
    });
    expect(result.success).toBe(false);
  });

  it('should fail if name is too short', () => {
    const result = UserSchema.safeParse({
      ...baseUser,
      name: 'ab',
    });
    expect(result.success).toBe(false);
  });

  it('should fail if name is too long', () => {
    const result = UserSchema.safeParse({
      ...baseUser,
      name: 'a'.repeat(21),
    });
    expect(result.success).toBe(false);
  });

  it('should fail if email is invalid', () => {
    const result = UserSchema.safeParse({
      ...baseUser,
      email: 'invalid-email',
    });
    expect(result.success).toBe(false);
  });

  it('should fail if phone is not 11 characters', () => {
    const result = UserSchema.safeParse({
      ...baseUser,
      phone: '123',
    });
    expect(result.success).toBe(false);
  });

  it('should fail if password is too short', () => {
    const result = UserSchema.safeParse({
      ...baseUser,
      password: 'A1!',
    });
    expect(result.success).toBe(false);
  });

  it('should fail if password does not contain uppercase', () => {
    const result = UserSchema.safeParse({
      ...baseUser,
      password: 'password1!',
    });
    expect(result.success).toBe(false);
  });

  it('should fail if password does not contain lowercase', () => {
    const result = UserSchema.safeParse({
      ...baseUser,
      password: 'PASSWORD1!',
    });
    expect(result.success).toBe(false);
  });

  it('should fail if password does not contain number', () => {
    const result = UserSchema.safeParse({
      ...baseUser,
      password: 'Password!',
    });
    expect(result.success).toBe(false);
  });

  it('should fail if password does not contain special character', () => {
    const result = UserSchema.safeParse({
      ...baseUser,
      password: 'Password1',
    });
    expect(result.success).toBe(false);
  });

  it('should fail if role is invalid', () => {
    const result = UserSchema.safeParse({
      ...baseUser,
      role: 'InvalidRole' as any,
    });
    expect(result.success).toBe(false);
  });

  it('should fail if status is invalid', () => {
    const result = UserSchema.safeParse({
      ...baseUser,
      status: 'InvalidStatus' as any,
    });
    expect(result.success).toBe(false);
  });

  it('should fail if date format is invalid', () => {
    const result = UserSchema.safeParse({
      ...baseUser,
      created_at: '2023-01-01',
    });
    expect(result.success).toBe(false);
  });

  it('should allow optional fields to be null', () => {
    const result = UserSchema.safeParse({
      ...baseUser,
      phone: null,
      avatar_url: null,
      email_verified_at: null,
      phone_verified_at: null,
      bio: null,
      language: null,
      timezone: null,
      last_active_at: null,
      updated_at: null,
    });
    expect(result.success).toBe(true);
  });

  it('should allow optional fields to be undefined (omitted)', () => {
    const {
      phone,
      avatarUrl: avatar_url,
      emailVerifiedAt: email_verified_at,
      phoneVerifiedAt: phone_verified_at,
      bio,
      language,
      timezone,
      lastActiveAt: last_active_at,
      updatedAt: updated_at,
      ...rest
    } = baseUser;

    const result = UserSchema.safeParse(rest);
    expect(result.success).toBe(true);
  });
});
