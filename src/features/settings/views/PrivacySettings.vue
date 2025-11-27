<script setup lang="ts">
import {
  Camera,
  Download,
  FileText,
  MapPin,
  Mic,
  RotateCcw,
  Save,
  Trash,
} from 'lucide-vue-next';
import { Lg } from '@/utils/debugLog';
import { toast } from '@/utils/toast';

// 数据隐私设置
const dataCollection = ref(true);
const analytics = ref(true);
const crashReports = ref(true);

// 个人信息设置
const profileVisibility = ref('public');
const showOnlineStatus = ref(true);
const showLastActive = ref(true);
const searchIndexing = ref(false);

// 权限管理
const permissions = ref([
  {
    id: 'camera',
    name: '摄像头',
    description: '拍照和录制视频',
    icon: Camera,
    status: 'denied',
  },
  {
    id: 'microphone',
    name: '麦克风',
    description: '录制音频',
    icon: Mic,
    status: 'granted',
  },
  {
    id: 'location',
    name: '位置信息',
    description: '访问您的地理位置',
    icon: MapPin,
    status: 'prompt',
  },
  {
    id: 'files',
    name: '文件访问',
    description: '读取和写入本地文件',
    icon: FileText,
    status: 'granted',
  },
]);

// 清除数据
const showClearData = ref(false);
const selectedClearTypes = ref<string[]>([]);

const clearDataTypes = [
  {
    id: 'cache',
    name: '缓存数据',
    description: '临时存储的文件和图片',
  },
  {
    id: 'history',
    name: '浏览历史',
    description: '访问过的页面记录',
  },
  {
    id: 'cookies',
    name: 'Cookies',
    description: '网站存储的小文件',
  },
  {
    id: 'localStorage',
    name: '本地存储',
    description: '应用本地保存的数据',
  },
];

// 获取权限状态文本
function getPermissionStatusText(status: string) {
  const texts = {
    granted: '已授权',
    denied: '已拒绝',
    prompt: '询问时',
  };
  return texts[status as keyof typeof texts] || '未知';
}

