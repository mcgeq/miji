/**
 * Store 模板生成器
 * 提供标准的 Store 模板，确保所有 Store 遵循一致的结构
 * @module stores/utils/storeTemplate
 */

import { defineStore } from 'pinia';
import type { ComputedRef, Ref } from 'vue';
import { computed, ref } from 'vue';
import type { AppError } from '@/errors/appError';
import { withLoadingSafe } from './withLoadingSafe';

/**
 * 标准 Store 状态接口
 */
export interface BaseStoreState<T> {
  items: Ref<T[]>;
  currentItem: Ref<T | null>;
  isLoading: Ref<boolean>;
  error: Ref<AppError | null>;
}

/**
 * 标准 Store 计算属性接口
 */
export interface BaseStoreGetters<_T = unknown> {
  itemCount: ComputedRef<number>;
  hasItems: ComputedRef<boolean>;
  hasError: ComputedRef<boolean>;
}

/**
 * 标准 Store Actions 接口
 */
export interface BaseStoreActions<T, CreateDto = Partial<T>, UpdateDto = Partial<T>> {
  fetchItems: () => Promise<void>;
  fetchItemById: (id: string) => Promise<void>;
  createItem: (data: CreateDto) => Promise<T>;
  updateItem: (id: string, data: UpdateDto) => Promise<T>;
  deleteItem: (id: string) => Promise<void>;
  $reset: () => void;
}

/**
 * 完整的 Store 接口
 */
export type BaseStore<T, CreateDto = Partial<T>, UpdateDto = Partial<T>> = BaseStoreState<T> &
  BaseStoreGetters<T> &
  BaseStoreActions<T, CreateDto, UpdateDto>;

/**
 * Service 接口（Store 依赖的服务）
 */
export interface CrudService<T, CreateDto = Partial<T>, UpdateDto = Partial<T>> {
  list: () => Promise<T[]>;
  getById: (id: string) => Promise<T | null>;
  create: (data: CreateDto) => Promise<T>;
  update: (id: string, data: UpdateDto) => Promise<T>;
  delete: (id: string) => Promise<void>;
}

/**
 * Store 配置选项
 */
export interface StoreTemplateOptions<T, CreateDto = Partial<T>, UpdateDto = Partial<T>> {
  /** Store 名称 */
  name: string;
  /** Service 实例 */
  service: CrudService<T, CreateDto, UpdateDto>;
  /** 初始状态工厂函数（可选） */
  initialState?: () => Partial<BaseStoreState<T>>;
}

/**
 * 创建标准 Store
 *
 * @param options - Store 配置选项
 * @returns Pinia Store
 *
 * @example
 * ```typescript
 * import { createStoreTemplate } from '@/stores/utils/storeTemplate';
 * import { tagService } from '@/services/tagService';
 *
 * export const useTagStore = createStoreTemplate({
 *   name: 'tag',
 *   service: tagService,
 * });
 * ```
 */
export function createStoreTemplate<T, CreateDto = Partial<T>, UpdateDto = Partial<T>>(
  options: StoreTemplateOptions<T, CreateDto, UpdateDto>,
) {
  const { name, service, initialState } = options;

  return defineStore(name, () => {
    // ============ 状态 ============
    const items = ref<T[]>([]) as Ref<T[]>;
    const currentItem = ref<T | null>(null) as Ref<T | null>;
    const isLoading = ref(false);
    const error = ref<AppError | null>(null);

    // 应用初始状态（如果提供）
    if (initialState) {
      const initial = initialState();
      if (initial.items) items.value = initial.items.value;
      if (initial.currentItem) currentItem.value = initial.currentItem.value;
      if (initial.isLoading) isLoading.value = initial.isLoading.value;
      if (initial.error) error.value = initial.error.value;
    }

    // ============ 计算属性 ============
    const itemCount = computed(() => items.value.length);
    const hasItems = computed(() => items.value.length > 0);
    const hasError = computed(() => error.value !== null);

    // ============ Actions ============

    /**
     * 获取所有项目
     */
    const fetchItems = withLoadingSafe(
      async () => {
        items.value = await service.list();
      },
      isLoading,
      error,
    );

    /**
     * 根据 ID 获取项目
     */
    const fetchItemById = withLoadingSafe(
      async (id: string) => {
        const item = await service.getById(id);
        currentItem.value = item;
      },
      isLoading,
      error,
    );

    /**
     * 创建新项目
     */
    const createItem = withLoadingSafe(
      async (data: CreateDto) => {
        const newItem = await service.create(data);
        items.value.push(newItem);
        return newItem;
      },
      isLoading,
      error,
    );

    /**
     * 更新项目
     */
    const updateItem = withLoadingSafe(
      async (id: string, data: UpdateDto) => {
        const updatedItem = await service.update(id, data);

        // 更新列表中的项目
        const index = items.value.findIndex((item: any) => item.id === id || item.serialNum === id);
        if (index !== -1) {
          items.value[index] = updatedItem;
        }

        // 如果是当前项目，也更新它
        if (
          currentItem.value &&
          ((currentItem.value as any).id === id || (currentItem.value as any).serialNum === id)
        ) {
          currentItem.value = updatedItem;
        }

        return updatedItem;
      },
      isLoading,
      error,
    );

    /**
     * 删除项目
     */
    const deleteItem = withLoadingSafe(
      async (id: string) => {
        await service.delete(id);

        // 从列表中移除
        items.value = items.value.filter((item: any) => item.id !== id && item.serialNum !== id);

        // 如果是当前项目，清空它
        if (
          currentItem.value &&
          ((currentItem.value as any).id === id || (currentItem.value as any).serialNum === id)
        ) {
          currentItem.value = null;
        }
      },
      isLoading,
      error,
    );

    /**
     * 重置 Store 到初始状态
     */
    function $reset() {
      items.value = [];
      currentItem.value = null;
      isLoading.value = false;
      error.value = null;
    }

    // ============ 返回 ============
    return {
      // 状态
      items,
      currentItem,
      isLoading,
      error,

      // 计算属性
      itemCount,
      hasItems,
      hasError,

      // Actions
      fetchItems,
      fetchItemById,
      createItem,
      updateItem,
      deleteItem,
      $reset,
    };
  });
}

