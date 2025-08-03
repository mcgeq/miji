<template>
  <div class="min-h-screen flex items-center justify-center bg-gray-100 dark:bg-gray-900 px-4 overflow-hidden">
    <div
      class="w-full max-w-md p6 sm:p8 bg-white/90 dark:bg-gray-800/80 backdrop-blur-xl border border-gray-200 dark:border-gray-700 rounded-xl shadow-lg space-y-6">
      <!-- 标题 -->
      <h2 class="text-center text-3xl font-bold text-gray-900 dark:text-white tracking-tight">
        {{ t('auth.login') }}
      </h2>

      <!-- 登录表单 -->
      <form @submit.prevent="handleSubmit" class="space-y-4">
        <FormInput v-model="form.email" name="email" :placeholder="t('auth.email')" :error="errors.email" />
        <FormInput v-model="form.password" name="password" type="password" :placeholder="t('auth.password')"
          :error="errors.password" />

        <!-- 记住我 -->
        <label
          class="inline-flex items-center gap-2 text-sm text-gray-800 dark:text-gray-200 cursor-pointer select-none">
          <input type="checkbox" v-model="rememberMe" class="accent-blue-600 dark:accent-blue-500 w-4 h-4" />
          <span>{{ t('auth.rememberMe') }}</span>
        </label>

        <!-- 登录按钮 -->
        <button type="submit" :disabled="isSubmitting"
          class="w-full py-2 px-4 rounded-md bg-gradient-to-r from-blue-600 to-indigo-600 hover:brightness-110 text-white font-semibold shadow-md transition-all disabled:opacity-50 disabled:cursor-not-allowed"
          style="color: white !important; background: linear-gradient(to right, #2563eb, #4f46e5);">
          {{ isSubmitting ? t('auth.loading.loggingIn') : t('auth.login') }}
        </button>
      </form>

      <!-- 注册跳转 -->
      <p class="text-center text-sm text-gray-600 dark:text-gray-400">
        {{ t('auth.noAccount') }}
        <router-link to="/auth/register" class="text-blue-600 dark:text-blue-400 hover:underline ml-1 font-medium">
          {{ t('auth.register') }}
        </router-link>
      </p>
    </div>
  </div>
</template>

<script setup lang="ts">
import { useRouter } from 'vue-router';
import FormInput from '@/components/common/FormInput.vue';
import { LoginSchema } from '@/schema/auth';
import { login } from '@/services/auth';
import { Lg } from '@/utils/debugLog';
import { toast } from '@/utils/toast';

const { t } = useI18n();
const router = useRouter();

const form = reactive({
  email: '',
  password: '',
});

const rememberMe = ref(true);
const errors = reactive<{ email?: string; password?: string }>({});
const isSubmitting = ref(false);

const handleSubmit = async () => {
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
    await login(result.data, rememberMe.value);
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
