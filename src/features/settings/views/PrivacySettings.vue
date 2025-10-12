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
    granted: 'permission-status-granted',
    denied: 'permission-status-denied',
    prompt: 'permission-status-prompt',
  };
  return classes[status as keyof typeof classes] || 'permission-status-granted';
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
  <div class="general-settings-container">
    <!-- 数据隐私 -->
    <div class="general-settings-section">
      <h3 class="general-settings-title">
        数据隐私
      </h3>

      <div class="general-settings-items">
        <div class="general-setting-item">
          <div class="general-setting-label-wrapper">
            <label class="general-setting-label">数据收集</label>
            <p class="general-setting-description">
              允许收集匿名使用数据以改善产品
            </p>
          </div>
          <div class="general-setting-control">
            <label class="toggle-switch">
              <input
                v-model="dataCollection"
                type="checkbox"
                class="toggle-switch-input"
              >
              <div class="toggle-switch-track">
                <div class="toggle-switch-thumb" />
              </div>
            </label>
          </div>
        </div>

        <div class="general-setting-item">
          <div class="general-setting-label-wrapper">
            <label class="general-setting-label">使用分析</label>
            <p class="general-setting-description">
              帮助我们了解功能使用情况
            </p>
          </div>
          <div class="general-setting-control">
            <label class="toggle-switch">
              <input
                v-model="analytics"
                type="checkbox"
                class="toggle-switch-input"
              >
              <div class="toggle-switch-track">
                <div class="toggle-switch-thumb" />
              </div>
            </label>
          </div>
        </div>

        <div class="general-setting-item">
          <div class="general-setting-label-wrapper">
            <label class="general-setting-label">崩溃报告</label>
            <p class="general-setting-description">
              自动发送崩溃报告以帮助修复问题
            </p>
          </div>
          <div class="general-setting-control">
            <label class="toggle-switch">
              <input
                v-model="crashReports"
                type="checkbox"
                class="toggle-switch-input"
              >
              <div class="toggle-switch-track">
                <div class="toggle-switch-thumb" />
              </div>
            </label>
          </div>
        </div>
      </div>
    </div>

    <!-- 个人信息 -->
    <div class="general-settings-section">
      <h3 class="general-settings-title">
        个人信息
      </h3>

      <div class="general-settings-items">
        <div class="general-setting-item">
          <div class="general-setting-label-wrapper">
            <label class="general-setting-label">个人资料可见性</label>
            <p class="general-setting-description">
              控制谁可以查看您的个人资料
            </p>
          </div>
          <div class="general-setting-control">
            <select
              v-model="profileVisibility"
              class="general-select"
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

        <div class="general-setting-item">
          <div class="general-setting-label-wrapper">
            <label class="general-setting-label">在线状态</label>
            <p class="general-setting-description">
              显示您的在线/离线状态
            </p>
          </div>
          <div class="general-setting-control">
            <label class="toggle-switch">
              <input
                v-model="showOnlineStatus"
                type="checkbox"
                class="toggle-switch-input"
              >
              <div class="toggle-switch-track">
                <div class="toggle-switch-thumb" />
              </div>
            </label>
          </div>
        </div>

        <div class="general-setting-item">
          <div class="general-setting-label-wrapper">
            <label class="general-setting-label">最后活跃时间</label>
            <p class="general-setting-description">
              允许他人查看您最后的活跃时间
            </p>
          </div>
          <div class="general-setting-control">
            <label class="toggle-switch">
              <input
                v-model="showLastActive"
                type="checkbox"
                class="toggle-switch-input"
              >
              <div class="toggle-switch-track">
                <div class="toggle-switch-thumb" />
              </div>
            </label>
          </div>
        </div>

        <div class="general-setting-item">
          <div class="general-setting-label-wrapper">
            <label class="general-setting-label">搜索引擎索引</label>
            <p class="general-setting-description">
              允许搜索引擎索引您的公开资料
            </p>
          </div>
          <div class="general-setting-control">
            <label class="toggle-switch">
              <input
                v-model="searchIndexing"
                type="checkbox"
                class="toggle-switch-input"
              >
              <div class="toggle-switch-track">
                <div class="toggle-switch-thumb" />
              </div>
            </label>
          </div>
        </div>
      </div>
    </div>

    <!-- 数据管理 -->
    <div class="general-settings-section">
      <h3 class="general-settings-title">
        数据管理
      </h3>

      <div class="general-settings-items">
        <div class="general-setting-item">
          <div class="general-setting-label-wrapper">
            <label class="general-setting-label">下载我的数据</label>
            <p class="general-setting-description">
              下载您的个人数据副本
            </p>
          </div>
          <div class="general-setting-control">
            <button
              class="action-button-primary button-compact"
              @click="requestDataExport"
            >
              <Download class="action-button-primary-icon" />
              请求下载
            </button>
          </div>
        </div>

        <div class="general-setting-item">
          <div class="general-setting-label-wrapper">
            <label class="general-setting-label">清除浏览数据</label>
            <p class="general-setting-description">
              清除缓存、历史记录等本地数据
            </p>
          </div>
          <div class="general-setting-control">
            <button
              class="action-button-secondary button-compact"
              @click="showClearData = true"
            >
              <Trash class="action-button-secondary-icon" />
              清除数据
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- 权限管理 -->
    <div class="general-settings-section">
      <h3 class="general-settings-title">
        权限管理
      </h3>

      <div class="dnd-schedule general-settings-items">
        <div
          v-for="permission in permissions"
          :key="permission.id"
          class="permission-card"
        >
          <div class="permission-info">
            <component :is="permission.icon" class="permission-icon" />
            <div>
              <div class="permission-name">
                {{ permission.name }}
              </div>
              <div class="permission-description">
                {{ permission.description }}
              </div>
            </div>
          </div>
          <div class="permission-actions">
            <span
              class="permission-status"
              :class="getPermissionStatusClass(permission.status)"
            >
              {{ getPermissionStatusText(permission.status) }}
            </span>
            <button
              class="permission-toggle-button"
              @click="togglePermission(permission.id)"
            >
              {{ permission.status === 'granted' ? '撤销' : '授权' }}
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- 操作按钮 -->
    <div class="setting-action-buttons">
      <button
        class="action-button-primary"
        @click="handleSave"
      >
        <Save class="action-button-primary-icon" />
        保存设置
      </button>
      <button
        class="action-button-secondary"
        @click="resetToDefault"
      >
        <RotateCcw class="action-button-secondary-icon" />
        重置为默认
      </button>
    </div>

    <!-- 清除数据对话框 -->
    <div v-if="showClearData" class="modal-overlay">
      <div class="modal-content">
        <h3 class="modal-title">
          清除浏览数据
        </h3>
        <p class="modal-description">
          选择要清除的数据类型：
        </p>

        <div class="general-settings-items clear-data-list">
          <label
            v-for="dataType in clearDataTypes"
            :key="dataType.id"
            class="notification-method-checkbox clear-data-item"
          >
            <input
              v-model="selectedClearTypes"
              :value="dataType.id"
              type="checkbox"
              class="notification-method-checkbox-input"
            >
            <div>
              <div class="notification-method-checkbox-label data-type-name">{{ dataType.name }}</div>
              <div class="general-setting-description">{{ dataType.description }}</div>
            </div>
          </label>
        </div>

        <div class="modal-actions-full">
          <button
            class="modal-button modal-button-cancel"
            @click="showClearData = false"
          >
            取消
          </button>
          <button
            class="modal-button modal-button-danger"
            @click="clearSelectedData"
          >
            清除
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped lang="postcss">
.button-compact {
  padding: 0.5rem 1rem;
}

.clear-data-list {
  margin-bottom: 1.5rem;
}

.clear-data-item {
  display: flex;
  gap: 0.75rem;
}

.data-type-name {
  color: #334155;
  font-weight: 500;
}
</style>
