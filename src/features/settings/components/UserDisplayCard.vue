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
  } catch (error) {
    console.error('头像更新失败:', error);
  }
}
</script>

<template>
  <div class="w-full">
    <!-- 移动端紧凑布局 -->
    <div class="block lg:hidden">
      <div class="bg-gradient-to-br text-white p-4 rounded-2xl shadow-lg relative overflow-hidden from-indigo-600 to-blue-700 via-purple-600">
        <!-- 简化的背景装饰 -->
        <div class="pointer-events-none inset-0 absolute">
          <div class="bg-[url('data:image/svg+xml,%3Csvg%20width%3D%2260%22%20height%3D%2260%22%20viewBox%3D%220%200%2060%2060%22%20xmlns%3D%22http%3A//www.w3.org/2000/svg%22%3E%3Cg%20fill%3D%22none%22%20fill-rule%3D%22evenodd%22%3E%3Cg%20fill%3D%22%23ffffff%22%20fill-opacity%3D%220.08%22%3E%3Ccircle%20cx%3D%2230%22%20cy%3D%2230%22%20r%3D%222%22/%3E%3C/g%3E%3C/g%3E%3C/svg%3E')] opacity-30 inset-0 absolute" />
          <div class="rounded-full bg-white/10 h-20 w-20 absolute blur-xl -right-8 -top-8" />
          <div class="rounded-full bg-white/5 h-12 w-12 absolute blur-lg -bottom-10 -left-4" />
        </div>

        <div class="relative z-10">
          <div class="flex items-center space-x-4">
            <!-- 头像区域 -->
            <div class="group flex-shrink-0 relative">
              <div class="h-12 w-12 transform transition-all duration-300 relative group-hover:scale-105">
                <!-- 头像光环 -->
                <div class="bg-gradient-to-r rounded-full absolute from-white/30 to-white/10 blur-sm -inset-0.5" />

                <!-- 头像容器 -->
                <div class="h-full w-full relative">
                  <img
                    v-if="user?.avatarUrl"
                    :src="user.avatarUrl"
                    :alt="user.name"
                    class="border-2 border-white/30 rounded-full h-full w-full shadow-lg transition-all duration-300 object-cover group-hover:border-white/50"
                  >
                  <div
                    v-else
                    class="bg-gradient-to-br text-sm font-bold border-2 border-white/30 rounded-full flex h-full w-full shadow-lg transition-all duration-300 items-center justify-center from-white/20 to-white/10 backdrop-blur-sm group-hover:border-white/50"
                  >
                    {{ getInitials(user?.name || '') }}
                  </div>
                </div>
              </div>

              <!-- 编辑按钮 -->
              <button
                class="bg-gradient-to-r p-1 border border-white rounded-full shadow-md transition-all duration-300 left-0 top-0 absolute from-blue-500 to-purple-600 focus:outline-none focus:ring-2 focus:ring-white/30 hover:shadow-lg hover:scale-110 hover:from-blue-600 hover:to-purple-700"
                aria-label="编辑头像"
                @click="handleAvatarEdit"
              >
                <Camera class="text-white h-2.5 w-2.5" />
              </button>
            </div>

            <!-- 用户信息 -->
            <div class="flex-1 min-w-0">
              <div class="mb-1 flex gap-2 items-center">
                <h3 class="bg-gradient-to-r text-lg text-transparent font-bold truncate from-white to-white/90 bg-clip-text">
                  {{ user?.name || '用户' }}
                </h3>
                <span
                  class="text-xs tracking-wide font-semibold px-2 py-0.5 rounded-full flex-shrink-0 uppercase transition-all duration-300 backdrop-blur-sm"
                  :class="getRoleClass(user?.role)"
                >
                  {{ getRoleText(user?.role) }}
                </span>
              </div>
              <p class="text-sm text-white/80 font-medium truncate">
                {{ user?.email || '' }}
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- 桌面端完整布局 -->
    <div class="hidden lg:block">
      <div class="bg-gradient-to-br text-white p-8 rounded-3xl shadow-2xl shadow-purple-500/20 relative overflow-hidden from-indigo-600 to-blue-700 via-purple-600">
        <!-- 动态背景装饰 -->
        <div class="pointer-events-none inset-0 absolute">
          <!-- 网格图案 -->
          <div class="bg-[url('data:image/svg+xml,%3Csvg%20width%3D%2260%22%20height%3D%2260%22%20viewBox%3D%220%200%2060%2060%22%20xmlns%3D%22http%3A//www.w3.org/2000/svg%22%3E%3Cg%20fill%3D%22none%22%20fill-rule%3D%22evenodd%22%3E%3Cg%20fill%3D%22%23ffffff%22%20fill-opacity%3D%220.08%22%3E%3Ccircle%20cx%3D%2230%22%20cy%3D%2230%22%20r%3D%222%22/%3E%3C/g%3E%3C/g%3E%3C/svg%3E')] opacity-30 inset-0 absolute" />

          <!-- 浮动装饰球 -->
          <div class="rounded-full bg-white/10 h-32 w-32 absolute blur-2xl -right-12 -top-12" />
          <div class="rounded-full bg-white/5 h-24 w-24 absolute blur-xl -bottom-16 -left-8" />
          <div class="rounded-full bg-white/10 h-16 w-16 right-20 top-20 absolute blur-lg" />

          <!-- 渐变遮罩 -->
          <div class="bg-gradient-to-t inset-0 absolute from-black/10 to-transparent via-transparent" />
        </div>

        <div class="relative z-10">
          <!-- 用户头像和基本信息 -->
          <div class="mb-10 flex gap-6 items-start">
            <!-- 头像区域 -->
            <div class="group flex-shrink-0 relative">
              <div class="h-16 w-16 transform transition-all duration-300 relative group-hover:scale-105">
                <!-- 头像光环 -->
                <div class="bg-gradient-to-r rounded-full absolute from-white/30 to-white/10 blur-sm -inset-1" />

                <!-- 头像容器 -->
                <div class="h-full w-full relative">
                  <img
                    v-if="user?.avatarUrl"
                    :src="user.avatarUrl"
                    :alt="user.name"
                    class="border-3 border-white/30 rounded-full h-full w-full shadow-xl transition-all duration-300 object-cover group-hover:border-white/50"
                  >
                  <div
                    v-else
                    class="bg-gradient-to-br text-lg font-bold border-3 border-white/30 rounded-full flex h-full w-full shadow-xl transition-all duration-300 items-center justify-center from-white/20 to-white/10 backdrop-blur-sm group-hover:border-white/50"
                  >
                    {{ getInitials(user?.name || '') }}
                  </div>
                </div>
              </div>

              <!-- 编辑按钮 -->
              <button
                class="bg-gradient-to-r p-1.5 border-2 border-white rounded-full shadow-lg transition-all duration-300 left-0 top-0 absolute from-blue-500 to-purple-600 focus:outline-none focus:ring-4 focus:ring-white/30 hover:shadow-xl hover:scale-110 hover:from-blue-600 hover:to-purple-700"
                aria-label="编辑头像"
                @click="handleAvatarEdit"
              >
                <Camera class="text-white h-3 w-3" />
              </button>
            </div>

            <!-- 用户信息 -->
            <div class="flex-1 min-w-0">
              <div class="mb-1 flex gap-3 items-center">
                <h2 class="bg-gradient-to-r text-2xl text-transparent font-bold truncate from-white to-white/90 bg-clip-text">
                  {{ user?.name || '用户' }}
                </h2>
                <span
                  class="text-xs tracking-wide font-semibold px-3 py-1.5 rounded-full flex-shrink-0 uppercase transition-all duration-300 backdrop-blur-sm hover:scale-105"
                  :class="getRoleClass(user?.role)"
                >
                  {{ getRoleText(user?.role) }}
                </span>
              </div>
              <p class="text-base text-white/80 font-medium truncate">
                {{ user?.email || '' }}
              </p>
            </div>
          </div>

          <!-- 用户详细信息卡片 -->
          <div class="gap-6 grid grid-cols-1 md:grid-cols-3">
            <div class="group p-6 text-center rounded-2xl bg-white/10 transition-all duration-300 relative overflow-hidden backdrop-blur-md hover:bg-white/15 hover:shadow-lg hover:scale-105">
              <div class="bg-gradient-to-br opacity-0 transition-opacity duration-300 inset-0 absolute from-white/5 to-transparent group-hover:opacity-100" />
              <div class="relative z-10">
                <div class="text-xs text-white/70 tracking-wider font-semibold mb-2 uppercase">
                  序列号
                </div>
                <div class="text-lg text-white font-bold">
                  {{ formatSerialNum(user?.serialNum) }}
                </div>
              </div>
            </div>

            <div class="group p-6 text-center rounded-2xl bg-white/10 transition-all duration-300 relative overflow-hidden backdrop-blur-md hover:bg-white/15 hover:shadow-lg hover:scale-105">
              <div class="bg-gradient-to-br opacity-0 transition-opacity duration-300 inset-0 absolute from-white/5 to-transparent group-hover:opacity-100" />
              <div class="relative z-10">
                <div class="text-xs text-white/70 tracking-wider font-semibold mb-2 uppercase">
                  时区
                </div>
                <div class="text-lg text-white font-bold">
                  {{ user?.timezone || 'Asia/Shanghai' }}
                </div>
              </div>
            </div>

            <div class="group p-6 text-center rounded-2xl bg-white/10 transition-all duration-300 relative overflow-hidden backdrop-blur-md hover:bg-white/15 hover:shadow-lg hover:scale-105">
              <div class="bg-gradient-to-br opacity-0 transition-opacity duration-300 inset-0 absolute from-white/5 to-transparent group-hover:opacity-100" />
              <div class="relative z-10">
                <div class="text-xs text-white/70 tracking-wider font-semibold mb-2 uppercase">
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
