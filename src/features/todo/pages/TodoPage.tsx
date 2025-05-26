import { useState } from 'react';
import { invoke } from '@tauri-apps/api/core';

export default function TodoPage() {
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [code, setCode] = useState('');
  const [registerResult, setRegisterResult] = useState<string | null>(null);
  const [registerError, setRegisterError] = useState<string | null>(null);

  const register = async () => {
    setRegisterError(null);
    try {
      const payload = { name, email, password, code };
      const user = await invoke('register', { payload });
      setRegisterResult(JSON.stringify(user, null, 2));
    } catch (error) {
      console.error('注册失败', error);
      if (typeof error === 'object' && error !== null) {
        setRegisterError(JSON.stringify(error, null, 2));
      } else {
        setRegisterError(String(error));
      }
    }
  };

  return (
    <div className="flex justify-center items-center min-h-screen bg-gray-100 dark:bg-gray-900 p-4">
      <div className="w-full max-w-md bg-white dark:bg-gray-800 p-6 rounded-2xl shadow-xl space-y-6">
        <h1 className="text-2xl font-bold text-center text-gray-800 dark:text-gray-100">
          📝 注册账户
        </h1>

        <div className="space-y-4">
          <input
            placeholder="用户名"
            value={name}
            onChange={(e) => setName(e.target.value)}
            className="w-full px-4 py-2 rounded-lg border border-gray-300 dark:border-gray-600 bg-gray-50 dark:bg-gray-700 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
          <input
            placeholder="邮箱"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className="w-full px-4 py-2 rounded-lg border border-gray-300 dark:border-gray-600 bg-gray-50 dark:bg-gray-700 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
          <input
            placeholder="密码"
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            className="w-full px-4 py-2 rounded-lg border border-gray-300 dark:border-gray-600 bg-gray-50 dark:bg-gray-700 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
          <input
            placeholder="验证码"
            value={code}
            onChange={(e) => setCode(e.target.value)}
            className="w-full px-4 py-2 rounded-lg border border-gray-300 dark:border-gray-600 bg-gray-50 dark:bg-gray-700 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>

        <button
          type="button"
          onClick={register}
          className="w-full py-2 rounded-lg bg-gradient-to-r from-blue-500 to-indigo-500 hover:brightness-110 text-white font-semibold shadow-md transition duration-200"
        >
          注册
        </button>

        {registerResult && (
          <pre className="mt-4 p-2 bg-green-100 dark:bg-green-900 text-green-700 dark:text-green-200 rounded-lg text-sm overflow-auto">
            {registerResult}
          </pre>
        )}

        {registerError && (
          <pre className="mt-4 p-2 bg-red-100 dark:bg-red-900 text-red-700 dark:text-red-200 rounded-lg text-sm overflow-auto">
            {registerError}
          </pre>
        )}
      </div>
    </div>
  );
}
