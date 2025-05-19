import { useState } from 'react';

export default function LoginPage() {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');

  const handleLogin = () => {
    alert(`登录：${username} / ${password}`);
    // TODO: 调用 auth store 登录逻辑
  };

  return (
    <div className="p-4 space-y-4 max-w-sm mx-auto">
      <h1 className="text-xl font-bold">登录</h1>
      <input
        className="border px-2 py-1 w-full rounded"
        placeholder="用户名"
        value={username}
        onChange={(e) => setUsername(e.target.value)}
      />
      <input
        className="border px-2 py-1 w-full rounded"
        type="password"
        placeholder="密码"
        value={password}
        onChange={(e) => setPassword(e.target.value)}
      />
      <button
        type="button"
        className="bg-blue-500 text-white px-4 py-2 rounded"
        onClick={handleLogin}
      >
        登录
      </button>
    </div>
  );
}
