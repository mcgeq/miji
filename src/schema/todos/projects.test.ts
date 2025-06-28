import { describe, it, expect } from 'vitest';
import { ProjectSchema } from './projects';

const validProject = {
  serialNum: 'abcdefghijklmnopqrstuvwxyz123456782145', // 38位
  name: 'My Project',
  description: 'This is a sample project description.',
  ownerId: 'abcdefghijklmnopqrstuvwxyz123456782145',
  color: '0xff00ff', // 合法 hex 颜色
  isArchived: false,
  createdAt: '2025-06-14T12:00:00.000000Z',
  updatedAt: '2025-06-14T12:30:00.000000Z',
};

describe('ProjectSchema', () => {
  it('should pass validation with valid data', () => {
    const result = ProjectSchema.safeParse(validProject);
    expect(result.success).toBe(true);
  });

  it('should fail if serial_num is invalid', () => {
    const invalid = { ...validProject, serialNum: 'abc!' };
    const result = ProjectSchema.safeParse(invalid);
    expect(result.success).toBe(false);
    if (!result.success) {
      expect(result.error.issues[0].path).toContain('serial_num');
    }
  });

  it('should fail if name is empty', () => {
    const invalid = { ...validProject, name: '' };
    const result = ProjectSchema.safeParse(invalid);
    expect(result.success).toBe(false);
  });

  it('should fail if color is not hex format', () => {
    const invalid = { ...validProject, color: 'red' };
    const result = ProjectSchema.safeParse(invalid);
    expect(result.success).toBe(false);
    if (!result.success) {
      expect(result.error.issues[0].message).toContain(
        'Color must be in hex format',
      );
    }
  });

  it('should allow updated_at to be null or omitted', () => {
    const dataWithNull = { ...validProject, updatedAt: null };

    const { updatedAt: updated_at, ...dataWithoutUpdatedAt } = validProject;
    expect(ProjectSchema.safeParse(dataWithNull).success).toBe(true);
    expect(ProjectSchema.safeParse(dataWithoutUpdatedAt).success).toBe(true);
  });

  it('should fail if created_at format is invalid', () => {
    const invalid = { ...validProject, createdAt: '2025-06-14 12:00:00' };
    const result = ProjectSchema.safeParse(invalid);
    expect(result.success).toBe(false);
  });
});