/**
 * 创建自定义 Store 的辅助函数
 * 提供基础状态和方法，允许扩展自定义逻辑
 *
 * @param options - Store 配置选项
 * @param extend - 扩展函数，接收基础 Store 并返回扩展的 Store
 * @returns Pinia Store
 *
 * @example
 * ```typescript
 * export const useTagStore = createCustomStore(
 *   { name: 'tag', service: tagService },
 *   (base) => {
 *     // 添加自定义方法
 *     const searchByName = async (name: string) => {
 *       const results = base.items.value.filter(item => item.name.includes(name));
 *       return results;
 *     };
 *
 *     return {
 *       ...base,
 *       searchByName,
 *     };
 *   }
 * );
 * ```
 */
export function createCustomStore<
  T,
  CreateDto = Partial<T>,
  UpdateDto = Partial<T>,
  Extended = Record<string, any>,
>(
  options: StoreTemplateOptions<T, CreateDto, UpdateDto>,
  extend: (base: BaseStore<T, CreateDto, UpdateDto>) => Extended,
) {
  const { name, service, initialState } = options;

  return defineStore(name, () => {
    // ============ 状态 ============
    const items = ref<T[]>([]) as Ref<T[]>;
    const currentItem = ref<T | null>(null) as Ref<T | null>;
    const isLoading = ref(false);
    const error = ref<AppError | null>(null);

    // 应用初始状态（如果提供）
    if (initialState) {
      const initial = initialState();
      if (initial.items) items.value = initial.items.value;
      if (initial.currentItem) currentItem.value = initial.currentItem.value;
      if (initial.isLoading) isLoading.value = initial.isLoading.value;
      if (initial.error) error.value = initial.error.value;
    }

    // ============ 计算属性 ============
    const itemCount = computed(() => items.value.length);
    const hasItems = computed(() => items.value.length > 0);
    const hasError = computed(() => error.value !== null);

    // ============ Actions ============

    const fetchItems = withLoadingSafe(
      async () => {
        items.value = await service.list();
      },
      isLoading,
      error,
    );

    const fetchItemById = withLoadingSafe(
      async (id: string) => {
        const item = await service.getById(id);
        currentItem.value = item;
      },
      isLoading,
      error,
    );

    const createItem = withLoadingSafe(
      async (data: CreateDto) => {
        const newItem = await service.create(data);
        items.value.push(newItem);
        return newItem;
      },
      isLoading,
      error,
    );

    const updateItem = withLoadingSafe(
      async (id: string, data: UpdateDto) => {
        const updatedItem = await service.update(id, data);

        const index = items.value.findIndex((item: any) => item.id === id || item.serialNum === id);
        if (index !== -1) {
          items.value[index] = updatedItem;
        }

        if (
          currentItem.value &&
          ((currentItem.value as any).id === id || (currentItem.value as any).serialNum === id)
        ) {
          currentItem.value = updatedItem;
        }

        return updatedItem;
      },
      isLoading,
      error,
    );

    const deleteItem = withLoadingSafe(
      async (id: string) => {
        await service.delete(id);

        items.value = items.value.filter((item: any) => item.id !== id && item.serialNum !== id);

        if (
          currentItem.value &&
          ((currentItem.value as any).id === id || (currentItem.value as any).serialNum === id)
        ) {
          currentItem.value = null;
        }
      },
      isLoading,
      error,
    );

    function $reset() {
      items.value = [];
      currentItem.value = null;
      isLoading.value = false;
      error.value = null;
    }

    // 创建基础 Store 对象
    const baseStore: BaseStore<T, CreateDto, UpdateDto> = {
      items,
      currentItem,
      isLoading,
      error,
      itemCount,
      hasItems,
      hasError,
      fetchItems,
      fetchItemById,
      createItem,
      updateItem,
      deleteItem,
      $reset,
    };

    // 扩展自定义逻辑
    const extended = extend(baseStore);

    return {
      ...baseStore,
      ...extended,
    };
  });
}
