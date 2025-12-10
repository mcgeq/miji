import { AppError } from '@/errors/appError';
import { Lg } from '@/utils/debugLog';
import { toast } from '@/utils/toast';

// ==================== Constants ====================
const COMPOSABLE_MODULE = 'useCrudActions';

// ==================== Error Codes ====================
export enum CrudActionErrorCode {
  CREATE_FAILED = 'CREATE_FAILED',
  UPDATE_FAILED = 'UPDATE_FAILED',
  DELETE_FAILED = 'DELETE_FAILED',
  BATCH_DELETE_FAILED = 'BATCH_DELETE_FAILED',
  BATCH_UPDATE_FAILED = 'BATCH_UPDATE_FAILED',
  OPTIMISTIC_UPDATE_ROLLBACK = 'OPTIMISTIC_UPDATE_ROLLBACK',
}

/**
 * CRUD 操作的 Store 接口
 */
export interface CrudStore<T, C, U> {
  create: (data: C) => Promise<T>;
  update: (id: string, data: U) => Promise<T>;
  delete: (id: string) => Promise<void>;
  fetchAll?: () => Promise<void>;
  /** 可选：获取单个项目 */
  getById?: (id: string) => T | undefined;
}

/**
 * 批量操作结果
 */
export interface BatchOperationResult<T = void> {
  /** 成功的项目 */
  succeeded: { id: string; result?: T }[];
  /** 失败的项目 */
  failed: { id: string; error: Error }[];
  /** 是否全部成功 */
  allSucceeded: boolean;
}

/**
 * 乐观更新配置
 */
export interface OptimisticUpdateConfig<T> {
  /** 是否启用乐观更新 */
  enabled: boolean;
  /** 获取当前项目状态（用于回滚） */
  getCurrentState?: () => T | null;
  /** 应用乐观更新 */
  applyOptimistic?: (data: Partial<T>) => void;
  /** 回滚乐观更新 */
  rollback?: (previousState: T) => void;
}

/**
 * CRUD Actions 配置选项
 */
