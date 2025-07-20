<script setup lang="ts">
import { Camera } from 'lucide-vue-next';
import { useAuthStore } from '@/stores/auth';
import { toast } from '@/utils/toast';
import AvatarEditModal from './AvatarEditModal.vue';
import type { AuthUser } from '@/schema/user';

const authStore = useAuthStore();

const user = computed<AuthUser | null>(() => authStore.user);
const isAvatarEditModalOpen = ref(false);

function getInitials(name: string): string {
  return name
    .split(' ')
    .map(word => word.charAt(0))
    .join('')
    .toUpperCase()
    .slice(0, 2);
}

function getRoleClass(role?: string): string {
  const roleClasses = {
    Admin: 'bg-gradient-to-r from-red-500 to-red-600 text-white shadow-lg shadow-red-500/25',
    Owner: 'bg-gradient-to-r from-amber-500 to-amber-600 text-white shadow-lg shadow-amber-500/25',
    Developer: 'bg-gradient-to-r from-emerald-500 to-emerald-600 text-white shadow-lg shadow-emerald-500/25',
    Moderator: 'bg-gradient-to-r from-purple-500 to-purple-600 text-white shadow-lg shadow-purple-500/25',
    Editor: 'bg-gradient-to-r from-blue-500 to-blue-600 text-white shadow-lg shadow-blue-500/25',
    User: 'bg-gradient-to-r from-gray-500 to-gray-600 text-white shadow-lg shadow-gray-500/25',
    Guest: 'bg-gradient-to-r from-slate-500 to-slate-600 text-white shadow-lg shadow-slate-500/25',
  };
  return roleClasses[role as keyof typeof roleClasses] || 'bg-gradient-to-r from-gray-500 to-gray-600 text-white shadow-lg shadow-gray-500/25';
}

function getRoleText(role?: string): string {
  const roleTexts = {
    Admin: '管理员',
    Owner: '所有者',
    Developer: '开发者',
    Moderator: '版主',
    Editor: '编辑',
    User: '用户',
    Guest: '访客',
  };
  return roleTexts[role as keyof typeof roleTexts] || '用户';
}

function getLanguageText(language?: string): string {
  const languageTexts = {
    'zh-CN': '简体中文',
    'zh-TW': '繁体中文',
    'en-US': 'English',
    'ja-JP': '日本語',
    'ko-KR': '한국어',
  };
  return languageTexts[language as keyof typeof languageTexts] || '简体中文';
}

// 格式化序列号：前3位+3个*+后3位
function formatSerialNum(serialNum?: string): string {
  if (!serialNum || serialNum.length <= 6) {
    return serialNum || '--';
  }
  const prefix = serialNum.slice(0, 3);
  const suffix = serialNum.slice(-3);
  return `${prefix}***${suffix}`;
}

function handleAvatarEdit() {
  isAvatarEditModalOpen.value = true;
}

function handleCloseAvatarEditModal() {
  isAvatarEditModalOpen.value = false;
}

async function handleAvatarUpdate(avatarUrl: string) {
  try {
    await authStore.updateUser({ avatarUrl });
    toast.success('头像更新成功');
  }
  catch (error) {
    console.error('头像更新失败:', error);
  }
}
</script>

