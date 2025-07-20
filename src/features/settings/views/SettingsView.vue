<script setup lang="ts">
import {
  Bell,
  Lock,
  Settings,
  Shield,
  User,
} from 'lucide-vue-next';
import UserDisplayCard from '../components/UserDisplayCard.vue';
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
    <div class="mb-2">
      <p class="text-lg text-slate-600">
        管理您的账户设置和偏好
      </p>
    </div>

    <div class="space-y-8">
      <!-- 顶部：用户信息卡片和标签导航 -->
      <div class="flex flex-col items-stretch gap-8 lg:flex-row">
        <!-- 用户信息卡片 - 占2/3宽度 -->
        <div class="w-full lg:w-2/3">
          <UserDisplayCard />
        </div>

        <!-- 标签导航 - 占1/3宽度 -->
        <div class="w-full lg:w-1/3">
          <div class="h-full flex flex-col justify-between border border-slate-200 rounded-xl bg-white p-6 shadow-sm">
            <div class="h-full flex flex-col justify-between">
              <div>
                <div class="grid grid-cols-2 gap-3 sm:grid-cols-3">
                  <button
                    v-for="tab in tabs"
                    :key="tab.id"
                    class="min-h-[3.5rem] flex items-center gap-3 rounded-lg px-4 py-3 text-left transition-all duration-200"
                    :class="[
                      activeTab === tab.id
                        ? 'bg-blue-500 text-white shadow-lg'
                        : 'bg-gray-50 text-slate-600 hover:bg-gray-100 hover:text-slate-800 border border-slate-200',
                    ]"
                    @click="activeTab = tab.id"
                  >
                    <component :is="tab.icon" class="h-5 w-5 flex-shrink-0" />
                    <span class="text-sm font-medium">{{ tab.label }}</span>
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- 设置内容区域 - 下方铺满 -->
      <div class="w-full">
        <div class="border border-slate-200 rounded-xl bg-white p-8 shadow-sm">
          <component :is="currentTabComponent" />
        </div>
      </div>
    </div>
  </div>
</template>
