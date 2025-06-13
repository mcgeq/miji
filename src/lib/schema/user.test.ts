import { describe, it, expect } from 'vitest';
import { UserSchema, type UserRole, type UserStatus } from './user';

describe('UserSchema', () => {
  // 有效数据测试
  it('should validate valid user data', () => {
    const validUser = {
      serial_num: 'abcdefghijklmnopqrstuvwxyz12345678121', // 38个字母数字
      name: 'John Doe',
      email: 'john@example.com',
      phone: '12345678901',
      password: 'Password1!', // 包含大小写字母、数字和特殊字符
      avatar_url: 'https://example.com/avatar.jpg',
      last_login_at: '2023-01-01T12:00:00.000000Z',
      is_verified: true,
      role: 'User',
      status: 'Active',
      email_verified_at: '2023-01-01T12:00:00.000000Z',
      phone_verified_at: '2023-01-01T12:00:00.000000Z',
      bio: 'Hello, I am John.',
      language: 'en',
      timezone: 'America/New_York',
      last_active_at: '2023-01-01T12:00:00.000000Z',
      created_at: '2023-01-01T12:00:00.000000Z',
      updated_at: '2023-01-01T12:00:00.000000Z',
    };

    const result = UserSchema.safeParse(validUser);
    expect(result.error).toBe(true);
  });

  // serial_num 测试
  it('should fail if serial_num is not 38 characters', () => {
    const invalidUser = {
      serial_num: 'abc', // 太短
      // 其他字段...
    };

    const result = UserSchema.safeParse(invalidUser);
    expect(result.success).toBe(false);
    if (!result.success) {
      expect(result.error.issues[0].message).toBe(
        'Serial number must be 38 character.',
      );
    }
  });

  it('should fail if serial_num contains non-alphanumeric characters', () => {
    const invalidUser = {
      serial_num: 'abcdefghijklmnopqrstuvwxyz12345678!', // 包含特殊字符
      // 其他字段...
    };

    const result = UserSchema.safeParse(invalidUser);
    expect(result.success).toBe(false);
    if (!result.success) {
      expect(result.error.issues[0].message).toBe(
        'Serial number must be 38 character.',
      );
    }
  });

  // name 测试
  it('should fail if name is too short', () => {
    const invalidUser = {
      name: 'ab', // 小于3个字符
      // 其他字段...
    };

    const result = UserSchema.safeParse(invalidUser);
    expect(result.success).toBe(false);
  });

  it('should fail if name is too long', () => {
    const invalidUser = {
      name: 'a'.repeat(21), // 超过20个字符
      // 其他字段...
    };

    const result = UserSchema.safeParse(invalidUser);
    expect(result.success).toBe(false);
  });

  // email 测试
  it('should fail if email is invalid', () => {
    const invalidUser = {
      email: 'invalidemail',
      // 其他字段...
    };

    const result = UserSchema.safeParse(invalidUser);
    expect(result.success).toBe(false);
  });

  // phone 测试
  it('should fail if phone is not 11 characters', () => {
    const invalidUser = {
      phone: '123', // 太短
      // 其他字段...
    };

    const result = UserSchema.safeParse(invalidUser);
    expect(result.success).toBe(false);
  });

  // password 测试
  it('should fail if password is too short', () => {
    const invalidUser = {
      password: 'Pass1!', // 少于8个字符
      // 其他字段...
    };

    const result = UserSchema.safeParse(invalidUser);
    expect(result.success).toBe(false);
  });

  it('should fail if password does not contain uppercase', () => {
    const invalidUser = {
      password: 'password1!', // 没有大写字母
      // 其他字段...
    };

    const result = UserSchema.safeParse(invalidUser);
    expect(result.success).toBe(false);
  });

  it('should fail if password does not contain lowercase', () => {
    const invalidUser = {
      password: 'PASSWORD1!', // 没有小写字母
      // 其他字段...
    };

    const result = UserSchema.safeParse(invalidUser);
    expect(result.success).toBe(false);
  });

  it('should fail if password does not contain number', () => {
    const invalidUser = {
      password: 'Password!', // 没有数字
      // 其他字段...
    };

    const result = UserSchema.safeParse(invalidUser);
    expect(result.success).toBe(false);
  });

  it('should fail if password does not contain special character', () => {
    const invalidUser = {
      password: 'Password1', // 没有特殊字符
      // 其他字段...
    };

    const result = UserSchema.safeParse(invalidUser);
    expect(result.success).toBe(false);
  });

  // role 测试
  it('should fail if role is invalid', () => {
    const invalidUser = {
      role: 'InvalidRole' as UserRole, // 无效的角色
      // 其他字段...
    };

    const result = UserSchema.safeParse(invalidUser);
    expect(result.success).toBe(false);
  });

  // status 测试
  it('should fail if status is invalid', () => {
    const invalidUser = {
      status: 'InvalidStatus' as UserStatus, // 无效的状态
      // 其他字段...
    };

    const result = UserSchema.safeParse(invalidUser);
    expect(result.success).toBe(false);
  });

  // 日期格式测试
  it('should fail if date format is invalid', () => {
    const invalidUser = {
      created_at: '2023-01-01', // 缺少时间部分
      // 其他字段...
    };

    const result = UserSchema.safeParse(invalidUser);
    expect(result.success).toBe(false);
  });

  // 可选字段测试
  it('should allow optional fields to be null', () => {
    const userWithNullFields = {
      // 必须字段...
      phone: null,
      avatar_url: null,
      email_verified_at: null,
      phone_verified_at: null,
      bio: null,
      language: null,
      timezone: null,
      last_active_at: null,
      deleted_at: null,
      updated_at: null,
    };

    const result = UserSchema.safeParse(userWithNullFields);
    expect(result.success).toBe(true);
  });

  it('should allow optional fields to be undefined', () => {
    const userWithUndefinedFields = {
      // 必须字段...
      // 可选字段省略...
    };

    const result = UserSchema.safeParse(userWithUndefinedFields);
    expect(result.success).toBe(true);
  });
});