// 切换权限状态
function togglePermission(permissionId: string) {
  const permission = permissions.value.find(p => p.id === permissionId);
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

// 保存设置
function handleSave() {
  const settings = {
    dataCollection: dataCollection.value,
    analytics: analytics.value,
    crashReports: crashReports.value,
    profileVisibility: profileVisibility.value,
    showOnlineStatus: showOnlineStatus.value,
    showLastActive: showLastActive.value,
    searchIndexing: searchIndexing.value,
    permissions: permissions.value,
  };

  Lg.i('Settings Privacy', '保存隐私设置:', settings);
}

// 重置为默认
function resetToDefault() {
  dataCollection.value = true;
  analytics.value = true;
  crashReports.value = true;
  profileVisibility.value = 'public';
  showOnlineStatus.value = true;
  showLastActive.value = true;
  searchIndexing.value = false;
}
</script>

<template>
  <div class="max-w-4xl w-full">
    <!-- 数据隐私 -->
    <div class="mb-10">
      <h3 class="text-xl font-semibold text-gray-900 dark:text-white mb-6 pb-2 border-b-2 border-gray-200 dark:border-gray-700">
        数据隐私
      </h3>

      <div class="space-y-6">
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between py-6 border-b border-gray-200 dark:border-gray-700">
          <div class="mb-4 sm:mb-0">
            <label class="block font-medium text-gray-900 dark:text-white mb-1">数据收集</label>
            <p class="text-sm text-gray-600 dark:text-gray-400">
              允许收集匿名使用数据以改善产品
            </p>
          </div>
          <div class="sm:ml-8">
            <label class="inline-flex cursor-pointer items-center relative">
              <input
                v-model="dataCollection"
                type="checkbox"
                class="sr-only peer"
              >
              <div class="w-12 h-6 bg-gray-300 dark:bg-gray-600 rounded-full peer peer-checked:bg-blue-600 transition-colors relative">
                <div class="absolute w-5 h-5 bg-white rounded-full top-0.5 left-0.5 peer-checked:translate-x-6 transition-transform" />
              </div>
            </label>
          </div>
        </div>

        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between py-6 border-b border-gray-200 dark:border-gray-700">
          <div class="mb-4 sm:mb-0">
            <label class="block font-medium text-gray-900 dark:text-white mb-1">使用分析</label>
            <p class="text-sm text-gray-600 dark:text-gray-400">
              帮助我们了解功能使用情况
            </p>
          </div>
          <div class="sm:ml-8">
            <label class="inline-flex cursor-pointer items-center relative">
              <input
                v-model="analytics"
                type="checkbox"
                class="sr-only peer"
              >
              <div class="w-12 h-6 bg-gray-300 dark:bg-gray-600 rounded-full peer peer-checked:bg-blue-600 transition-colors relative">
                <div class="absolute w-5 h-5 bg-white rounded-full top-0.5 left-0.5 peer-checked:translate-x-6 transition-transform" />
              </div>
            </label>
          </div>
        </div>

        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between py-6 border-b border-gray-200 dark:border-gray-700">
          <div class="mb-4 sm:mb-0">
            <label class="block font-medium text-gray-900 dark:text-white mb-1">崩溃报告</label>
            <p class="text-sm text-gray-600 dark:text-gray-400">
              自动发送崩溃报告以帮助修复问题
            </p>
          </div>
          <div class="sm:ml-8">
            <label class="inline-flex cursor-pointer items-center relative">
              <input
                v-model="crashReports"
                type="checkbox"
                class="sr-only peer"
              >
              <div class="w-12 h-6 bg-gray-300 dark:bg-gray-600 rounded-full peer peer-checked:bg-blue-600 transition-colors relative">
                <div class="absolute w-5 h-5 bg-white rounded-full top-0.5 left-0.5 peer-checked:translate-x-6 transition-transform" />
              </div>
            </label>
          </div>
        </div>
      </div>
    </div>

    <!-- 个人信息 -->
    <div class="mb-10">
      <h3 class="text-xl font-semibold text-gray-900 dark:text-white mb-6 pb-2 border-b-2 border-gray-200 dark:border-gray-700">
        个人信息
      </h3>

      <div class="space-y-6">
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between py-6 border-b border-gray-200 dark:border-gray-700">
          <div class="mb-4 sm:mb-0">
            <label class="block font-medium text-gray-900 dark:text-white mb-1">个人资料可见性</label>
            <p class="text-sm text-gray-600 dark:text-gray-400">
              控制谁可以查看您的个人资料
            </p>
          </div>
          <div class="sm:ml-8">
            <select
              v-model="profileVisibility"
              class="w-full sm:w-48 px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20 focus:outline-none"
            >
              <option value="public">
                公开
              </option>
              <option value="friends">
                仅好友
              </option>
              <option value="private">
                私有
              </option>
            </select>
          </div>
        </div>

        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between py-6 border-b border-gray-200 dark:border-gray-700">
          <div class="mb-4 sm:mb-0">
            <label class="block font-medium text-gray-900 dark:text-white mb-1">在线状态</label>
            <p class="text-sm text-gray-600 dark:text-gray-400">
              显示您的在线/离线状态
            </p>
          </div>
          <div class="sm:ml-8">
            <label class="inline-flex cursor-pointer items-center relative">
              <input
                v-model="showOnlineStatus"
                type="checkbox"
                class="sr-only peer"
              >
              <div class="w-12 h-6 bg-gray-300 dark:bg-gray-600 rounded-full peer peer-checked:bg-blue-600 transition-colors relative">
                <div class="absolute w-5 h-5 bg-white rounded-full top-0.5 left-0.5 peer-checked:translate-x-6 transition-transform" />
              </div>
            </label>
          </div>
        </div>

        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between py-6 border-b border-gray-200 dark:border-gray-700">
          <div class="mb-4 sm:mb-0">
            <label class="block font-medium text-gray-900 dark:text-white mb-1">最后活跃时间</label>
            <p class="text-sm text-gray-600 dark:text-gray-400">
              允许他人查看您最后的活跃时间
            </p>
          </div>
          <div class="sm:ml-8">
            <label class="inline-flex cursor-pointer items-center relative">
              <input
                v-model="showLastActive"
                type="checkbox"
                class="sr-only peer"
              >
              <div class="w-12 h-6 bg-gray-300 dark:bg-gray-600 rounded-full peer peer-checked:bg-blue-600 transition-colors relative">
                <div class="absolute w-5 h-5 bg-white rounded-full top-0.5 left-0.5 peer-checked:translate-x-6 transition-transform" />
              </div>
            </label>
          </div>
        </div>

        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between py-6 border-b border-gray-200 dark:border-gray-700">
          <div class="mb-4 sm:mb-0">
            <label class="block font-medium text-gray-900 dark:text-white mb-1">搜索引擎索引</label>
            <p class="text-sm text-gray-600 dark:text-gray-400">
              允许搜索引擎索引您的公开资料
            </p>
          </div>
          <div class="sm:ml-8">
            <label class="inline-flex cursor-pointer items-center relative">
              <input
                v-model="searchIndexing"
                type="checkbox"
                class="sr-only peer"
              >
              <div class="w-12 h-6 bg-gray-300 dark:bg-gray-600 rounded-full peer peer-checked:bg-blue-600 transition-colors relative">
                <div class="absolute w-5 h-5 bg-white rounded-full top-0.5 left-0.5 peer-checked:translate-x-6 transition-transform" />
              </div>
            </label>
          </div>
        </div>
      </div>
    </div>

    <!-- 数据管理 -->
    <div class="mb-10">
      <h3 class="text-xl font-semibold text-gray-900 dark:text-white mb-6 pb-2 border-b-2 border-gray-200 dark:border-gray-700">
        数据管理
      </h3>

      <div class="space-y-6">
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between py-6 border-b border-gray-200 dark:border-gray-700">
          <div class="mb-4 sm:mb-0">
            <label class="block font-medium text-gray-900 dark:text-white mb-1">下载我的数据</label>
            <p class="text-sm text-gray-600 dark:text-gray-400">
              下载您的个人数据副本
            </p>
          </div>
          <div class="sm:ml-8">
            <button
              class="flex items-center gap-2 px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white font-medium rounded-lg transition-colors"
              @click="requestDataExport"
            >
              <Download class="w-4 h-4" />
              请求下载
            </button>
          </div>
        </div>

        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between py-6 border-b border-gray-200 dark:border-gray-700">
          <div class="mb-4 sm:mb-0">
            <label class="block font-medium text-gray-900 dark:text-white mb-1">清除浏览数据</label>
            <p class="text-sm text-gray-600 dark:text-gray-400">
              清除缓存、历史记录等本地数据
            </p>
          </div>
          <div class="sm:ml-8">
            <button
              class="flex items-center gap-2 px-4 py-2 border border-gray-300 dark:border-gray-600 hover:bg-gray-50 dark:hover:bg-gray-700 text-gray-900 dark:text-white font-medium rounded-lg transition-colors"
              @click="showClearData = true"
            >
              <Trash class="w-4 h-4" />
              清除数据
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- 权限管理 -->
    <div class="mb-10">
      <h3 class="text-xl font-semibold text-gray-900 dark:text-white mb-6 pb-2 border-b-2 border-gray-200 dark:border-gray-700">
        权限管理
      </h3>

      <div class="space-y-4">
        <div
          v-for="permission in permissions"
          :key="permission.id"
          class="flex items-center justify-between p-4 border border-gray-200 dark:border-gray-700 rounded-lg bg-white dark:bg-gray-800"
        >
          <div class="flex items-center gap-4">
            <component :is="permission.icon" class="w-5 h-5 text-gray-600 dark:text-gray-400" />
            <div>
              <div class="font-medium text-gray-900 dark:text-white">
                {{ permission.name }}
              </div>
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
              class="text-sm font-medium text-blue-600 dark:text-blue-400 px-2 py-1 rounded hover:bg-blue-600 dark:hover:bg-blue-600 hover:text-white transition-colors"
              @click="togglePermission(permission.id)"
            >
              {{ permission.status === 'granted' ? '撤销' : '授权' }}
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- 操作按钮 -->
    <div class="pt-8 border-t border-gray-200 dark:border-gray-700 flex flex-col sm:flex-row gap-4">
      <button
        class="flex items-center justify-center gap-2 px-6 py-3 bg-blue-600 hover:bg-blue-700 text-white font-medium rounded-lg transition-colors"
        @click="handleSave"
      >
        <Save class="w-4 h-4" />
        保存设置
      </button>
      <button
        class="flex items-center justify-center gap-2 px-6 py-3 border border-gray-300 dark:border-gray-600 hover:bg-gray-50 dark:hover:bg-gray-700 text-gray-900 dark:text-white font-medium rounded-lg transition-colors"
        @click="resetToDefault"
      >
        <RotateCcw class="w-4 h-4" />
        重置为默认
      </button>
    </div>

    <!-- 清除数据对话框 -->
    <div v-if="showClearData" class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm p-4">
      <div class="w-full max-w-md bg-white dark:bg-gray-800 rounded-xl shadow-2xl p-6">
        <h3 class="text-xl font-semibold text-gray-900 dark:text-white mb-4">
          清除浏览数据
        </h3>
        <p class="text-sm text-gray-600 dark:text-gray-400 mb-6">
          选择要清除的数据类型：
        </p>

        <div class="space-y-3 mb-6">
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
            >
            <div>
              <div class="font-medium text-gray-900 dark:text-white">{{ dataType.name }}</div>
              <div class="text-sm text-gray-600 dark:text-gray-400">{{ dataType.description }}</div>
            </div>
          </label>
        </div>

        <div class="flex gap-3">
          <button
            class="flex-1 px-4 py-2 border border-gray-300 dark:border-gray-600 hover:bg-gray-50 dark:hover:bg-gray-700 text-gray-900 dark:text-white rounded-lg transition-colors"
            @click="showClearData = false"
          >
            取消
          </button>
          <button
            class="flex-1 px-4 py-2 bg-red-600 hover:bg-red-700 text-white rounded-lg transition-colors"
            @click="clearSelectedData"
          >
            清除
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
