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

<div class="flex flex-col items-center justify-center min-h-screen bg-gray-100 dark:bg-gray-900">
  <div class="w-full max-w-sm p-6 space-y-6 bg-white dark:bg-gray-800 rounded-lg shadow-md">
    <h2 class="text-3xl font-bold text-center text-gray-900 dark:text-white">{$t('register')}</h2>

    <form use:form class="flex flex-col gap-4">
      <FormInput name="username" placeholder={$t('username')} errors={$errors} />
      <FormInput name="email" placeholder={$t('email')} errors={$errors} />
      <FormInput name="password" type="password" placeholder={$t('password')} errors={$errors} />
      <FormInput name="code" placeholder={$t('code')} errors={$errors} />

      <button
        type="submit"
        class="w-full py-2 rounded-lg bg-gradient-to-r from-blue-500 to-indigo-600 text-white font-semibold shadow-md hover:brightness-110 transition duration-200"
        disabled={$isSubmitting}
      >
        {$isSubmitting ? $t('registering') : $t('register')}
      </button>
    </form>

    <p class="text-center">
      {$t('haveAccount')}
      <a href="/auth/login" class="text-blue-600 hover:underline">{$t('login')}</a>
    </p>

    {#if success}
      <p class="text-green-600 font-semibold text-center select-text">{$t('registerSuccess')}</p>
    {/if}
  </div>
</div>
