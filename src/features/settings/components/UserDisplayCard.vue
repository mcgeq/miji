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
      <div class="relative p-4 rounded-2xl bg-gradient-to-br from-purple-600 to-blue-600 text-white shadow-lg overflow-hidden">
        <!-- 简化的背景装饰 -->
        <div class="absolute inset-0 pointer-events-none">
          <div class="absolute inset-0 opacity-30" style="background-image: url('data:image/svg+xml,%3Csvg width=\'60\' height=\'60\' viewBox=\'0 0 60 60\' xmlns=\'http://www.w3.org/2000/svg\'%3E%3Cg fill=\'none\' fill-rule=\'evenodd\'%3E%3Cg fill=\'%23ffffff\' fill-opacity=\'0.08\'%3E%3Ccircle cx=\'30\' cy=\'30\' r=\'2\'/%3E%3C/g%3E%3C/g%3E%3C/svg%3E')" />
          <div class="absolute -right-8 -top-8 w-20 h-20 rounded-full bg-white/10 blur-2xl" />
          <div class="absolute -left-4 -bottom-10 w-12 h-12 rounded-full bg-white/5 blur-xl" />
        </div>

        <div class="relative z-10">
          <div class="flex items-center gap-4">
            <!-- 头像区域 -->
            <div class="relative flex-shrink-0 group">
              <div class="relative w-12 h-12 transform transition-transform group-hover:scale-105">
                <!-- 头像光环 -->
                <div class="absolute -inset-0.5 bg-gradient-to-r from-white/30 to-white/10 rounded-full blur-sm" />

                <!-- 头像容器 -->
                <div class="relative h-full w-full">
                  <img
                    v-if="user?.avatarUrl"
                    :src="user.avatarUrl"
                    :alt="user.name"
                    class="w-full h-full rounded-full border-2 border-white/30 object-cover shadow-lg transition-all group-hover:border-white/50"
                  >
                  <div
                    v-else
                    class="w-full h-full rounded-full border-2 border-white/30 bg-white/20 backdrop-blur-sm flex items-center justify-center text-sm font-bold shadow-lg transition-all group-hover:border-white/50"
                  >
                    {{ getInitials(user?.name || '') }}
                  </div>
                </div>
              </div>

              <!-- 编辑按钮 -->
              <button
                class="absolute left-0 top-0 p-1 rounded-full bg-gradient-to-r from-blue-600 to-blue-600 border border-white shadow-md transition-all hover:scale-110 hover:shadow-lg focus:outline-none focus:ring-4 focus:ring-white/30"
                aria-label="编辑头像"
                @click="handleAvatarEdit"
              >
                <Camera class="w-2.5 h-2.5 text-white" />
              </button>
            </div>

            <!-- 用户信息 -->
            <div class="flex-1 min-w-0">
              <div class="flex items-center gap-2 mb-1">
                <h3 class="text-lg font-bold bg-gradient-to-r from-white to-white/90 bg-clip-text text-transparent truncate">
                  {{ user?.name || '用户' }}
                </h3>
                <span class="flex-shrink-0 text-xs font-semibold px-2 py-0.5 rounded-full uppercase tracking-wide bg-white/20 backdrop-blur-sm transition-transform hover:scale-105">
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
      <div class="relative p-8 rounded-3xl bg-gradient-to-br from-purple-600 to-blue-600 text-white overflow-hidden" style="box-shadow: 0 25px 50px -12px rgba(147, 51, 234, 0.2)">
        <!-- 动态背景装饰 -->
        <div class="absolute inset-0 pointer-events-none">
          <!-- 网格图案 -->
          <div class="absolute inset-0 opacity-30" style="background-image: url('data:image/svg+xml,%3Csvg width=\'60\' height=\'60\' viewBox=\'0 0 60 60\' xmlns=\'http://www.w3.org/2000/svg\'%3E%3Cg fill=\'none\' fill-rule=\'evenodd\'%3E%3Cg fill=\'%23ffffff\' fill-opacity=\'0.08\'%3E%3Ccircle cx=\'30\' cy=\'30\' r=\'2\'/%3E%3C/g%3E%3C/g%3E%3C/svg%3E')" />

          <!-- 浮动装饰球 -->
          <div class="absolute -right-12 -top-12 w-32 h-32 rounded-full bg-white/10 blur-3xl" />
          <div class="absolute -left-8 -bottom-16 w-24 h-24 rounded-full bg-white/5 blur-2xl" />
          <div class="absolute right-20 top-20 w-16 h-16 rounded-full bg-white/10 blur-xl" />

          <!-- 渐变遮罩 -->
          <div class="absolute inset-0 bg-gradient-to-t from-black/10 via-transparent to-transparent" />
        </div>

        <div class="relative z-10">
          <!-- 用户头像和基本信息 -->
          <div class="flex items-center gap-6 mb-10">
            <!-- 头像区域 -->
            <div class="relative flex-shrink-0 group">
              <div class="relative w-16 h-16 transform transition-transform group-hover:scale-105">
                <!-- 头像光环 -->
                <div class="absolute -inset-1 bg-gradient-to-r from-white/30 to-white/10 rounded-full blur-md" />

                <!-- 头像容器 -->
                <div class="relative h-full w-full">
                  <img
                    v-if="user?.avatarUrl"
                    :src="user.avatarUrl"
                    :alt="user.name"
                    class="w-full h-full rounded-full border-3 border-white/30 object-cover shadow-2xl transition-all group-hover:border-white/50"
                  >
                  <div
                    v-else
                    class="w-full h-full rounded-full border-3 border-white/30 bg-gradient-to-br from-white/20 to-white/10 backdrop-blur-md flex items-center justify-center text-lg font-bold shadow-2xl transition-all group-hover:border-white/50"
                  >
                    {{ getInitials(user?.name || '') }}
                  </div>
                </div>
              </div>

              <!-- 编辑按钮 -->
              <button
                class="absolute left-0 top-0 p-1.5 rounded-full bg-gradient-to-r from-blue-600 to-blue-600 border-2 border-white shadow-lg transition-all hover:scale-110 hover:shadow-2xl focus:outline-none focus:ring-4 focus:ring-white/30"
                aria-label="编辑头像"
                @click="handleAvatarEdit"
              >
                <Camera class="w-3 h-3 text-white" />
              </button>
            </div>

            <!-- 用户信息 -->
            <div class="flex-1 min-w-0">
              <div class="flex items-center gap-3 mb-1">
                <h2 class="text-2xl font-bold bg-gradient-to-r from-white to-white/90 bg-clip-text text-transparent truncate">
                  {{ user?.name || '用户' }}
                </h2>
                <span class="flex-shrink-0 text-xs font-semibold px-3 py-1.5 rounded-full uppercase tracking-wide bg-white/20 backdrop-blur-md transition-transform hover:scale-105">
                  {{ getRoleText(user?.role) }}
                </span>
              </div>
              <p class="text-base text-white/80 font-medium truncate">
                {{ user?.email || '' }}
              </p>
            </div>
          </div>

          <!-- 用户详细信息卡片 -->
          <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
            <div class="relative p-6 text-center rounded-2xl bg-white/10 backdrop-blur-xl overflow-hidden transition-all hover:bg-white/15 hover:shadow-lg hover:scale-105 group">
              <div class="absolute inset-0 bg-gradient-to-br from-white/5 to-transparent opacity-0 group-hover:opacity-100 transition-opacity" />
              <div class="relative z-10">
                <div class="text-xs text-white/70 font-semibold uppercase tracking-widest mb-2">
                  序列号
                </div>
                <div class="text-white font-bold px-1 break-words">
                  {{ formatSerialNum(user?.serialNum) }}
                </div>
              </div>
            </div>

            <div class="relative p-6 text-center rounded-2xl bg-white/10 backdrop-blur-xl overflow-hidden transition-all hover:bg-white/15 hover:shadow-lg hover:scale-105 group">
              <div class="absolute inset-0 bg-gradient-to-br from-white/5 to-transparent opacity-0 group-hover:opacity-100 transition-opacity" />
              <div class="relative z-10">
                <div class="text-xs text-white/70 font-semibold uppercase tracking-widest mb-2">
                  时区
                </div>
                <div class="text-white font-bold px-1 break-words">
                  {{ user?.timezone || 'Asia/Shanghai' }}
                </div>
              </div>
            </div>

            <div class="relative p-6 text-center rounded-2xl bg-white/10 backdrop-blur-xl overflow-hidden transition-all hover:bg-white/15 hover:shadow-lg hover:scale-105 group">
              <div class="absolute inset-0 bg-gradient-to-br from-white/5 to-transparent opacity-0 group-hover:opacity-100 transition-opacity" />
              <div class="relative z-10">
                <div class="text-xs text-white/70 font-semibold uppercase tracking-widest mb-2">
                  语言
                </div>
                <div class="text-white font-bold px-1 break-words">
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
