<script setup lang="ts">
  import { Bell, Clock, Database, Lock, Settings, Shield, User } from 'lucide-vue-next';
  import { useRoute } from 'vue-router';
  import SchedulerSettingsTabs from '@/components/settings/SchedulerSettingsTabs.vue';
  import DataMigration from '../components/DataMigration.vue';
  import UserDisplayCard from '../components/UserDisplayCard.vue';
  import UserProfileCard from '../components/UserProfileCard.vue';
  import GeneralSettings from './GeneralSettings.vue';
  import NotificationSettings from './NotificationSettings.vue';
  import PrivacySettings from './PrivacySettings.vue';
  import SecuritySettings from './SecuritySettings.vue';

  const route = useRoute();

  // 从路由查询参数中读取标签，默认为 'general'
  const activeTab = ref((route.query.tab as string) || 'general');

  const tabs = [
    { id: 'general', label: '通用', icon: Settings },
    { id: 'account', label: '账户', icon: User },
    { id: 'security', label: '安全', icon: Shield },
    { id: 'notifications', label: '通知', icon: Bell },
    { id: 'scheduler', label: '调度器', icon: Clock },
    { id: 'privacy', label: '隐私', icon: Lock },
    { id: 'data', label: '数据', icon: Database },
  ];

  const currentTabComponent = computed(() => {
    const componentMap = {
      general: GeneralSettings,
      account: UserProfileCard,
      security: SecuritySettings,
      notifications: NotificationSettings,
      scheduler: SchedulerSettingsTabs,
      privacy: PrivacySettings,
      data: DataMigration,
    };
    return componentMap[activeTab.value as keyof typeof componentMap] || GeneralSettings;
  });
</script>

<template>
  <div class="min-h-screen bg-gray-50 dark:bg-gray-900 p-6">
    <div class="max-w-7xl mx-auto space-y-6">
      <!-- 顶部：用户信息卡片和标签导航 -->
      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <!-- 用户信息卡片 - 占2/3宽度 -->
        <div class="lg:col-span-2">
          <UserDisplayCard />
        </div>

        <!-- 标签导航 - 占1/3宽度 -->
        <div class="lg:col-span-1">
          <div
            class="bg-white dark:bg-gray-800 rounded-xl shadow-sm border border-gray-200 dark:border-gray-700 p-3 h-full flex flex-col justify-center"
          >
            <div class="grid grid-cols-3 gap-2">
              <button
                v-for="tab in tabs"
                :key="tab.id"
                class="flex flex-col items-center justify-center gap-1 p-2.5 rounded-lg transition-all duration-200"
                :class="activeTab === tab.id
                  ? 'bg-blue-50 dark:bg-blue-900/20 text-blue-600 dark:text-blue-400 shadow-sm'
                  : 'text-gray-600 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-700/50'"
                @click="activeTab = tab.id"
              >
                <component :is="tab.icon" class="w-4 h-4" />
                <span class="text-xs font-medium">{{ tab.label }}</span>
              </button>
            </div>
          </div>
        </div>
      </div>

      <!-- 设置内容区域 - 下方铺满 -->
      <div
        class="bg-white dark:bg-gray-800 rounded-xl shadow-sm border border-gray-200 dark:border-gray-700"
        :class="activeTab === 'account' ? 'p-0' : 'p-6'"
      >
        <component :is="currentTabComponent" />
      </div>
    </div>
  </div>
</template>
