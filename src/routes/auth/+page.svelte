<!-- src/routes/auth/+page.svelte -->
<script lang="ts">
import { login, register } from '$lib/api/auth';
import { goto } from '$app/navigation';
import type { Credentials } from '@/types';
import { LoginSchema, RegisterSchema } from '$lib/schema/auth';

let isLoginMode = $state(true);
let form = $state({
  username: '',
  email: '',
  password: '',
  code: '',
});
let rememberMe = $state(false);
let error = $state('');
let loading = $state(false);
let success = $state(false);

function validate() {
  const schema = isLoginMode ? LoginSchema : RegisterSchema;
  const data = isLoginMode
    ? { email: form.email, password: form.password }
    : {
        username: form.username,
        email: form.email,
        password: form.password,
        code: form.code,
      };

  const result = schema.safeParse(data);
  if (!result.success) {
    return result.error.errors[0].message; // Return the first error message
  }
  return '';
}

async function handleSubmit(event: Event) {
  event.preventDefault();
  error = '';
  success = false;

  const msg = validate();
  if (msg) {
    error = msg;
    return;
  }

  loading = true;
  try {
    const credentials: Credentials = {
      username: isLoginMode ? form.email : form.username,
      email: form.email,
      password: form.password,
      code: form.code,
    };
    if (isLoginMode) {
      await login(credentials);
    } else {
      await register(credentials, rememberMe);
    }
    success = true;
    goto('/todo');
  } catch (err) {
    console.error(err);
    error =
      typeof err === 'string'
        ? err
        : (err as Error)?.message || (isLoginMode ? '登录失败' : '注册失败');
  } finally {
    loading = false;
  }
}

function toggleMode() {
  isLoginMode = !isLoginMode;
  error = '';
  success = false;
}
</script>

<div class="flex flex-col items-center justify-center min-h-screen bg-gray-100 dark:bg-gray-900">
  <div class="w-full max-w-sm p-6 space-y-6 bg-white dark:bg-gray-800 rounded-lg shadow-md">
    <h2 class="text-3xl font-bold text-center text-gray-900 dark:text-white">
      {isLoginMode ? '登录' : '注册'}
    </h2>

    <form class="flex flex-col gap-4" onsubmit={handleSubmit}>
      {#if !isLoginMode}
        <input
          type="text"
          placeholder="用户名"
          bind:value={form.username}
          class="w-full px-4 py-2 rounded-lg border border-gray-300 dark:border-gray-600 bg-gray-50 dark:bg-gray-700 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500"
          disabled={loading}
          class:op-50={loading}
          class:cursor-not-allowed={loading}
        />
      {/if}

      <input
        type="text"
        placeholder="邮箱"
        bind:value={form.email}
        class="w-full px-4 py-2 rounded-lg border border-gray-300 dark:border-gray-600 bg-gray-50 dark:bg-gray-700 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500"
        disabled={loading}
        class:op-50={loading}
        class:cursor-not-allowed={loading}
      />

      <input
        type="password"
        placeholder="密码"
        bind:value={form.password}
        class="w-full px-4 py-2 rounded-lg border border-gray-300 dark:border-gray-600 bg-gray-50 dark:bg-gray-700 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500"
        disabled={loading}
        class:op-50={loading}
        class:cursor-not-allowed={loading}
      />

      <input
        type="text"
        placeholder="验证码"
        bind:value={form.code}
        class="w-full px-4 py-2 rounded-lg border border-gray-300 dark:border-gray-600 bg-gray-50 dark:bg-gray-700 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500"
        disabled={loading}
        class:op-50={loading}
        class:cursor-not-allowed={loading}
      />
      {#if isLoginMode}
      <label class="flex items-center gap-2 select-none">
        <input
          type="checkbox"
          bind:checked={rememberMe}
          disabled={loading}
          class="cursor-pointer disabled:cursor-not-allowed"
        />
        <span class="text-gray-900 dark:text-white">记住我</span>
      </label>
      {/if}
      <button
        type="submit"
        class="w-full py-2 rounded-lg bg-gradient-to-r from-blue-500 to-indigo-600 text-white font-semibold shadow-md hover:brightness-110 transition duration-200"
        disabled={loading}
        class:op-50={loading}
        class:cursor-not-allowed={loading}
      >
        {loading ? (isLoginMode ? '登录中...' : '注册中...') : (isLoginMode ? '登录' : '注册')}
      </button>
    </form>

    <p class="text-center">
      {isLoginMode ? '没有账号？' : '已有账号？'}
      <button
        class="text-blue-600 hover:underline"
        onclick={toggleMode}
        disabled={loading}
      >
        {isLoginMode ? '注册' : '登录'}
      </button>
    </p>

    {#if error}
      <p class="text-red-600 font-semibold text-center select-text">
        {error}
      </p>
    {/if}

    {#if success}
      <p class="text-green-600 font-semibold text-center select-text">
        {isLoginMode ? '登录成功！' : '注册成功！'}欢迎加入。
      </p>
    {/if}
  </div>
</div>
