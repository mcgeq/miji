<script setup lang="ts">
import { useRouter } from 'vue-router';
import FormInput from '@/components/common/FormInput.vue';
import { LoginSchema } from '@/schema/auth';
import { login } from '@/services/auth';
import { Lg } from '@/utils/debugLog';
import { toast } from '@/utils/toast';

const { t } = useI18n();
const router = useRouter();

// 检测是否为移动端
const isMobile = /Android|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(
  navigator.userAgent,
);

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
    // 移动端强制使用 rememberMe = true 以保持登录状态
    const shouldRemember = isMobile ? true : rememberMe.value;
    Lg.i('Login', 'Attempting login', { isMobile, shouldRemember });
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
  <div class="container">
    <div class="card">
      <!-- 标题 -->
      <h2 class="title">
        {{ t('auth.login') }}
      </h2>
      <!-- 登录表单 -->
      <form class="form" @submit.prevent="handleSubmit">
        <FormInput
          v-model="form.email"
          name="email"
          :placeholder="t('auth.email')"
          :error="errors.email"
        />
        <FormInput
          v-model="form.password"
          name="password"
          type="password"
          :placeholder="t('auth.password')"
          :error="errors.password"
        />
        <!-- 记住我（移动端自动记住，不显示） -->
        <label v-if="!isMobile" class="remember-me">
          <input
            v-model="rememberMe"
            type="checkbox"
          >
          <span>{{ t('auth.rememberMe') }}</span>
        </label>

        <!-- 登录按钮 -->
        <button
          type="submit"
          :disabled="isSubmitting"
          class="btn-submit"
        >
          {{ isSubmitting ? t('auth.loading.loggingIn') : t('auth.login') }}
        </button>
      </form>

      <!-- 注册跳转 -->
      <p class="register-text">
        {{ t('auth.noAccount') }}
        <router-link to="/auth/register" class="register-link">
          {{ t('auth.register') }}
        </router-link>
      </p>
    </div>
  </div>
</template>

<style scoped>
/* 页面容器 */
.container {
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 100vh;
  padding: 1rem;
  background-color: var(--color-base-100);
}

/* 卡片 */
.card {
  width: 100%;
  max-width: 28rem;
  padding: 2rem;
  background-color: var(--color-base-200);
  border-radius: 1rem;
  border: 1px solid var(--color-base-300);
  box-shadow: 0 10px 15px rgba(0,0,0,0.1);
  backdrop-filter: blur(10px);
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
}

/* 标题 */
.title {
  font-size: 1.875rem; /* 3xl */
  font-weight: bold;
  text-align: center;
  color: var(--color-base-content);
  letter-spacing: -0.015em;
}

/* 表单 */
.form {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

/* 记住我 */
.remember-me {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  cursor: pointer;
  font-size: 0.875rem;
  color: rgb(0,0,0,0.8);
}

/* 复选框基础 */
.remember-me input[type="checkbox"] {
  appearance: none;         /* 移除系统默认样式 */
  -webkit-appearance: none;
  -moz-appearance: none;

  width: 1.1rem;
  height: 1.1rem;
  border: 2px solid var(--color-neutral);
  border-radius: 0.375rem;  /* 圆角方形 */
  background-color: var(--color-base-100);
  cursor: pointer;
  position: relative;
  transition: all 0.2s ease;
  box-shadow: 0 1px 2px rgba(0,0,0,0.05);
}

/* hover 效果 */
.remember-me input[type="checkbox"]:hover {
  border-color: var(--color-primary);
  box-shadow: 0 0 0 3px color-mix(in oklch, var(--color-primary) 25%, transparent);
}

/* 选中状态 */
.remember-me input[type="checkbox"]:checked {
  background-color: var(--color-info);
  border-color: var(--color-base-300);
  box-shadow: 0 0 0 3px color-mix(in oklch, var(--color-base-300) 35%, transparent);
}

/* 选中时的对勾 */
.remember-me input[type="checkbox"]:checked::after {
  content: "√";
  color: var(--color-primary-content);
  font-size: 0.75rem;
  font-weight: bold;
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -60%);
}

/* 禁用状态 */
.remember-me input[type="checkbox"]:disabled {
  background-color: var(--color-neutral);
  border-color: var(--color-neutral);
  cursor: not-allowed;
  opacity: 0.6;
}

/* 登录按钮 */
.btn-submit {
  width: 100%;
  padding: 0.5rem 1rem;
  font-weight: 600;
  color: white;
  border: none;
  border-radius: 0.375rem;
  background: var(--color-neutral);
  box-shadow: 0 4px 6px rgba(0,0,0,0.1);
  cursor: pointer;
  transition: all 0.2s;
}

.btn-submit:hover:not(:disabled) {
  filter: brightness(1.1);
}

.btn-submit:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

/* 注册文字 */
.register-text {
  text-align: center;
  font-size: 0.875rem;
  color: var(--color-neutral);
}

.register-link {
  margin-left: 0.25rem;
  color: var(--color-info);
  font-weight: 500;
  text-decoration: none;
}

.register-link:hover {
  text-decoration: underline;
}
</style>
