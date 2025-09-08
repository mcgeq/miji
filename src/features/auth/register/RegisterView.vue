<script lang="ts" setup>
import { toTypedSchema } from '@vee-validate/zod';
import { useField, useForm } from 'vee-validate';
import { useRouter } from 'vue-router';
import { RegisterSchema } from '@/schema/auth';
import { register } from '@/services/auth';
import { Lg } from '@/utils/debugLog';
import { toast } from '@/utils/toast';

const router = useRouter();
const { t } = useI18n();

const rememberMe = ref(false);
const success = ref(false);

const validationSchema = toTypedSchema(RegisterSchema);

const { handleSubmit, errors, isSubmitting } = useForm({
  validationSchema,
});

const { value: username } = useField('username');
const { value: email } = useField('email');
const { value: password } = useField('password');
const { value: code } = useField('code');

const onSubmit = handleSubmit(async values => {
  try {
    await register({ ...values, code: values.code ?? '' }, rememberMe.value);
    success.value = true;
    router.push('/todos');
  } catch (e) {
    toast.error(t('registerFailed'));
    Lg.e('register', e, 'error');
  }
});
</script>

<template>
  <div class="px-4 bg-gray-100 flex min-h-screen items-center justify-center dark:bg-gray-900">
    <div
      class="p-6 border border-gray-200 rounded-xl bg-white/90 max-w-md w-full shadow-lg backdrop-blur-xl space-y-6 sm:p-8 dark:border-gray-700 dark:bg-gray-800/80"
    >
      <h2 class="text-3xl text-gray-900 tracking-tight font-bold text-center dark:text-white">
        {{ t('auth.register') }}
      </h2>

      <form class="space-y-4" @submit.prevent="onSubmit">
        <div>
          <input v-model="username" name="username" type="text" :placeholder="t('auth.username')" class="input">
          <p v-if="errors.username" class="text-sm text-red-600 mt-1">
            {{ errors.username }}
          </p>
        </div>

        <div>
          <input v-model="email" name="email" type="email" :placeholder="t('auth.email')" class="input">
          <p v-if="errors.email" class="text-sm text-red-600 mt-1">
            {{ errors.email }}
          </p>
        </div>

        <div>
          <input v-model="password" name="password" type="password" :placeholder="t('auth.password')" class="input">
          <p v-if="errors.password" class="text-sm text-red-600 mt-1">
            {{ errors.password }}
          </p>
        </div>

        <div>
          <input v-model="code" name="code" type="text" :placeholder="t('auth.code')" class="input">
          <p v-if="errors.code" class="text-sm text-red-600 mt-1">
            {{ errors.code }}
          </p>
        </div>

        <button
          type="submit" :disabled="isSubmitting"
          class="bg-gradient-to-r text-white font-semibold px-4 py-2 rounded-md w-full shadow-md transition-all from-blue-600 to-indigo-600 disabled:opacity-50 disabled:cursor-not-allowed hover:brightness-110"
          style="color: white !important; background: linear-gradient(to right, #2563eb, #4f46e5);"
        >
          <template v-if="isSubmitting">
            {{ t('auth.loading.registering') }}
          </template>
          <template v-else>
            {{ t('auth.register') }}
          </template>
        </button>
      </form>

      <p class="text-sm text-gray-600 text-center dark:text-gray-400">
        {{ t('auth.haveAccount') }}
        <router-link to="/auth/login" class="text-blue-600 font-medium ml-1 dark:text-blue-400 hover:underline">
          {{ t('auth.login') }}
        </router-link>
      </p>

      <p v-if="success" class="text-sm text-green-600 font-semibold text-center select-text">
        {{ t('auth.messages.registerSuccess') }}
      </p>
    </div>
  </div>
</template>

<style scoped>
.input {
  width: 100%;
  padding: 0.5rem 0.75rem;
  border: 1px solid #d1d5db;
  border-radius: 0.375rem;
  font-size: 1rem;
  color: #374151;
  background-color: white;
}

.input:focus {
  outline: none;
  border-color: #2563eb;
  box-shadow: 0 0 0 3px rgb(59 130 246 / 0.5);
}
</style>
