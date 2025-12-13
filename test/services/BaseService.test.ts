/**
 * BaseService 单元测试
 * 测试 CRUD 操作、分页、错误处理和数据源切换
 */

import { describe, it, expect, vi, beforeEach } from 'vitest';
import { BaseService, type IMapper } from '../../src/services/base/BaseService';
import type { TauriClient } from '../../src/utils/tauriClient';
import { wrapError } from '../../src/utils/errorHandler';

// Mock wrapError
vi.mock('../../src/utils/errorHandler', () => ({
  wrapError: vi.fn((module, error, code, message) => {
    const err = new Error(message);
    (err as any).code = code;
    (err as any).module = module;
    (err as any).originalError = error;
    return err;
  }),
}));

// 测试实体类型
interface TestEntity {
  id: string;
  name: string;
  value: number;
}

type CreateTestDto = Omit<TestEntity, 'id'>;
type UpdateTestDto = Partial<CreateTestDto>;

// 创建测试用的 Service 子类
class TestService extends BaseService<TestEntity, CreateTestDto, UpdateTestDto> {
  constructor(mapper: IMapper<TestEntity, CreateTestDto, UpdateTestDto>, tauriClient?: TauriClient) {
    super('test', mapper, tauriClient);
  }
}

describe('BaseService - CRUD Operations', () => {
  let mockMapper: IMapper<TestEntity, CreateTestDto, UpdateTestDto>;
  let service: TestService;

  beforeEach(() => {
    vi.clearAllMocks();
    
    // 创建 mock mapper
    mockMapper = {
      create: vi.fn(),
      getById: vi.fn(),
      list: vi.fn(),
      update: vi.fn(),
      delete: vi.fn(),
    };

    service = new TestService(mockMapper);
  });

  describe('create', () => {
    it('should create entity successfully', async () => {
      const createDto: CreateTestDto = { name: 'Test', value: 42 };
      const createdEntity: TestEntity = { id: '1', ...createDto };

      vi.mocked(mockMapper.create).mockResolvedValueOnce(createdEntity);

      const result = await service.create(createDto);

      expect(result).toEqual(createdEntity);
      expect(mockMapper.create).toHaveBeenCalledWith(createDto);
      expect(mockMapper.create).toHaveBeenCalledTimes(1);
    });

    it('should wrap errors on create failure', async () => {
      const createDto: CreateTestDto = { name: 'Test', value: 42 };
      const error = new Error('Database error');

      vi.mocked(mockMapper.create).mockRejectedValueOnce(error);

      await expect(service.create(createDto)).rejects.toThrow('创建test失败');
      expect(wrapError).toHaveBeenCalledWith(
        'TestService',
        error,
        'CREATE_FAILED',
        '创建test失败'
      );
    });
  });

  describe('getById', () => {
    it('should get entity by id successfully', async () => {
      const entity: TestEntity = { id: '1', name: 'Test', value: 42 };

      vi.mocked(mockMapper.getById).mockResolvedValueOnce(entity);

      const result = await service.getById('1');

      expect(result).toEqual(entity);
      expect(mockMapper.getById).toHaveBeenCalledWith('1');
      expect(mockMapper.getById).toHaveBeenCalledTimes(1);
    });

    it('should return null when entity not found', async () => {
      vi.mocked(mockMapper.getById).mockResolvedValueOnce(null);

      const result = await service.getById('999');

      expect(result).toBeNull();
      expect(mockMapper.getById).toHaveBeenCalledWith('999');
    });

    it('should wrap errors on getById failure', async () => {
      const error = new Error('Database error');

      vi.mocked(mockMapper.getById).mockRejectedValueOnce(error);

      await expect(service.getById('1')).rejects.toThrow('获取test失败');
      expect(wrapError).toHaveBeenCalledWith(
        'TestService',
        error,
        'GET_FAILED',
        '获取test失败'
      );
    });
  });

  describe('list', () => {
    it('should list entities successfully', async () => {
      const entities: TestEntity[] = [
        { id: '1', name: 'Test1', value: 1 },
        { id: '2', name: 'Test2', value: 2 },
      ];

      vi.mocked(mockMapper.list).mockResolvedValueOnce(entities);

      const result = await service.list();

      expect(result).toEqual(entities);
      expect(mockMapper.list).toHaveBeenCalledWith(undefined);
      expect(mockMapper.list).toHaveBeenCalledTimes(1);
    });

    it('should list entities with filters', async () => {
      const entities: TestEntity[] = [{ id: '1', name: 'Test1', value: 1 }];
      const filters = { name: 'Test1' };

      vi.mocked(mockMapper.list).mockResolvedValueOnce(entities);

      const result = await service.list(filters);

      expect(result).toEqual(entities);
      expect(mockMapper.list).toHaveBeenCalledWith(filters);
    });

    it('should wrap errors on list failure', async () => {
      const error = new Error('Database error');

      vi.mocked(mockMapper.list).mockRejectedValueOnce(error);

      await expect(service.list()).rejects.toThrow('获取test列表失败');
      expect(wrapError).toHaveBeenCalledWith(
        'TestService',
        error,
        'LIST_FAILED',
        '获取test列表失败'
      );
    });
  });

  describe('update', () => {
    it('should update entity successfully', async () => {
      const updateDto: UpdateTestDto = { name: 'Updated' };
      const updatedEntity: TestEntity = { id: '1', name: 'Updated', value: 42 };

      vi.mocked(mockMapper.update).mockResolvedValueOnce(updatedEntity);

      const result = await service.update('1', updateDto);

      expect(result).toEqual(updatedEntity);
      expect(mockMapper.update).toHaveBeenCalledWith('1', updateDto);
      expect(mockMapper.update).toHaveBeenCalledTimes(1);
    });

    it('should wrap errors on update failure', async () => {
      const updateDto: UpdateTestDto = { name: 'Updated' };
      const error = new Error('Database error');

      vi.mocked(mockMapper.update).mockRejectedValueOnce(error);

      await expect(service.update('1', updateDto)).rejects.toThrow('更新test失败');
      expect(wrapError).toHaveBeenCalledWith(
        'TestService',
        error,
        'UPDATE_FAILED',
        '更新test失败'
      );
    });
  });

  describe('delete', () => {
    it('should delete entity successfully', async () => {
      vi.mocked(mockMapper.delete).mockResolvedValueOnce(undefined);

      await service.delete('1');

      expect(mockMapper.delete).toHaveBeenCalledWith('1');
      expect(mockMapper.delete).toHaveBeenCalledTimes(1);
    });

    it('should wrap errors on delete failure', async () => {
      const error = new Error('Database error');

      vi.mocked(mockMapper.delete).mockRejectedValueOnce(error);

      await expect(service.delete('1')).rejects.toThrow('删除test失败');
      expect(wrapError).toHaveBeenCalledWith(
        'TestService',
        error,
        'DELETE_FAILED',
        '删除test失败'
      );
    });
  });
});

