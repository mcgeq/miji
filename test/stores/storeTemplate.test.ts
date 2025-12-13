/**
 * Store 模板生成器测试
 */

import { describe, it, expect, vi, beforeEach } from 'vitest';
import { setActivePinia, createPinia } from 'pinia';
import { computed } from 'vue';
import { createStoreTemplate, createCustomStore } from '@/stores/utils/storeTemplate';
import type { CrudService } from '@/stores/utils/storeTemplate';

// 测试数据类型
interface TestItem {
  id: string;
  name: string;
  value: number;
}

type CreateTestItem = Omit<TestItem, 'id'>;
type UpdateTestItem = Partial<Omit<TestItem, 'id'>>;

describe('createStoreTemplate', () => {
  let mockService: CrudService<TestItem, CreateTestItem, UpdateTestItem>;

  beforeEach(() => {
    // 为每个测试创建新的 Pinia 实例
    setActivePinia(createPinia());

    // 创建 mock service
    mockService = {
      list: vi.fn(async () => [
        { id: '1', name: 'Item 1', value: 10 },
        { id: '2', name: 'Item 2', value: 20 },
      ]),
      getById: vi.fn(async (id: string) => {
        if (id === '1') return { id: '1', name: 'Item 1', value: 10 };
        return null;
      }),
      create: vi.fn(async (data: CreateTestItem) => ({
        id: '3',
        ...data,
      })),
      update: vi.fn(async (id: string, data: UpdateTestItem) => ({
        id,
        name: data.name || 'Updated',
        value: data.value || 0,
      })),
      delete: vi.fn(async () => {}),
    };
  });

  describe('状态初始化', () => {
    it('应该创建具有初始状态的 Store', () => {
      const useTestStore = createStoreTemplate({
        name: 'test',
        service: mockService,
      });

      const store = useTestStore();

      expect(store.items).toEqual([]);
      expect(store.currentItem).toBeNull();
      expect(store.isLoading).toBe(false);
      expect(store.error).toBeNull();
    });

    it('应该支持自定义初始状态', () => {
      const useTestStore = createStoreTemplate({
        name: 'test',
        service: mockService,
        initialState: () => ({
          items: { value: [{ id: '1', name: 'Initial', value: 5 }] } as any,
        }),
      });

      const store = useTestStore();

      expect(store.items).toHaveLength(1);
      expect(store.items[0].name).toBe('Initial');
    });
  });

  describe('计算属性', () => {
    it('应该正确计算 itemCount', async () => {
      const useTestStore = createStoreTemplate({
        name: 'test',
        service: mockService,
      });

      const store = useTestStore();
      expect(store.itemCount).toBe(0);

      await store.fetchItems();
      expect(store.itemCount).toBe(2);
    });

    it('应该正确计算 hasItems', async () => {
      const useTestStore = createStoreTemplate({
        name: 'test',
        service: mockService,
      });

      const store = useTestStore();
      expect(store.hasItems).toBe(false);

      await store.fetchItems();
      expect(store.hasItems).toBe(true);
    });

    it('应该正确计算 hasError', async () => {
      const useTestStore = createStoreTemplate({
        name: 'test',
        service: mockService,
      });

      const store = useTestStore();
      expect(store.hasError).toBe(false);

      // 触发错误
      mockService.list = vi.fn(async () => {
        throw new Error('Test error');
      });

      try {
        await store.fetchItems();
      } catch {
        // 预期会抛出错误
      }

      expect(store.hasError).toBe(true);
    });
  });

  describe('fetchItems', () => {
    it('应该获取所有项目', async () => {
      const useTestStore = createStoreTemplate({
        name: 'test',
        service: mockService,
      });

      const store = useTestStore();
      await store.fetchItems();

      expect(mockService.list).toHaveBeenCalled();
      expect(store.items).toHaveLength(2);
      expect(store.items[0].name).toBe('Item 1');
    });

    it('应该在获取时管理加载状态', async () => {
      const useTestStore = createStoreTemplate({
        name: 'test',
        service: mockService,
      });

      const store = useTestStore();
      const promise = store.fetchItems();

      // 在异步操作期间，isLoading 应该为 true
      expect(store.isLoading).toBe(true);

      await promise;

      // 完成后应该为 false
      expect(store.isLoading).toBe(false);
    });

    it('应该在失败时设置错误状态', async () => {
      mockService.list = vi.fn(async () => {
        throw new Error('Fetch failed');
      });

      const useTestStore = createStoreTemplate({
        name: 'test',
        service: mockService,
      });

      const store = useTestStore();

      try {
        await store.fetchItems();
        expect.fail('应该抛出错误');
      } catch {
        expect(store.error).not.toBeNull();
        expect(store.error?.message).toContain('Fetch failed');
      }
    });
  });

  describe('fetchItemById', () => {
    it('应该根据 ID 获取项目', async () => {
      const useTestStore = createStoreTemplate({
        name: 'test',
        service: mockService,
      });

      const store = useTestStore();
      await store.fetchItemById('1');

      expect(mockService.getById).toHaveBeenCalledWith('1');
      expect(store.currentItem).not.toBeNull();
      expect(store.currentItem?.name).toBe('Item 1');
    });

    it('应该处理找不到项目的情况', async () => {
      const useTestStore = createStoreTemplate({
        name: 'test',
        service: mockService,
      });

      const store = useTestStore();
      await store.fetchItemById('999');

      expect(store.currentItem).toBeNull();
    });
  });

  describe('createItem', () => {
    it('应该创建新项目并添加到列表', async () => {
      const useTestStore = createStoreTemplate({
        name: 'test',
        service: mockService,
      });

      const store = useTestStore();
      const newItem = await store.createItem({ name: 'New Item', value: 30 });

      expect(mockService.create).toHaveBeenCalledWith({ name: 'New Item', value: 30 });
      expect(newItem.id).toBe('3');
      expect(store.items).toHaveLength(1);
      expect(store.items[0]).toEqual(newItem);
    });

    it('应该返回创建的项目', async () => {
      const useTestStore = createStoreTemplate({
        name: 'test',
        service: mockService,
      });

      const store = useTestStore();
      const result = await store.createItem({ name: 'Test', value: 100 });

      expect(result).toEqual({
        id: '3',
        name: 'Test',
        value: 100,
      });
    });
  });

  describe('updateItem', () => {
    it('应该更新列表中的项目', async () => {
      const useTestStore = createStoreTemplate({
        name: 'test',
        service: mockService,
      });

      const store = useTestStore();
      await store.fetchItems();

      const updated = await store.updateItem('1', { name: 'Updated Item' });

      expect(mockService.update).toHaveBeenCalledWith('1', { name: 'Updated Item' });
      expect(updated.name).toBe('Updated Item');
      expect(store.items[0].name).toBe('Updated Item');
    });

    it('应该更新 currentItem 如果它是被更新的项目', async () => {
      const useTestStore = createStoreTemplate({
        name: 'test',
        service: mockService,
      });

      const store = useTestStore();
      await store.fetchItemById('1');

      await store.updateItem('1', { name: 'Updated Current' });

      expect(store.currentItem?.name).toBe('Updated Current');
    });

    it('应该支持使用 serialNum 作为 ID', async () => {
      // 修改 mock 数据使用 serialNum
      const itemWithSerialNum = { serialNum: 's1', name: 'Item S1', value: 10 };
      mockService.list = vi.fn(async () => [itemWithSerialNum as any]);
      mockService.update = vi.fn(async (id: string, data: UpdateTestItem) => ({
        serialNum: id,
        name: data.name || 'Updated',
        value: data.value || 0,
      } as any));

      const useTestStore = createStoreTemplate({
        name: 'test',
        service: mockService,
      });

      const store = useTestStore();
      await store.fetchItems();

      await store.updateItem('s1', { name: 'Updated S1' });

      expect(mockService.update).toHaveBeenCalledWith('s1', { name: 'Updated S1' });
    });
  });

  describe('deleteItem', () => {
    it('应该从列表中删除项目', async () => {
      const useTestStore = createStoreTemplate({
        name: 'test',
        service: mockService,
      });

      const store = useTestStore();
      await store.fetchItems();

      expect(store.items).toHaveLength(2);

      await store.deleteItem('1');

      expect(mockService.delete).toHaveBeenCalledWith('1');
      expect(store.items).toHaveLength(1);
      expect(store.items.find(item => item.id === '1')).toBeUndefined();
    });

    it('应该清空 currentItem 如果它是被删除的项目', async () => {
      const useTestStore = createStoreTemplate({
        name: 'test',
        service: mockService,
      });

      const store = useTestStore();
      await store.fetchItemById('1');

      expect(store.currentItem).not.toBeNull();

      await store.deleteItem('1');

      expect(store.currentItem).toBeNull();
    });
  });

  describe('$reset', () => {
    it('应该重置所有状态到初始值', async () => {
      const useTestStore = createStoreTemplate({
        name: 'test',
        service: mockService,
      });

      const store = useTestStore();

      // 修改状态
      await store.fetchItems();
      await store.fetchItemById('1');

      expect(store.items).toHaveLength(2);
      expect(store.currentItem).not.toBeNull();

      // 重置
      store.$reset();

      expect(store.items).toEqual([]);
      expect(store.currentItem).toBeNull();
      expect(store.isLoading).toBe(false);
      expect(store.error).toBeNull();
    });

    it('应该清除错误状态', async () => {
      mockService.list = vi.fn(async () => {
        throw new Error('Test error');
      });

      const useTestStore = createStoreTemplate({
        name: 'test',
        service: mockService,
      });

      const store = useTestStore();

      try {
        await store.fetchItems();
      } catch {
        // 预期会抛出错误
      }

      expect(store.error).not.toBeNull();

      store.$reset();

      expect(store.error).toBeNull();
    });
  });
});

