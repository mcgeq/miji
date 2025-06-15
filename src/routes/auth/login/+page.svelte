<script lang="ts">
import { createForm } from 'felte';
import { validator } from '@felte/validator-zod';
import { LoginSchema } from '$lib/schema/auth';
import { login } from '$lib/api/auth';
import { goto } from '$app/navigation';
import FormInput from '@/components/common/FormInput.svelte';
import { t } from 'svelte-i18n';
import { toast } from '@/lib/utils/toast';
import { Lg } from '@/lib/utils/debugLog';

let rememberMe = $state(true);
let success = $state(false);

const { form, errors, isSubmitting } = createForm({
  extend: validator({ schema: LoginSchema }),
  onSubmit: async (values) => {
    try {
      await login(values, rememberMe);
      success = true;
      goto('/todos');
    } catch (e) {
      toast.error($t('loginFailed'));
      Lg.e('login', e);
    }
  },
});
</script>

<!-- 页面容器 -->
<div class="min-h-screen flex items-center justify-center bg-gray-100 dark:bg-gray-900 px4">
  <!-- 表单卡片 -->
  <div class="w-full max-w-md p6 sm:p8 bg-white/90 dark:bg-gray-800/80 backdrop-blur-xl border border-gray-200 dark:border-gray-700 rounded-xl shadow-lg space-y-6">
    <!-- 标题 -->
    <h2 class="text-center text-3xl font-bold text-gray-900 dark:text-white tracking-tight">
      {$t('login')}
    </h2>

    <!-- 登录表单 -->
    <form use:form class="space-y-4">
      <FormInput name="email" placeholder={$t('email')} errors={$errors} />
      <FormInput name="password" type="password" placeholder={$t('password')} errors={$errors} />

      <!-- 记住我 -->
      <label class="inline-flex items-center gap-2 text-sm text-gray-800 dark:text-gray-200 cursor-pointer select-none">
        <input
          type="checkbox"
          bind:checked={rememberMe}
          class="accent-blue-600 dark:accent-blue-500 w4 h4"
        />
        <span>{$t('rememberMe')}</span>
      </label>

      <!-- 提交按钮 -->
      <button
        type="submit"
        class="w-full py2 px4 rounded-md bg-gradient-to-r from-blue-600 to-indigo-600 hover:brightness-110 text-white font-semibold shadow-sm transition-all disabled:opacity-50 disabled:cursor-not-allowed"
        disabled={$isSubmitting}
      >
        {$isSubmitting ? $t('loggingIn') : $t('login')}
      </button>
    </form>

    <!-- 注册跳转 -->
    <p class="text-center text-sm text-gray-600 dark:text-gray-400">
      {$t('noAccount')}
      <a href="/auth/register" class="text-blue-600 dark:text-blue-400 hover:underline ml-1 font-medium">
        {$t('register')}
      </a>
    </p>

    <!-- 登录成功提示 -->
    {#if success}
      <p class="text-center text-green-600 text-sm font-semibold select-text">
        {$t('loginSuccess')}
      </p>
    {/if}
  </div>
</div>
