<template>
  <div class="min-h-screen flex items-center justify-center bg-gray-100 dark:bg-gray-900 px-4">
    <div
      class="w-full max-w-md p-6 sm:p-8 bg-white/90 dark:bg-gray-800/80 backdrop-blur-xl border border-gray-200 dark:border-gray-700 rounded-xl shadow-lg space-y-6"
    >
      <h2 class="text-center text-3xl font-bold text-gray-900 dark:text-white tracking-tight">
        {{ t('register') }}
      </h2>

      <form @submit.prevent="onSubmit" class="space-y-4">
        <div>
          <input
            v-model="username"
            name="username"
            type="text"
            :placeholder="t('username')"
            class="input"
          />
          <p v-if="errors.username" class="text-red-600 text-sm mt-1">{{ errors.username }}</p>
        </div>

        <div>
          <input
            v-model="email"
            name="email"
            type="email"
            :placeholder="t('email')"
            class="input"
          />
          <p v-if="errors.email" class="text-red-600 text-sm mt-1">{{ errors.email }}</p>
        </div>

        <div>
          <input
            v-model="password"
            name="password"
            type="password"
            :placeholder="t('password')"
            class="input"
          />
          <p v-if="errors.password" class="text-red-600 text-sm mt-1">{{ errors.password }}</p>
        </div>

        <div>
          <input
            v-model="code"
            name="code"
            type="text"
            :placeholder="t('code')"
            class="input"
          />
          <p v-if="errors.code" class="text-red-600 text-sm mt-1">{{ errors.code }}</p>
        </div>

        <button
          type="submit"
          :disabled="isSubmitting"
          class="w-full py-2 px-4 rounded-md bg-gradient-to-r from-blue-600 to-indigo-600 hover:brightness-110 text-white font-semibold shadow-md transition-all disabled:opacity-50 disabled:cursor-not-allowed"
          style="color: white !important; background: linear-gradient(to right, #2563eb, #4f46e5);"
        >
          <template v-if="isSubmitting">
           {{ t('registering') }}
          </template>
          <template v-else>
            {{ t('register') }}
          </template>
        </button>
      </form>

      <p class="text-center text-sm text-gray-600 dark:text-gray-400">
        {{ t('haveAccount') }}
        <router-link to="/auth/login" class="text-blue-600 dark:text-blue-400 hover:underline ml-1 font-medium">
          {{ t('login') }}
        </router-link>
      </p>

      <p v-if="success" class="text-center text-green-600 text-sm font-semibold select-text">
        {{ t('registerSuccess') }}
      </p>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { useRouter } from 'vue-router';
import { useForm, useField } from 'vee-validate';
import { toTypedSchema } from '@vee-validate/zod';
import { Lg } from '@/utils/debugLog';
import { register } from '@/services/auth';
import { toast } from '@/utils/toast';
import { RegisterSchema } from '@/schema/auth';

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

const onSubmit = handleSubmit(async (values) => {
  try {
    await register(values, rememberMe.value);
    success.value = true;
    router.push('/todos');
  } catch (e) {
    toast.error(t('registerFailed'));
    Lg.e('register', e, 'error');
  }
});
</script>

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
