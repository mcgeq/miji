<script lang="ts">
import { createForm } from 'felte';
import { validator } from '@felte/validator-zod';
import { RegisterSchema } from '$lib/schema/auth';
import { register } from '$lib/api/auth';
import { goto } from '$app/navigation';
import FormInput from '@/components/common/FormInput.svelte';
import { t } from 'svelte-i18n';

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
      alert((e as Error)?.message ?? $t('registerFailed'));
    }
  },
});
</script>

<div class="min-h-screen flex items-center justify-center bg-gray-100 dark:bg-gray-900 px4">
  <div class="w-full max-w-md p6 sm:p8 bg-white/90 dark:bg-gray-800/80 backdrop-blur-xl border border-gray-200 dark:border-gray-700 rounded-xl shadow-lg space-y-6">
    <h2 class="text-center text-3xl font-bold text-gray-900 dark:text-white tracking-tight">
      {$t('register')}
    </h2>

    <form use:form class="space-y-4">
      <FormInput name="username" placeholder={$t('username')} errors={$errors} />
      <FormInput name="email" placeholder={$t('email')} errors={$errors} />
      <FormInput name="password" type="password" placeholder={$t('password')} errors={$errors} />
      <FormInput name="code" placeholder={$t('code')} errors={$errors} />

      <button
        type="submit"
        class="w-full py2 px4 rounded-md bg-blue-600 hover:bg-blue-700 text-white font-semibold shadow-sm
               disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2 transition-all"
        disabled={$isSubmitting}
      >
        {#if $isSubmitting}
          <div class="i-svg-spinners-ring-resize h5 w5 animate-spin"></div>
          {$t('registering')}
        {:else}
          {$t('register')}
        {/if}
      </button>
    </form>

    <p class="text-center text-sm text-gray-600 dark:text-gray-400">
      {$t('haveAccount')}
      <a href="/auth/login" class="text-blue-600 dark:text-blue-400 hover:underline ml1 font-medium">
        {$t('login')}
      </a>
    </p>

    {#if success}
      <p class="text-center text-green-600 text-sm font-semibold select-text">
        {$t('registerSuccess')}
      </p>
    {/if}
  </div>
</div>