describe('BaseService - Pagination', () => {
  let mockMapper: IMapper<TestEntity, CreateTestDto, UpdateTestDto>;
  let service: TestService;

  beforeEach(() => {
    vi.clearAllMocks();
    
    mockMapper = {
      create: vi.fn(),
      getById: vi.fn(),
      list: vi.fn(),
      update: vi.fn(),
      delete: vi.fn(),
    };

    service = new TestService(mockMapper);
  });

  it('should paginate results correctly', async () => {
    const entities: TestEntity[] = [
      { id: '1', name: 'Test1', value: 1 },
      { id: '2', name: 'Test2', value: 2 },
      { id: '3', name: 'Test3', value: 3 },
      { id: '4', name: 'Test4', value: 4 },
      { id: '5', name: 'Test5', value: 5 },
    ];

    vi.mocked(mockMapper.list).mockResolvedValueOnce(entities);

    const result = await service.listPaged({ page: 1, pageSize: 2 });

    expect(result).toEqual({
      items: [entities[0], entities[1]],
      total: 5,
      page: 1,
      pageSize: 2,
      totalPages: 3,
    });
  });

  it('should handle second page correctly', async () => {
    const entities: TestEntity[] = [
      { id: '1', name: 'Test1', value: 1 },
      { id: '2', name: 'Test2', value: 2 },
      { id: '3', name: 'Test3', value: 3 },
      { id: '4', name: 'Test4', value: 4 },
      { id: '5', name: 'Test5', value: 5 },
    ];

    vi.mocked(mockMapper.list).mockResolvedValueOnce(entities);

    const result = await service.listPaged({ page: 2, pageSize: 2 });

    expect(result).toEqual({
      items: [entities[2], entities[3]],
      total: 5,
      page: 2,
      pageSize: 2,
      totalPages: 3,
    });
  });

  it('should handle last page with partial results', async () => {
    const entities: TestEntity[] = [
      { id: '1', name: 'Test1', value: 1 },
      { id: '2', name: 'Test2', value: 2 },
      { id: '3', name: 'Test3', value: 3 },
    ];

    vi.mocked(mockMapper.list).mockResolvedValueOnce(entities);

    const result = await service.listPaged({ page: 2, pageSize: 2 });

    expect(result).toEqual({
      items: [entities[2]],
      total: 3,
      page: 2,
      pageSize: 2,
      totalPages: 2,
    });
  });

  it('should handle empty results', async () => {
    vi.mocked(mockMapper.list).mockResolvedValueOnce([]);

    const result = await service.listPaged({ page: 1, pageSize: 10 });

    expect(result).toEqual({
      items: [],
      total: 0,
      page: 1,
      pageSize: 10,
      totalPages: 0,
    });
  });

  it('should wrap errors on listPaged failure', async () => {
    const error = new Error('Database error');

    vi.mocked(mockMapper.list).mockRejectedValueOnce(error);

    await expect(service.listPaged({ page: 1, pageSize: 10 })).rejects.toThrow(
      '分页查询test失败'
    );
    expect(wrapError).toHaveBeenCalledWith(
      'TestService',
      error,
      'LIST_PAGED_FAILED',
      '分页查询test失败'
    );
  });
});

