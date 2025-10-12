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

function getRoleClass(_role?: string): string {
  return 'user-profile-role-badge';
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
  <div class="user-profile-card">
    <!-- 背景装饰 -->
    <div class="user-profile-pattern" />

    <div class="user-profile-content">
      <div class="user-profile-header">
        <div class="user-profile-avatar-wrapper">
          <div class="user-profile-avatar-container">
            <img
              v-if="user?.avatarUrl"
              :src="user.avatarUrl"
              :alt="user.name"
              class="user-profile-avatar-image"
            >
            <div v-else class="user-profile-avatar-fallback">
              {{ getInitials(user?.name || '') }}
            </div>
          </div>
          <button
            class="user-profile-avatar-edit"
            @click="handleAvatarEdit"
          >
            <Camera class="user-profile-avatar-edit-icon" />
          </button>
        </div>

        <div class="user-profile-info">
          <h2 class="user-profile-name">
            {{ user?.name || '用户' }}
          </h2>
          <p class="user-profile-email">
            {{ user?.email || '' }}
          </p>
          <div>
            <span
              class="user-profile-role-badge badge-with-bg"
              :class="getRoleClass(user?.role)"
            >
              {{ getRoleText(user?.role) }}
            </span>
          </div>
        </div>
      </div>

      <div class="user-profile-stats">
        <div class="user-profile-stat">
          <div class="user-profile-stat-label">
            序列号
          </div>
          <div class="user-profile-stat-value">
            {{ formatSerialNum(user?.serialNum) }}
          </div>
        </div>
        <div class="user-profile-stat">
          <div class="user-profile-stat-label">
            时区
          </div>
          <div class="user-profile-stat-value">
            {{ user?.timezone || 'Asia/Shanghai' }}
          </div>
        </div>
        <div class="user-profile-stat">
          <div class="user-profile-stat-label">
            语言
          </div>
          <div class="user-profile-stat-value">
            {{ getLanguageText(user?.language) }}
          </div>
        </div>
      </div>

      <!-- 只保留编辑资料按钮，移除退出登录按钮 -->
      <div class="user-profile-actions">
        <button
          class="user-profile-edit-button"
          @click="handleEditProfile"
        >
          <Edit class="user-profile-edit-icon" />
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

<style scoped lang="postcss">
.badge-with-bg {
  background-color: rgba(255, 255, 255, 0.2);
}
</style>
