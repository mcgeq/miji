<script setup lang="ts">
  import {
    Key as KeyIcon,
    Mail,
    Monitor,
    Smartphone as Phone,
    RotateCcw,
    Smartphone,
    Trash2,
  } from 'lucide-vue-next';
  import { useI18n } from 'vue-i18n';
  import ToggleSwitch from '@/components/ToggleSwitch.vue';
  import Modal from '@/components/ui/Modal.vue';
  import { createDatabaseSetting, useAutoSaveSettings } from '@/composables/useAutoSaveSettings';
  import { useAuthStore } from '@/stores/auth';
  import { toast } from '@/utils/toast';

  const { t } = useI18n();

  const authStore = useAuthStore();
  const user = computed(() => authStore.user);

  // 密码相关
  const showChangePassword = ref(false);
  const passwordForm = ref({
    current: '',
    new: '',
    confirm: '',
  });

  // 使用自动保存设置系统
  const { fields, isSaving, resetAll } = useAutoSaveSettings({
    moduleName: 'security',
    fields: {
      twoFactorEnabled: createDatabaseSetting({
        key: 'settings.security.twoFactorEnabled',
        defaultValue: false,
      }),
      autoLockTime: createDatabaseSetting({
        key: 'settings.security.autoLockTime',
        defaultValue: 15,
      }),
    },
  });

  // 登录会话（只读，不保存）
  const loginSessions = ref([
    {
      id: '1',
      device: 'Windows - Chrome',
      location: '北京, 中国',
      timestamp: Date.now() - 1000 * 60 * 5,
      current: true,
    },
    {
      id: '2',
      device: 'iPhone 14 - Safari',
      location: '上海, 中国',
      timestamp: Date.now() - 1000 * 60 * 60 * 2,
      current: false,
    },
    {
      id: '3',
      device: 'MacBook Pro - Safari',
      location: '广州, 中国',
      timestamp: Date.now() - 1000 * 60 * 60 * 24,
      current: false,
    },
  ]);

  // 账户安全
  const showDeleteAccount = ref(false);
  const deleteConfirmEmail = ref('');

  // 格式化时间
  function getSessionTimeText(timestamp: number) {
    const date = new Date(timestamp);
    const now = new Date();
    const diff = now.getTime() - timestamp;

    if (diff < 1000 * 60) {
      return '刚刚';
    }
    if (diff < 1000 * 60 * 60) {
      return `${Math.floor(diff / (1000 * 60))} 分钟前`;
    }
    if (diff < 1000 * 60 * 60 * 24) {
      return `${Math.floor(diff / (1000 * 60 * 60))} 小时前`;
    }
    return date.toLocaleDateString('zh-CN');
  }

  // 修改密码
  function handleChangePassword() {
    if (passwordForm.value.new !== passwordForm.value.confirm) {
      return;
    }

    // TODO: 实现修改密码的逻辑
    showChangePassword.value = false;
    passwordForm.value = { current: '', new: '', confirm: '' };
  }

  // 终止会话
  function handleTerminateSession(sessionId: string) {
    const index = loginSessions.value.findIndex(s => s.id === sessionId);
    if (index > -1) {
      loginSessions.value.splice(index, 1);
      // TODO: 调用 API 终止远程会话
    }
  }

  // 删除账户
  function handleDeleteAccount() {
    // TODO: 实现删除账户的逻辑
    showDeleteAccount.value = false;
    deleteConfirmEmail.value = '';
  }

  // 重置设置
  async function handleReset() {
    await resetAll();
    toast.info(t('settings.security.resetSecurity'));
  }
</script>

