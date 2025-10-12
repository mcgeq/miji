<script setup lang="ts">
import {
  Key as KeyIcon,
  Mail,
  Monitor,
  Smartphone as Phone,
  Smartphone,
  Trash2,
} from 'lucide-vue-next';
import { useAuthStore } from '@/stores/auth';

const authStore = useAuthStore();
const user = computed(() => authStore.user);

// 密码相关
const showChangePassword = ref(false);
const passwordForm = ref({
  current: '',
  new: '',
  confirm: '',
});

// 两步验证
const twoFactorEnabled = ref(false);

// 登录会话
const loginSessions = ref([
  {
    id: '1',
    device: 'Windows - Chrome',
    location: '北京, 中国',
    timestamp: new Date().getTime() - 1000 * 60 * 5,
    current: true,
  },
  {
    id: '2',
    device: 'iPhone 14 - Safari',
    location: '上海, 中国',
    timestamp: new Date().getTime() - 1000 * 60 * 60 * 2,
    current: false,
  },
  {
    id: '3',
    device: 'MacBook Pro - Safari',
    location: '广州, 中国',
    timestamp: new Date().getTime() - 1000 * 60 * 60 * 24,
    current: false,
  },
]);

// 账户安全
const autoLockTime = ref(15);
const showDeleteAccount = ref(false);
const deleteConfirmEmail = ref('');

// 格式化时间
function getSessionTimeText(timestamp: number) {
  const date = new Date(timestamp);
  const now = new Date();
  const diff = now.getTime() - timestamp;

  if (diff < 1000 * 60) {
    return '刚刚';
  } else if (diff < 1000 * 60 * 60) {
    return `${Math.floor(diff / (1000 * 60))} 分钟前`;
  } else if (diff < 1000 * 60 * 60 * 24) {
    return `${Math.floor(diff / (1000 * 60 * 60))} 小时前`;
  } else {
    return date.toLocaleDateString('zh-CN');
  }
}

// 修改密码
function handleChangePassword() {
  if (passwordForm.value.new !== passwordForm.value.confirm) {
    return;
  }

  // TODO: 实现修改密码的逻辑
  showChangePassword.value = false;
  passwordForm.value = { current: '', new: '', confirm: '' };
}

// 终止会话
function handleTerminateSession(sessionId: string) {
  const index = loginSessions.value.findIndex(s => s.id === sessionId);
  if (index > -1) {
    loginSessions.value.splice(index, 1);
    // TODO: 调用 API 终止远程会话
  }
}

// 删除账户
function handleDeleteAccount() {
  // TODO: 实现删除账户的逻辑
  showDeleteAccount.value = false;
  deleteConfirmEmail.value = '';
}
</script>

