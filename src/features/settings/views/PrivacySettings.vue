<script setup lang="ts">
  import { Camera, Download, FileText, MapPin, Mic, RotateCcw, Trash } from 'lucide-vue-next';
  import type { Component } from 'vue';
  import { useI18n } from 'vue-i18n';
  import ToggleSwitch from '@/components/ToggleSwitch.vue';
  import Modal from '@/components/ui/Modal.vue';
  import { createDatabaseSetting, useAutoSaveSettings } from '@/composables/useAutoSaveSettings';
  import { toast } from '@/utils/toast';

  const { t } = useI18n();

  type PermissionStatus = 'denied' | 'granted' | 'prompt';

  interface Permission {
    id: string;
    name: string;
    description: string;
    icon: Component;
    status: PermissionStatus;
  }

  // 默认权限列表
  const defaultPermissions = computed(() => [
    {
      id: 'camera',
      name: t('settings.privacy.camera'),
      description: t('settings.privacy.cameraDesc'),
      icon: Camera,
      status: 'denied',
    },
    {
      id: 'microphone',
      name: t('settings.privacy.microphone'),
      description: t('settings.privacy.microphoneDesc'),
      icon: Mic,
      status: 'granted',
    },
    {
      id: 'location',
      name: t('settings.privacy.location'),
      description: t('settings.privacy.locationDesc'),
      icon: MapPin,
      status: 'prompt',
    },
    {
      id: 'files',
      name: t('settings.privacy.files'),
      description: t('settings.privacy.filesDesc'),
      icon: FileText,
      status: 'granted',
    },
  ]);

  // 使用自动保存设置系统
  const { fields, isSaving, resetAll } = useAutoSaveSettings({
    moduleName: 'privacy',
    fields: {
      dataCollection: createDatabaseSetting({
        key: 'settings.privacy.dataCollection',
        defaultValue: true,
      }),
      analytics: createDatabaseSetting({
        key: 'settings.privacy.analytics',
        defaultValue: true,
      }),
      crashReports: createDatabaseSetting({
        key: 'settings.privacy.crashReports',
        defaultValue: true,
      }),
      profileVisibility: createDatabaseSetting({
        key: 'settings.privacy.profileVisibility',
        defaultValue: 'public',
      }),
      showOnlineStatus: createDatabaseSetting({
        key: 'settings.privacy.showOnlineStatus',
        defaultValue: true,
      }),
      showLastActive: createDatabaseSetting({
        key: 'settings.privacy.showLastActive',
        defaultValue: true,
      }),
      searchIndexing: createDatabaseSetting({
        key: 'settings.privacy.searchIndexing',
        defaultValue: false,
      }),
      permissions: createDatabaseSetting({
        key: 'settings.privacy.permissions',
        defaultValue: defaultPermissions.value,
      }),
    },
  });

  // 清除数据
  const showClearData = ref(false);
  const selectedClearTypes = ref<string[]>([]);

  const clearDataTypes = computed(() => [
    {
      id: 'cache',
      name: t('settings.privacy.clearDataDialog.cache'),
      description: t('settings.privacy.clearDataDialog.cacheDesc'),
    },
    {
      id: 'history',
      name: t('settings.privacy.clearDataDialog.history'),
      description: t('settings.privacy.clearDataDialog.historyDesc'),
    },
    {
      id: 'cookies',
      name: t('settings.privacy.clearDataDialog.cookies'),
      description: t('settings.privacy.clearDataDialog.cookiesDesc'),
    },
    {
      id: 'localStorage',
      name: t('settings.privacy.clearDataDialog.localStorage'),
      description: t('settings.privacy.clearDataDialog.localStorageDesc'),
    },
  ]);

  // 获取权限状态文本
  function getPermissionStatusText(status: string) {
    const texts: Record<string, string> = {
      granted: t('settings.privacy.permissionStatus.granted'),
      denied: t('settings.privacy.permissionStatus.denied'),
      prompt: t('settings.privacy.permissionStatus.prompt'),
    };
    return texts[status] || status;
  }

  // 切换权限状态
  function togglePermission(permissionId: string) {
    const permissions = fields.permissions.value.value as Permission[];
    const permission = permissions.find(p => p.id === permissionId);
    if (permission) {
      permission.status = permission.status === 'granted' ? 'denied' : 'granted';
    }
  }

  // 请求数据导出
  function requestDataExport() {
    toast.info('请求数据导出');
    // 这里可以实现实际的数据导出逻辑
  }

  // 清除选中的数据
  function clearSelectedData() {
    toast.info(`清除数据类型:, ${selectedClearTypes.value}`);
    showClearData.value = false;
    selectedClearTypes.value = [];
  }

  // 重置为默认
  async function handleReset() {
    await resetAll();
    toast.info(t('settings.privacy.resetPrivacy'));
  }