<template>
  <div class="max-w-4xl w-full">
    <!-- 密码安全 -->
    <div class="mb-10">
      <h3
        class="text-xl font-semibold text-gray-900 dark:text-white mb-6 pb-2 border-b-2 border-gray-200 dark:border-gray-700"
      >
        {{ $t('settings.security.passwordSecurity') }}
      </h3>

      <div class="space-y-6">
        <div
          class="flex flex-col sm:flex-row sm:items-center sm:justify-between py-6 border-b border-gray-200 dark:border-gray-700"
        >
          <div class="mb-4 sm:mb-0">
            <label class="block font-medium text-gray-900 dark:text-white mb-1">
              {{ $t('settings.security.changePassword') }}
            </label>
            <p class="text-sm text-gray-600 dark:text-gray-400">
              {{ $t('settings.security.changePasswordDesc') }}
            </p>
          </div>
          <div class="sm:ml-8">
            <button
              class="flex items-center gap-2 px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white font-medium rounded-lg transition-colors"
              @click="showChangePassword = true"
            >
              <KeyIcon class="w-4 h-4" />
              {{ $t('settings.security.changePassword') }}
            </button>
          </div>
        </div>

        <div
          class="flex flex-col sm:flex-row sm:items-center sm:justify-between py-6 border-b border-gray-200 dark:border-gray-700"
        >
          <div class="mb-4 sm:mb-0">
            <label class="block font-medium text-gray-900 dark:text-white mb-1">
              {{ $t('settings.security.passwordStrength') }}
            </label>
            <p class="text-sm text-gray-600 dark:text-gray-400">
              {{ $t('settings.security.passwordStrengthDesc') }}
            </p>
          </div>
          <div class="sm:ml-8">
            <div class="flex items-center gap-4">
              <div class="w-32 h-2 bg-gray-300 dark:bg-gray-600 rounded-full overflow-hidden">
                <div class="h-full bg-green-500 transition-all" style="width: 60%" />
              </div>
              <span class="text-sm font-medium text-green-600 dark:text-green-400"
                >{{ $t('settings.security.strengthLevels.good') }}</span
              >
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- 两步验证 -->
    <div class="mb-10">
      <h3
        class="text-xl font-semibold text-gray-900 dark:text-white mb-6 pb-2 border-b-2 border-gray-200 dark:border-gray-700"
      >
        {{ $t('settings.security.twoFactor') }}
      </h3>

      <div class="space-y-6">
        <div
          class="flex flex-col sm:flex-row sm:items-center sm:justify-between py-6 border-b border-gray-200 dark:border-gray-700"
        >
          <div class="mb-4 sm:mb-0">
            <label class="block font-medium text-gray-900 dark:text-white mb-1">
              {{ $t('settings.security.enableTwoFactor') }}
            </label>
            <p class="text-sm text-gray-600 dark:text-gray-400">
              {{ $t('settings.security.enableTwoFactorDesc') }}
            </p>
          </div>
          <div class="sm:ml-8">
            <ToggleSwitch v-model="fields.twoFactorEnabled.value.value" />
          </div>
        </div>

        <div
          v-if="fields.twoFactorEnabled.value.value"
          class="flex flex-col sm:flex-row sm:items-center sm:justify-between py-6 border-b border-gray-200 dark:border-gray-700"
        >
          <div class="mb-4 sm:mb-0">
            <label class="block font-medium text-gray-900 dark:text-white mb-1">
              {{ $t('settings.security.verificationMethod') }}
            </label>
            <p class="text-sm text-gray-600 dark:text-gray-400">
              {{ $t('settings.security.verificationMethodDesc') }}
            </p>
          </div>
          <div class="sm:ml-8">
            <div class="flex flex-wrap gap-2 max-w-full">
              <button
                class="text-sm font-medium px-4 py-2 border rounded-lg flex items-center gap-2 border-blue-600 bg-blue-600 text-white"
              >
                <Smartphone class="w-4 h-4" />
                {{ $t('settings.security.methods.app') }}
              </button>
              <button
                class="text-sm font-medium px-4 py-2 border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white rounded-lg flex items-center gap-2 hover:border-blue-600"
              >
                <Phone class="w-4 h-4" />
                {{ $t('settings.security.methods.sms') }}
              </button>
              <button
                class="text-sm font-medium px-4 py-2 border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white rounded-lg flex items-center gap-2 hover:border-blue-600"
              >
                <Mail class="w-4 h-4" />
                {{ $t('settings.security.methods.email') }}
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- 登录历史 -->
    <div class="mb-10">
      <h3
        class="text-xl font-semibold text-gray-900 dark:text-white mb-6 pb-2 border-b-2 border-gray-200 dark:border-gray-700"
      >
        {{ $t('settings.security.loginHistory') }}
      </h3>

      <div class="space-y-4">
        <div
          v-for="session in loginSessions"
          :key="session.id"
          class="flex flex-col sm:flex-row sm:items-center sm:justify-between p-4 border border-gray-200 dark:border-gray-700 rounded-lg bg-white dark:bg-gray-800 gap-4"
        >
          <div class="flex items-center gap-4 flex-wrap flex-1 min-w-0">
            <Monitor class="w-5 h-5 text-gray-600 dark:text-gray-400 shrink-0" />
            <div class="flex flex-col gap-1 min-w-0 flex-1">
              <div class="font-medium text-gray-900 dark:text-white wrap-break-words">
                {{ session.device }}
              </div>
              <div class="text-sm text-gray-600 dark:text-gray-400 wrap-break-words">
                {{ session.location }}
              </div>
            </div>
            <div class="text-sm text-gray-600 dark:text-gray-400 whitespace-nowrap shrink-0">
              {{ getSessionTimeText(session.timestamp) }}
            </div>
          </div>
          <div class="shrink-0">
            <span
              v-if="session.current"
              class="inline-flex items-center text-xs font-medium px-3 py-1.5 rounded-full bg-green-500 text-white"
            >
              {{ $t('settings.security.currentSession') }}
            </span>
            <button
              v-else
              class="text-sm font-medium text-red-600 dark:text-red-400 px-2 py-1 rounded-md hover:bg-red-600 hover:text-white transition-colors"
              @click="handleTerminateSession(session.id)"
            >
              {{ $t('settings.security.terminate') }}
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- 账户安全 -->
    <div class="mb-10">
      <h3
        class="text-xl font-semibold text-gray-900 dark:text-white mb-6 pb-2 border-b-2 border-gray-200 dark:border-gray-700"
      >
        {{ $t('settings.security.accountSecurity') }}
      </h3>

      <div class="space-y-6">
        <div
          class="flex flex-col sm:flex-row sm:items-center sm:justify-between py-6 border-b border-gray-200 dark:border-gray-700"
        >
          <div class="mb-4 sm:mb-0">
            <label class="block font-medium text-gray-900 dark:text-white mb-1">
              {{ $t('settings.security.autoLock') }}
            </label>
            <p class="text-sm text-gray-600 dark:text-gray-400">
              {{ $t('settings.security.autoLockDesc') }}
            </p>
          </div>
          <div class="sm:ml-8">
            <select
              v-model.number="fields.autoLockTime.value.value"
              class="w-full sm:w-48 px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-white transition-all focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20 focus:outline-none"
            >
              <option :value="0">{{ $t('settings.security.lockTimeOptions.never') }}</option>
              <option :value="5">{{ $t('settings.security.lockTimeOptions.5min') }}</option>
              <option :value="15">{{ $t('settings.security.lockTimeOptions.15min') }}</option>
              <option :value="30">{{ $t('settings.security.lockTimeOptions.30min') }}</option>
              <option :value="60">{{ $t('settings.security.lockTimeOptions.1hour') }}</option>
            </select>
          </div>
        </div>

        <div
          class="flex flex-col sm:flex-row sm:items-center sm:justify-between py-6 border-b border-gray-200 dark:border-gray-700"
        >
          <div class="mb-4 sm:mb-0">
            <label class="block font-medium text-gray-900 dark:text-white mb-1">
              {{ $t('settings.security.deleteAccount') }}
            </label>
            <p class="text-sm text-gray-600 dark:text-gray-400">
              {{ $t('settings.security.deleteAccountDesc') }}
            </p>
          </div>
          <div class="sm:ml-8">
            <button
              class="flex items-center gap-2 px-4 py-2 bg-red-600 hover:bg-red-700 text-white font-medium rounded-lg transition-colors"
              @click="showDeleteAccount = true"
            >
              <Trash2 class="w-4 h-4" />
              {{ $t('settings.security.deleteAccountButton') }}
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- 操作按钮 -->
    <div class="pt-8 border-t border-gray-200 dark:border-gray-700 flex justify-center gap-4">
      <button
        :title="$t('settings.general.resetSettings')"
        class="flex items-center justify-center w-12 h-12 rounded-full bg-gray-100 hover:bg-gray-200 dark:bg-gray-700 dark:hover:bg-gray-600 text-gray-900 dark:text-white transition-colors"
        @click="handleReset"
      >
        <RotateCcw class="w-5 h-5" />
      </button>
      <div
        v-if="isSaving"
        class="flex items-center justify-center w-12 h-12 text-gray-600 dark:text-gray-400"
      >
        <span class="animate-spin text-xl">⏳</span>
      </div>
    </div>

    <!-- 修改密码对话框 -->
    <Modal
      :open="showChangePassword"
      :title="$t('settings.security.changePasswordDialog.title')"
      size="md"
      @close="showChangePassword = false"
      @confirm="handleChangePassword"
      @cancel="showChangePassword = false"
    >
      <form class="space-y-4" @submit.prevent="handleChangePassword">
        <div>
          <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1.5">
            {{ $t('settings.security.changePasswordDialog.currentPassword') }}
          </label>
          <input
            v-model="passwordForm.current"
            type="password"
            class="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20 focus:outline-none"
            required
          />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1.5">
            {{ $t('settings.security.changePasswordDialog.newPassword') }}
          </label>
          <input
            v-model="passwordForm.new"
            type="password"
            class="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20 focus:outline-none"
            required
          />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1.5">
            {{ $t('settings.security.changePasswordDialog.confirmPassword') }}
          </label>
          <input
            v-model="passwordForm.confirm"
            type="password"
            class="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20 focus:outline-none"
            required
          />
        </div>
      </form>
    </Modal>

    <!-- 删除账户确认对话框 -->
    <Modal
      :open="showDeleteAccount"
      :title="$t('settings.security.deleteAccountDialog.title')"
      size="md"
      show-delete
      :confirm-disabled="deleteConfirmEmail !== user?.email"
      @close="showDeleteAccount = false"
      @delete="handleDeleteAccount"
      @cancel="showDeleteAccount = false"
    >
      <div class="space-y-4">
        <p
          class="text-sm text-gray-700 dark:text-gray-300 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg p-4"
        >
          {{ $t('settings.security.deleteAccountDialog.warning') }}
        </p>
        <div>
          <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1.5">
            {{ $t('settings.security.deleteAccountDialog.confirmPlaceholder') }}
          </label>
          <input
            v-model="deleteConfirmEmail"
            type="email"
            class="w-full px-4 py-2 border border-red-300 dark:border-red-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:border-red-500 focus:ring-2 focus:ring-red-500/20 focus:outline-none"
            :placeholder="user?.email || ''"
          />
        </div>
      </div>
    </Modal>
  </div>
</template>
