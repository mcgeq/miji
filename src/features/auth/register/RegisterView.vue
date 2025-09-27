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
  <div class="page-container">
    <div class="card">
      <h2 class="card__title">
        {{ t('auth.register') }}
      </h2>

      <form class="form" @submit.prevent="onSubmit">
        <div class="form__group">
          <input v-model="username" name="username" type="text" :placeholder="t('auth.username')" class="input">
          <p v-if="errors.username" class="form__error">
            {{ errors.username }}
          </p>
        </div>

        <div class="form__group">
          <input v-model="email" name="email" type="email" :placeholder="t('auth.email')" class="input">
          <p v-if="errors.email" class="form__error">
            {{ errors.email }}
          </p>
        </div>

        <div class="form__group">
          <input v-model="password" name="password" type="password" :placeholder="t('auth.password')" class="input">
          <p v-if="errors.password" class="form__error">
            {{ errors.password }}
          </p>
        </div>

        <div class="form__group">
          <input v-model="code" name="code" type="text" :placeholder="t('auth.code')" class="input">
          <p v-if="errors.code" class="form__error">
            {{ errors.code }}
          </p>
        </div>

        <button
          type="submit"
          :disabled="isSubmitting"
          class="btn-submit"
        >
          <template v-if="isSubmitting">
            {{ t('auth.loading.registering') }}
          </template>
          <template v-else>
            {{ t('auth.register') }}
          </template>
        </button>
      </form>

      <p class="form__text">
        {{ t('auth.haveAccount') }}
        <router-link to="/auth/login" class="form__link">
          {{ t('auth.login') }}
        </router-link>
      </p>

      <p v-if="success" class="form__success">
        {{ t('auth.messages.registerSuccess') }}
      </p>
    </div>
  </div>
</template>

<style scoped lang="postcss">
.page-container {
  padding: 1rem;
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--color-base-100);
}

.card {
  width: 100%;
  max-width: 28rem; /* 等于 max-w-md */
  padding: 1.5rem;
  border: 1px solid var(--color-base-200);
  border-radius: 0.75rem;
  background-color: var(--color-base-200);
  box-shadow: 0 10px 15px -3px rgb(0 0 0 / 0.1),
              0 4px 6px -4px rgb(0 0 0 / 0.1);
  backdrop-filter: blur(20px);
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
}

@media (min-width: 640px) {
  .card {
    padding: 2rem;
  }
}

.card__title {
  font-size: 1.875rem; /* text-3xl */
  font-weight: 700;
  text-align: center;
  color: var(--color-base-content);
  letter-spacing: -0.01em;
}

.form {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.form__group {
  display: flex;
  flex-direction: column;
}

.input {
  width: 100%;
  padding: 0.5rem 0.75rem;
  border: 1px solid var(--color-neutral);
  border-radius: 0.375rem;
  font-size: 1rem;
  color: var(--color-base-content);
  background-color: var(--color-base-100);
  transition: border-color 0.2s, box-shadow 0.2s;
}

.input:focus {
  outline: none;
  border-color: var(--color-primary);
  box-shadow: 0 0 0 3px var(--color-primary-soft);
}

.form__error {
  margin-top: 0.25rem;
  font-size: 0.875rem;
  color: var(--color-error);
}

.btn-submit {
  width: 100%;
  padding: 0.5rem 1rem;
  font-weight: 600;
  color: white;
  border: none;
  border-radius: 0.375rem;
  cursor: pointer;
  background: var(--color-neutral);
  box-shadow: 0 4px 6px -1px rgb(0 0 0 / 0.1),
              0 2px 4px -2px rgb(0 0 0 / 0.1);
  transition: filter 0.2s;
}

.btn-submit:hover:not(:disabled) {
  filter: brightness(1.1);
}

.btn-submit:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.form__text {
  font-size: 0.875rem;
  text-align: center;
  color: var(--color-neutral);
}

.form__link {
  margin-left: 0.25rem;
  color: var(--color-info);
  font-weight: 500;
  text-decoration: none;
}

.form__link:hover {
  text-decoration: underline;
}

.form__success {
  font-size: 0.875rem;
  font-weight: 600;
  text-align: center;
  color: var(--color-success);
  user-select: text;
}
</style>
