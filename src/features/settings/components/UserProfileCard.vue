<script setup lang="ts">
  import { Camera, Edit } from 'lucide-vue-next';
  import { computed, ref } from 'vue';
  import type { AuthUser } from '@/schema/user';
  import { useAuthStore } from '@/stores/auth';
  import { toast } from '@/utils/toast';
  import AvatarEditModal from './AvatarEditModal.vue';
  import ProfileEditModal from './ProfileEditModal.vue';

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
  <div
    class="relative p-8 rounded-2xl bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 shadow-lg overflow-hidden"
  >
    <!-- 背景装饰 -->
    <div
      class="absolute inset-0 opacity-5 dark:opacity-10 pointer-events-none"
      style="background-image: url('data:image/svg+xml,%3Csvg width=\'60\' height=\'60\' viewBox=\'0 0 60 60\' xmlns=\'http://www.w3.org/2000/svg\'%3E%3Cg fill=\'none\' fill-rule=\'evenodd\'%3E%3Cg fill=\'%239333ea\' fill-opacity=\'1\'%3E%3Ccircle cx=\'30\' cy=\'30\' r=\'2\'/%3E%3C/g%3E%3C/g%3E%3C/svg%3E')"
    />

    <div class="relative z-10">
      <div class="flex flex-col sm:flex-row items-center sm:items-start gap-6 mb-8">
        <div class="relative shrink-0 group">
          <div class="relative w-24 h-24 rounded-full">
            <img
              v-if="user?.avatarUrl"
              :src="user.avatarUrl"
              :alt="user.name"
              class="w-full h-full rounded-full border-4 border-gray-200 dark:border-gray-700 object-cover shadow-xl"
            />
            <div
              v-else
              class="w-full h-full rounded-full border-4 border-gray-200 dark:border-gray-700 bg-gradient-to-br from-purple-500 to-blue-500 flex items-center justify-center text-2xl font-bold text-white shadow-xl"
            >
              {{ getInitials(user?.name || '') }}
            </div>
          </div>
          <button
            class="absolute right-0 bottom-0 p-2 rounded-full bg-blue-600 hover:bg-blue-700 text-white border-2 border-white dark:border-gray-800 shadow-lg transition-all hover:scale-110 focus:outline-none focus:ring-4 focus:ring-blue-500/20"
            @click="handleAvatarEdit"
          >
            <Camera class="w-4 h-4" />
          </button>
        </div>

        <div class="flex-1 text-center sm:text-left">
          <h2 class="text-2xl font-bold text-gray-900 dark:text-white mb-2">
            {{ user?.name || '用户' }}
          </h2>
          <p class="text-gray-600 dark:text-gray-400 mb-3">{{ user?.email || '' }}</p>
          <div>
            <span
              class="inline-block text-xs font-semibold px-3 py-1.5 rounded-full uppercase tracking-wide bg-purple-100 dark:bg-purple-900/30 text-purple-800 dark:text-purple-300"
            >
              {{ getRoleText(user?.role) }}
            </span>
          </div>
        </div>
      </div>

      <div class="grid grid-cols-1 sm:grid-cols-3 gap-6 mb-8">
        <div class="text-center p-4 rounded-lg bg-gray-50 dark:bg-gray-900/50">
          <div class="text-sm text-gray-600 dark:text-gray-400 mb-1">序列号</div>
          <div class="text-base font-semibold text-gray-900 dark:text-white wrap-break-words">
            {{ formatSerialNum(user?.serialNum) }}
          </div>
        </div>
        <div class="text-center p-4 rounded-lg bg-gray-50 dark:bg-gray-900/50">
          <div class="text-sm text-gray-600 dark:text-gray-400 mb-1">时区</div>
          <div class="text-base font-semibold text-gray-900 dark:text-white wrap-break-words">
            {{ user?.timezone || 'Asia/Shanghai' }}
          </div>
        </div>
        <div class="text-center p-4 rounded-lg bg-gray-50 dark:bg-gray-900/50">
          <div class="text-sm text-gray-600 dark:text-gray-400 mb-1">语言</div>
          <div class="text-base font-semibold text-gray-900 dark:text-white wrap-break-words">
            {{ getLanguageText(user?.language) }}
          </div>
        </div>
      </div>

      <!-- 只保留编辑资料按钮，移除退出登录按钮 -->
      <div class="flex justify-center">
        <button
          class="flex items-center gap-2 px-6 py-3 bg-blue-600 hover:bg-blue-700 text-white font-medium rounded-lg transition-colors shadow-md hover:shadow-lg"
          @click="handleEditProfile"
        >
          <Edit class="w-4 h-4" />
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
