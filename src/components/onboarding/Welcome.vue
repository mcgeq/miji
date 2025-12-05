<template>
  <div class="welcome-onboarding">
    <!-- 欢迎步骤 -->
    <div v-if="currentStep === 0" class="onboarding-step">
      <div class="step-content">
        <component :is="Sparkles" class="step-icon text-blue-500" />
        <h1 class="step-title">欢迎使用觅记</h1>
        <p class="step-description">
          一个功能强大的个人管理应用，帮助您更好地管理生活
        </p>
        <ul class="feature-list">
          <li>
            <component :is="CheckCircle" class="feature-icon" />
            <span>待办事项管理</span>
          </li>
          <li>
            <component :is="CheckCircle" class="feature-icon" />
            <span>财务管理和账单提醒</span>
          </li>
          <li>
            <component :is="CheckCircle" class="feature-icon" />
            <span>健康记录和周期追踪</span>
          </li>
          <li>
            <component :is="CheckCircle" class="feature-icon" />
            <span>跨平台同步</span>
          </li>
        </ul>
      </div>
      <div class="step-actions">
        <Button 
          variant="primary" 
          size="lg" 
          @click="nextStep"
          title="开始使用"
          class="icon-only-button-primary"
        >
          <component :is="ArrowRight" class="w-6 h-6" />
        </Button>
      </div>
    </div>

    <!-- 通知权限步骤 -->
    <div v-if="currentStep === 1" class="onboarding-step">
      <div class="step-content">
        <component :is="Bell" class="step-icon text-blue-500" />
        <p class="step-description">
          及时提醒您的重要事项，不错过任何待办和账单
        </p>
        
        <div class="notification-benefits">
          <div class="benefit-item">
            <component :is="Clock" class="benefit-icon text-orange-500" />
            <span>待办提醒 - 准时提醒，不错过重要事项</span>
          </div>
          <div class="benefit-item">
            <component :is="CreditCard" class="benefit-icon text-green-500" />
            <span>账单提醒 - 避免逾期，按时支付账单</span>
          </div>
          <div class="benefit-item">
            <component :is="Heart" class="benefit-icon text-red-500" />
            <span>健康提醒 - 关注身体，记录健康数据</span>
          </div>
        </div>

        <div v-if="permissionError" class="error-message">
          <component :is="AlertCircle" class="w-5 h-5" />
          <span>{{ permissionError }}</span>
        </div>
      </div>

      <div class="step-actions">
        <Button 
          variant="outline" 
          @click="skipPermission"
          title="稍后设置"
          class="icon-only-button"
        >
          <component :is="X" class="w-5 h-5" />
        </Button>
        <Button 
          variant="primary" 
          size="lg" 
          @click="requestPermission"
          :loading="requesting"
          title="授予通知权限"
          class="icon-only-button-primary"
        >
          <component :is="Unlock" class="w-6 h-6" />
        </Button>
      </div>
    </div>

    <!-- 完成步骤 -->
    <div v-if="currentStep === 2" class="onboarding-step">
      <div class="step-content">
        <component :is="CheckCircle2" class="step-icon text-green-500" />
        <h2 class="step-title">准备就绪！</h2>
        <p class="step-description">
          您已完成初始设置，现在可以开始使用觅记了
        </p>
        
        <div class="quick-actions">
          <div class="quick-action-item" @click="handleQuickAction('todo')">
            <component :is="CheckSquare" class="quick-action-icon" />
            <span>创建待办</span>
          </div>
          <div class="quick-action-item" @click="handleQuickAction('transaction')">
            <component :is="DollarSign" class="quick-action-icon" />
            <span>记一笔账</span>
          </div>
          <div class="quick-action-item" @click="handleQuickAction('health')">
            <component :is="Activity" class="quick-action-icon" />
            <span>健康记录</span>
          </div>
        </div>
      </div>

      <div class="step-actions">
        <Button 
          variant="primary" 
          size="lg" 
          @click="completeOnboarding"
          title="开始使用觅记"
          class="icon-only-button-primary"
        >
          <component :is="Rocket" class="w-6 h-6" />
        </Button>
      </div>
    </div>

    <!-- 步骤指示器 -->
    <div class="step-indicator">
      <div
        v-for="i in 3"
        :key="i"
        class="indicator-dot"
        :class="{ active: currentStep === i - 1 }"
      />
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue';
import { useRouter } from 'vue-router';
import { useFirstLaunch } from '@/composables/useFirstLaunch';
import { useNotificationPermission } from '@/composables/useNotificationPermission';
import Button from '@/components/ui/Button.vue';
import {
  Sparkles,
  CheckCircle,
  ArrowRight,
  Bell,
  Clock,
  CreditCard,
  Heart,
  Unlock,
  AlertCircle,
  CheckCircle2,
  CheckSquare,
  DollarSign,
  Activity,
  Rocket,
  X,
} from 'lucide-vue-next';

// ==================== Props & Emits ====================

interface Emits {
  (e: 'complete'): void;
}

const emit = defineEmits<Emits>();

// ==================== Composables ====================

const router = useRouter();
const firstLaunch = useFirstLaunch();
const { requestPermission: requestNotificationPermission } = useNotificationPermission();

// ==================== 状态 ====================

const currentStep = ref(0);
const requesting = ref(false);
const permissionError = ref<string | null>(null);

// ==================== 方法 ====================

/**
 * 下一步
 */
function nextStep() {
  if (currentStep.value < 2) {
    currentStep.value++;
  }
}

/**
 * 请求通知权限
 */
