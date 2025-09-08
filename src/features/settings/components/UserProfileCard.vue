<script setup lang="ts">
import { Camera, Edit } from 'lucide-vue-next';
import { computed, ref } from 'vue';
import { useAuthStore } from '@/stores/auth';
import { toast } from '@/utils/toast';
import AvatarEditModal from './AvatarEditModal.vue';
import ProfileEditModal from './ProfileEditModal.vue';
import type { AuthUser } from '@/schema/user';

const authStore = useAuthStore();

const user = computed<AuthUser | null>(() => authStore.user);
const isEditModalOpen = ref(false);
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
    Admin: 'bg-red-500/20 text-red-100',
    Owner: 'bg-amber-500/20 text-amber-100',
    Developer: 'bg-emerald-500/20 text-emerald-100',
    Moderator: 'bg-purple-500/20 text-purple-100',
    Editor: 'bg-blue-500/20 text-blue-100',
    User: 'bg-gray-500/20 text-gray-100',
    Guest: 'bg-gray-600/20 text-gray-100',
  };
  return roleClasses[role as keyof typeof roleClasses] || 'bg-gray-500/20 text-gray-100';
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

function handleEditProfile() {
  // 禁用body滚动条
  document.body.style.overflow = 'hidden';
  isEditModalOpen.value = true;
}

function handleCloseEditModal() {
  // 恢复body滚动条
  document.body.style.overflow = '';
  isEditModalOpen.value = false;
}

async function handleProfileUpdate(data: Partial<AuthUser>) {
  try {
    // 使用现有的 updateUser 方法更新用户信息
    await authStore.updateUser(data);

    toast.success('资料更新成功');

    // 可以添加成功提示
    // showSuccessMessage('资料更新成功');
  } catch (error) {
    console.error('更新资料失败:', error);
    // 可以添加错误提示
    // showErrorMessage('更新资料失败，请重试');
  }
}
</script>

<template>
  <div class="bg-gradient-to-br text-white p-8 rounded-2xl relative overflow-hidden from-blue-600 to-blue-800 via-purple-600">
    <!-- 背景装饰 -->
    <div class="bg-[url('data:image/svg+xml,%3Csvg%20width%3D%2260%22%20height%3D%2260%22%20viewBox%3D%220%200%2060%2060%22%20xmlns%3D%22http%3A//www.w3.org/2000/svg%22%3E%3Cg%20fill%3D%22none%22%20fill-rule%3D%22evenodd%22%3E%3Cg%20fill%3D%22%23ffffff%22%20fill-opacity%3D%220.1%22%3E%3Ccircle%20cx%3D%2230%22%20cy%3D%2230%22%20r%3D%222%22/%3E%3C/g%3E%3C/g%3E%3C/svg%3E')] pointer-events-none inset-0 absolute" />

    <div class="relative z-10">
      <div class="mb-8 flex flex-col gap-6 items-center md:flex-row md:items-start">
        <div class="relative">
          <div class="h-20 w-20 relative">
            <img
              v-if="user?.avatarUrl"
              :src="user.avatarUrl"
              :alt="user.name"
              class="border-3 border-white/20 rounded-full h-full w-full object-cover"
            >
            <div v-else class="text-2xl font-semibold border-3 border-white/20 rounded-full bg-white/20 flex h-full w-full items-center justify-center">
              {{ getInitials(user?.name || '') }}
            </div>
          </div>
          <button
            class="p-2 border-2 border-white rounded-full bg-blue-500 transition-all duration-200 absolute hover:bg-blue-600 hover:scale-110 -bottom-1 -right-1"
            @click="handleAvatarEdit"
          >
            <Camera class="h-4 w-4" />
          </button>
        </div>

        <div class="text-center flex-1 md:text-left">
          <h2 class="text-2xl font-bold mb-1">
            {{ user?.name || '用户' }}
          </h2>
          <p class="text-white/90 mb-3">
            {{ user?.email || '' }}
          </p>
          <div class="inline-flex items-center">
            <span
              class="text-xs tracking-wide font-medium px-3 py-1 rounded-full uppercase"
              :class="getRoleClass(user?.role)"
            >
              {{ getRoleText(user?.role) }}
            </span>
          </div>
        </div>
      </div>

      <div class="mb-8 gap-4 grid grid-cols-1 md:grid-cols-3">
        <div class="p-4 text-center rounded-xl bg-white/10 backdrop-blur-sm">
          <div class="text-xs text-white/80 tracking-wide mb-1 uppercase">
            序列号
          </div>
          <div class="text-sm font-semibold">
            {{ formatSerialNum(user?.serialNum) }}
          </div>
        </div>
        <div class="p-4 text-center rounded-xl bg-white/10 backdrop-blur-sm">
          <div class="text-xs text-white/80 tracking-wide mb-1 uppercase">
            时区
          </div>
          <div class="text-sm font-semibold">
            {{ user?.timezone || 'Asia/Shanghai' }}
          </div>
        </div>
        <div class="p-4 text-center rounded-xl bg-white/10 backdrop-blur-sm">
          <div class="text-xs text-white/80 tracking-wide mb-1 uppercase">
            语言
          </div>
          <div class="text-sm font-semibold">
            {{ getLanguageText(user?.language) }}
          </div>
        </div>
      </div>

      <!-- 只保留编辑资料按钮，移除退出登录按钮 -->
      <div class="flex justify-center">
        <button
          class="font-medium px-8 py-3 rounded-xl bg-white/20 flex gap-2 transition-all duration-200 items-center justify-center backdrop-blur-sm hover:bg-white/30"
          @click="handleEditProfile"
        >
          <Edit class="h-4 w-4" />
          编辑资料
        </button>
      </div>
    </div>

    <!-- 资料编辑 Modal -->
    <ProfileEditModal
      :is-open="isEditModalOpen"
      @close="handleCloseEditModal"
      @update="handleProfileUpdate"
    />

    <!-- 头像编辑 Modal -->
    <AvatarEditModal
      :is-open="isAvatarEditModalOpen"
      @close="handleCloseAvatarEditModal"
      @updated="handleAvatarUpdate"
    />
  </div>
</template>
