/**
 * BaseService 属性测试
 * 使用 fast-check 进行基于属性的测试
 */

import { describe, it, expect, vi, beforeEach } from 'vitest';
import * as fc from 'fast-check';
import { BaseService, type IMapper } from '../../src/services/base/BaseService';
import type { TauriClient } from '../../src/utils/tauriClient';
import { AppError } from '../../src/errors/appError';

// Mock wrapError
vi.mock('../../src/utils/errorHandler', () => ({
  wrapError: vi.fn((module, error, code, message) => {
    const appError = new (class extends AppError {
      constructor() {
        super(module, code, message);
      }
    })();
    (appError as any).originalError = error;
    return appError;
  }),
}));

interface TestEntity {
  id: string;
  name: string;
  value: number;
}

type CreateTestDto = Omit<TestEntity, 'id'>;
type UpdateTestDto = Partial<CreateTestDto>;

class TestService extends BaseService<TestEntity, CreateTestDto, UpdateTestDto> {
  constructor(mapper: IMapper<TestEntity, CreateTestDto, UpdateTestDto>, tauriClient?: TauriClient) {
    super('test', mapper, tauriClient);
  }
}

const testEntityArb = fc.record({
  id: fc.uuid(),
  name: fc.string({ minLength: 1, maxLength: 50 }),
  value: fc.integer({ min: 0, max: 1000 }),
});

const createDtoArb = fc.record({
  name: fc.string({ minLength: 1, maxLength: 50 }),
  value: fc.integer({ min: 0, max: 1000 }),
});

