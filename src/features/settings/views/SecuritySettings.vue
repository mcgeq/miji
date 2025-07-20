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
  }
  else if (diff < 1000 * 60 * 60) {
    return `${Math.floor(diff / (1000 * 60))} 分钟前`;
  }
  else if (diff < 1000 * 60 * 60 * 24) {
    return `${Math.floor(diff / (1000 * 60 * 60))} 小时前`;
  }
  else {
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
  <div class="max-w-4xl">
    <!-- 密码安全 -->
    <div class="mb-10">
      <h3 class="mb-6 border-b-2 border-slate-200 pb-2 text-xl text-slate-800 font-semibold">
        密码安全
      </h3>

      <div class="space-y-6">
        <div class="flex flex-col border-b border-slate-100 py-6 sm:flex-row sm:items-center sm:justify-between">
          <div class="mb-4 sm:mb-0">
            <label class="mb-1 block text-slate-700 font-medium">修改密码</label>
            <p class="text-sm text-slate-500">
              定期更改密码以保护账户安全
            </p>
          </div>
          <div class="sm:ml-8">
            <button
              class="flex items-center gap-2 rounded-lg bg-blue-500 px-4 py-2 text-white transition-all duration-200 hover:bg-blue-600"
              @click="showChangePassword = true"
            >
              <KeyIcon class="h-4 w-4" />
              修改密码
            </button>
          </div>
        </div>

        <div class="flex flex-col border-b border-slate-100 py-6 sm:flex-row sm:items-center sm:justify-between">
          <div class="mb-4 sm:mb-0">
            <label class="mb-1 block text-slate-700 font-medium">密码强度</label>
            <p class="text-sm text-slate-500">
              您的密码安全强度评估
            </p>
          </div>
          <div class="sm:ml-8">
            <div class="flex items-center gap-4">
              <div class="h-2 w-32 overflow-hidden rounded-full bg-slate-200">
                <div
                  class="h-full rounded-full bg-green-500 transition-all duration-300"
                  style="width: 60%"
                />
              </div>
              <span class="text-sm text-green-600 font-medium">良好</span>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- 两步验证 -->
    <div class="mb-10">
      <h3 class="mb-6 border-b-2 border-slate-200 pb-2 text-xl text-slate-800 font-semibold">
        两步验证
      </h3>

      <div class="space-y-6">
        <div class="flex flex-col border-b border-slate-100 py-6 sm:flex-row sm:items-center sm:justify-between">
          <div class="mb-4 sm:mb-0">
            <label class="mb-1 block text-slate-700 font-medium">启用两步验证</label>
            <p class="text-sm text-slate-500">
              使用手机应用或短信验证码增强账户安全
            </p>
          </div>
          <div class="sm:ml-8">
            <label class="relative inline-flex cursor-pointer items-center">
              <input
                v-model="twoFactorEnabled"
                type="checkbox"
                class="peer sr-only"
              >
              <div class="peer relative h-6 w-12 rounded-full bg-slate-300 after:absolute after:left-0.5 after:top-0.5 after:h-5 after:w-5 after:rounded-full after:bg-white peer-checked:bg-blue-500 peer-focus:ring-2 peer-focus:ring-blue-500 after:transition-all after:content-[''] peer-checked:after:translate-x-6 peer-checked:after:border-white" />
            </label>
          </div>
        </div>

        <div v-if="twoFactorEnabled" class="border-b border-slate-100 py-6">
          <div class="mb-4">
            <label class="mb-1 block text-slate-700 font-medium">验证方式</label>
            <p class="text-sm text-slate-500">
              选择接收验证码的方式
            </p>
          </div>
          <div class="flex flex-wrap gap-2">
            <button class="flex items-center gap-2 border border-blue-500 rounded-lg bg-blue-500 px-4 py-2 text-sm text-white font-medium">
              <Smartphone class="h-4 w-4" />
              验证器应用
            </button>
            <button class="flex items-center gap-2 border border-slate-300 rounded-lg bg-white px-4 py-2 text-sm text-slate-700 font-medium hover:border-blue-300">
              <Phone class="h-4 w-4" />
              短信验证
            </button>
            <button class="flex items-center gap-2 border border-slate-300 rounded-lg bg-white px-4 py-2 text-sm text-slate-700 font-medium hover:border-blue-300">
              <Mail class="h-4 w-4" />
              邮箱验证
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- 登录历史 -->
    <div class="mb-10">
      <h3 class="mb-6 border-b-2 border-slate-200 pb-2 text-xl text-slate-800 font-semibold">
        登录历史
      </h3>

      <div class="rounded-xl bg-slate-50 p-4 space-y-3">
        <div
          v-for="session in loginSessions"
          :key="session.id"
          class="flex items-center justify-between border border-slate-200 rounded-lg bg-white p-4"
        >
          <div class="flex items-center gap-4">
            <Monitor class="h-5 w-5 text-slate-500" />
            <div>
              <div class="text-slate-800 font-medium">
                {{ session.device }}
              </div>
              <div class="text-sm text-slate-500">
                {{ session.location }}
              </div>
            </div>
            <div class="text-sm text-slate-400">
              {{ getSessionTimeText(session.timestamp) }}
            </div>
          </div>
          <div>
            <span v-if="session.current" class="inline-flex items-center rounded-full bg-green-100 px-3 py-1 text-xs text-green-800 font-medium">
              当前会话
            </span>
            <button
              v-else
              class="rounded px-2 py-1 text-sm text-red-600 font-medium transition-all duration-200 hover:bg-red-50 hover:text-red-800"
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
      <h3 class="mb-6 border-b-2 border-slate-200 pb-2 text-xl text-slate-800 font-semibold">
        账户安全
      </h3>

      <div class="space-y-6">
        <div class="flex flex-col border-b border-slate-100 py-6 sm:flex-row sm:items-center sm:justify-between">
          <div class="mb-4 sm:mb-0">
            <label class="mb-1 block text-slate-700 font-medium">自动锁定</label>
            <p class="text-sm text-slate-500">
              闲置指定时间后自动锁定应用
            </p>
          </div>
          <div class="sm:ml-8">
            <select
              v-model="autoLockTime"
              class="w-full border border-slate-300 rounded-lg bg-white px-4 py-2 transition-all duration-200 sm:w-40 focus:border-blue-500 focus:ring-2 focus:ring-blue-500"
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

        <div class="flex flex-col py-6 sm:flex-row sm:items-center sm:justify-between">
          <div class="mb-4 sm:mb-0">
            <label class="mb-1 block text-slate-700 font-medium">删除账户</label>
            <p class="text-sm text-slate-500">
              永久删除您的账户和所有数据
            </p>
          </div>
          <div class="sm:ml-8">
            <button
              class="flex items-center gap-2 rounded-lg bg-red-500 px-4 py-2 text-white transition-all duration-200 hover:bg-red-600"
              @click="showDeleteAccount = true"
            >
              <Trash2 class="h-4 w-4" />
              删除账户
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- 修改密码对话框 -->
    <div v-if="showChangePassword" class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
      <div class="max-w-md w-full rounded-xl bg-white p-6">
        <h3 class="mb-4 text-xl text-slate-800 font-semibold">
          修改密码
        </h3>
        <form class="space-y-4" @submit.prevent="handleChangePassword">
          <div>
            <label class="mb-2 block text-sm text-slate-700 font-medium">当前密码</label>
            <input
              v-model="passwordForm.current"
              type="password"
              class="w-full border border-slate-300 rounded-lg px-3 py-2 focus:border-blue-500 focus:ring-2 focus:ring-blue-500"
              required
            >
          </div>
          <div>
            <label class="mb-2 block text-sm text-slate-700 font-medium">新密码</label>
            <input
              v-model="passwordForm.new"
              type="password"
              class="w-full border border-slate-300 rounded-lg px-3 py-2 focus:border-blue-500 focus:ring-2 focus:ring-blue-500"
              required
            >
          </div>
          <div>
            <label class="mb-2 block text-sm text-slate-700 font-medium">确认新密码</label>
            <input
              v-model="passwordForm.confirm"
              type="password"
              class="w-full border border-slate-300 rounded-lg px-3 py-2 focus:border-blue-500 focus:ring-2 focus:ring-blue-500"
              required
            >
          </div>
          <div class="flex gap-3 pt-4">
            <button
              type="button"
              class="flex-1 rounded-lg bg-slate-100 px-4 py-2 text-slate-700 transition-all duration-200 hover:bg-slate-200"
              @click="showChangePassword = false"
            >
              取消
            </button>
            <button
              type="submit"
              class="flex-1 rounded-lg bg-blue-500 px-4 py-2 text-white transition-all duration-200 hover:bg-blue-600"
            >
              确认修改
            </button>
          </div>
        </form>
      </div>
    </div>

    <!-- 删除账户确认对话框 -->
    <div v-if="showDeleteAccount" class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
      <div class="max-w-md w-full rounded-xl bg-white p-6">
        <h3 class="mb-4 text-xl text-red-600 font-semibold">
          删除账户
        </h3>
        <p class="mb-4 text-slate-600 leading-relaxed">
          此操作无法撤销。删除账户将永久移除您的所有数据，包括设置、文件和历史记录。
        </p>
        <div class="mb-6">
          <label class="mb-2 block text-sm text-slate-700 font-medium">请输入您的邮箱地址确认删除</label>
          <input
            v-model="deleteConfirmEmail"
            type="email"
            class="w-full border border-slate-300 rounded-lg px-3 py-2 focus:border-red-500 focus:ring-2 focus:ring-red-500"
            :placeholder="user?.email || ''"
          >
        </div>
        <div class="flex gap-3">
          <button
            class="flex-1 rounded-lg bg-slate-100 px-4 py-2 text-slate-700 transition-all duration-200 hover:bg-slate-200"
            @click="showDeleteAccount = false"
          >
            取消
          </button>
          <button
            class="flex-1 rounded-lg bg-red-500 px-4 py-2 text-white transition-all duration-200 disabled:cursor-not-allowed disabled:bg-red-300 hover:bg-red-600"
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
