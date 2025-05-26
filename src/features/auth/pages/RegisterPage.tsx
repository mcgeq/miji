import { useState, useCallback } from 'react';
import { invoke } from '@tauri-apps/api/core';
import { Link } from '@tanstack/react-router';
import { useAuthStore } from '../store';

export default function RegisterPage() {
  const [form, setForm] = useState({
    name: '',
    email: '',
    password: '',
    code: '',
  });
  const [rememberMe, setRememberMe] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [success, setSuccess] = useState(false);

  const setAuth = useAuthStore((s) => s.setAuth);

  const handleChange = useCallback((key: keyof typeof form, value: string) => {
    setForm((f) => ({ ...f, [key]: value }));
  }, []);

  const validate = () => {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!form.name.trim()) return '请输入名称';
    if (!emailRegex.test(form.email)) return '邮箱格式不正确';
    if (form.password.length < 6) return '密码至少 6 位';
    return null;
  };

  const handleRegister = async () => {
    setError(null);
    setSuccess(false);
    const msg = validate();
    if (msg) return setError(msg);

    setLoading(true);
    try {
      const user = await invoke('register', { payload: { ...form } });
      setAuth((user as any).token, user, rememberMe);
      setSuccess(true);
    } catch (err) {
      console.error(err);
      if (typeof err === 'string') {
        setError(err);
      } else if (err instanceof Error) {
        setError(err.message);
      } else {
        setError('注册失败');
      }
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
        注册账号
      </h2>

      <input
        className="
          w-full px-4 py-2 rounded-lg border border-gray-300 dark:border-gray-600
          bg-gray-50 dark:bg-gray-700
          text-gray-900 dark:text-white
          focus:outline-none focus:ring-2 focus:ring-blue-500
          disabled:opacity-50 disabled:cursor-not-allowed
        "
        placeholder="用户名"
        value={form.name}
        onChange={(e) => handleChange('name', e.target.value)}
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
        placeholder="邮箱"
        value={form.email}
        onChange={(e) => handleChange('email', e.target.value)}
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
        value={form.password}
        onChange={(e) => handleChange('password', e.target.value)}
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
        value={form.code}
        onChange={(e) => handleChange('code', e.target.value)}
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
        onClick={handleRegister}
        disabled={loading}
      >
        {loading ? '注册中...' : '注册'}
      </button>

      <Link
        to="/login"
        className="block text-center text-blue-600 hover:underline"
      >
        已有账号？点击登录
      </Link>

      {error && (
        <p className="text-center text-red-600 font-semibold select-text">
          {error}
        </p>
      )}

      {success && (
        <p className="text-center text-green-600 font-semibold select-text">
          注册成功！欢迎加入。
        </p>
      )}
    </div>
  );
}