async function requestPermission() {
  requesting.value = true;
  permissionError.value = null;

  try {
    const granted = await requestNotificationPermission();
    
    // 标记已请求权限
    await firstLaunch.markPermissionAsked();

    if (granted) {
      console.log('✅ 用户授予了通知权限');
      nextStep();
    } else {
      permissionError.value = '权限请求被拒绝。您可以稍后在设置中开启。';
      // 即使拒绝也进入下一步
      setTimeout(() => {
        nextStep();
      }, 2000);
    }
  } catch (error) {
    console.error('请求权限失败:', error);
    permissionError.value = '请求权限时发生错误';
  } finally {
    requesting.value = false;
  }
}

/**
 * 跳过权限设置
 */
async function skipPermission() {
  await firstLaunch.markPermissionAsked();
  nextStep();
}

/**
 * 快捷操作
 */
function handleQuickAction(action: string) {
  const routes: Record<string, string> = {
    todo: '/todos',
    transaction: '/money',
    health: '/health',
  };

  const route = routes[action];
  if (route) {
    completeOnboarding();
    router.push(route);
  }
}

/**
 * 完成引导
 */
async function completeOnboarding() {
  await firstLaunch.markFirstLaunchCompleted();
  emit('complete');
  router.push('/');
}
</script>

<style scoped>
.welcome-onboarding {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  min-height: 100vh;
  padding: 30px 20px;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  position: relative;
}

.onboarding-step {
  max-width: 600px;
  width: 100%;
  max-height: calc(100vh - 80px);
  background: white;
  border-radius: 20px;
  padding: 28px;
  box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
  animation: slideUp 0.5s ease-out;
  overflow: hidden;
  display: flex;
  flex-direction: column;
}

@keyframes slideUp {
  from {
    opacity: 0;
    transform: translateY(30px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.step-content {
  text-align: center;
  margin-bottom: 20px;
  flex: 1;
  overflow: hidden;
}

.step-icon {
  width: 80px;
  height: 80px;
  margin: 0 auto 16px;
}

.step-title {
  font-size: 28px;
  font-weight: 700;
  color: #1a202c;
  margin-bottom: 12px;
}

.step-description {
  font-size: 15px;
  color: #718096;
  line-height: 1.5;
  margin-bottom: 20px;
}

.feature-list {
  list-style: none;
  padding: 0;
  text-align: left;
  max-width: 400px;
  margin: 0 auto;
}

.feature-list li {
  display: flex;
  align-items: center;
  padding: 8px 0;
  font-size: 15px;
  color: #2d3748;
}

.feature-icon {
  width: 20px;
  height: 20px;
  color: #48bb78;
  margin-right: 10px;
  flex-shrink: 0;
}

.notification-benefits {
  display: flex;
  flex-direction: column;
  gap: 12px;
  margin: 16px 0;
}

.benefit-item {
  display: flex;
  align-items: center;
  text-align: left;
  padding: 10px 12px;
  background: #f7fafc;
  border-radius: 8px;
  gap: 12px;
}

.benefit-icon {
  width: 28px;
  height: 28px;
  flex-shrink: 0;
}

.benefit-item span {
  font-size: 13px;
  color: #475569;
  line-height: 1.4;
}

.error-message {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  padding: 10px 12px;
  background: #fed7d7;
  color: #c53030;
  border-radius: 8px;
  font-size: 13px;
  margin-top: 12px;
}

.quick-actions {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 12px;
  margin-top: 24px;
}

.quick-action-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
  padding: 16px 12px;
  background: #f7fafc;
  border-radius: 10px;
  cursor: pointer;
  transition: all 0.2s;
}

.quick-action-item:hover {
  background: #edf2f7;
  transform: translateY(-2px);
}

.quick-action-icon {
  width: 32px;
  height: 32px;
  color: #667eea;
}

.quick-action-item span {
  font-size: 14px;
  font-weight: 500;
  color: #2d3748;
}

.step-actions {
  display: flex;
  gap: 16px;
  justify-content: center;
  margin-top: 4px;
  flex-shrink: 0;
}

.step-indicator {
  display: flex;
  gap: 8px;
  margin-top: 24px;
}

.indicator-dot {
  width: 10px;
  height: 10px;
  border-radius: 50%;
  background: rgba(255, 255, 255, 0.4);
  transition: all 0.3s;
}

.indicator-dot.active {
  width: 30px;
  border-radius: 5px;
  background: white;
}

/* 图标按钮样式 */
.icon-only-button {
  min-width: 64px !important;
  width: 64px !important;
  height: 64px !important;
  padding: 0 !important;
  display: flex !important;
  align-items: center !important;
  justify-content: center !important;
  border: 2px solid #e2e8f0 !important;
  border-radius: 50% !important;
  background: white !important;
  color: #64748b !important;
  transition: all 0.2s !important;
}

.icon-only-button:hover {
  border-color: #cbd5e0 !important;
  background: #f8fafc !important;
  color: #475569 !important;
  transform: scale(1.05) !important;
}

.icon-only-button-primary {
  min-width: 64px !important;
  width: 64px !important;
  height: 64px !important;
  padding: 0 !important;
  display: flex !important;
  align-items: center !important;
  justify-content: center !important;
  border-radius: 50% !important;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%) !important;
  border: none !important;
  box-shadow: 0 4px 12px rgba(102, 126, 234, 0.4) !important;
  transition: all 0.3s !important;
}

.icon-only-button-primary:hover {
  transform: translateY(-2px) scale(1.05) !important;
  box-shadow: 0 6px 20px rgba(102, 126, 234, 0.5) !important;
}
</style>
