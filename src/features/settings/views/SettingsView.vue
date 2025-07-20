<script setup lang="ts">
import {
  Bell,
  Lock,
  Settings,
  Shield,
  User,
} from 'lucide-vue-next';
import UserProfileCard from '../components/UserProfileCard.vue';
import GeneralSettings from './GeneralSettings.vue';
import NotificationSettings from './NotificationSettings.vue';
import PrivacySettings from './PrivacySettings.vue';
import SecuritySettings from './SecuritySettings.vue';

const activeTab = ref('general');

const tabs = [
  { id: 'general', label: '通用', icon: Settings },
  { id: 'account', label: '账户', icon: User },
  { id: 'security', label: '安全', icon: Shield },
  { id: 'notifications', label: '通知', icon: Bell },
  { id: 'privacy', label: '隐私', icon: Lock },
];

const currentTabComponent = computed(() => {
  const componentMap = {
    general: GeneralSettings,
    account: UserProfileCard,
    security: SecuritySettings,
    notifications: NotificationSettings,
    privacy: PrivacySettings,
  };
  return componentMap[activeTab.value as keyof typeof componentMap] || GeneralSettings;
});
</script>

<template>
  <div class="mx-auto max-w-7xl min-h-screen bg-gray-50 p-8">
    <div class="mb-8">
      <h1 class="mb-2 text-4xl text-slate-800 font-bold">
        设置
      </h1>
      <p class="text-lg text-slate-600">
        管理您的账户设置和偏好
      </p>
    </div>

    <div class="grid grid-cols-1 gap-8 lg:grid-cols-4">
      <!-- 用户信息卡片 -->
      <div class="lg:col-span-4">
        <UserProfileCard />
      </div>

      <!-- 侧边栏 -->
      <div class="lg:col-span-1">
        <div class="sticky top-8">
          <div class="flex flex-col gap-2">
            <button
              v-for="tab in tabs"
              :key="tab.id"
              class="w-full flex items-center gap-3 rounded-lg px-4 py-3 text-left transition-all duration-200" :class="[
                activeTab === tab.id
                  ? 'bg-blue-500 text-white shadow-lg'
                  : 'bg-white text-slate-600 hover:bg-slate-50 hover:text-slate-800 border border-slate-200',
              ]"
              @click="activeTab = tab.id"
            >
              <component :is="tab.icon" class="h-5 w-5" />
              {{ tab.label }}
            </button>
          </div>
        </div>
      </div>

      <!-- 设置内容区域 -->
      <div class="lg:col-span-3">
        <div class="border border-slate-200 rounded-xl bg-white p-8 shadow-sm">
          <component :is="currentTabComponent" />
        </div>
      </div>
    </div>
  </div>
</template>