<template>
  <div class="general-settings-container">
    <!-- 密码安全 -->
    <div class="general-settings-section">
      <h3 class="general-settings-title">
        密码安全
      </h3>

      <div class="general-settings-items">
        <div class="general-setting-item">
          <div class="general-setting-label-wrapper">
            <label class="general-setting-label">修改密码</label>
            <p class="general-setting-description">
              定期更改密码以保护账户安全
            </p>
          </div>
          <div class="general-setting-control">
            <button
              class="action-button-primary button-compact"
              @click="showChangePassword = true"
            >
              <KeyIcon class="action-button-primary-icon" />
              修改密码
            </button>
          </div>
        </div>

        <div class="general-setting-item">
          <div class="general-setting-label-wrapper">
            <label class="general-setting-label">密码强度</label>
            <p class="general-setting-description">
              您的密码安全强度评估
            </p>
          </div>
          <div class="general-setting-control">
            <div class="password-strength">
              <div class="password-strength-bar-wrapper">
                <div
                  class="password-strength-bar"
                  style="width: 60%"
                />
              </div>
              <span class="password-strength-text">良好</span>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- 两步验证 -->
    <div class="general-settings-section">
      <h3 class="general-settings-title">
        两步验证
      </h3>

      <div class="general-settings-items">
        <div class="general-setting-item">
          <div class="general-setting-label-wrapper">
            <label class="general-setting-label">启用两步验证</label>
            <p class="general-setting-description">
              使用手机应用或短信验证码增强账户安全
            </p>
          </div>
          <div class="general-setting-control">
            <label class="toggle-switch">
              <input
                v-model="twoFactorEnabled"
                type="checkbox"
                class="toggle-switch-input"
              >
              <div class="toggle-switch-track">
                <div class="toggle-switch-thumb" />
              </div>
            </label>
          </div>
        </div>

        <div v-if="twoFactorEnabled" class="general-setting-item">
          <div class="general-setting-label-wrapper">
            <label class="general-setting-label">验证方式</label>
            <p class="general-setting-description">
              选择接收验证码的方式
            </p>
          </div>
          <div class="general-setting-control no-margin">
            <div class="verification-methods">
              <button class="verification-method-button verification-method-active">
                <Smartphone class="verification-method-button-icon" />
                验证器应用
              </button>
              <button class="verification-method-button verification-method-inactive">
                <Phone class="verification-method-button-icon" />
                短信验证
              </button>
              <button class="verification-method-button verification-method-inactive">
                <Mail class="verification-method-button-icon" />
                邮箱验证
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- 登录历史 -->
    <div class="general-settings-section">
      <h3 class="general-settings-title">
        登录历史
      </h3>

      <div class="dnd-schedule general-settings-items">
        <div
          v-for="session in loginSessions"
          :key="session.id"
          class="session-card"
        >
          <div class="session-info">
            <Monitor class="session-icon" />
            <div>
              <div class="session-device">
                {{ session.device }}
              </div>
              <div class="session-location">
                {{ session.location }}
              </div>
            </div>
            <div class="session-time">
              {{ getSessionTimeText(session.timestamp) }}
            </div>
          </div>
          <div>
            <span v-if="session.current" class="session-current-badge">
              当前会话
            </span>
            <button
              v-else
              class="session-terminate-button"
              @click="handleTerminateSession(session.id)"
            >
              终止
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- 账户安全 -->
    <div class="general-settings-section">
      <h3 class="general-settings-title">
        账户安全
      </h3>

      <div class="general-settings-items">
        <div class="general-setting-item">
          <div class="general-setting-label-wrapper">
            <label class="general-setting-label">自动锁定</label>
            <p class="general-setting-description">
              闲置指定时间后自动锁定应用
            </p>
          </div>
          <div class="general-setting-control">
            <select
              v-model="autoLockTime"
              class="general-select"
            >
              <option value="0">
                从不
              </option>
              <option value="5">
                5 分钟
              </option>
              <option value="15">
                15 分钟
              </option>
              <option value="30">
                30 分钟
              </option>
              <option value="60">
                1 小时
              </option>
            </select>
          </div>
        </div>

        <div class="general-setting-item">
          <div class="general-setting-label-wrapper">
            <label class="general-setting-label">删除账户</label>
            <p class="general-setting-description">
              永久删除您的账户和所有数据
            </p>
          </div>
          <div class="general-setting-control">
            <button
              class="modal-button-danger delete-account-button"
              @click="showDeleteAccount = true"
            >
              <Trash2 class="action-button-primary-icon" />
              删除账户
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- 修改密码对话框 -->
    <div v-if="showChangePassword" class="modal-overlay">
      <div class="modal-content">
        <h3 class="modal-title">
          修改密码
        </h3>
        <form class="modal-form" @submit.prevent="handleChangePassword">
          <div class="modal-form-group">
            <label>当前密码</label>
            <input
              v-model="passwordForm.current"
              type="password"
              class="modal-form-input"
              required
            >
          </div>
          <div class="modal-form-group">
            <label>新密码</label>
            <input
              v-model="passwordForm.new"
              type="password"
              class="modal-form-input"
              required
            >
          </div>
          <div class="modal-form-group">
            <label>确认新密码</label>
            <input
              v-model="passwordForm.confirm"
              type="password"
              class="modal-form-input"
              required
            >
          </div>
          <div class="modal-actions">
            <button
              type="button"
              class="modal-button modal-button-cancel"
              @click="showChangePassword = false"
            >
              取消
            </button>
            <button
              type="submit"
              class="modal-button modal-button-confirm"
            >
              确认修改
            </button>
          </div>
        </form>
      </div>
    </div>

    <!-- 删除账户确认对话框 -->
    <div v-if="showDeleteAccount" class="modal-overlay">
      <div class="modal-content">
        <h3 class="modal-title modal-title-danger">
          删除账户
        </h3>
        <p class="modal-description-warning">
          此操作无法撤销。删除账户将永久移除您的所有数据，包括设置、文件和历史记录。
        </p>
        <div class="modal-form-group confirm-email-group">
          <label>请输入您的邮箱地址确认删除</label>
          <input
            v-model="deleteConfirmEmail"
            type="email"
            class="modal-form-input modal-form-input-danger"
            :placeholder="user?.email || ''"
          >
        </div>
        <div class="modal-actions-full">
          <button
            class="modal-button modal-button-cancel"
            @click="showDeleteAccount = false"
          >
            取消
          </button>
          <button
            class="modal-button modal-button-danger"
            :disabled="deleteConfirmEmail !== user?.email"
            @click="handleDeleteAccount"
          >
            确认删除
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

.no-margin {
  margin-left: 0;
}

.delete-account-button {
  padding: 0.5rem 1rem;
  display: flex;
  gap: 0.5rem;
  align-items: center;
}

.confirm-email-group {
  margin-bottom: 1.5rem;
}
</style>