describe('BaseService Property Tests', () => {
  /**
   * Feature: architecture-refactor, Property 2: Service 返回类型安全
   * 验证: 需求 3.2
   */
  it('Property 2: create 方法返回类型安全的实体', async () => {
    await fc.assert(
      fc.asyncProperty(createDtoArb, testEntityArb, async (createDto, expectedEntity) => {
        const mockMapper: IMapper<TestEntity, CreateTestDto, UpdateTestDto> = {
          create: vi.fn().mockResolvedValue(expectedEntity),
          getById: vi.fn(),
          list: vi.fn(),
          update: vi.fn(),
          delete: vi.fn(),
        };

        const service = new TestService(mockMapper);
        const result = await service.create(createDto);

        expect(result).toHaveProperty('id');
        expect(result).toHaveProperty('name');
        expect(result).toHaveProperty('value');
        expect(typeof result.id).toBe('string');
        expect(typeof result.name).toBe('string');
        expect(typeof result.value).toBe('number');
      }),
      { numRuns: 100 }
    );
  });

  /**
   * Feature: architecture-refactor, Property 4: 错误统一包装
   * 验证: 需求 6.2, 6.3
   */
  it('Property 4: 所有错误都被包装为 AppError', async () => {
    await fc.assert(
      fc.asyncProperty(
        fc.constantFrom('create', 'getById', 'list'),
        fc.string(),
        async (method, errorMessage) => {
          const error = new Error(errorMessage);
          const mockMapper: IMapper<TestEntity, CreateTestDto, UpdateTestDto> = {
            create: vi.fn().mockRejectedValue(error),
            getById: vi.fn().mockRejectedValue(error),
            list: vi.fn().mockRejectedValue(error),
            update: vi.fn().mockRejectedValue(error),
            delete: vi.fn().mockRejectedValue(error),
          };

          const service = new TestService(mockMapper);

          try {
            if (method === 'create') await service.create({ name: 'test', value: 1 });
            else if (method === 'getById') await service.getById('test-id');
            else await service.list();
            
            expect.fail('应该抛出错误');
          } catch (err) {
            expect(err).toBeInstanceOf(AppError);
            expect((err as AppError).module).toBe('TestService');
          }
        }
      ),
      { numRuns: 100 }
    );
  });

  /**
   * Feature: architecture-refactor, Property 11: Service 实现 CRUD 接口
   * 验证: 需求 3.1
   */
  it('Property 11: Service 实现所有 CRUD 方法', () => {
    const mockMapper: IMapper<TestEntity, CreateTestDto, UpdateTestDto> = {
      create: vi.fn(),
      getById: vi.fn(),
      list: vi.fn(),
      update: vi.fn(),
      delete: vi.fn(),
    };

    const service = new TestService(mockMapper);

    expect(typeof service.create).toBe('function');
    expect(typeof service.getById).toBe('function');
    expect(typeof service.list).toBe('function');
    expect(typeof service.update).toBe('function');
    expect(typeof service.delete).toBe('function');
  });

  /**
   * Feature: architecture-refactor, Property 12: Service 使用统一分页
   * 验证: 需求 3.4
   */
  it('Property 12: listPaged 返回符合 PagedResult 接口', async () => {
    await fc.assert(
      fc.asyncProperty(
        fc.array(testEntityArb, { minLength: 0, maxLength: 100 }),
        fc.integer({ min: 1, max: 10 }),
        fc.integer({ min: 1, max: 20 }),
        async (entities, page, pageSize) => {
          const mockMapper: IMapper<TestEntity, CreateTestDto, UpdateTestDto> = {
            create: vi.fn(),
            getById: vi.fn(),
            list: vi.fn().mockResolvedValue(entities),
            update: vi.fn(),
            delete: vi.fn(),
          };

          const service = new TestService(mockMapper);
          const result = await service.listPaged({ page, pageSize });

          expect(result).toHaveProperty('items');
          expect(result).toHaveProperty('total');
          expect(result).toHaveProperty('page');
          expect(result).toHaveProperty('pageSize');
          expect(result).toHaveProperty('totalPages');
          expect(Array.isArray(result.items)).toBe(true);
          expect(result.total).toBe(entities.length);
          expect(result.items.length).toBeLessThanOrEqual(pageSize);
        }
      ),
      { numRuns: 100 }
    );
  });

  /**
   * Feature: architecture-refactor, Property 27: Service 错误使用 wrapError
   * 验证: 需求 6.2
   */
  it('Property 27: 错误通过 wrapError 包装', async () => {
    await fc.assert(
      fc.asyncProperty(
        fc.oneof(
          fc.constant(new Error('Database error')),
          fc.constant(new Error('Network error'))
        ),
        async (originalError) => {
          const mockMapper: IMapper<TestEntity, CreateTestDto, UpdateTestDto> = {
            create: vi.fn().mockRejectedValue(originalError),
            getById: vi.fn(),
            list: vi.fn(),
            update: vi.fn(),
            delete: vi.fn(),
          };

          const service = new TestService(mockMapper);

          try {
            await service.create({ name: 'test', value: 1 });
            expect.fail('应该抛出错误');
          } catch (err) {
            expect(err).toBeInstanceOf(AppError);
            expect((err as any).originalError).toBe(originalError);
          }
        }
      ),
      { numRuns: 100 }
    );
  });

  /**
   * Feature: architecture-refactor, Property 33: 数据源可切换
   * 验证: 需求 5.5
   */
  it('Property 33: Service 可以混合使用 Mapper 和 TauriClient', async () => {
    await fc.assert(
      fc.asyncProperty(testEntityArb, fc.string(), async (entity, commandName) => {
        const mockMapper: IMapper<TestEntity, CreateTestDto, UpdateTestDto> = {
          create: vi.fn(),
          getById: vi.fn().mockResolvedValue(entity),
          list: vi.fn(),
          update: vi.fn(),
          delete: vi.fn(),
        };

        const mockTauriClient = {
          invoke: vi.fn().mockResolvedValue({ success: true }),
        } as any;

        const service = new TestService(mockMapper, mockTauriClient);

        await service.getById(entity.id);
        expect(mockMapper.getById).toHaveBeenCalled();

        await (service as any).invokeCommand(commandName, {});
        expect(mockTauriClient.invoke).toHaveBeenCalled();
      }),
      { numRuns: 100 }
    );
  });
});