describe('BaseService - Tauri Command Integration', () => {
  let mockMapper: IMapper<TestEntity, CreateTestDto, UpdateTestDto>;
  let mockTauriClient: TauriClient;
  let service: TestService;

  beforeEach(() => {
    vi.clearAllMocks();
    
    mockMapper = {
      create: vi.fn(),
      getById: vi.fn(),
      list: vi.fn(),
      update: vi.fn(),
      delete: vi.fn(),
    };

    mockTauriClient = {
      invoke: vi.fn(),
    } as any;

    service = new TestService(mockMapper, mockTauriClient);
  });

  it('should invoke Tauri command successfully', async () => {
    const commandResult = { success: true, data: 'result' };
    vi.mocked(mockTauriClient.invoke).mockResolvedValueOnce(commandResult);

    const result = await (service as any).invokeCommand('custom_operation', { param: 'value' });

    expect(result).toEqual(commandResult);
    expect(mockTauriClient.invoke).toHaveBeenCalledWith('test_custom_operation', {
      param: 'value',
    });
  });

  it('should wrap errors on command failure', async () => {
    const error = new Error('Command failed');
    vi.mocked(mockTauriClient.invoke).mockRejectedValueOnce(error);

    await expect(
      (service as any).invokeCommand('custom_operation', { param: 'value' })
    ).rejects.toThrow('执行命令失败: custom_operation');

    expect(wrapError).toHaveBeenCalledWith(
      'TestService',
      error,
      'COMMAND_FAILED',
      '执行命令失败: custom_operation'
    );
  });

  it('should use default TauriClient when not provided', () => {
    const serviceWithDefaultClient = new TestService(mockMapper);
    expect((serviceWithDefaultClient as any).tauriClient).toBeDefined();
  });
});

describe('BaseService - Data Source Switching', () => {
  let mockMapper: IMapper<TestEntity, CreateTestDto, UpdateTestDto>;
  let service: TestService;

  beforeEach(() => {
    vi.clearAllMocks();
    
    mockMapper = {
      create: vi.fn(),
      getById: vi.fn(),
      list: vi.fn(),
      update: vi.fn(),
      delete: vi.fn(),
    };

    service = new TestService(mockMapper);
  });

  it('should use mapper for CRUD operations by default', async () => {
    const entity: TestEntity = { id: '1', name: 'Test', value: 42 };
    vi.mocked(mockMapper.getById).mockResolvedValueOnce(entity);

    await service.getById('1');

    expect(mockMapper.getById).toHaveBeenCalled();
  });

  it('should allow switching between mapper and Tauri commands', async () => {
    // 首先使用 mapper
    const entity: TestEntity = { id: '1', name: 'Test', value: 42 };
    vi.mocked(mockMapper.getById).mockResolvedValueOnce(entity);

    const result1 = await service.getById('1');
    expect(result1).toEqual(entity);
    expect(mockMapper.getById).toHaveBeenCalledTimes(1);

    // 然后可以使用 Tauri 命令进行复杂操作
    const mockTauriClient = {
      invoke: vi.fn().mockResolvedValueOnce({ success: true }),
    } as any;

    (service as any).tauriClient = mockTauriClient;

    await (service as any).invokeCommand('complex_operation', {});
    expect(mockTauriClient.invoke).toHaveBeenCalledWith('test_complex_operation', {});
  });
});
