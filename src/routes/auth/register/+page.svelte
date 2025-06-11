<script lang="ts">
import { createForm } from 'felte';
import { validator } from '@felte/validator-zod';
import { RegisterSchema } from '$lib/schema/auth';
import { register } from '$lib/api/auth';
import { goto } from '$app/navigation';
import FormInput from '@/components/common/FormInput.svelte';

let rememberMe = false;
let success = false;

const { form, errors, isSubmitting } = createForm({
  extend: validator({ schema: RegisterSchema }),
  onSubmit: async (values) => {
    try {
      await register(values, rememberMe);
      success = true;
      goto('/todo');
    } catch (e) {
      alert((e as Error)?.message ?? '注册失败');
    }
  },
});
</script>

<div class="flex flex-col items-center justify-center min-h-screen bg-gray-100 dark:bg-gray-900">
  <div class="w-full max-w-sm p-6 space-y-6 bg-white dark:bg-gray-800 rounded-lg shadow-md">
    <h2 class="text-3xl font-bold text-center text-gray-900 dark:text-white">注册</h2>

    <form use:form class="flex flex-col gap-4">
      <FormInput name="username" placeholder="用户名" errors={$errors} />
      <FormInput name="email" placeholder="邮箱" errors={$errors} />
      <FormInput name="password" type="password" placeholder="密码" errors={$errors} />
      <FormInput name="code" placeholder="验证码" errors={$errors} />

      <button
        type="submit"
        class="w-full py-2 rounded-lg bg-gradient-to-r from-blue-500 to-indigo-600 text-white font-semibold shadow-md hover:brightness-110 transition duration-200"
        disabled={$isSubmitting}
      >
        {$isSubmitting ? '注册中...' : '注册'}
      </button>
    </form>

    <p class="text-center">
      已有账号？
      <a href="/auth/login" class="text-blue-600 hover:underline">登录</a>
    </p>

    {#if success}
      <p class="text-green-600 font-semibold text-center select-text">注册成功！欢迎加入。</p>
    {/if}
  </div>
</div>
