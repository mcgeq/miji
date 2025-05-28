import { useState } from 'react';
import { invoke } from '@tauri-apps/api/core';
import { Link, useNavigate } from '@tanstack/react-router';
import { useAuthStore } from '../store';
import type { UserDto } from '@/features/common/users/user';

export default function LoginPage() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [code, setCode] = useState('');
  const [rememberMe, setRememberMe] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const setAuth = useAuthStore((s) => s.setAuth);

  const validate = () => {
    if (!email.includes('@')) return '邮箱格式不正确';
    if (password.length < 6) return '密码至少 6 位';
    return null;
  };

  const navigate = useNavigate();

  const handleLogin = async () => {
    setError(null);
    const msg = validate();
    if (msg) return setError(msg);

    setLoading(true);
    try {
      const user = await invoke<UserDto>('login', {
        payload: { email, password, code },
      });
      console.log(user);
      setAuth(user.token, user, rememberMe);
      navigate({ to: '/' });
    } catch (err) {
      console.error(err);
      setError(typeof err === 'string' ? err : '登录失败');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div
      className="
        w-full max-w-sm mx-auto p-6 space-y-6
        bg-white dark:bg-gray-800
        rounded-lg shadow-md
      "
    >
      <h2 className="text-3xl font-bold text-center text-gray-900 dark:text-white">
        登录
      </h2>

      <input
        className="
          w-full px-4 py-2 rounded-lg border border-gray-300 dark:border-gray-600
          bg-gray-50 dark:bg-gray-700
          text-gray-900 dark:text-white
          focus:outline-none focus:ring-2 focus:ring-blue-500
          disabled:opacity-50 disabled:cursor-not-allowed
        "
        placeholder="邮箱"
        value={email}
        onChange={(e) => setEmail(e.target.value)}
        disabled={loading}
      />
      <input
        className="
          w-full px-4 py-2 rounded-lg border border-gray-300 dark:border-gray-600
          bg-gray-50 dark:bg-gray-700
          text-gray-900 dark:text-white
          focus:outline-none focus:ring-2 focus:ring-blue-500
          disabled:opacity-50 disabled:cursor-not-allowed
        "
        placeholder="密码"
        type="password"
        value={password}
        onChange={(e) => setPassword(e.target.value)}
        disabled={loading}
      />
      <input
        className="
          w-full px-4 py-2 rounded-lg border border-gray-300 dark:border-gray-600
          bg-gray-50 dark:bg-gray-700
          text-gray-900 dark:text-white
          focus:outline-none focus:ring-2 focus:ring-blue-500
          disabled:opacity-50 disabled:cursor-not-allowed
        "
        placeholder="验证码"
        value={code}
        onChange={(e) => setCode(e.target.value)}
        disabled={loading}
      />

      <label className="flex items-center gap-2 select-none">
        <input
          type="checkbox"
          checked={rememberMe}
          onChange={(e) => setRememberMe(e.target.checked)}
          disabled={loading}
          className="cursor-pointer"
        />
        记住我
      </label>

      <button
        type="button"
        className="
          w-full py-2 rounded-lg
          bg-gradient-to-r from-blue-500 to-indigo-600
          text-white font-semibold shadow-md
          hover:brightness-110
          transition duration-200
          disabled:opacity-50 disabled:cursor-not-allowed
        "
        onClick={handleLogin}
        disabled={loading}
      >
        {loading ? '登录中...' : '登录'}
      </button>

      <Link
        to="/register"
        className="block text-center text-blue-600 hover:underline"
      >
        没有账号？点击注册
      </Link>

      {error && (
        <p className="text-center text-red-600 font-semibold select-text">
          {error}
        </p>
      )}
    </div>
  );
}
