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

// 获取权限状态样式
function getPermissionStatusClass(status: string) {
  const classes = {
    granted: 'bg-green-100 text-green-800',
    denied: 'bg-red-100 text-red-800',
    prompt: 'bg-yellow-100 text-yellow-800',
  };
  return classes[status as keyof typeof classes] || 'bg-gray-100 text-gray-800';
}

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
  <div class="max-w-4xl">
    <!-- 数据隐私 -->
    <div class="mb-10">
      <h3 class="mb-6 border-b-2 border-slate-200 pb-2 text-xl text-slate-800 font-semibold">
        数据隐私
      </h3>

      <div class="space-y-6">
        <div class="flex flex-col border-b border-slate-100 py-6 sm:flex-row sm:items-center sm:justify-between">
          <div class="mb-4 sm:mb-0">
            <label class="mb-1 block text-slate-700 font-medium">数据收集</label>
            <p class="text-sm text-slate-500">
              允许收集匿名使用数据以改善产品
            </p>
          </div>
          <div class="sm:ml-8">
            <label class="relative inline-flex cursor-pointer items-center">
              <input
                v-model="dataCollection"
                type="checkbox"
                class="peer sr-only"
              >
              <div class="peer relative h-6 w-12 rounded-full bg-slate-300 after:absolute after:left-0.5 after:top-0.5 after:h-5 after:w-5 after:rounded-full after:bg-white peer-checked:bg-blue-500 peer-focus:ring-2 peer-focus:ring-blue-500 after:transition-all after:content-[''] peer-checked:after:translate-x-6 peer-checked:after:border-white" />
            </label>
          </div>
        </div>

        <div class="flex flex-col border-b border-slate-100 py-6 sm:flex-row sm:items-center sm:justify-between">
          <div class="mb-4 sm:mb-0">
            <label class="mb-1 block text-slate-700 font-medium">使用分析</label>
            <p class="text-sm text-slate-500">
              帮助我们了解功能使用情况
            </p>
          </div>
          <div class="sm:ml-8">
            <label class="relative inline-flex cursor-pointer items-center">
              <input
                v-model="analytics"
                type="checkbox"
                class="peer sr-only"
              >
              <div class="peer relative h-6 w-12 rounded-full bg-slate-300 after:absolute after:left-0.5 after:top-0.5 after:h-5 after:w-5 after:rounded-full after:bg-white peer-checked:bg-blue-500 peer-focus:ring-2 peer-focus:ring-blue-500 after:transition-all after:content-[''] peer-checked:after:translate-x-6 peer-checked:after:border-white" />
            </label>
          </div>
        </div>

        <div class="flex flex-col border-b border-slate-100 py-6 sm:flex-row sm:items-center sm:justify-between">
          <div class="mb-4 sm:mb-0">
            <label class="mb-1 block text-slate-700 font-medium">崩溃报告</label>
            <p class="text-sm text-slate-500">
              自动发送崩溃报告以帮助修复问题
            </p>
          </div>
          <div class="sm:ml-8">
            <label class="relative inline-flex cursor-pointer items-center">
              <input
                v-model="crashReports"
                type="checkbox"
                class="peer sr-only"
              >
              <div class="peer relative h-6 w-12 rounded-full bg-slate-300 after:absolute after:left-0.5 after:top-0.5 after:h-5 after:w-5 after:rounded-full after:bg-white peer-checked:bg-blue-500 peer-focus:ring-2 peer-focus:ring-blue-500 after:transition-all after:content-[''] peer-checked:after:translate-x-6 peer-checked:after:border-white" />
            </label>
          </div>
        </div>
      </div>
    </div>

    <!-- 个人信息 -->
    <div class="mb-10">
      <h3 class="mb-6 border-b-2 border-slate-200 pb-2 text-xl text-slate-800 font-semibold">
        个人信息
      </h3>

      <div class="space-y-6">
        <div class="flex flex-col border-b border-slate-100 py-6 sm:flex-row sm:items-center sm:justify-between">
          <div class="mb-4 sm:mb-0">
            <label class="mb-1 block text-slate-700 font-medium">个人资料可见性</label>
            <p class="text-sm text-slate-500">
              控制谁可以查看您的个人资料
            </p>
          </div>
          <div class="sm:ml-8">
            <select
              v-model="profileVisibility"
              class="w-full border border-slate-300 rounded-lg bg-white px-4 py-2 transition-all duration-200 sm:w-40 focus:border-blue-500 focus:ring-2 focus:ring-blue-500"
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

        <div class="flex flex-col border-b border-slate-100 py-6 sm:flex-row sm:items-center sm:justify-between">
          <div class="mb-4 sm:mb-0">
            <label class="mb-1 block text-slate-700 font-medium">在线状态</label>
            <p class="text-sm text-slate-500">
              显示您的在线/离线状态
            </p>
          </div>
          <div class="sm:ml-8">
            <label class="relative inline-flex cursor-pointer items-center">
              <input
                v-model="showOnlineStatus"
                type="checkbox"
                class="peer sr-only"
              >
              <div class="peer relative h-6 w-12 rounded-full bg-slate-300 after:absolute after:left-0.5 after:top-0.5 after:h-5 after:w-5 after:rounded-full after:bg-white peer-checked:bg-blue-500 peer-focus:ring-2 peer-focus:ring-blue-500 after:transition-all after:content-[''] peer-checked:after:translate-x-6 peer-checked:after:border-white" />
            </label>
          </div>
        </div>

        <div class="flex flex-col border-b border-slate-100 py-6 sm:flex-row sm:items-center sm:justify-between">
          <div class="mb-4 sm:mb-0">
            <label class="mb-1 block text-slate-700 font-medium">最后活跃时间</label>
            <p class="text-sm text-slate-500">
              允许他人查看您最后的活跃时间
            </p>
          </div>
          <div class="sm:ml-8">
            <label class="relative inline-flex cursor-pointer items-center">
              <input
                v-model="showLastActive"
                type="checkbox"
                class="peer sr-only"
              >
              <div class="peer relative h-6 w-12 rounded-full bg-slate-300 after:absolute after:left-0.5 after:top-0.5 after:h-5 after:w-5 after:rounded-full after:bg-white peer-checked:bg-blue-500 peer-focus:ring-2 peer-focus:ring-blue-500 after:transition-all after:content-[''] peer-checked:after:translate-x-6 peer-checked:after:border-white" />
            </label>
          </div>
        </div>

        <div class="flex flex-col border-b border-slate-100 py-6 sm:flex-row sm:items-center sm:justify-between">
          <div class="mb-4 sm:mb-0">
            <label class="mb-1 block text-slate-700 font-medium">搜索引擎索引</label>
            <p class="text-sm text-slate-500">
              允许搜索引擎索引您的公开资料
            </p>
          </div>
          <div class="sm:ml-8">
            <label class="relative inline-flex cursor-pointer items-center">
              <input
                v-model="searchIndexing"
                type="checkbox"
                class="peer sr-only"
              >
              <div class="peer relative h-6 w-12 rounded-full bg-slate-300 after:absolute after:left-0.5 after:top-0.5 after:h-5 after:w-5 after:rounded-full after:bg-white peer-checked:bg-blue-500 peer-focus:ring-2 peer-focus:ring-blue-500 after:transition-all after:content-[''] peer-checked:after:translate-x-6 peer-checked:after:border-white" />
            </label>
          </div>
        </div>
      </div>
    </div>

    <!-- 数据管理 -->
    <div class="mb-10">
      <h3 class="mb-6 border-b-2 border-slate-200 pb-2 text-xl text-slate-800 font-semibold">
        数据管理
      </h3>

      <div class="space-y-6">
        <div class="flex flex-col border-b border-slate-100 py-6 sm:flex-row sm:items-center sm:justify-between">
          <div class="mb-4 sm:mb-0">
            <label class="mb-1 block text-slate-700 font-medium">下载我的数据</label>
            <p class="text-sm text-slate-500">
              下载您的个人数据副本
            </p>
          </div>
          <div class="sm:ml-8">
            <button
              class="flex items-center gap-2 rounded-lg bg-blue-500 px-4 py-2 text-white transition-all duration-200 hover:bg-blue-600"
              @click="requestDataExport"
            >
              <Download class="h-4 w-4" />
              请求下载
            </button>
          </div>
        </div>

        <div class="flex flex-col border-b border-slate-100 py-6 sm:flex-row sm:items-center sm:justify-between">
          <div class="mb-4 sm:mb-0">
            <label class="mb-1 block text-slate-700 font-medium">清除浏览数据</label>
            <p class="text-sm text-slate-500">
              清除缓存、历史记录等本地数据
            </p>
          </div>
          <div class="sm:ml-8">
            <button
              class="flex items-center gap-2 border border-slate-300 rounded-lg bg-slate-100 px-4 py-2 text-slate-700 transition-all duration-200 hover:bg-slate-200"
              @click="showClearData = true"
            >
              <Trash class="h-4 w-4" />
              清除数据
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- 权限管理 -->
    <div class="mb-10">
      <h3 class="mb-6 border-b-2 border-slate-200 pb-2 text-xl text-slate-800 font-semibold">
        权限管理
      </h3>

      <div class="rounded-xl bg-slate-50 p-6 space-y-4">
        <div
          v-for="permission in permissions"
          :key="permission.id"
          class="flex items-center justify-between border border-slate-200 rounded-lg bg-white p-4"
        >
          <div class="flex items-center gap-4">
            <component :is="permission.icon" class="h-5 w-5 text-slate-500" />
            <div>
              <div class="text-slate-800 font-medium">
                {{ permission.name }}
              </div>
              <div class="text-sm text-slate-500">
                {{ permission.description }}
              </div>
            </div>
          </div>
          <div class="flex items-center gap-2">
            <span
              class="rounded px-2 py-1 text-xs font-medium"
              :class="getPermissionStatusClass(permission.status)"
            >
              {{ getPermissionStatusText(permission.status) }}
            </span>
            <button
              class="rounded px-2 py-1 text-sm text-blue-600 font-medium transition-all duration-200 hover:bg-blue-50 hover:text-blue-800"
              @click="togglePermission(permission.id)"
            >
              {{ permission.status === 'granted' ? '撤销' : '授权' }}
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- 操作按钮 -->
    <div class="flex flex-col gap-4 border-t border-slate-200 pt-8 sm:flex-row">
      <button
        class="flex items-center justify-center gap-2 rounded-lg bg-blue-500 px-6 py-3 text-white font-medium transition-all duration-200 hover:bg-blue-600"
        @click="handleSave"
      >
        <Save class="h-4 w-4" />
        保存设置
      </button>
      <button
        class="flex items-center justify-center gap-2 border border-slate-300 rounded-lg bg-slate-100 px-6 py-3 text-slate-700 font-medium transition-all duration-200 hover:bg-slate-200"
        @click="resetToDefault"
      >
        <RotateCcw class="h-4 w-4" />
        重置为默认
      </button>
    </div>

    <!-- 清除数据对话框 -->
    <div v-if="showClearData" class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
      <div class="max-w-md w-full rounded-xl bg-white p-6">
        <h3 class="mb-4 text-xl text-slate-800 font-semibold">
          清除浏览数据
        </h3>
        <p class="mb-4 text-slate-600">
          选择要清除的数据类型：
        </p>

        <div class="mb-6 space-y-3">
          <label
            v-for="dataType in clearDataTypes"
            :key="dataType.id"
            class="flex cursor-pointer items-center gap-3"
          >
            <input
              v-model="selectedClearTypes"
              :value="dataType.id"
              type="checkbox"
              class="h-4 w-4 border-gray-300 rounded bg-gray-100 text-blue-600 focus:ring-blue-500"
            >
            <div>
              <div class="text-slate-700 font-medium">{{ dataType.name }}</div>
              <div class="text-sm text-slate-500">{{ dataType.description }}</div>
            </div>
          </label>
        </div>

        <div class="flex gap-3">
          <button
            class="flex-1 rounded-lg bg-slate-100 px-4 py-2 text-slate-700 transition-all duration-200 hover:bg-slate-200"
            @click="showClearData = false"
          >
            取消
          </button>
          <button
            class="flex-1 rounded-lg bg-red-500 px-4 py-2 text-white transition-all duration-200 hover:bg-red-600"
            @click="clearSelectedData"
          >
            清除
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
