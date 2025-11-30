import { toast } from '@/utils/toast';

/**
 * CRUD 操作的 Store 接口
 */
export interface CrudStore<T, C, U> {
  create: (data: C) => Promise<T>;
  update: (id: string, data: U) => Promise<T>;
  delete: (id: string) => Promise<void>;
  fetchAll?: () => Promise<void>;
}

/**
 * CRUD Actions 配置选项
 */
export interface CrudActionsOptions {
  /** 成功消息配置 */
  successMessages?: {
    create?: string;
    update?: string;
    delete?: string;
  };
  /** 错误消息配置 */
  errorMessages?: {
    create?: string;
    update?: string;
    delete?: string;
  };
  /** 是否在操作后自动刷新列表 */
  autoRefresh?: boolean;
  /** 是否在操作后自动关闭模态框 */
  autoClose?: boolean;
}

/**
 * 通用 CRUD Actions Composable
 * 提供统一的增删改查操作逻辑
 *
 * @param store - CRUD Store 实例
 * @param options - 配置选项
 *
 * @example
 * ```typescript
 * const accountActions = useCrudActions(
 *   useAccountStore(),
 *   {
 *     successMessages: {
 *       create: '账户创建成功',
 *       update: '账户更新成功',
 *       delete: '账户删除成功',
 *     },
 *   }
 * );
 * ```
 */
export function useCrudActions<T extends { serialNum: string }, C = Partial<T>, U = Partial<T>>(
  store: CrudStore<T, C, U>,
  options: CrudActionsOptions = {},
) {
  const {
    successMessages = {},
    errorMessages = {},
    autoRefresh = true,
    autoClose = true,
  } = options;

  // 状态
  const show = ref(false);
  const selected = ref<T | null>(null);
  const isViewMode = ref(false);
  const loading = ref(false);

  /**
   * 显示创建模态框
   */
  function showModal() {
    show.value = true;
    selected.value = null;
    isViewMode.value = false;
  }

  /**
   * 关闭模态框
   */
  function closeModal() {
    show.value = false;
    selected.value = null;
    isViewMode.value = false;
  }

  /**
   * 编辑项目
   */
  function edit(item: T) {
    selected.value = item;
    show.value = true;
    isViewMode.value = false;
  }

  /**
   * 查看项目详情
   */
  function view(item: T) {
    selected.value = item;
    show.value = true;
    isViewMode.value = true;
  }

  /**
   * 创建项目
   */
  async function handleSave(data: C): Promise<T | null> {
    loading.value = true;
    try {
      const result = await store.create(data);
      toast.success(successMessages.create || '创建成功');

      if (autoClose) {
        closeModal();
      }

      if (autoRefresh && store.fetchAll) {
        await store.fetchAll();
      }

      return result;
    } catch (error: any) {
      const message = error.message || errorMessages.create || '创建失败';
      toast.error(message);
      return null;
    } finally {
      loading.value = false;
    }
  }

  /**
   * 更新项目
   */
  async function handleUpdate(id: string, data: U): Promise<T | null> {
    loading.value = true;
    try {
      const result = await store.update(id, data);
      toast.success(successMessages.update || '更新成功');

      if (autoClose) {
        closeModal();
      }

      if (autoRefresh && store.fetchAll) {
        await store.fetchAll();
      }

      return result;
    } catch (error: any) {
      const message = error.message || errorMessages.update || '更新失败';
      toast.error(message);
      return null;
    } finally {
      loading.value = false;
    }
  }

  /**
   * 删除项目
   */
  async function handleDelete(id: string): Promise<boolean> {
    loading.value = true;
    try {
      await store.delete(id);
      toast.success(successMessages.delete || '删除成功');

      if (autoRefresh && store.fetchAll) {
        await store.fetchAll();
      }

      return true;
    } catch (error: any) {
      const message = error.message || errorMessages.delete || '删除失败';
      toast.error(message);
      return false;
    } finally {
      loading.value = false;
    }
  }

  /**
   * 批量删除项目
   */
  async function handleBatchDelete(ids: string[]): Promise<boolean> {
    loading.value = true;
    try {
      await Promise.all(ids.map(id => store.delete(id)));
      toast.success(`成功删除 ${ids.length} 项`);

      if (autoRefresh && store.fetchAll) {
        await store.fetchAll();
      }

      return true;
    } catch (error: any) {
      const message = error.message || '批量删除失败';
      toast.error(message);
      return false;
    } finally {
      loading.value = false;
    }
  }

  return {
    // 状态
    show: readonly(show),
    selected: readonly(selected),
    isViewMode: readonly(isViewMode),
    loading: readonly(loading),

    // 方法
    showModal,
    closeModal,
    edit,
    view,
    handleSave,
    handleUpdate,
    handleDelete,
    handleBatchDelete,
  };
}
