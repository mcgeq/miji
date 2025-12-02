<script setup lang="ts">
import {
  Key as KeyIcon,
  Mail,
  Monitor,
  Smartphone as Phone,
  Smartphone,
  Trash2,
} from 'lucide-vue-next';
import { useAuthStore } from '@/stores/auth';

const authStore = useAuthStore();
const user = computed(() => authStore.user);

// 密码相关
const showChangePassword = ref(false);
const passwordForm = ref({
  current: '',
  new: '',
  confirm: '',
});

// 两步验证
const twoFactorEnabled = ref(false);

// 登录会话
const loginSessions = ref([
  {
    id: '1',
    device: 'Windows - Chrome',
    location: '北京, 中国',
    timestamp: new Date().getTime() - 1000 * 60 * 5,
    current: true,
  },
  {
    id: '2',
    device: 'iPhone 14 - Safari',
    location: '上海, 中国',
    timestamp: new Date().getTime() - 1000 * 60 * 60 * 2,
    current: false,
  },
  {
    id: '3',
    device: 'MacBook Pro - Safari',
    location: '广州, 中国',
    timestamp: new Date().getTime() - 1000 * 60 * 60 * 24,
    current: false,
  },
]);

// 账户安全
const autoLockTime = ref(15);
const showDeleteAccount = ref(false);
const deleteConfirmEmail = ref('');

