<script setup lang="ts">
  import { Download, FileUp, Plus, Settings, Trash2 } from 'lucide-vue-next';
  import Modal from '@/components/ui/Modal.vue';
  import { invokeCommand, isBusinessError } from '@/types/api';
  import { toast } from '@/utils/toast';

  interface SettingProfile {
    serialNum: string;
    userSerialNum: string;
    profileName: string;
    profileData: Record<string, unknown>;
    isActive: boolean;
    isDefault: boolean;
    description?: string;
    createdAt: string;
    updatedAt: string;
  }

  interface ProfileExportData {
    profileName: string;
    profileData: Record<string, unknown>;
    description?: string;
    exportedAt: string;
  }

  // 状态
  const profiles = ref<SettingProfile[]>([]);
  const isLoading = ref(false);
  const showCreateModal = ref(false);
  const showDeleteModal = ref(false);
  const selectedProfile = ref<SettingProfile | null>(null);

  // 新建表单
  const newProfileName = ref('');
  const newProfileDescription = ref('');

  // 加载配置方案列表
  async function loadProfiles() {
    isLoading.value = true;
    try {
      profiles.value = await invokeCommand<SettingProfile[]>('user_setting_profile_list');
    } catch (error) {
      console.error('加载配置方案失败:', error);
      const message = isBusinessError(error) ? error.description : '加载配置方案失败';
      toast.error(message);
    } finally {
      isLoading.value = false;
    }
  }

  // 从当前设置创建方案
  async function createFromCurrent() {
    if (!newProfileName.value.trim()) {
      toast.error('请输入配置方案名称');
      return;
    }

    try {
      await invokeCommand<SettingProfile>('user_setting_profile_create_from_current', {
        profileName: newProfileName.value,
        description: newProfileDescription.value || null,
      });

      toast.success(`配置方案 "${newProfileName.value}" 创建成功`);
      newProfileName.value = '';
      newProfileDescription.value = '';
      showCreateModal.value = false;
      await loadProfiles();
    } catch (error) {
      console.error('创建配置方案失败:', error);
      const message = isBusinessError(error) ? error.description : '创建配置方案失败';
      toast.error(message);
    }
  }

  // 切换配置方案
  async function switchProfile(profile: SettingProfile) {
    if (profile.isActive) {
      toast.info('已经是当前激活的配置方案');
      return;
    }

    try {
      await invokeCommand<SettingProfile>('user_setting_profile_switch', {
        profileSerialNum: profile.serialNum,
      });

      toast.success(`已切换到 "${profile.profileName}" 配置`);
      await loadProfiles();
      // 刷新页面以应用新配置
      window.location.reload();
    } catch (error) {
      console.error('切换配置方案失败:', error);
      const message = isBusinessError(error) ? error.description : '切换配置方案失败';
      toast.error(message);
    }
  }

  // 删除配置方案
  async function deleteProfile() {
    if (!selectedProfile.value) return;

    const profileName = selectedProfile.value.profileName;

    try {
      await invokeCommand<boolean>('user_setting_profile_delete', {
        profileSerialNum: selectedProfile.value.serialNum,
      });

      toast.success(`配置方案 "${profileName}" 已删除`);
      showDeleteModal.value = false;
      selectedProfile.value = null;
      await loadProfiles();
    } catch (error) {
      console.error('删除配置方案失败:', error);
      const message = isBusinessError(error) ? error.description : '删除配置方案失败';
      toast.error(message);
    }
  }

  // 导出配置方案
  async function exportProfile(profile: SettingProfile) {
    try {
      const data = await invokeCommand<ProfileExportData>('user_setting_profile_export', {
        profileSerialNum: profile.serialNum,
      });

      // 下载为JSON文件
      const dataStr = JSON.stringify(data, null, 2);
      const blob = new Blob([dataStr], { type: 'application/json' });
      const url = URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.download = `${profile.profileName}-config.json`;
      link.click();
      URL.revokeObjectURL(url);
      toast.success('配置方案已导出');
    } catch (error) {
      console.error('导出配置方案失败:', error);
      const message = isBusinessError(error) ? error.description : '导出配置方案失败';
      toast.error(message);
    }
  }

  // 导入配置方案
  async function importProfile(event: Event) {
    const input = event.target as HTMLInputElement;
    const file = input.files?.[0];
    if (!file) return;

    try {
      const text = await file.text();
      const importData = JSON.parse(text);

      await invokeCommand<SettingProfile>('user_setting_profile_import', {
        importData,
      });

      toast.success('配置方案导入成功');
      await loadProfiles();
    } catch (error) {
      console.error('导入配置方案失败:', error);
      if (error instanceof SyntaxError) {
        toast.error('文件格式错误，请检查 JSON 格式');
      } else {
        const message = isBusinessError(error) ? error.description : '导入配置方案失败';
        toast.error(message);
      }
    } finally {
      // 清空文件输入
      input.value = '';
    }
  }

  // 组件挂载时加载
  onMounted(() => {
    loadProfiles();
  });
</script>

