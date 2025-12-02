<script setup lang="ts">
import { useRouter } from 'vue-router';
import { Input } from '@/components/ui';
import { LoginSchema } from '@/schema/auth';
import { login } from '@/services/auth';
import { Lg } from '@/utils/debugLog';
import { detectMobileDevice } from '@/utils/platform';
import { toast } from '@/utils/toast';

const { t } = useI18n();
const router = useRouter();

// 检测是否为移动设备（用于登录行为控制）
const isMobileDevice = detectMobileDevice();

const form = reactive({
  email: 'miji@miji.com',
  password: 'miji@4321QW',
});

const rememberMe = ref(true);
const errors = reactive<{ email?: string; password?: string }>({});
const isSubmitting = ref(false);

async function handleSubmit() {
  errors.email = '';
  errors.password = '';

  const result = LoginSchema.safeParse(form);
  if (!result.success) {
    const fieldErrors = result.error.flatten().fieldErrors;
    errors.email = fieldErrors.email?.[0];
    errors.password = fieldErrors.password?.[0];
    return;
  }

  isSubmitting.value = true;

  try {
    // 移动设备强制使用 rememberMe = true 以保持登录状态
    const shouldRemember = isMobileDevice ? true : rememberMe.value;
    Lg.i('Login', 'Attempting login', { isMobileDevice, shouldRemember });
    await login(result.data, shouldRemember);
    toast.success(t('auth.messages.loginSuccess'));
    router.push('/todos');
  } catch (e) {
    toast.error(t('loginFailed'));
    Lg.e('login', e);
  } finally {
    isSubmitting.value = false;
  }
};
</script>

<template>
  <div class="flex items-center justify-center min-h-screen p-4 bg-gray-50 dark:bg-gray-900">
    <div class="w-full max-w-md p-8 bg-white dark:bg-gray-800 rounded-2xl border border-gray-200 dark:border-gray-700 shadow-xl backdrop-blur-sm flex flex-col gap-6">
      <!-- 标题 -->
      <h2 class="text-3xl font-bold text-center text-gray-900 dark:text-white tracking-tight">
        {{ t('auth.login') }}
      </h2>

      <!-- 登录表单 -->
      <form class="flex flex-col gap-4" @submit.prevent="handleSubmit">
        <Input
          v-model="form.email"
          name="email"
          :placeholder="t('auth.email')"
          :error="errors.email"
          full-width
        />
        <Input
          v-model="form.password"
          name="password"
          type="password"
          :placeholder="t('auth.password')"
          :error="errors.password"
          full-width
        />

        <!-- 记住我（移动设备自动记住，不显示） -->
        <label v-if="!isMobileDevice" class="inline-flex items-center gap-2 cursor-pointer text-sm text-gray-700 dark:text-gray-300">
          <input
            v-model="rememberMe"
            type="checkbox"
            class="w-4 h-4 text-blue-600 bg-white dark:bg-gray-800 border-gray-300 dark:border-gray-600 rounded focus:ring-2 focus:ring-blue-500/20 transition-all"
          >
          <span>{{ t('auth.rememberMe') }}</span>
        </label>

        <!-- 登录按钮 -->
        <button
          type="submit"
          :disabled="isSubmitting"
          class="w-full px-4 py-2.5 font-semibold text-white bg-blue-600 hover:bg-blue-700 rounded-lg shadow-md transition-all disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:bg-blue-600"
        >
          {{ isSubmitting ? t('auth.loading.loggingIn') : t('auth.login') }}
        </button>
      </form>

      <!-- 注册跳转 -->
      <p class="text-center text-sm text-gray-600 dark:text-gray-400">
        {{ t('auth.noAccount') }}
        <router-link to="/auth/register" class="ml-1 text-blue-600 dark:text-blue-400 font-medium hover:underline">
          {{ t('auth.register') }}
        </router-link>
      </p>
    </div>
  </div>
</template>