// 格式化时间
function getSessionTimeText(timestamp: number) {
  const date = new Date(timestamp);
  const now = new Date();
  const diff = now.getTime() - timestamp;

  if (diff < 1000 * 60) {
    return '刚刚';
  } else if (diff < 1000 * 60 * 60) {
    return `${Math.floor(diff / (1000 * 60))} 分钟前`;
  } else if (diff < 1000 * 60 * 60 * 24) {
    return `${Math.floor(diff / (1000 * 60 * 60))} 小时前`;
  } else {
    return date.toLocaleDateString('zh-CN');
  }
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
</script>

<template>
  <div class="max-w-4xl w-full">
    <!-- 密码安全 -->
    <div class="mb-10">
      <h3 class="text-xl font-semibold text-gray-900 dark:text-white mb-6 pb-2 border-b-2 border-gray-200 dark:border-gray-700">
        密码安全
      </h3>

      <div class="space-y-6">
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between py-6 border-b border-gray-200 dark:border-gray-700">
          <div class="mb-4 sm:mb-0">
            <label class="block font-medium text-gray-900 dark:text-white mb-1">修改密码</label>
            <p class="text-sm text-gray-600 dark:text-gray-400">
              定期更改密码以保护账户安全
            </p>
          </div>
          <div class="sm:ml-8">
            <button
              class="flex items-center gap-2 px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white font-medium rounded-lg transition-colors"
              @click="showChangePassword = true"
            >
              <KeyIcon class="w-4 h-4" />
              修改密码
            </button>
          </div>
        </div>

        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between py-6 border-b border-gray-200 dark:border-gray-700">
          <div class="mb-4 sm:mb-0">
            <label class="block font-medium text-gray-900 dark:text-white mb-1">密码强度</label>
            <p class="text-sm text-gray-600 dark:text-gray-400">
              您的密码安全强度评估
            </p>
          </div>
          <div class="sm:ml-8">
            <div class="flex items-center gap-4">
              <div class="w-32 h-2 bg-gray-300 dark:bg-gray-600 rounded-full overflow-hidden">
                <div
                  class="h-full bg-green-500 transition-all"
                  style="width: 60%"
                />
              </div>
              <span class="text-sm font-medium text-green-600 dark:text-green-400">良好</span>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- 两步验证 -->
    <div class="mb-10">
      <h3 class="text-xl font-semibold text-gray-900 dark:text-white mb-6 pb-2 border-b-2 border-gray-200 dark:border-gray-700">
        两步验证
      </h3>

      <div class="space-y-6">
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between py-6 border-b border-gray-200 dark:border-gray-700">
          <div class="mb-4 sm:mb-0">
            <label class="block font-medium text-gray-900 dark:text-white mb-1">启用两步验证</label>
            <p class="text-sm text-gray-600 dark:text-gray-400">
              使用手机应用或短信验证码增强账户安全
            </p>
          </div>
          <div class="sm:ml-8">
            <label class="inline-flex cursor-pointer items-center relative">
              <input
                v-model="twoFactorEnabled"
                type="checkbox"
                class="sr-only peer"
              >
              <div class="w-12 h-6 bg-gray-300 dark:bg-gray-600 rounded-full peer peer-checked:bg-blue-600 transition-colors relative">
                <div class="absolute w-5 h-5 bg-white rounded-full top-0.5 left-0.5 peer-checked:translate-x-6 transition-transform" />
              </div>
            </label>
          </div>
        </div>

        <div v-if="twoFactorEnabled" class="flex flex-col sm:flex-row sm:items-center sm:justify-between py-6 border-b border-gray-200 dark:border-gray-700">
          <div class="mb-4 sm:mb-0">
            <label class="block font-medium text-gray-900 dark:text-white mb-1">验证方式</label>
            <p class="text-sm text-gray-600 dark:text-gray-400">
              选择接收验证码的方式
            </p>
          </div>
          <div class="sm:ml-8">
            <div class="flex flex-wrap gap-2 max-w-full">
              <button class="text-sm font-medium px-4 py-2 border rounded-lg flex items-center gap-2 border-blue-600 bg-blue-600 text-white">
                <Smartphone class="w-4 h-4" />
                验证器应用
              </button>
              <button class="text-sm font-medium px-4 py-2 border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white rounded-lg flex items-center gap-2 hover:border-blue-600">
                <Phone class="w-4 h-4" />
                短信验证
              </button>
              <button class="text-sm font-medium px-4 py-2 border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white rounded-lg flex items-center gap-2 hover:border-blue-600">
                <Mail class="w-4 h-4" />
                邮箱验证
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- 登录历史 -->
    <div class="mb-10">
      <h3 class="text-xl font-semibold text-gray-900 dark:text-white mb-6 pb-2 border-b-2 border-gray-200 dark:border-gray-700">
        登录历史
      </h3>

      <div class="space-y-4">
        <div
          v-for="session in loginSessions"
          :key="session.id"
          class="flex flex-col sm:flex-row sm:items-center sm:justify-between p-4 border border-gray-200 dark:border-gray-700 rounded-lg bg-white dark:bg-gray-800 gap-4"
        >
          <div class="flex items-center gap-4 flex-wrap flex-1 min-w-0">
            <Monitor class="w-5 h-5 text-gray-600 dark:text-gray-400 flex-shrink-0" />
            <div class="flex flex-col gap-1 min-w-0 flex-1">
              <div class="font-medium text-gray-900 dark:text-white break-words">
                {{ session.device }}
              </div>
              <div class="text-sm text-gray-600 dark:text-gray-400 break-words">
                {{ session.location }}
              </div>
            </div>
            <div class="text-sm text-gray-600 dark:text-gray-400 whitespace-nowrap flex-shrink-0">
              {{ getSessionTimeText(session.timestamp) }}
            </div>
          </div>
          <div class="flex-shrink-0">
            <span v-if="session.current" class="inline-flex items-center text-xs font-medium px-3 py-1.5 rounded-full bg-green-500 text-white">
              当前会话
            </span>
            <button
              v-else
              class="text-sm font-medium text-red-600 dark:text-red-400 px-2 py-1 rounded-md hover:bg-red-600 hover:text-white transition-colors"
              @click="handleTerminateSession(session.id)"
            >
              终止
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- 账户安全 -->
    <div class="mb-10">
      <h3 class="text-xl font-semibold text-gray-900 dark:text-white mb-6 pb-2 border-b-2 border-gray-200 dark:border-gray-700">
        账户安全
      </h3>

      <div class="space-y-6">
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between py-6 border-b border-gray-200 dark:border-gray-700">
          <div class="mb-4 sm:mb-0">
            <label class="block font-medium text-gray-900 dark:text-white mb-1">自动锁定</label>
            <p class="text-sm text-gray-600 dark:text-gray-400">
              闲置指定时间后自动锁定应用
            </p>
          </div>
          <div class="sm:ml-8">
            <select
              v-model="autoLockTime"
              class="w-full sm:w-48 px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-white transition-all focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20 focus:outline-none"
            >
              <option value="0">
                从不
              </option>
              <option value="5">
                5 分钟
              </option>
              <option value="15">
                15 分钟
              </option>
              <option value="30">
                30 分钟
              </option>
              <option value="60">
                1 小时
              </option>
            </select>
          </div>
        </div>

        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between py-6 border-b border-gray-200 dark:border-gray-700">
          <div class="mb-4 sm:mb-0">
            <label class="block font-medium text-gray-900 dark:text-white mb-1">删除账户</label>
            <p class="text-sm text-gray-600 dark:text-gray-400">
              永久删除您的账户和所有数据
            </p>
          </div>
          <div class="sm:ml-8">
            <button
              class="flex items-center gap-2 px-4 py-2 bg-red-600 hover:bg-red-700 text-white font-medium rounded-lg transition-colors"
              @click="showDeleteAccount = true"
            >
              <Trash2 class="w-4 h-4" />
              删除账户
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- 修改密码对话框 -->
    <div v-if="showChangePassword" class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm p-4">
      <div class="w-full max-w-md bg-white dark:bg-gray-800 rounded-xl shadow-2xl p-6">
        <h3 class="text-xl font-semibold text-gray-900 dark:text-white mb-6">
          修改密码
        </h3>
        <form class="space-y-4" @submit.prevent="handleChangePassword">
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1.5">当前密码</label>
            <input
              v-model="passwordForm.current"
              type="password"
              class="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20 focus:outline-none"
              required
            >
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1.5">新密码</label>
            <input
              v-model="passwordForm.new"
              type="password"
              class="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20 focus:outline-none"
              required
            >
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1.5">确认新密码</label>
            <input
              v-model="passwordForm.confirm"
              type="password"
              class="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20 focus:outline-none"
              required
            >
          </div>
          <div class="flex gap-3 pt-4">
            <button
              type="button"
              class="flex-1 px-4 py-2 border border-gray-300 dark:border-gray-600 hover:bg-gray-50 dark:hover:bg-gray-700 text-gray-900 dark:text-white rounded-lg transition-colors"
              @click="showChangePassword = false"
            >
              取消
            </button>
            <button
              type="submit"
              class="flex-1 px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg transition-colors"
            >
              确认修改
            </button>
          </div>
        </form>
      </div>
    </div>

    <!-- 删除账户确认对话框 -->
    <div v-if="showDeleteAccount" class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm p-4">
      <div class="w-full max-w-md bg-white dark:bg-gray-800 rounded-xl shadow-2xl p-6">
        <h3 class="text-xl font-semibold text-red-600 dark:text-red-400 mb-4">
          删除账户
        </h3>
        <p class="text-sm text-gray-700 dark:text-gray-300 mb-6 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg p-4">
          此操作无法撤销。删除账户将永久移除您的所有数据，包括设置、文件和历史记录。
        </p>
        <div class="mb-6">
          <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1.5">请输入您的邮箱地址确认删除</label>
          <input
            v-model="deleteConfirmEmail"
            type="email"
            class="w-full px-4 py-2 border border-red-300 dark:border-red-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:border-red-500 focus:ring-2 focus:ring-red-500/20 focus:outline-none"
            :placeholder="user?.email || ''"
          >
        </div>
        <div class="flex gap-3">
          <button
            class="flex-1 px-4 py-2 border border-gray-300 dark:border-gray-600 hover:bg-gray-50 dark:hover:bg-gray-700 text-gray-900 dark:text-white rounded-lg transition-colors"
            @click="showDeleteAccount = false"
          >
            取消
          </button>
          <button
            class="flex-1 px-4 py-2 bg-red-600 hover:bg-red-700 text-white rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            :disabled="deleteConfirmEmail !== user?.email"
            @click="handleDeleteAccount"
          >
            确认删除
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
