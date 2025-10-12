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
    Admin: 'user-role-badge',
    Owner: 'user-role-badge',
    Developer: 'user-role-badge',
    Moderator: 'user-role-badge',
    Editor: 'user-role-badge',
    User: 'user-role-badge',
    Guest: 'user-role-badge',
  };
  return roleClasses[role as keyof typeof roleClasses] || 'user-role-badge';
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
  <div class="user-display-wrapper">
    <!-- 移动端紧凑布局 -->
    <div class="user-display-card-mobile">
      <div class="user-card-gradient">
        <!-- 简化的背景装饰 -->
        <div class="user-card-background">
          <div class="user-card-pattern" />
          <div class="user-card-blob-1" />
          <div class="user-card-blob-2" />
        </div>

        <div class="user-card-content">
          <div class="user-card-header mobile-header">
            <!-- 头像区域 -->
            <div class="user-avatar-wrapper">
              <div class="user-avatar-container">
                <!-- 头像光环 -->
                <div class="user-avatar-glow" />

                <!-- 头像容器 -->
                <div class="user-avatar-image-wrapper">
                  <img
                    v-if="user?.avatarUrl"
                    :src="user.avatarUrl"
                    :alt="user.name"
                    class="user-avatar-image"
                  >
                  <div
                    v-else
                    class="user-avatar-fallback"
                  >
                    {{ getInitials(user?.name || '') }}
                  </div>
                </div>
              </div>

              <!-- 编辑按钮 -->
              <button
                class="user-avatar-edit-button"
                aria-label="编辑头像"
                @click="handleAvatarEdit"
              >
                <Camera class="user-avatar-edit-icon" />
              </button>
            </div>

            <!-- 用户信息 -->
            <div class="user-info">
              <div class="user-name-row">
                <h3 class="user-name">
                  {{ user?.name || '用户' }}
                </h3>
                <span
                  class="user-role-badge badge-with-bg"
                  :class="getRoleClass(user?.role)"
                >
                  {{ getRoleText(user?.role) }}
                </span>
              </div>
              <p class="user-email">
                {{ user?.email || '' }}
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- 桌面端完整布局 -->
    <div class="user-display-card-desktop">
      <div class="user-card-gradient desktop-shadow">
        <!-- 动态背景装饰 -->
        <div class="user-card-background">
          <!-- 网格图案 -->
          <div class="user-card-pattern" />

          <!-- 浮动装饰球 -->
          <div class="user-card-blob-1" />
          <div class="user-card-blob-2" />
          <div class="user-card-blob-3" />

          <!-- 渐变遮罩 -->
          <div class="gradient-mask" />
        </div>

        <div class="user-card-content">
          <!-- 用户头像和基本信息 -->
          <div class="user-card-header">
            <!-- 头像区域 -->
            <div class="user-avatar-wrapper">
              <div class="user-avatar-container">
                <!-- 头像光环 -->
                <div class="user-avatar-glow" />

                <!-- 头像容器 -->
                <div class="user-avatar-image-wrapper">
                  <img
                    v-if="user?.avatarUrl"
                    :src="user.avatarUrl"
                    :alt="user.name"
                    class="user-avatar-image"
                  >
                  <div
                    v-else
                    class="user-avatar-fallback"
                  >
                    {{ getInitials(user?.name || '') }}
                  </div>
                </div>
              </div>

              <!-- 编辑按钮 -->
              <button
                class="user-avatar-edit-button"
                aria-label="编辑头像"
                @click="handleAvatarEdit"
              >
                <Camera class="user-avatar-edit-icon" />
              </button>
            </div>

            <!-- 用户信息 -->
            <div class="user-info">
              <div class="user-name-row">
                <h2 class="user-name">
                  {{ user?.name || '用户' }}
                </h2>
                <span
                  class="user-role-badge badge-with-bg"
                  :class="getRoleClass(user?.role)"
                >
                  {{ getRoleText(user?.role) }}
                </span>
              </div>
              <p class="user-email">
                {{ user?.email || '' }}
              </p>
            </div>
          </div>

          <!-- 用户详细信息卡片 -->
          <div class="user-details-grid">
            <div class="user-detail-card">
              <div class="user-detail-card-glow" />
              <div class="user-detail-card-content">
                <div class="user-detail-label">
                  序列号
                </div>
                <div class="user-detail-value">
                  {{ formatSerialNum(user?.serialNum) }}
                </div>
              </div>
            </div>

            <div class="user-detail-card">
              <div class="user-detail-card-glow" />
              <div class="user-detail-card-content">
                <div class="user-detail-label">
                  时区
                </div>
                <div class="user-detail-value">
                  {{ user?.timezone || 'Asia/Shanghai' }}
                </div>
              </div>
            </div>

            <div class="user-detail-card">
              <div class="user-detail-card-glow" />
              <div class="user-detail-card-content">
                <div class="user-detail-label">
                  语言
                </div>
                <div class="user-detail-value">
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

<style scoped lang="postcss">
.user-display-wrapper {
  width: 100%;
}

.mobile-header {
  margin-bottom: 0;
}

.desktop-shadow {
  box-shadow: 0 25px 50px -12px rgba(147, 51, 234, 0.2);
}

.badge-with-bg {
  background-color: rgba(255, 255, 255, 0.2);
}

.gradient-mask {
  background: linear-gradient(to top, rgba(0, 0, 0, 0.1), transparent, transparent);
  inset: 0;
  position: absolute;
}
</style>
