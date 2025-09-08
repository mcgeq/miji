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
  <div class="max-w-4xl">
    <!-- 密码安全 -->
    <div class="mb-10">
      <h3 class="text-xl text-slate-800 font-semibold mb-6 pb-2 border-b-2 border-slate-200">
        密码安全
      </h3>

      <div class="space-y-6">
        <div class="py-6 border-b border-slate-100 flex flex-col sm:flex-row sm:items-center sm:justify-between">
          <div class="mb-4 sm:mb-0">
            <label class="text-slate-700 font-medium mb-1 block">修改密码</label>
            <p class="text-sm text-slate-500">
              定期更改密码以保护账户安全
            </p>
          </div>
          <div class="sm:ml-8">
            <button
              class="text-white px-4 py-2 rounded-lg bg-blue-500 flex gap-2 transition-all duration-200 items-center hover:bg-blue-600"
              @click="showChangePassword = true"
            >
              <KeyIcon class="h-4 w-4" />
              修改密码
            </button>
          </div>
        </div>

        <div class="py-6 border-b border-slate-100 flex flex-col sm:flex-row sm:items-center sm:justify-between">
          <div class="mb-4 sm:mb-0">
            <label class="text-slate-700 font-medium mb-1 block">密码强度</label>
            <p class="text-sm text-slate-500">
              您的密码安全强度评估
            </p>
          </div>
          <div class="sm:ml-8">
            <div class="flex gap-4 items-center">
              <div class="rounded-full bg-slate-200 h-2 w-32 overflow-hidden">
                <div
                  class="rounded-full bg-green-500 h-full transition-all duration-300"
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
      <h3 class="text-xl text-slate-800 font-semibold mb-6 pb-2 border-b-2 border-slate-200">
        两步验证
      </h3>

      <div class="space-y-6">
        <div class="py-6 border-b border-slate-100 flex flex-col sm:flex-row sm:items-center sm:justify-between">
          <div class="mb-4 sm:mb-0">
            <label class="text-slate-700 font-medium mb-1 block">启用两步验证</label>
            <p class="text-sm text-slate-500">
              使用手机应用或短信验证码增强账户安全
            </p>
          </div>
          <div class="sm:ml-8">
            <label class="inline-flex cursor-pointer items-center relative">
              <input
                v-model="twoFactorEnabled"
                type="checkbox"
                class="peer sr-only"
              >
              <div class="peer rounded-full bg-slate-300 h-6 w-12 relative after:rounded-full after:bg-white peer-checked:bg-blue-500 after:h-5 after:w-5 after:content-[''] peer-focus:ring-2 peer-focus:ring-blue-500 after:transition-all after:left-0.5 after:top-0.5 after:absolute peer-checked:after:border-white peer-checked:after:translate-x-6" />
            </label>
          </div>
        </div>

        <div v-if="twoFactorEnabled" class="py-6 border-b border-slate-100">
          <div class="mb-4">
            <label class="text-slate-700 font-medium mb-1 block">验证方式</label>
            <p class="text-sm text-slate-500">
              选择接收验证码的方式
            </p>
          </div>
          <div class="flex flex-wrap gap-2">
            <button class="text-sm text-white font-medium px-4 py-2 border border-blue-500 rounded-lg bg-blue-500 flex gap-2 items-center">
              <Smartphone class="h-4 w-4" />
              验证器应用
            </button>
            <button class="text-sm text-slate-700 font-medium px-4 py-2 border border-slate-300 rounded-lg bg-white flex gap-2 items-center hover:border-blue-300">
              <Phone class="h-4 w-4" />
              短信验证
            </button>
            <button class="text-sm text-slate-700 font-medium px-4 py-2 border border-slate-300 rounded-lg bg-white flex gap-2 items-center hover:border-blue-300">
              <Mail class="h-4 w-4" />
              邮箱验证
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- 登录历史 -->
    <div class="mb-10">
      <h3 class="text-xl text-slate-800 font-semibold mb-6 pb-2 border-b-2 border-slate-200">
        登录历史
      </h3>

      <div class="p-4 rounded-xl bg-slate-50 space-y-3">
        <div
          v-for="session in loginSessions"
          :key="session.id"
          class="p-4 border border-slate-200 rounded-lg bg-white flex items-center justify-between"
        >
          <div class="flex gap-4 items-center">
            <Monitor class="text-slate-500 h-5 w-5" />
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
            <span v-if="session.current" class="text-xs text-green-800 font-medium px-3 py-1 rounded-full bg-green-100 inline-flex items-center">
              当前会话
            </span>
            <button
              v-else
              class="text-sm text-red-600 font-medium px-2 py-1 rounded transition-all duration-200 hover:text-red-800 hover:bg-red-50"
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
      <h3 class="text-xl text-slate-800 font-semibold mb-6 pb-2 border-b-2 border-slate-200">
        账户安全
      </h3>

      <div class="space-y-6">
        <div class="py-6 border-b border-slate-100 flex flex-col sm:flex-row sm:items-center sm:justify-between">
          <div class="mb-4 sm:mb-0">
            <label class="text-slate-700 font-medium mb-1 block">自动锁定</label>
            <p class="text-sm text-slate-500">
              闲置指定时间后自动锁定应用
            </p>
          </div>
          <div class="sm:ml-8">
            <select
              v-model="autoLockTime"
              class="px-4 py-2 border border-slate-300 rounded-lg bg-white w-full transition-all duration-200 focus:border-blue-500 sm:w-40 focus:ring-2 focus:ring-blue-500"
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

        <div class="py-6 flex flex-col sm:flex-row sm:items-center sm:justify-between">
          <div class="mb-4 sm:mb-0">
            <label class="text-slate-700 font-medium mb-1 block">删除账户</label>
            <p class="text-sm text-slate-500">
              永久删除您的账户和所有数据
            </p>
          </div>
          <div class="sm:ml-8">
            <button
              class="text-white px-4 py-2 rounded-lg bg-red-500 flex gap-2 transition-all duration-200 items-center hover:bg-red-600"
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
    <div v-if="showChangePassword" class="p-4 bg-black/50 flex items-center inset-0 justify-center fixed z-50">
      <div class="p-6 rounded-xl bg-white max-w-md w-full">
        <h3 class="text-xl text-slate-800 font-semibold mb-4">
          修改密码
        </h3>
        <form class="space-y-4" @submit.prevent="handleChangePassword">
          <div>
            <label class="text-sm text-slate-700 font-medium mb-2 block">当前密码</label>
            <input
              v-model="passwordForm.current"
              type="password"
              class="px-3 py-2 border border-slate-300 rounded-lg w-full focus:border-blue-500 focus:ring-2 focus:ring-blue-500"
              required
            >
          </div>
          <div>
            <label class="text-sm text-slate-700 font-medium mb-2 block">新密码</label>
            <input
              v-model="passwordForm.new"
              type="password"
              class="px-3 py-2 border border-slate-300 rounded-lg w-full focus:border-blue-500 focus:ring-2 focus:ring-blue-500"
              required
            >
          </div>
          <div>
            <label class="text-sm text-slate-700 font-medium mb-2 block">确认新密码</label>
            <input
              v-model="passwordForm.confirm"
              type="password"
              class="px-3 py-2 border border-slate-300 rounded-lg w-full focus:border-blue-500 focus:ring-2 focus:ring-blue-500"
              required
            >
          </div>
          <div class="pt-4 flex gap-3">
            <button
              type="button"
              class="text-slate-700 px-4 py-2 rounded-lg bg-slate-100 flex-1 transition-all duration-200 hover:bg-slate-200"
              @click="showChangePassword = false"
            >
              取消
            </button>
            <button
              type="submit"
              class="text-white px-4 py-2 rounded-lg bg-blue-500 flex-1 transition-all duration-200 hover:bg-blue-600"
            >
              确认修改
            </button>
          </div>
        </form>
      </div>
    </div>

    <!-- 删除账户确认对话框 -->
    <div v-if="showDeleteAccount" class="p-4 bg-black/50 flex items-center inset-0 justify-center fixed z-50">
      <div class="p-6 rounded-xl bg-white max-w-md w-full">
        <h3 class="text-xl text-red-600 font-semibold mb-4">
          删除账户
        </h3>
        <p class="text-slate-600 leading-relaxed mb-4">
          此操作无法撤销。删除账户将永久移除您的所有数据，包括设置、文件和历史记录。
        </p>
        <div class="mb-6">
          <label class="text-sm text-slate-700 font-medium mb-2 block">请输入您的邮箱地址确认删除</label>
          <input
            v-model="deleteConfirmEmail"
            type="email"
            class="px-3 py-2 border border-slate-300 rounded-lg w-full focus:border-red-500 focus:ring-2 focus:ring-red-500"
            :placeholder="user?.email || ''"
          >
        </div>
        <div class="flex gap-3">
          <button
            class="text-slate-700 px-4 py-2 rounded-lg bg-slate-100 flex-1 transition-all duration-200 hover:bg-slate-200"
            @click="showDeleteAccount = false"
          >
            取消
          </button>
          <button
            class="text-white px-4 py-2 rounded-lg bg-red-500 flex-1 transition-all duration-200 disabled:bg-red-300 hover:bg-red-600 disabled:cursor-not-allowed"
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
