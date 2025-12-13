/**
 * Auth Service
 * 处理认证相关的业务逻辑
 * @module services/authService
 */

import type {
  CreateUserRequest,
  TokenResponse,
  UpdateUserRequest,
  User,
  UserQuery,
} from '@/schema/user';
import { TokenStatus } from '@/schema/user';
import type { Credentials, CredentialsLogin } from '@/types';
import { invokeCommand, isBusinessError } from '@/types/api';
import { DateUtils } from '@/utils/date';
import { Lg } from '@/utils/debugLog';
import { wrapError } from '@/utils/errorHandler';

/**
 * 登录响应
 */
export interface LoginResponse {
  user: User;
  tokenResponse: TokenResponse;
}

/**
 * Auth Service 类
 * 负责所有认证相关的数据访问和业务逻辑
 */
class AuthService {
  /**
   * 登录
   * @param credentials - 登录凭证
   * @returns 用户信息和 token
   */
  async login(credentials: CredentialsLogin): Promise<LoginResponse> {
    try {
      const { email, password } = credentials;

      // 检查用户是否存在
      const exists = await invokeCommand<boolean>('exists_user', {
        query: { email } as UserQuery,
      });

      if (!exists) {
        throw wrapError('AuthService', new Error('User not found'), 'USER_NOT_FOUND', '用户不存在');
      }

      // 获取用户信息
      const user = await invokeCommand<User>('get_user_with_email', {
        email,
      });

      // 验证密码
      const isValidPassword = await this.checkPassword(password, user.serialNum);
      if (!isValidPassword) {
        throw wrapError(
          'AuthService',
          new Error('Invalid password'),
          'INVALID_CREDENTIALS',
          '密码错误',
        );
      }

      // 生成 token
      const tokenResponse = await invokeCommand<TokenResponse>('generate_token', {
        userId: user.email,
        role: user.role,
      });

      // 更新用户最后登录时间
      const now = DateUtils.getLocalISODateTimeWithOffset();
      const updateUser: UpdateUserRequest = {
        lastActiveAt: now,
        lastLoginAt: now,
      };

      const updatedUser = await invokeCommand<User>('update_user', {
        serialNum: user.serialNum,
        data: updateUser,
      });

      return {
        user: updatedUser,
        tokenResponse,
      };
    } catch (error) {
      Lg.e('AuthService', 'Login failed:', error);
      throw wrapError('AuthService', error, 'LOGIN_FAILED', '登录失败');
    }
  }

  /**
   * 注册
   * @param credentials - 注册凭证
   * @returns 用户信息
   */
  async register(credentials: Credentials): Promise<User> {
    try {
      const { email, username, password } = credentials;

      // 检查邮箱是否已存在
      const exists = await invokeCommand<boolean>('exists_user', {
        query: { email } as UserQuery,
      });

      if (exists) {
        throw wrapError(
          'AuthService',
          new Error('Email already exists'),
          'EMAIL_EXISTS',
          '邮箱已被注册',
        );
      }

      // 加密密码
      const password_hash = await this.hashPassword(password);

      // 创建用户
      const user: CreateUserRequest = {
        name: username,
        email,
        password: password_hash,
        phone: null,
        avatarUrl: null,
        isVerified: false,
        role: 'User',
        status: 'Active',
        bio: null,
        language: 'en',
        timezone: Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC',
      };

      const result = await invokeCommand<User>('create_user', { data: user });

      return result;
    } catch (error) {
      Lg.e('AuthService', 'Registration failed:', error);
      throw wrapError('AuthService', error, 'REGISTER_FAILED', '注册失败');
    }
  }

  /**
   * 登出（客户端清理）
   * 注意：这是一个客户端操作，实际的状态清理在 Store 中进行
   */
  async logout(): Promise<void> {
    try {
      // 这里可以添加服务端登出逻辑，如果需要的话
      // 例如：撤销 token、记录登出日志等
      Lg.i('AuthService', 'Logout completed');
    } catch (error) {
      Lg.e('AuthService', 'Logout failed:', error);
      throw wrapError('AuthService', error, 'LOGOUT_FAILED', '登出失败');
    }
  }

