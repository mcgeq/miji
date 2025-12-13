/**
 * AuthStore 单元测试
 * 测试 Store actions、错误处理和 $reset 方法
 */

import { describe, it, expect, beforeEach, vi } from 'vitest';
import { setActivePinia, createPinia } from 'pinia';
import { useAuthStore } from '@/stores/auth';
import { authService } from '@/services/authService';
import type { User, TokenResponse } from '@/schema/user';
import { TokenStatus } from '@/schema/user';

// Mock authService
vi.mock('@/services/authService', () => ({
  authService: {
    login: vi.fn(),
    register: vi.fn(),
    logout: vi.fn(),
    refreshToken: vi.fn(),
    verifyToken: vi.fn(),
    updateUser: vi.fn(),
  },
}));

// Mock auth-audit
vi.mock('@/utils/auth-audit', () => ({
  authAudit: {
    logLogin: vi.fn(),
    logLogout: vi.fn(),
    logPermissionGranted: vi.fn(),
    logPermissionDenied: vi.fn(),
  },
}));

// Mock router guards
vi.mock('@/router/guards/auth.guard', () => ({
  clearAuthCache: vi.fn(),
}));

describe('AuthStore', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
  });

  const mockUser: User = {
    serialNum: 'user-1',
    name: 'Test User',
    email: 'test@example.com',
    password: 'hashed-password',
    phone: null,
    avatarUrl: null,
    isVerified: true,
    role: 'User',
    status: 'Active',
    bio: null,
    language: 'en',
    timezone: 'UTC',
    createdAt: '2025-01-01T00:00:00Z',
    updatedAt: '2025-01-01T00:00:00Z',
    lastLoginAt: '2025-01-01T00:00:00Z',
    lastActiveAt: null,
    emailVerifiedAt: null,
  };

  const mockTokenResponse: TokenResponse = {
    token: 'test-token-123',
    expiresAt: Math.floor(Date.now() / 1000) + 3600, // 1 hour from now
  };

  describe('login', () => {
    it('should login successfully with token', async () => {
      const store = useAuthStore();
      vi.mocked(authService.verifyToken).mockResolvedValue(TokenStatus.Valid);

      await store.login(mockUser, mockTokenResponse, false);

      expect(store.user).not.toBeNull();
      expect(store.user?.serialNum).toBe('user-1');
      expect(store.token).toBe('test-token-123');
      expect(store.rememberMe).toBe(false);
      expect(store.isAuthenticated).toBe(true);
      expect(store.error).toBeNull();
    });

    it('should login with remember me', async () => {
      const store = useAuthStore();
      vi.mocked(authService.verifyToken).mockResolvedValue(TokenStatus.Valid);

      await store.login(mockUser, mockTokenResponse, true);

      expect(store.rememberMe).toBe(true);
      expect(store.tokenExpiresAt).toBe(mockTokenResponse.expiresAt);
    });

    it('should handle invalid token on login', async () => {
      const store = useAuthStore();
      vi.mocked(authService.verifyToken).mockResolvedValue(TokenStatus.Invalid);

      await expect(store.login(mockUser, mockTokenResponse, false)).rejects.toThrow();
      expect(store.error).not.toBeNull();
    });

    it('should handle login error', async () => {
      const store = useAuthStore();
      const mockError = new Error('Login failed');
      vi.mocked(authService.verifyToken).mockRejectedValue(mockError);

      await expect(store.login(mockUser, mockTokenResponse, false)).rejects.toThrow();
      expect(store.error).not.toBeNull();
      expect(store.error?.code).toBe('LOGIN_FAILED');
    });
  });

  describe('logout', () => {
    it('should logout successfully', async () => {
      const store = useAuthStore();
      // Setup logged in state directly
      store.user = mockUser as any;
      store.token = 'test-token';
      vi.mocked(authService.logout).mockResolvedValue();

      await store.logout();

      expect(authService.logout).toHaveBeenCalledOnce();
      expect(store.user).toBeNull();
      expect(store.token).toBeNull();
      expect(store.tokenExpiresAt).toBeNull();
      expect(store.rememberMe).toBe(false);
      expect(store.isAuthenticated).toBe(false);
    });

    it('should handle logout error', async () => {
      const store = useAuthStore();
      const mockError = new Error('Logout failed');
      vi.mocked(authService.logout).mockRejectedValue(mockError);

      await expect(store.logout()).rejects.toThrow();
      expect(store.error).not.toBeNull();
      expect(store.error?.code).toBe('LOGOUT_FAILED');
    });
  });

  describe('refreshToken', () => {
    it('should refresh token successfully', async () => {
      const store = useAuthStore();
      // Setup logged in state
      store.user = mockUser as any;
      store.token = 'old-token';
      
      const newTokenResponse: TokenResponse = {
        token: 'new-token-456',
        expiresAt: Math.floor(Date.now() / 1000) + 7200,
      };
      vi.mocked(authService.refreshToken).mockResolvedValue(newTokenResponse);

      await store.refreshToken();

      expect(authService.refreshToken).toHaveBeenCalledWith('old-token');
      expect(store.token).toBe('new-token-456');
      expect(store.tokenExpiresAt).toBe(newTokenResponse.expiresAt);
      expect(store.error).toBeNull();
    });

    it('should throw error if no token available', async () => {
      const store = useAuthStore();
      store.user = mockUser as any;
      store.token = null;

      await expect(store.refreshToken()).rejects.toThrow();
    });

    it('should throw error if no user available', async () => {
      const store = useAuthStore();
      store.user = null;
      store.token = 'test-token';

      await expect(store.refreshToken()).rejects.toThrow();
    });

    it('should handle refresh token error', async () => {
      const store = useAuthStore();
      store.user = mockUser as any;
      store.token = 'old-token';
      
      const mockError = new Error('Refresh failed');
      vi.mocked(authService.refreshToken).mockRejectedValue(mockError);

      await expect(store.refreshToken()).rejects.toThrow();
      expect(store.error).not.toBeNull();
      expect(store.error?.code).toBe('TOKEN_REFRESH_FAILED');
    });
  });

  describe('updateUser', () => {
    it('should update user info', async () => {
      const store = useAuthStore();
      store.user = mockUser as any;
      
      const updatedUser = { ...mockUser, name: 'Updated Name' };
      vi.mocked(authService.updateUser).mockResolvedValue(updatedUser);

      await store.updateUser({ name: 'Updated Name' });

      expect(authService.updateUser).toHaveBeenCalledWith('user-1', { name: 'Updated Name' });
      expect(store.user?.name).toBe('Updated Name');
      expect(store.error).toBeNull();
    });

    it('should throw error if not authenticated', async () => {
      const store = useAuthStore();
      store.user = null;

      await expect(store.updateUser({ name: 'Updated Name' })).rejects.toThrow();
    });

    it('should handle update user error', async () => {
      const store = useAuthStore();
      store.user = mockUser as any;
      
      const mockError = new Error('Update failed');
      vi.mocked(authService.updateUser).mockRejectedValue(mockError);

      await expect(store.updateUser({ name: 'Updated Name' })).rejects.toThrow();
      expect(store.error).not.toBeNull();
      expect(store.error?.code).toBe('UPDATE_USER_FAILED');
    });
  });

  describe('checkAuthStatus', () => {
    it('should return false if no user or token', async () => {
      const store = useAuthStore();

      const result = await store.checkAuthStatus();

      expect(result).toBe(false);
    });

    it('should return true for valid token', async () => {
      const store = useAuthStore();
      store.user = mockUser as any;
      store.token = 'test-token';
      store.rememberMe = false;
      
      vi.mocked(authService.verifyToken).mockResolvedValue(TokenStatus.Valid);

      const result = await store.checkAuthStatus();

      expect(result).toBe(true);
      expect(authService.verifyToken).toHaveBeenCalledWith('test-token');
    });

    it('should logout and return false for invalid token', async () => {
      const store = useAuthStore();
      store.user = mockUser as any;
      store.token = 'test-token';
      store.rememberMe = false;
      
      vi.mocked(authService.verifyToken).mockResolvedValue(TokenStatus.Invalid);
      vi.mocked(authService.logout).mockResolvedValue();

      const result = await store.checkAuthStatus();

      expect(result).toBe(false);
      expect(store.user).toBeNull();
      expect(store.token).toBeNull();
    });

    it('should handle auth check error', async () => {
      const store = useAuthStore();
      store.user = mockUser as any;
      store.token = 'test-token';
      
      const mockError = new Error('Check failed');
      vi.mocked(authService.verifyToken).mockRejectedValue(mockError);
      vi.mocked(authService.logout).mockResolvedValue();

      const result = await store.checkAuthStatus();

      expect(result).toBe(false);
      // Note: error is cleared by logout, so we just check the result
    });
  });

  describe('$reset', () => {
    it('should reset store to initial state', () => {
      const store = useAuthStore();
      // Setup state directly
      store.user = mockUser as any;
      store.token = 'test-token';
      store.tokenExpiresAt = 123456;
      store.rememberMe = true;
      store.isLoading = true;
      store.error = { code: 'TEST_ERROR' } as any;

      store.$reset();

      expect(store.user).toBeNull();
      expect(store.token).toBeNull();
      expect(store.tokenExpiresAt).toBeNull();
      expect(store.rememberMe).toBe(false);
      expect(store.isLoading).toBe(false);
      expect(store.error).toBeNull();
      expect(store.permissions).toEqual([]);
      expect(store.role).toBe('guest');
    });
  });

  describe('computed properties', () => {
    it('should compute isAuthenticated correctly', async () => {
      const store = useAuthStore();
      expect(store.isAuthenticated).toBe(false);

      vi.mocked(authService.verifyToken).mockResolvedValue(TokenStatus.Valid);
      await store.login(mockUser, mockTokenResponse, false);
      expect(store.isAuthenticated).toBe(true);
    });

    it('should compute isTokenExpired correctly', () => {
      const store = useAuthStore();
      expect(store.isTokenExpired).toBe(false);

      // Set expired token
      store.tokenExpiresAt = Math.floor(Date.now() / 1000) - 3600; // 1 hour ago
      expect(store.isTokenExpired).toBe(true);

      // Set valid token
      store.tokenExpiresAt = Math.floor(Date.now() / 1000) + 3600; // 1 hour from now
      expect(store.isTokenExpired).toBe(false);
    });
  });

  describe('permission checks', () => {
    it('should check hasAnyPermission correctly', async () => {
      const store = useAuthStore();
      vi.mocked(authService.verifyToken).mockResolvedValue(TokenStatus.Valid);
      await store.login(mockUser, mockTokenResponse, false);

      // Should return true for empty permissions
      expect(store.hasAnyPermission([])).toBe(true);
      expect(store.hasAnyPermission()).toBe(true);
    });

    it('should check hasAllPermissions correctly', async () => {
      const store = useAuthStore();
      vi.mocked(authService.verifyToken).mockResolvedValue(TokenStatus.Valid);
      await store.login(mockUser, mockTokenResponse, false);

      // Should return true for empty permissions
      expect(store.hasAllPermissions([])).toBe(true);
      expect(store.hasAllPermissions()).toBe(true);
    });

    it('should check hasAnyRole correctly', async () => {
      const store = useAuthStore();
      vi.mocked(authService.verifyToken).mockResolvedValue(TokenStatus.Valid);
      await store.login(mockUser, mockTokenResponse, false);

      // Should return true for empty roles
      expect(store.hasAnyRole([])).toBe(true);
      expect(store.hasAnyRole()).toBe(true);
    });
  });
});
