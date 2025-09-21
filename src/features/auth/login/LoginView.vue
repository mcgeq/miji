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
        <!-- 记住我 -->
        <label class="remember-me">
          <input v-model="rememberMe" type="checkbox">
          <span>{{ t('auth.rememberMe') }}</span>
        </label>

        <!-- 登录按钮 -->
        <button type="submit" :disabled="isSubmitting" class="btn-submit">
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
  background-color: #f3f4f6; /* light gray */
}

/* 卡片 */
.card {
  width: 100%;
  max-width: 28rem;
  padding: 2rem;
  background-color: rgba(255, 255, 255, 0.9);
  border-radius: 1rem;
  border: 1px solid #e5e7eb;
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
  color: #111827;
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
  color: #1f2937;
}

.remember-me input[type="checkbox"] {
  width: 1rem;
  height: 1rem;
  accent-color: #2563eb; /* blue-600 */
}

/* 登录按钮 */
.btn-submit {
  width: 100%;
  padding: 0.5rem 1rem;
  font-weight: 600;
  color: white;
  border: none;
  border-radius: 0.375rem;
  background: linear-gradient(to right, #2563eb, #4f46e5);
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
  color: #4b5563;
}

.register-link {
  margin-left: 0.25rem;
  color: #2563eb;
  font-weight: 500;
  text-decoration: none;
}

.register-link:hover {
  text-decoration: underline;
}

/* dark mode */
@media (prefers-color-scheme: dark) {
  .container {
    background-color: #111827;
  }
  .card {
    background-color: rgba(31, 41, 55, 0.8);
    border-color: #374151;
  }
  .title {
    color: #ffffff;
  }
  .remember-me {
    color: #e5e7eb;
  }
  .register-text {
    color: #9ca3af;
  }
  .register-link {
    color: #60a5fa;
  }
  .remember-me input[type="checkbox"] {
    accent-color: #3b82f6;
  }
}
</style>
