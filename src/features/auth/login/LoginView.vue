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

<template>
  <div class="px-4 bg-gray-100 flex min-h-screen items-center justify-center overflow-hidden dark:bg-gray-900">
    <div
      class="p6 border border-gray-200 rounded-xl bg-white/90 max-w-md w-full shadow-lg backdrop-blur-xl space-y-6 sm:p8 dark:border-gray-700 dark:bg-gray-800/80"
    >
      <!-- 标题 -->
      <h2 class="text-3xl text-gray-900 tracking-tight font-bold text-center dark:text-white">
        {{ t('auth.login') }}
      </h2>
      <!-- 登录表单 -->
      <form
        class="space-y-4"
        @submit.prevent="handleSubmit"
      >
        <FormInput v-model="form.email" name="email" :placeholder="t('auth.email')" :error="errors.email" />
        <FormInput
          v-model="form.password" name="password" type="password" :placeholder="t('auth.password')"
          :error="errors.password"
        />
        <!-- 记住我 -->
        <label
          class="text-sm text-gray-800 inline-flex gap-2 cursor-pointer select-none items-center dark:text-gray-200"
        >
          <input v-model="rememberMe" type="checkbox" class="accent-blue-600 h-4 w-4 dark:accent-blue-500">
          <span>{{ t('auth.rememberMe') }}</span>
        </label>

        <!-- 登录按钮 -->
        <button
          type="submit"
          :disabled="isSubmitting"
          class="bg-gradient-to-r text-white font-semibold px-4 py-2 rounded-md w-full shadow-md transition-all from-blue-600 to-indigo-600 disabled:opacity-50 disabled:cursor-not-allowed hover:brightness-110"
          style="color: white !important; background: linear-gradient(to right, #2563eb, #4f46e5);"
        >
          {{ isSubmitting ? t('auth.loading.loggingIn') : t('auth.login') }}
        </button>
      </form>

      <!-- 注册跳转 -->
      <p class="text-sm text-gray-600 text-center dark:text-gray-400">
        {{ t('auth.noAccount') }}
        <router-link to="/auth/register" class="text-blue-600 font-medium ml-1 dark:text-blue-400 hover:underline">
          {{ t('auth.register') }}
        </router-link>
      </p>
    </div>
  </div>
</template>