</script>

<template>
  <div class="max-w-4xl w-full">
    <!-- 数据隐私 -->
    <div class="mb-10">
      <h3
        class="text-xl font-semibold text-gray-900 dark:text-white mb-6 pb-2 border-b-2 border-gray-200 dark:border-gray-700"
      >
        {{ $t('settings.privacy.dataPrivacy') }}
      </h3>

      <div class="space-y-6">
        <div
          class="flex flex-col sm:flex-row sm:items-center sm:justify-between py-6 border-b border-gray-200 dark:border-gray-700"
        >
          <div class="mb-4 sm:mb-0">
            <label class="block font-medium text-gray-900 dark:text-white mb-1">
              {{ $t('settings.privacy.dataCollection') }}
            </label>
            <p class="text-sm text-gray-600 dark:text-gray-400">
              {{ $t('settings.privacy.dataCollectionDesc') }}
            </p>
          </div>
          <div class="sm:ml-8">
            <ToggleSwitch v-model="fields.dataCollection.value.value" />
          </div>
        </div>

        <div
          class="flex flex-col sm:flex-row sm:items-center sm:justify-between py-6 border-b border-gray-200 dark:border-gray-700"
        >
          <div class="mb-4 sm:mb-0">
            <label class="block font-medium text-gray-900 dark:text-white mb-1">
              {{ $t('settings.privacy.analytics') }}
            </label>
            <p class="text-sm text-gray-600 dark:text-gray-400">
              {{ $t('settings.privacy.analyticsDesc') }}
            </p>
          </div>
          <div class="sm:ml-8">
            <ToggleSwitch v-model="fields.analytics.value.value" />
          </div>
        </div>

        <div
          class="flex flex-col sm:flex-row sm:items-center sm:justify-between py-6 border-b border-gray-200 dark:border-gray-700"
        >
          <div class="mb-4 sm:mb-0">
            <label class="block font-medium text-gray-900 dark:text-white mb-1">
              {{ $t('settings.privacy.crashReports') }}
            </label>
            <p class="text-sm text-gray-600 dark:text-gray-400">
              {{ $t('settings.privacy.crashReportsDesc') }}
            </p>
          </div>
          <div class="sm:ml-8">
            <ToggleSwitch v-model="fields.crashReports.value.value" />
          </div>
        </div>
      </div>
    </div>

    <!-- 个人信息 -->
    <div class="mb-10">
      <h3
        class="text-xl font-semibold text-gray-900 dark:text-white mb-6 pb-2 border-b-2 border-gray-200 dark:border-gray-700"
      >
        {{ $t('settings.privacy.personalInfo') }}
      </h3>

      <div class="space-y-6">
        <div
          class="flex flex-col sm:flex-row sm:items-center sm:justify-between py-6 border-b border-gray-200 dark:border-gray-700"
        >
          <div class="mb-4 sm:mb-0">
            <label class="block font-medium text-gray-900 dark:text-white mb-1">
              {{ $t('settings.privacy.profileVisibility') }}
            </label>
            <p class="text-sm text-gray-600 dark:text-gray-400">
              {{ $t('settings.privacy.profileVisibilityDesc') }}
            </p>
          </div>
          <div class="sm:ml-8">
            <select
              v-model="fields.profileVisibility.value.value"
              class="w-full sm:w-48 px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20 focus:outline-none"
            >
              <option value="public">{{ $t('settings.privacy.visibilityOptions.public') }}</option>
              <option value="friends">
                {{ $t('settings.privacy.visibilityOptions.friends') }}
              </option>
              <option value="private">
                {{ $t('settings.privacy.visibilityOptions.private') }}
              </option>
            </select>
          </div>
        </div>

        <div
          class="flex flex-col sm:flex-row sm:items-center sm:justify-between py-6 border-b border-gray-200 dark:border-gray-700"
        >
          <div class="mb-4 sm:mb-0">
            <label class="block font-medium text-gray-900 dark:text-white mb-1">
              {{ $t('settings.privacy.onlineStatus') }}
            </label>
            <p class="text-sm text-gray-600 dark:text-gray-400">
              {{ $t('settings.privacy.onlineStatusDesc') }}
            </p>
          </div>
          <div class="sm:ml-8">
            <ToggleSwitch v-model="fields.showOnlineStatus.value.value" />
          </div>
        </div>

        <div
          class="flex flex-col sm:flex-row sm:items-center sm:justify-between py-6 border-b border-gray-200 dark:border-gray-700"
        >
          <div class="mb-4 sm:mb-0">
            <label class="block font-medium text-gray-900 dark:text-white mb-1">
              {{ $t('settings.privacy.lastActive') }}
            </label>
            <p class="text-sm text-gray-600 dark:text-gray-400">
              {{ $t('settings.privacy.lastActiveDesc') }}
            </p>
          </div>
          <div class="sm:ml-8">
            <ToggleSwitch v-model="fields.showLastActive.value.value" />
          </div>
        </div>

        <div
          class="flex flex-col sm:flex-row sm:items-center sm:justify-between py-6 border-b border-gray-200 dark:border-gray-700"
        >
          <div class="mb-4 sm:mb-0">
            <label class="block font-medium text-gray-900 dark:text-white mb-1">
              {{ $t('settings.privacy.searchIndexing') }}
            </label>
            <p class="text-sm text-gray-600 dark:text-gray-400">
              {{ $t('settings.privacy.searchIndexingDesc') }}
            </p>
          </div>
          <div class="sm:ml-8">
            <ToggleSwitch v-model="fields.searchIndexing.value.value" />
          </div>
        </div>
      </div>
    </div>

    <!-- 数据管理 -->
    <div class="mb-10">
      <h3
        class="text-xl font-semibold text-gray-900 dark:text-white mb-6 pb-2 border-b-2 border-gray-200 dark:border-gray-700"
      >
        {{ $t('settings.privacy.dataManagement') }}
      </h3>

      <div class="space-y-6">
        <div
          class="flex flex-col sm:flex-row sm:items-center sm:justify-between py-6 border-b border-gray-200 dark:border-gray-700"
        >
          <div class="mb-4 sm:mb-0">
            <label class="block font-medium text-gray-900 dark:text-white mb-1">
              {{ $t('settings.privacy.downloadData') }}
            </label>
            <p class="text-sm text-gray-600 dark:text-gray-400">
              {{ $t('settings.privacy.downloadDataDesc') }}
            </p>
          </div>
          <div class="sm:ml-8">
            <button
              class="flex items-center gap-2 px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white font-medium rounded-lg transition-colors"
              @click="requestDataExport"
            >
              <Download class="w-4 h-4" />
              {{ $t('settings.privacy.requestDownload') }}
            </button>
          </div>
        </div>

        <div
          class="flex flex-col sm:flex-row sm:items-center sm:justify-between py-6 border-b border-gray-200 dark:border-gray-700"
        >
          <div class="mb-4 sm:mb-0">
            <label class="block font-medium text-gray-900 dark:text-white mb-1">
              {{ $t('settings.privacy.clearBrowsingData') }}
            </label>
            <p class="text-sm text-gray-600 dark:text-gray-400">
              {{ $t('settings.privacy.clearBrowsingDataDesc') }}
            </p>
          </div>
          <div class="sm:ml-8">
            <button
              class="flex items-center gap-2 px-4 py-2 border border-gray-300 dark:border-gray-600 hover:bg-gray-50 dark:hover:bg-gray-700 text-gray-900 dark:text-white font-medium rounded-lg transition-colors"
              @click="showClearData = true"
            >
              <Trash class="w-4 h-4" />
              {{ $t('settings.privacy.clearData') }}
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- 权限管理 -->
    <div class="mb-10">
      <h3
        class="text-xl font-semibold text-gray-900 dark:text-white mb-6 pb-2 border-b-2 border-gray-200 dark:border-gray-700"
      >
        {{ $t('settings.privacy.permissions') }}
      </h3>

      <div class="space-y-4">
        <div
          v-for="permission in fields.permissions.value.value"
          :key="permission.id"
          class="flex items-center justify-between p-4 border border-gray-200 dark:border-gray-700 rounded-lg bg-white dark:bg-gray-800"
        >
          <div class="flex items-center gap-4">
            <component :is="permission.icon" class="w-5 h-5 text-gray-600 dark:text-gray-400" />
            <div>
              <div class="font-medium text-gray-900 dark:text-white">{{ permission.name }}</div>
              <div class="text-sm text-gray-600 dark:text-gray-400">
                {{ permission.description }}
              </div>
            </div>
          </div>
          <div class="flex items-center gap-2">
            <span
              class="text-xs font-medium px-2 py-1 rounded"
              :class="permission.status === 'granted' ? 'bg-green-500 text-white' : permission.status === 'denied' ? 'bg-red-500 text-white' : 'bg-amber-500 text-white'"
            >
              {{ getPermissionStatusText(permission.status) }}
            </span>
            <button
              class="text-xs px-3 py-1 border border-gray-300 dark:border-gray-600 hover:bg-gray-50 dark:hover:bg-gray-700 rounded transition-colors"
              @click="togglePermission(permission.id)"
            >
              {{ permission.status === 'granted' ? $t('settings.privacy.revoke') : $t('settings.privacy.grant') }}
            </button>
          </div>
        </div>
      </div>
    </div>
    <!-- 操作按钮 -->
    <div class="pt-8 border-t border-gray-200 dark:border-gray-700 flex justify-center gap-4">
      <button
        :title="$t('settings.general.resetSettings')"
        class="flex items-center justify-center w-12 h-12 rounded-full bg-gray-100 hover:bg-gray-200 dark:bg-gray-700 dark:hover:bg-gray-600 text-gray-900 dark:text-white transition-colors"
        @click="handleReset"
      >
        <RotateCcw class="w-5 h-5" />
      </button>
      <button
        :title="$t('settings.privacy.downloadData')"
        class="flex items-center justify-center w-12 h-12 rounded-full border border-gray-300 dark:border-gray-600 hover:bg-gray-50 dark:hover:bg-gray-700 text-gray-900 dark:text-white transition-colors"
        @click="requestDataExport"
      >
        <Download class="w-5 h-5" />
      </button>
      <div
        v-if="isSaving"
        class="flex items-center justify-center w-12 h-12 text-gray-600 dark:text-gray-400"
      >
        <span class="animate-spin text-xl">⏳</span>
      </div>
    </div>

    <!-- 清除数据对话框 -->
    <Modal
      :open="showClearData"
      :title="$t('settings.privacy.clearDataDialog.title')"
      size="md"
      show-delete
      @close="showClearData = false"
      @delete="clearSelectedData"
      @cancel="showClearData = false"
    >
      <div class="space-y-4">
        <p class="text-sm text-gray-600 dark:text-gray-400">
          {{ $t('settings.privacy.clearDataDialog.description') }}
        </p>

        <div class="space-y-3">
          <label
            v-for="dataType in clearDataTypes"
            :key="dataType.id"
            class="flex items-start gap-3 cursor-pointer"
          >
            <input
              v-model="selectedClearTypes"
              :value="dataType.id"
              type="checkbox"
              class="mt-1 w-4 h-4 text-blue-600 bg-white dark:bg-gray-800 border-gray-300 dark:border-gray-600 rounded focus:ring-2 focus:ring-blue-500/20"
            />
            <div>
              <div class="font-medium text-gray-900 dark:text-white">{{ dataType.name }}</div>
              <div class="text-sm text-gray-600 dark:text-gray-400">{{ dataType.description }}</div>
            </div>
          </label>
        </div>
      </div>
    </Modal>
  </div>
</template>