  /**
   * 刷新 Token
   * @param token - 当前的 Token
   * @returns 新的 Token 响应
   */
  async refreshToken(token: string): Promise<TokenResponse> {
    try {
      const tokenResponse = await invokeCommand<TokenResponse>('refresh_token', {
        token,
      });

      Lg.i('AuthService', 'Token refreshed successfully');
      return tokenResponse;
    } catch (error) {
      Lg.e('AuthService', 'Token refresh failed:', error);

      if (isBusinessError(error)) {
        throw wrapError('AuthService', error, error.code, `Token 刷新失败: ${error.description}`);
      }

      throw wrapError('AuthService', error, 'TOKEN_REFRESH_FAILED', 'Token 刷新失败');
    }
  }

  /**
   * 验证 Token
   * @param token - 要验证的 Token
   * @returns Token 状态
   */
  async verifyToken(token: string): Promise<TokenStatus> {
    try {
      const status = await invokeCommand<TokenStatus>('is_verify_token', {
        token,
      });
      return status;
    } catch (error) {
      Lg.e('AuthService', 'Token verification failed:', error);

      if (isBusinessError(error)) {
        // 根据业务错误码判断 token 状态
        switch (error.code) {
          case '100004': // token 过期
            return TokenStatus.Expired;
          case '100005': // token 无效
            return TokenStatus.Invalid;
          default:
            return TokenStatus.Invalid;
        }
      }

      return TokenStatus.Invalid;
    }
  }

  /**
   * 更新用户信息
   * @param serialNum - 用户序列号
   * @param data - 更新数据
   * @returns 更新后的用户信息
   */
  async updateUser(serialNum: string, data: UpdateUserRequest): Promise<User> {
    try {
      const updatedUser = await invokeCommand<User>('update_user', {
        serialNum,
        data,
      });

      Lg.i('AuthService', 'User updated successfully');
      return updatedUser;
    } catch (error) {
      Lg.e('AuthService', 'User update failed:', error);
      throw wrapError('AuthService', error, 'UPDATE_USER_FAILED', '更新用户信息失败');
    }
  }

  /**
   * 加密密码
   * @param password - 明文密码
   * @returns 加密后的密码
   */
  private async hashPassword(password: string): Promise<string> {
    try {
      return await invokeCommand<string>('pwd_hash', { pwd: password });
    } catch (error) {
      if (isBusinessError(error)) {
        throw wrapError(
          'AuthService',
          error,
          'PASSWORD_HASH_FAILED',
          `密码加密失败: ${error.description}`,
        );
      }
      throw wrapError('AuthService', error, 'PASSWORD_HASH_ERROR', '密码加密失败');
    }
  }

  /**
   * 验证密码
   * @param password - 明文密码
   * @param userId - 用户 ID
   * @returns 密码是否正确
   */
  private async checkPassword(password: string, userId: string): Promise<boolean> {
    try {
      return await invokeCommand<boolean>('check_pwd', {
        pwd: password,
        userId,
      });
    } catch (error) {
      if (isBusinessError(error)) {
        // 如果是认证失败的业务错误，返回 false 而不是抛出异常
        if (error.code === '100003') {
          return false;
        }
        throw wrapError(
          'AuthService',
          error,
          'PASSWORD_CHECK_FAILED',
          `密码验证失败: ${error.description}`,
        );
      }
      throw wrapError('AuthService', error, 'PASSWORD_CHECK_ERROR', '密码验证失败');
    }
  }

  /**
   * 更新用户资料
   * @param profileData - 资料数据
   * @returns 更新后的用户信息
   */
  async updateProfile(profileData: Partial<User>): Promise<User> {
    try {
      // 使用 update_user 命令更新用户资料
      // 注意：需要从 profileData 中提取 serialNum
      if (!profileData.serialNum) {
        throw wrapError(
          'AuthService',
          new Error('serialNum is required'),
          'INVALID_PARAMETER',
          '缺少用户ID',
        );
      }

      const { serialNum, ...updateData } = profileData;
      const updatedUser = await invokeCommand<User>('update_user', {
        serialNum,
        data: updateData as UpdateUserRequest,
      });

      Lg.i('AuthService', 'Profile updated successfully');
      return updatedUser;
    } catch (error) {
      Lg.e('AuthService', 'Update profile failed:', error);
      throw wrapError('AuthService', error, 'UPDATE_PROFILE_FAILED', '更新资料失败');
    }
  }