<template>
  <div class="max-w-4xl w-full">
    <!-- 标题和操作按钮 -->
    <div class="flex items-center justify-between mb-6">
      <h3 class="text-xl font-semibold text-gray-900 dark:text-white">
        {{ $t('settings.profiles.title') || '配置方案管理' }}
      </h3>
      <div class="flex gap-2">
        <!-- 导入按钮 -->
        <label
          class="px-4 py-2 border border-gray-300 dark:border-gray-600 text-gray-700 dark:text-gray-300 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors cursor-pointer flex items-center gap-2"
        >
          <FileUp class="w-4 h-4" />
          <span class="hidden sm:inline">{{ $t('settings.profiles.import') || '导入' }}</span>
          <input type="file" accept=".json" class="hidden" @change="importProfile" />
        </label>

        <!-- 新建按钮 -->
        <button
          class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors flex items-center gap-2"
          @click="showCreateModal = true"
        >
          <Plus class="w-4 h-4" />
          <span class="hidden sm:inline">{{ $t('settings.profiles.create') || '新建方案' }}</span>
        </button>
      </div>
    </div>

    <!-- 配置方案列表 -->
    <div v-if="isLoading" class="text-center py-8">
      <div
        class="animate-spin w-8 h-8 border-4 border-blue-500 border-t-transparent rounded-full mx-auto"
      />
    </div>

    <div
      v-else-if="profiles.length === 0"
      class="text-center py-8 text-gray-500 dark:text-gray-400"
    >
      <Settings class="w-12 h-12 mx-auto mb-2 opacity-50" />
      <p>{{ $t('settings.profiles.empty') || '暂无配置方案' }}</p>
    </div>

    <div v-else class="space-y-3">
      <div
        v-for="profile in profiles"
        :key="profile.serialNum"
        class="p-4 rounded-lg border transition-all"
        :class="profile.isActive 
          ? 'border-blue-500 bg-blue-50 dark:bg-blue-900/20' 
          : 'border-gray-200 dark:border-gray-700 hover:border-gray-300 dark:hover:border-gray-600'"
      >
        <div class="flex items-start justify-between">
          <div class="flex-1">
            <div class="flex items-center gap-2 mb-1">
              <h4 class="font-medium text-gray-900 dark:text-white">{{ profile.profileName }}</h4>
              <span
                v-if="profile.isActive"
                class="px-2 py-0.5 text-xs font-semibold rounded bg-blue-500 text-white"
              >
                {{ $t('settings.profiles.active') || '当前' }}
              </span>
              <span
                v-if="profile.isDefault"
                class="px-2 py-0.5 text-xs rounded bg-gray-200 dark:bg-gray-700 text-gray-700 dark:text-gray-300"
              >
                {{ $t('settings.profiles.default') || '默认' }}
              </span>
            </div>
            <p v-if="profile.description" class="text-sm text-gray-600 dark:text-gray-400 mb-2">
              {{ profile.description }}
            </p>
            <p class="text-xs text-gray-500 dark:text-gray-500">
              {{ $t('settings.profiles.createdAt') || '创建于' }}:
              {{ new Date(profile.createdAt).toLocaleString() }}
            </p>
          </div>

          <!-- 操作按钮 -->
          <div class="flex gap-2">
            <button
              v-if="!profile.isActive"
              class="p-2 text-blue-600 hover:bg-blue-100 dark:hover:bg-blue-900/30 rounded transition-colors"
              :title="$t('settings.profiles.switch') || '切换'"
              @click="switchProfile(profile)"
            >
              <Settings class="w-4 h-4" />
            </button>

            <button
              class="p-2 text-gray-600 hover:bg-gray-100 dark:hover:bg-gray-700 rounded transition-colors"
              :title="$t('settings.profiles.export') || '导出'"
              @click="exportProfile(profile)"
            >
              <Download class="w-4 h-4" />
            </button>

            <button
              v-if="!profile.isDefault && !profile.isActive"
              class="p-2 text-red-600 hover:bg-red-100 dark:hover:bg-red-900/30 rounded transition-colors"
              :title="$t('settings.profiles.delete') || '删除'"
              @click="selectedProfile = profile; showDeleteModal = true"
            >
              <Trash2 class="w-4 h-4" />
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- 新建配置方案模态框 -->
    <Modal
      :open="showCreateModal"
      :title="$t('settings.profiles.createFromCurrent') || '保存当前配置为方案'"
      size="md"
      :confirm-disabled="!newProfileName.trim()"
      @close="showCreateModal = false; newProfileName = ''; newProfileDescription = ''"
      @confirm="createFromCurrent"
      @cancel="showCreateModal = false; newProfileName = ''; newProfileDescription = ''"
    >
      <div class="space-y-4">
        <div>
          <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
            {{ $t('settings.profiles.profileName') || '方案名称' }}*
          </label>
          <input
            v-model="newProfileName"
            type="text"
            class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-white"
            :placeholder="$t('settings.profiles.profileNamePlaceholder') || '例如：工作配置'"
          />
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
            {{ $t('settings.profiles.description') || '描述' }}
          </label>
          <textarea
            v-model="newProfileDescription"
            rows="3"
            class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-white"
            :placeholder="$t('settings.profiles.descriptionPlaceholder') || '可选，描述此配置方案的用途'"
          />
        </div>
      </div>
    </Modal>

    <!-- 删除确认模态框 -->
    <Modal
      v-if="selectedProfile"
      :open="showDeleteModal"
      :title="$t('settings.profiles.deleteConfirm') || '确认删除'"
      size="md"
      :show-confirm="false"
      :show-cancel="true"
      :show-delete="true"
      @close="showDeleteModal = false; selectedProfile = null"
      @cancel="showDeleteModal = false; selectedProfile = null"
      @delete="deleteProfile"
    >
      <p class="text-gray-600 dark:text-gray-400">
        {{ $t('settings.profiles.deleteMessage') || '确定要删除配置方案' }}"
        {{ selectedProfile.profileName }}"
        {{ $t('settings.profiles.deleteMessageEnd') || ' 吗？此操作无法撤销。' }}
      </p>
    </Modal>
  </div>
</template>
