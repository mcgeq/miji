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
  <div class="flex items-center justify-center min-h-screen p-4 bg-gray-50 dark:bg-gray-900">
    <div class="w-full max-w-md p-6 sm:p-8 bg-white dark:bg-gray-800 rounded-2xl border border-gray-200 dark:border-gray-700 shadow-xl backdrop-blur-sm flex flex-col gap-6">
      <!-- 标题 -->
      <h2 class="text-3xl font-bold text-center text-gray-900 dark:text-white tracking-tight">
        {{ t('auth.register') }}
      </h2>

      <!-- 注册表单 -->
      <form class="flex flex-col gap-4" @submit.prevent="onSubmit">
        <div class="flex flex-col">
          <input
            v-model="username"
            name="username"
            type="text"
            :placeholder="t('auth.username')"
            class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg text-gray-900 dark:text-white bg-white dark:bg-gray-800 focus:outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20 transition-all"
          >
          <p v-if="errors.username" class="mt-1 text-sm text-red-600 dark:text-red-400">
            {{ errors.username }}
          </p>
        </div>

        <div class="flex flex-col">
          <input
            v-model="email"
            name="email"
            type="email"
            :placeholder="t('auth.email')"
            class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg text-gray-900 dark:text-white bg-white dark:bg-gray-800 focus:outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20 transition-all"
          >
          <p v-if="errors.email" class="mt-1 text-sm text-red-600 dark:text-red-400">
            {{ errors.email }}
          </p>
        </div>

        <div class="flex flex-col">
          <input
            v-model="password"
            name="password"
            type="password"
            :placeholder="t('auth.password')"
            class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg text-gray-900 dark:text-white bg-white dark:bg-gray-800 focus:outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20 transition-all"
          >
          <p v-if="errors.password" class="mt-1 text-sm text-red-600 dark:text-red-400">
            {{ errors.password }}
          </p>
        </div>

        <div class="flex flex-col">
          <input
            v-model="code"
            name="code"
            type="text"
            :placeholder="t('auth.code')"
            class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg text-gray-900 dark:text-white bg-white dark:bg-gray-800 focus:outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20 transition-all"
          >
          <p v-if="errors.code" class="mt-1 text-sm text-red-600 dark:text-red-400">
            {{ errors.code }}
          </p>
        </div>

        <!-- 注册按钮 -->
        <button
          type="submit"
          :disabled="isSubmitting"
          class="w-full px-4 py-2.5 font-semibold text-white bg-blue-600 hover:bg-blue-700 rounded-lg shadow-md transition-all disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:bg-blue-600"
        >
          {{ isSubmitting ? t('auth.loading.registering') : t('auth.register') }}
        </button>
      </form>

      <!-- 登录跳转 -->
      <p class="text-center text-sm text-gray-600 dark:text-gray-400">
        {{ t('auth.haveAccount') }}
        <router-link to="/auth/login" class="ml-1 text-blue-600 dark:text-blue-400 font-medium hover:underline">
          {{ t('auth.login') }}
        </router-link>
      </p>

      <!-- 成功消息 -->
      <p v-if="success" class="text-sm font-semibold text-center text-green-600 dark:text-green-400 select-text">
        {{ t('auth.messages.registerSuccess') }}
      </p>
    </div>
  </div>
</template>
