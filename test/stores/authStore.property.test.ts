/**
 * AuthStore 属性测试
 * 使用 Property-Based Testing 验证架构正确性属性
 * 
 * 测试的属性:
 * - 属性 5: Store 使用 Composition API
 * - 属性 16: Store 使用 ref/reactive
 * - 属性 17: Store actions 是 async
 * - 属性 18: Store 使用 withLoadingSafe
 * - 属性 19: Store 提供 $reset
 * - 属性 28: Store 捕获并存储错误
 */

import { describe, it, expect, beforeEach, vi, afterEach } from 'vitest';
import * as fc from 'fast-check';
import { setActivePinia, createPinia } from 'pinia';

describe('AuthStore Property Tests', () => {
  beforeEach(async () => {
    vi.resetModules();
    setActivePinia(createPinia());
    vi.clearAllMocks();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  /**
   * 属性 5: Store 使用 Composition API
   * Feature: architecture-refactor, Property 5: Store 使用 Composition API
   * Validates: Requirements 8.1
   * 
   * 对于任何新创建或重构的 Store，应该使用 Composition API 风格（setup 函数）而不是 Options API。
   */
  it('Property 5: Store uses Composition API', async () => {
    // 不需要 mock，直接导入真实的 Store
    vi.unmock('@/stores/auth');
    vi.unmock('@/services/authService');
    
    const { useAuthStore } = await import('@/stores/auth');
    
    // 创建 Store 实例
    const store = useAuthStore();
    
    // 验证 Store 使用 Composition API（返回的是对象，包含响应式状态和方法）
    expect(typeof store).toBe('object');
    expect(store).not.toBeNull();
    
    // 验证 Store 有预期的状态和方法
    expect(store).toHaveProperty('user');
    expect(store).toHaveProperty('token');
    expect(store).toHaveProperty('isLoading');
    expect(store).toHaveProperty('error');
    expect(store).toHaveProperty('login');
    expect(store).toHaveProperty('logout');
    expect(store).toHaveProperty('$reset');
    
    // Composition API Store 应该有 $id 属性
    expect(store).toHaveProperty('$id');
    expect(store.$id).toBe('auth');
  });

  /**
   * 属性 16: Store 使用 ref/reactive
   * Feature: architecture-refactor, Property 16: Store 使用 ref/reactive
   * Validates: Requirements 8.2
   * 
   * 对于任何 Store 中的状态，应该使用 ref 或 reactive 声明为响应式状态。
   */
  it('Property 16: Store uses ref/reactive', async () => {
    vi.unmock('@/stores/auth');
    vi.unmock('@/services/authService');
    
    const { useAuthStore } = await import('@/stores/auth');
    
    const store = useAuthStore();
    
    // 验证状态是响应式的（通过检查是否可以被观察）
    // 在 Pinia 中，所有状态都会被自动转换为响应式
    expect(store.user).toBeDefined();
    expect(store.token).toBeDefined();
    expect(store.isLoading).toBeDefined();
    expect(store.error).toBeDefined();
    
    // 验证状态可以被修改并触发响应式更新
    const initialUser = store.user;
    store.user = { serialNum: 'test' } as any;
    expect(store.user).not.toBe(initialUser);
    expect(store.user?.serialNum).toBe('test');
  });

  /**
   * 属性 17: Store actions 是 async
   * Feature: architecture-refactor, Property 17: Store actions 是 async
   * Validates: Requirements 8.3
   * 
   * 对于任何 Store 中的异步操作，应该定义为 async 函数。
   */
  it('Property 17: Store actions are async', async () => {
    // Mock authService
    vi.doMock('@/services/authService', () => ({
      authService: {
        login: vi.fn(),
        register: vi.fn(),
        logout: vi.fn(),
        refreshToken: vi.fn(),
        verifyToken: vi.fn(),
        updateUser: vi.fn(),
      },
    }));

    const { useAuthStore } = await import('@/stores/auth');
    const { authService } = await import('@/services/authService');
    
    const store = useAuthStore();
    
    // 验证主要的 actions 返回 Promise
    expect(store.login).toBeInstanceOf(Function);
    expect(store.logout).toBeInstanceOf(Function);
    expect(store.refreshToken).toBeInstanceOf(Function);
    expect(store.updateUser).toBeInstanceOf(Function);
    
    // 验证调用 action 返回 Promise
    vi.mocked(authService.logout).mockResolvedValue();
    const logoutResult = store.logout();
    expect(logoutResult).toBeInstanceOf(Promise);
    
    await logoutResult;
  });

  /**
   * 属性 18: Store 使用 withLoadingSafe
   * Feature: architecture-refactor, Property 18: Store 使用 withLoadingSafe
   * Validates: Requirements 8.4
   * 
   * 对于任何 Store 中的异步 action，应该使用 withLoadingSafe 包装以管理加载状态。
   */
  it('Property 18: Store uses withLoadingSafe', async () => {
    // Mock authService
    vi.doMock('@/services/authService', () => ({
      authService: {
        login: vi.fn(),
        register: vi.fn(),
        logout: vi.fn(),
        refreshToken: vi.fn(),
        verifyToken: vi.fn(),
        updateUser: vi.fn(),
      },
    }));

    const { useAuthStore } = await import('@/stores/auth');
    const { authService } = await import('@/services/authService');

    await fc.assert(
      fc.asyncProperty(
        fc.integer({ min: 1, max: 10 }),
        async (delay) => {
          const store = useAuthStore();
          store.$reset();
          vi.clearAllMocks();
          
          // Mock logout with delay
          vi.mocked(authService.logout).mockImplementation(() => 
            new Promise(resolve => setTimeout(resolve, delay))
          );
          
          // 验证初始状态
          expect(store.isLoading).toBe(false);
          
          // 调用 action
          const promise = store.logout();
          
          // 验证加载状态被设置
          expect(store.isLoading).toBe(true);
          
          // 等待完成
          await promise;
          
          // 验证加载状态被清除
          expect(store.isLoading).toBe(false);
        }
      ),
      { numRuns: 20 }
    );
  });

  /**
   * 属性 19: Store 提供 $reset
   * Feature: architecture-refactor, Property 19: Store 提供 $reset
   * Validates: Requirements 8.5
   * 
   * 对于任何 Store，应该提供 $reset 方法用于重置状态到初始值。
   */
  it('Property 19: Store provides $reset', async () => {
    vi.unmock('@/stores/auth');
    vi.unmock('@/services/authService');
    
    const { useAuthStore } = await import('@/stores/auth');

    await fc.assert(
      fc.asyncProperty(
        fc.record({
          serialNum: fc.string({ minLength: 1, maxLength: 50 }),
          name: fc.string({ minLength: 1, maxLength: 100 }),
          email: fc.emailAddress(),
        }),
        fc.string({ minLength: 10, maxLength: 100 }),
        async (userData, token) => {
          const store = useAuthStore();
          
          // 设置一些状态
          store.user = userData as any;
          store.token = token;
          store.isLoading = true;
          store.error = { code: 'TEST_ERROR' } as any;
          
          // 验证状态已设置
          expect(store.user).not.toBeNull();
          expect(store.token).not.toBeNull();
          expect(store.isLoading).toBe(true);
          expect(store.error).not.toBeNull();
          
          // 调用 $reset
          store.$reset();
          
          // 验证状态被重置
          expect(store.user).toBeNull();
          expect(store.token).toBeNull();
          expect(store.isLoading).toBe(false);
          expect(store.error).toBeNull();
          expect(store.rememberMe).toBe(false);
          expect(store.tokenExpiresAt).toBeNull();
        }
      ),
      { numRuns: 100 }
    );
  });

  /**
   * 属性 28: Store 捕获并存储错误
   * Feature: architecture-refactor, Property 28: Store 捕获并存储错误
   * Validates: Requirements 6.3
   * 
   * 对于任何 Store action 中的错误，应该捕获并存储到 error 状态中。
   */
  it('Property 28: Store catches and stores errors', async () => {
    // Mock authService
    vi.doMock('@/services/authService', () => ({
      authService: {
        login: vi.fn(),
        register: vi.fn(),
        logout: vi.fn(),
        refreshToken: vi.fn(),
        verifyToken: vi.fn(),
        updateUser: vi.fn(),
      },
    }));

    const { useAuthStore } = await import('@/stores/auth');
    const { authService } = await import('@/services/authService');

    await fc.assert(
      fc.asyncProperty(
        fc.string({ minLength: 1, maxLength: 200 }),
        async (errorMessage) => {
          const store = useAuthStore();
          store.$reset();
          vi.clearAllMocks();
          
          const mockError = new Error(errorMessage);
          vi.mocked(authService.logout).mockRejectedValue(mockError);
          
          // 验证初始错误状态
          expect(store.error).toBeNull();
          
          try {
            await store.logout();
            // 如果没有抛出错误，测试失败
            expect.fail('Should have thrown an error');
          } catch (error) {
            // 验证错误被捕获并存储在 Store 中
            expect(store.error).not.toBeNull();
            expect(store.error?.code).toBe('LOGOUT_FAILED');
            
            // 验证错误被包装为 AppError
            expect(store.error).toHaveProperty('module');
            expect(store.error?.module).toBe('AuthStore');
            expect(store.error).toHaveProperty('timestamp');
          }
        }
      ),
      { numRuns: 50 }
    );
  });

  /**
   * 额外验证：Store actions 管理错误状态
   * 验证成功的操作会清除错误状态
   */
  it('Store actions clear error on success', async () => {
    // Mock authService
    vi.doMock('@/services/authService', () => ({
      authService: {
        login: vi.fn(),
        register: vi.fn(),
        logout: vi.fn(),
        refreshToken: vi.fn(),
        verifyToken: vi.fn(),
        updateUser: vi.fn(),
      },
    }));

    const { useAuthStore } = await import('@/stores/auth');
    const { authService } = await import('@/services/authService');

    await fc.assert(
      fc.asyncProperty(
        fc.string({ minLength: 1, maxLength: 200 }),
        async (errorMessage) => {
          const store = useAuthStore();
          store.$reset();
          vi.clearAllMocks();
          
          // 先设置一个错误
          store.error = { code: 'PREVIOUS_ERROR', message: errorMessage } as any;
          expect(store.error).not.toBeNull();
          
          // 执行成功的操作
          vi.mocked(authService.logout).mockResolvedValue();
          await store.logout();
          
          // 验证错误被清除（withLoadingSafe 会在操作开始时清除错误）
          expect(store.error).toBeNull();
        }
      ),
      { numRuns: 50 }
    );
  });

  /**
   * 额外验证：Store 计算属性是响应式的
   * 验证计算属性会根据状态变化自动更新
   */
  it('Store computed properties are reactive', async () => {
    vi.unmock('@/stores/auth');
    vi.unmock('@/services/authService');
    
    const { useAuthStore } = await import('@/stores/auth');

    await fc.assert(
      fc.asyncProperty(
        fc.record({
          serialNum: fc.string({ minLength: 1, maxLength: 50 }),
          name: fc.string({ minLength: 1, maxLength: 100 }),
          email: fc.emailAddress(),
        }),
        fc.string({ minLength: 10, maxLength: 100 }),
        async (userData, token) => {
          const store = useAuthStore();
          store.$reset();
          
          // 验证初始状态
          expect(store.isAuthenticated).toBe(false);
          
          // 设置用户和 token
          store.user = userData as any;
          store.token = token;
          
          // 验证计算属性自动更新
          expect(store.isAuthenticated).toBe(true);
          
          // 清除 token
          store.token = null;
          
          // 验证计算属性再次更新
          expect(store.isAuthenticated).toBe(false);
        }
      ),
      { numRuns: 100 }
    );
  });
});