export interface CrudActionsOptions<T = unknown> {
  /** 成功消息配置 */
  successMessages?: {
    create?: string;
    update?: string;
    delete?: string;
    batchDelete?: string;
    batchUpdate?: string;
  };
  /** 错误消息配置 */
  errorMessages?: {
    create?: string;
    update?: string;
    delete?: string;
    batchDelete?: string;
    batchUpdate?: string;
  };
  /** 是否在操作后自动刷新列表 */
  autoRefresh?: boolean;
  /** 是否在操作后自动关闭模态框 */
  autoClose?: boolean;
  /** 乐观更新配置 */
  optimisticUpdate?: OptimisticUpdateConfig<T>;
  /** 删除前确认回调 */
  onBeforeDelete?: (id: string) => Promise<boolean> | boolean;
  /** 批量删除前确认回调 */
  onBeforeBatchDelete?: (ids: string[]) => Promise<boolean> | boolean;
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
 *     optimisticUpdate: {
 *       enabled: true,
 *       getCurrentState: () => selectedAccount.value,
 *       applyOptimistic: (data) => { selectedAccount.value = { ...selectedAccount.value, ...data }; },
 *       rollback: (prev) => { selectedAccount.value = prev; },
 *     },
 *   }
 * );
 * ```
 */
export function useCrudActions<T extends { serialNum: string }, C = Partial<T>, U = Partial<T>>(
  store: CrudStore<T, C, U>,
  options: CrudActionsOptions<T> = {},
) {
  const {
    successMessages = {},
    errorMessages = {},
    autoRefresh = true,
    autoClose = true,
    optimisticUpdate,
    onBeforeDelete,
    onBeforeBatchDelete,
  } = options;

  // 状态
  const show = ref(false);
  const selected = ref<T | null>(null);
  const isViewMode = ref(false);
  const loading = ref(false);
  const error = ref<AppError | null>(null);

  // ==================== 错误处理 ====================

  /**
   * 统一错误处理
   */
  function handleError(err: unknown, code: CrudActionErrorCode, message: string): AppError {
    const appError = AppError.wrap(COMPOSABLE_MODULE, err, code, message);
    error.value = appError;
    appError.log();
    toast.error(appError.getUserMessage());
    return appError;
  }

  /**
   * 清除错误状态
   */
  function clearError() {
    error.value = null;
  }

  // ==================== 模态框管理 ====================

  /**
   * 显示创建模态框
   */
  function showModal() {
    Lg.d(COMPOSABLE_MODULE, '显示创建模态框');
    show.value = true;
    selected.value = null;
    isViewMode.value = false;
    clearError();
  }

  /**
   * 关闭模态框
   */
  function closeModal() {
    Lg.d(COMPOSABLE_MODULE, '关闭模态框');
    show.value = false;
    selected.value = null;
    isViewMode.value = false;
  }

  /**
   * 编辑项目
   */
  function edit(item: T) {
    Lg.d(COMPOSABLE_MODULE, '编辑项目', { serialNum: item.serialNum });
    selected.value = item;
    show.value = true;
    isViewMode.value = false;
    clearError();
  }

  /**
   * 查看项目详情
   */
  function view(item: T) {
    Lg.d(COMPOSABLE_MODULE, '查看项目', { serialNum: item.serialNum });
    selected.value = item;
    show.value = true;
    isViewMode.value = true;
  }

  // ==================== CRUD 操作 ====================

  /**
   * 创建项目
   */
  async function handleSave(data: C): Promise<T | null> {
    Lg.i(COMPOSABLE_MODULE, '创建项目');
    loading.value = true;
    clearError();

    try {
      const result = await store.create(data);
      toast.success(successMessages.create || '创建成功');
      Lg.i(COMPOSABLE_MODULE, '项目创建成功', { serialNum: result.serialNum });

      if (autoClose) {
        closeModal();
      }

      if (autoRefresh && store.fetchAll) {
        await store.fetchAll();
      }

      return result;
    } catch (err) {
      handleError(err, CrudActionErrorCode.CREATE_FAILED, errorMessages.create || '创建失败');
      return null;
    } finally {
      loading.value = false;
    }
  }

  /**
   * 应用乐观更新，返回之前的状态
   */
  function applyOptimisticUpdate(data: U): T | null {
    if (!(optimisticUpdate?.enabled && optimisticUpdate.getCurrentState)) {
      return null;
    }

    const previousState = optimisticUpdate.getCurrentState();
    if (optimisticUpdate.applyOptimistic) {
      optimisticUpdate.applyOptimistic(data as Partial<T>);
      Lg.d(COMPOSABLE_MODULE, '应用乐观更新');
    }
    return previousState;
  }

  /**
   * 回滚乐观更新
   */
  function rollbackOptimisticUpdate(previousState: T | null, id: string): void {
    if (optimisticUpdate?.enabled && previousState && optimisticUpdate.rollback) {
      optimisticUpdate.rollback(previousState);
      Lg.w(COMPOSABLE_MODULE, '乐观更新回滚', { id });
    }
  }

  /**
   * 更新后的后续处理
   */
  async function handlePostUpdate(): Promise<void> {
    if (autoClose) {
      closeModal();
    }

    if (autoRefresh && store.fetchAll) {
      await store.fetchAll();
    }
  }

  /**
   * 更新项目（支持乐观更新）
   */
  async function handleUpdate(id: string, data: U): Promise<T | null> {
    Lg.i(COMPOSABLE_MODULE, '更新项目', { id });
    loading.value = true;
    clearError();

    // 应用乐观更新
    const previousState = applyOptimisticUpdate(data);

    try {
      const result = await store.update(id, data);
      toast.success(successMessages.update || '更新成功');
      Lg.i(COMPOSABLE_MODULE, '项目更新成功', { id });

      await handlePostUpdate();

      return result;
    } catch (err) {
      rollbackOptimisticUpdate(previousState, id);
      handleError(err, CrudActionErrorCode.UPDATE_FAILED, errorMessages.update || '更新失败');
      return null;
    } finally {
      loading.value = false;
    }
  }

  /**
   * 删除项目
   */
  async function handleDelete(id: string): Promise<boolean> {
    Lg.i(COMPOSABLE_MODULE, '删除项目', { id });

    // 删除前确认
    if (onBeforeDelete) {
      const confirmed = await onBeforeDelete(id);
      if (!confirmed) {
        Lg.d(COMPOSABLE_MODULE, '删除已取消', { id });
        return false;
      }
    }

    loading.value = true;
    clearError();

    try {
      await store.delete(id);
      toast.success(successMessages.delete || '删除成功');
      Lg.i(COMPOSABLE_MODULE, '项目删除成功', { id });

      if (autoRefresh && store.fetchAll) {
        await store.fetchAll();
      }

      return true;
    } catch (err) {
      handleError(err, CrudActionErrorCode.DELETE_FAILED, errorMessages.delete || '删除失败');
      return false;
    } finally {
      loading.value = false;
    }
  }

  // ==================== 批量操作 ====================

  /**
   * 批量删除项目
   */
  async function handleBatchDelete(ids: string[]): Promise<BatchOperationResult> {
    Lg.i(COMPOSABLE_MODULE, '批量删除项目', { count: ids.length });

    // 批量删除前确认
    if (onBeforeBatchDelete) {
      const confirmed = await onBeforeBatchDelete(ids);
      if (!confirmed) {
        Lg.d(COMPOSABLE_MODULE, '批量删除已取消');
        return { succeeded: [], failed: [], allSucceeded: false };
      }
    }

    loading.value = true;
    clearError();

    const result: BatchOperationResult = {
      succeeded: [],
      failed: [],
      allSucceeded: false,
    };

    // 并行执行删除，收集结果
    const operations = ids.map(async id => {
      try {
        await store.delete(id);
        result.succeeded.push({ id });
      } catch (err) {
        result.failed.push({
          id,
          error: err instanceof Error ? err : new Error(String(err)),
        });
      }
    });

    await Promise.all(operations);

    result.allSucceeded = result.failed.length === 0;

    // 显示结果消息
    if (result.allSucceeded) {
      toast.success(successMessages.batchDelete || `成功删除 ${ids.length} 项`);
      Lg.i(COMPOSABLE_MODULE, '批量删除成功', { count: ids.length });
    } else if (result.succeeded.length > 0) {
      toast.warning(`删除完成：${result.succeeded.length} 成功，${result.failed.length} 失败`);
      Lg.w(COMPOSABLE_MODULE, '批量删除部分成功', {
        succeeded: result.succeeded.length,
        failed: result.failed.length,
      });
    } else {
      handleError(
        new Error('所有删除操作都失败了'),
        CrudActionErrorCode.BATCH_DELETE_FAILED,
        errorMessages.batchDelete || '批量删除失败',
      );
    }

    if (autoRefresh && store.fetchAll && result.succeeded.length > 0) {
      await store.fetchAll();
    }

    loading.value = false;
    return result;
  }

  /**
   * 批量更新项目
   */
  async function handleBatchUpdate(
    updates: Array<{ id: string; data: U }>,
  ): Promise<BatchOperationResult<T>> {
    Lg.i(COMPOSABLE_MODULE, '批量更新项目', { count: updates.length });
    loading.value = true;
    clearError();

    const result: BatchOperationResult<T> = {
      succeeded: [],
      failed: [],
      allSucceeded: false,
    };

    // 并行执行更新，收集结果
    const operations = updates.map(async ({ id, data }) => {
      try {
        const updated = await store.update(id, data);
        result.succeeded.push({ id, result: updated });
      } catch (err) {
        result.failed.push({
          id,
          error: err instanceof Error ? err : new Error(String(err)),
        });
      }
    });

    await Promise.all(operations);

    result.allSucceeded = result.failed.length === 0;

    // 显示结果消息
    if (result.allSucceeded) {
      toast.success(successMessages.batchUpdate || `成功更新 ${updates.length} 项`);
      Lg.i(COMPOSABLE_MODULE, '批量更新成功', { count: updates.length });
    } else if (result.succeeded.length > 0) {
      toast.warning(`更新完成：${result.succeeded.length} 成功，${result.failed.length} 失败`);
      Lg.w(COMPOSABLE_MODULE, '批量更新部分成功', {
        succeeded: result.succeeded.length,
        failed: result.failed.length,
      });
    } else {
      handleError(
        new Error('所有更新操作都失败了'),
        CrudActionErrorCode.BATCH_UPDATE_FAILED,
        errorMessages.batchUpdate || '批量更新失败',
      );
    }

    if (autoRefresh && store.fetchAll && result.succeeded.length > 0) {
      await store.fetchAll();
    }

    loading.value = false;
    return result;
  }

  // ==================== 工具方法 ====================

  /**
   * 检查是否为编辑模式
   */
  const isEditMode = computed(() => selected.value !== null && !isViewMode.value);

  /**
   * 检查是否为创建模式
   */
  const isCreateMode = computed(() => selected.value === null && show.value);

  /**
   * 获取当前选中项目的 ID
   */
  const selectedId = computed(() => selected.value?.serialNum ?? null);

  return {
    // 状态
    show: readonly(show),
    selected: readonly(selected),
    isViewMode: readonly(isViewMode),
    loading: readonly(loading),
    error: readonly(error),

    // 计算属性
    isEditMode,
    isCreateMode,
    selectedId,

    // 模态框方法
    showModal,
    closeModal,
    edit,
    view,

    // CRUD 方法
    handleSave,
    handleUpdate,
    handleDelete,

    // 批量操作方法
    handleBatchDelete,
    handleBatchUpdate,

    // 工具方法
    clearError,
  };
}
