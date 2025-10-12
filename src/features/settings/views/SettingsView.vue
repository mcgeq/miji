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
  <div class="settings-container">
    <div class="settings-layout">
      <!-- 顶部：用户信息卡片和标签导航 -->
      <div class="settings-top-section">
        <!-- 用户信息卡片 - 占2/3宽度 -->
        <div class="settings-user-card">
          <UserDisplayCard />
        </div>

        <!-- 标签导航 - 占1/3宽度 -->
        <div class="settings-tabs-card">
          <div class="settings-card">
            <div>
              <div class="settings-tabs-grid">
                <button
                  v-for="tab in tabs"
                  :key="tab.id"
                  class="settings-tab-button"
                  :class="activeTab === tab.id ? 'settings-tab-active' : 'settings-tab-inactive'"
                  @click="activeTab = tab.id"
                >
                  <component :is="tab.icon" class="settings-tab-button-icon" />
                  <span class="settings-tab-button-label">{{ tab.label }}</span>
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- 设置内容区域 - 下方铺满 -->
      <div class="settings-content-card">
        <component :is="currentTabComponent" />
      </div>
    </div>
  </div>
</template>