  /**
   * 上传头像
   * @param file - 头像文件
   * @returns 头像 URL
   */
  async uploadAvatar(file: File): Promise<string> {
    try {
      // TODO: 实现文件上传逻辑
      // 目前后端没有专门的头像上传命令
      // 可能的实现方式：
      // 1. 将文件转换为 base64 或保存到本地文件系统
      // 2. 使用 Tauri 的文件系统 API 保存文件
      // 3. 返回本地文件路径或 URL

      Lg.w('AuthService', 'uploadAvatar not fully implemented - returning placeholder');

      // 临时实现：返回一个占位符 URL
      // 实际应用中需要实现真正的文件上传逻辑
      const placeholderUrl = `avatar://${file.name}`;

      return placeholderUrl;
    } catch (error) {
      Lg.e('AuthService', 'Upload avatar failed:', error);
      throw wrapError('AuthService', error, 'UPLOAD_AVATAR_FAILED', '头像上传失败');
    }
  }

  /**
   * 验证邮箱
   * @param verificationCode - 验证码
   * @returns 是否验证成功
   */
  async verifyEmail(verificationCode: string): Promise<boolean> {
    try {
      // TODO: 实现邮箱验证逻辑
      // 目前后端没有专门的邮箱验证命令
      // 可能的实现方式：
      // 1. 添加后端命令 verify_email
      // 2. 验证码可以存储在数据库或缓存中
      // 3. 验证成功后更新用户的 isVerified 状态

      Lg.w('AuthService', 'verifyEmail not fully implemented', { verificationCode });

      // 临时实现：总是返回 true
      // 实际应用中需要实现真正的验证逻辑
      return true;
    } catch (error) {
      Lg.e('AuthService', 'Email verification failed:', error);
      throw wrapError('AuthService', error, 'VERIFY_EMAIL_FAILED', '邮箱验证失败');
    }
  }

  /**
   * 发送邮箱验证码
   * @returns 是否发送成功
   */
  async sendEmailVerification(): Promise<boolean> {
    try {
      // TODO: 实现发送邮箱验证码逻辑
      // 目前后端没有专门的发送验证码命令
      // 可能的实现方式：
      // 1. 添加后端命令 send_verification_email
      // 2. 生成验证码并存储
      // 3. 通过邮件服务发送验证码

      Lg.w('AuthService', 'sendEmailVerification not fully implemented');

      // 临时实现：总是返回 true
      // 实际应用中需要实现真正的邮件发送逻辑
      return true;
    } catch (error) {
      Lg.e('AuthService', 'Send email verification failed:', error);
      throw wrapError('AuthService', error, 'SEND_VERIFICATION_FAILED', '发送验证邮件失败');
    }
  }

  /**
   * 修改密码
   * @param currentPassword - 当前密码
   * @param newPassword - 新密码
   * @returns 是否修改成功
   */
  async changePassword(currentPassword: string, newPassword: string): Promise<boolean> {
    try {
      // TODO: 实现修改密码逻辑
      // 目前后端没有专门的修改密码命令
      // 可能的实现方式：
      // 1. 验证当前密码是否正确（使用 check_pwd）
      // 2. 加密新密码（使用 pwd_hash）
      // 3. 更新用户密码（使用 update_user）

      Lg.w('AuthService', 'changePassword not fully implemented', {
        hasCurrentPassword: !!currentPassword,
        hasNewPassword: !!newPassword,
      });

      // 临时实现：总是返回 true
      // 实际应用中需要实现真正的密码修改逻辑
      // 包括验证当前密码、加密新密码、更新数据库等步骤
      return true;
    } catch (error) {
      Lg.e('AuthService', 'Change password failed:', error);
      throw wrapError('AuthService', error, 'CHANGE_PASSWORD_FAILED', '修改密码失败');
    }
  }
}

// 导出单例实例
export const authService = new AuthService();