describe('createCustomStore', () => {
  let mockService: CrudService<TestItem, CreateTestItem, UpdateTestItem>;

  beforeEach(() => {
    setActivePinia(createPinia());

    mockService = {
      list: vi.fn(async () => [
        { id: '1', name: 'Item 1', value: 10 },
        { id: '2', name: 'Item 2', value: 20 },
      ]),
      getById: vi.fn(async () => null),
      create: vi.fn(async (data: CreateTestItem) => ({ id: '3', ...data })),
      update: vi.fn(async () => ({ id: '1', name: 'Updated', value: 0 })),
      delete: vi.fn(async () => {}),
    };
  });

  it('应该创建具有基础功能的 Store', async () => {
    const useTestStore = createCustomStore(
      { name: 'test', service: mockService },
      (base) => {
        return {
          ...base,
        };
      }
    );

    const store = useTestStore();

    expect(store.items).toEqual([]);
    expect(store.fetchItems).toBeDefined();
    expect(store.$reset).toBeDefined();
  });

  it('应该允许扩展自定义方法', async () => {
    const useTestStore = createCustomStore(
      { name: 'test', service: mockService },
      (base) => {
        const searchByName = (name: string) => {
          return base.items.value.filter(item => item.name.includes(name));
        };

        return {
          searchByName,
        };
      }
    );

    const store = useTestStore();
    await store.fetchItems();

    const results = store.searchByName('Item 1');
    expect(results).toHaveLength(1);
    expect(results[0].name).toBe('Item 1');
  });

  it('应该允许添加自定义计算属性', async () => {
    const useTestStore = createCustomStore(
      { name: 'test', service: mockService },
      (base) => {
        const totalValue = computed(() => 
          base.items.value.reduce((sum, item) => sum + item.value, 0)
        );

        return {
          totalValue,
        };
      }
    );

    const store = useTestStore();
    await store.fetchItems();

    expect(store.totalValue).toBe(30); // 10 + 20
  });

  it('应该允许覆盖基础方法', async () => {
    const customCreate = vi.fn(async (data: CreateTestItem) => {
      // 自定义创建逻辑
      return { id: 'custom', ...data };
    });

    const useTestStore = createCustomStore(
      { name: 'test', service: mockService },
      () => {
        return {
          createItem: customCreate,
        };
      }
    );

    const store = useTestStore();
    const result = await store.createItem({ name: 'Custom', value: 50 });

    expect(customCreate).toHaveBeenCalled();
    expect(result.id).toBe('custom');
  });
});