<template>
  <div class="w-full">
    <!-- 移动端紧凑布局 -->
    <div class="block lg:hidden">
      <div class="relative overflow-hidden rounded-2xl from-indigo-600 via-purple-600 to-blue-700 bg-gradient-to-br p-4 text-white shadow-lg">
        <!-- 简化的背景装饰 -->
        <div class="pointer-events-none absolute inset-0">
          <div class="absolute inset-0 bg-[url('data:image/svg+xml,%3Csvg%20width%3D%2260%22%20height%3D%2260%22%20viewBox%3D%220%200%2060%2060%22%20xmlns%3D%22http%3A//www.w3.org/2000/svg%22%3E%3Cg%20fill%3D%22none%22%20fill-rule%3D%22evenodd%22%3E%3Cg%20fill%3D%22%23ffffff%22%20fill-opacity%3D%220.08%22%3E%3Ccircle%20cx%3D%2230%22%20cy%3D%2230%22%20r%3D%222%22/%3E%3C/g%3E%3C/g%3E%3C/svg%3E')] opacity-30" />
          <div class="absolute h-20 w-20 rounded-full bg-white/10 blur-xl -right-8 -top-8" />
          <div class="absolute h-12 w-12 rounded-full bg-white/5 blur-lg -bottom-10 -left-4" />
        </div>

        <div class="relative z-10">
          <div class="flex items-center space-x-4">
            <!-- 头像区域 -->
            <div class="group relative flex-shrink-0">
              <div class="relative h-12 w-12 transform transition-all duration-300 group-hover:scale-105">
                <!-- 头像光环 -->
                <div class="absolute rounded-full from-white/30 to-white/10 bg-gradient-to-r blur-sm -inset-0.5" />

                <!-- 头像容器 -->
                <div class="relative h-full w-full">
                  <img
                    v-if="user?.avatarUrl"
                    :src="user.avatarUrl"
                    :alt="user.name"
                    class="h-full w-full border-2 border-white/30 rounded-full object-cover shadow-lg transition-all duration-300 group-hover:border-white/50"
                  >
                  <div
                    v-else
                    class="h-full w-full flex items-center justify-center border-2 border-white/30 rounded-full from-white/20 to-white/10 bg-gradient-to-br text-sm font-bold shadow-lg backdrop-blur-sm transition-all duration-300 group-hover:border-white/50"
                  >
                    {{ getInitials(user?.name || '') }}
                  </div>
                </div>
              </div>

              <!-- 编辑按钮 -->
              <button
                class="absolute left-0 top-0 border border-white rounded-full from-blue-500 to-purple-600 bg-gradient-to-r p-1 shadow-md transition-all duration-300 hover:scale-110 hover:from-blue-600 hover:to-purple-700 hover:shadow-lg focus:outline-none focus:ring-2 focus:ring-white/30"
                aria-label="编辑头像"
                @click="handleAvatarEdit"
              >
                <Camera class="h-2.5 w-2.5 text-white" />
              </button>
            </div>

            <!-- 用户信息 -->
            <div class="min-w-0 flex-1">
              <div class="mb-1 flex items-center gap-2">
                <h3 class="truncate from-white to-white/90 bg-gradient-to-r bg-clip-text text-lg text-transparent font-bold">
                  {{ user?.name || '用户' }}
                </h3>
                <span
                  class="flex-shrink-0 rounded-full px-2 py-0.5 text-xs font-semibold tracking-wide uppercase backdrop-blur-sm transition-all duration-300"
                  :class="getRoleClass(user?.role)"
                >
                  {{ getRoleText(user?.role) }}
                </span>
              </div>
              <p class="truncate text-sm text-white/80 font-medium">
                {{ user?.email || '' }}
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- 桌面端完整布局 -->
    <div class="hidden lg:block">
      <div class="relative overflow-hidden rounded-3xl from-indigo-600 via-purple-600 to-blue-700 bg-gradient-to-br p-8 text-white shadow-2xl shadow-purple-500/20">
        <!-- 动态背景装饰 -->
        <div class="pointer-events-none absolute inset-0">
          <!-- 网格图案 -->
          <div class="absolute inset-0 bg-[url('data:image/svg+xml,%3Csvg%20width%3D%2260%22%20height%3D%2260%22%20viewBox%3D%220%200%2060%2060%22%20xmlns%3D%22http%3A//www.w3.org/2000/svg%22%3E%3Cg%20fill%3D%22none%22%20fill-rule%3D%22evenodd%22%3E%3Cg%20fill%3D%22%23ffffff%22%20fill-opacity%3D%220.08%22%3E%3Ccircle%20cx%3D%2230%22%20cy%3D%2230%22%20r%3D%222%22/%3E%3C/g%3E%3C/g%3E%3C/svg%3E')] opacity-30" />

          <!-- 浮动装饰球 -->
          <div class="absolute h-32 w-32 rounded-full bg-white/10 blur-2xl -right-12 -top-12" />
          <div class="absolute h-24 w-24 rounded-full bg-white/5 blur-xl -bottom-16 -left-8" />
          <div class="absolute right-20 top-20 h-16 w-16 rounded-full bg-white/10 blur-lg" />

          <!-- 渐变遮罩 -->
          <div class="absolute inset-0 from-black/10 via-transparent to-transparent bg-gradient-to-t" />
        </div>

        <div class="relative z-10">
          <!-- 用户头像和基本信息 -->
          <div class="mb-10 flex items-start gap-6">
            <!-- 头像区域 -->
            <div class="group relative flex-shrink-0">
              <div class="relative h-16 w-16 transform transition-all duration-300 group-hover:scale-105">
                <!-- 头像光环 -->
                <div class="absolute rounded-full from-white/30 to-white/10 bg-gradient-to-r blur-sm -inset-1" />

                <!-- 头像容器 -->
                <div class="relative h-full w-full">
                  <img
                    v-if="user?.avatarUrl"
                    :src="user.avatarUrl"
                    :alt="user.name"
                    class="h-full w-full border-3 border-white/30 rounded-full object-cover shadow-xl transition-all duration-300 group-hover:border-white/50"
                  >
                  <div
                    v-else
                    class="h-full w-full flex items-center justify-center border-3 border-white/30 rounded-full from-white/20 to-white/10 bg-gradient-to-br text-lg font-bold shadow-xl backdrop-blur-sm transition-all duration-300 group-hover:border-white/50"
                  >
                    {{ getInitials(user?.name || '') }}
                  </div>
                </div>
              </div>

              <!-- 编辑按钮 -->
              <button
                class="absolute left-0 top-0 border-2 border-white rounded-full from-blue-500 to-purple-600 bg-gradient-to-r p-1.5 shadow-lg transition-all duration-300 hover:scale-110 hover:from-blue-600 hover:to-purple-700 hover:shadow-xl focus:outline-none focus:ring-4 focus:ring-white/30"
                aria-label="编辑头像"
                @click="handleAvatarEdit"
              >
                <Camera class="h-3 w-3 text-white" />
              </button>
            </div>

            <!-- 用户信息 -->
            <div class="min-w-0 flex-1">
              <div class="mb-1 flex items-center gap-3">
                <h2 class="truncate from-white to-white/90 bg-gradient-to-r bg-clip-text text-2xl text-transparent font-bold">
                  {{ user?.name || '用户' }}
                </h2>
                <span
                  class="flex-shrink-0 rounded-full px-3 py-1.5 text-xs font-semibold tracking-wide uppercase backdrop-blur-sm transition-all duration-300 hover:scale-105"
                  :class="getRoleClass(user?.role)"
                >
                  {{ getRoleText(user?.role) }}
                </span>
              </div>
              <p class="truncate text-base text-white/80 font-medium">
                {{ user?.email || '' }}
              </p>
            </div>
          </div>

          <!-- 用户详细信息卡片 -->
          <div class="grid grid-cols-1 gap-6 md:grid-cols-3">
            <div class="group relative overflow-hidden rounded-2xl bg-white/10 p-6 text-center backdrop-blur-md transition-all duration-300 hover:scale-105 hover:bg-white/15 hover:shadow-lg">
              <div class="absolute inset-0 from-white/5 to-transparent bg-gradient-to-br opacity-0 transition-opacity duration-300 group-hover:opacity-100" />
              <div class="relative z-10">
                <div class="mb-2 text-xs text-white/70 font-semibold tracking-wider uppercase">
                  序列号
                </div>
                <div class="text-lg text-white font-bold">
                  {{ formatSerialNum(user?.serialNum) }}
                </div>
              </div>
            </div>

            <div class="group relative overflow-hidden rounded-2xl bg-white/10 p-6 text-center backdrop-blur-md transition-all duration-300 hover:scale-105 hover:bg-white/15 hover:shadow-lg">
              <div class="absolute inset-0 from-white/5 to-transparent bg-gradient-to-br opacity-0 transition-opacity duration-300 group-hover:opacity-100" />
              <div class="relative z-10">
                <div class="mb-2 text-xs text-white/70 font-semibold tracking-wider uppercase">
                  时区
                </div>
                <div class="text-lg text-white font-bold">
                  {{ user?.timezone || 'Asia/Shanghai' }}
                </div>
              </div>
            </div>

            <div class="group relative overflow-hidden rounded-2xl bg-white/10 p-6 text-center backdrop-blur-md transition-all duration-300 hover:scale-105 hover:bg-white/15 hover:shadow-lg">
              <div class="absolute inset-0 from-white/5 to-transparent bg-gradient-to-br opacity-0 transition-opacity duration-300 group-hover:opacity-100" />
              <div class="relative z-10">
                <div class="mb-2 text-xs text-white/70 font-semibold tracking-wider uppercase">
                  语言
                </div>
                <div class="text-lg text-white font-bold">
                  {{ getLanguageText(user?.language) }}
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- 头像编辑 Modal -->
        <AvatarEditModal
          :is-open="isAvatarEditModalOpen"
          @close="handleCloseAvatarEditModal"
          @updated="handleAvatarUpdate"
        />
      </div>
    </div>
  </div>
</template>
