<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useNotificationStore } from '@/stores/notification';
import {
  NotificationTypeLabel,
  NotificationPriorityColor,
  type NotificationLog,
} from '@/types/notification';
import Card from '@/components/ui/Card.vue';
import Button from '@/components/ui/Button.vue';
import Badge from '@/components/ui/Badge.vue';
import {
  Bell,
  CheckCircle,
  AlertCircle,
  Clock,
  RefreshCw,
  Filter,
  Inbox,
  RotateCw,
  Trash2,
  CheckSquare,
  CreditCard,
  Calendar,
  Heart,
  Activity,
  BarChart3,
  ArrowLeft,
} from 'lucide-vue-next';

// 设置页面元信息
definePage({
  meta: {
    title: '通知历史',
    requiresAuth: true,
  },
});

// ==================== Store ====================

const store = useNotificationStore();

// ==================== 状态 ====================

const loading = ref(false);
const showFilterDialog = ref(false);
const currentPage = ref(1);
const pageSize = ref(20);

// ==================== 计算属性 ====================

const successCount = computed(() => {
  return store.logs.filter((log) => log.status === 'Sent').length;
});

const failureCount = computed(() => {
  return store.logs.filter((log) => log.status === 'Failed').length;
});

const pendingCount = computed(() => {
  return store.logs.filter((log) => log.status === 'Pending').length;
});

// ==================== 方法 ====================

/**
 * 获取日志图标
 */
function getLogIcon(type: string) {
  const iconMap: Record<string, any> = {
    TodoReminder: CheckSquare,
    BillReminder: CreditCard,
    PeriodReminder: Calendar,
    OvulationReminder: Heart,
    PmsReminder: Activity,
    SystemAlert: AlertCircle,
  };
  return iconMap[type] || Bell;
}

/**
 * 获取日志图标颜色
 */
function getLogIconColor(status: string) {
  const colorMap: Record<string, string> = {
    Sent: 'text-green-500',
    Failed: 'text-red-500',
    Pending: 'text-orange-500',
  };
  return colorMap[status] || 'text-gray-500';
}

/**
 * 获取状态文本
 */
function getStatusText(status: string) {
  const textMap: Record<string, string> = {
    Sent: '已发送',
    Failed: '失败',
    Pending: '待发送',
  };
  return textMap[status] || status;
}

/**
 * 获取状态颜色
 */
function getStatusColor(status: string) {
  const colorMap: Record<string, string> = {
    Sent: 'green',
    Failed: 'red',
    Pending: 'orange',
  };
  return colorMap[status] || 'gray';
}

/**
 * 获取优先级颜色
 */
function getPriorityColor(priority: string) {
  return NotificationPriorityColor[priority as keyof typeof NotificationPriorityColor] || 'gray';
}

/**
 * 获取类型标签
 */
function getTypeLabel(type: string) {
  return NotificationTypeLabel[type as keyof typeof NotificationTypeLabel] || type;
}

/**
 * 格式化时间
 */
function formatTime(time: string) {
  return new Date(time).toLocaleString('zh-CN');
}

/**
 * 刷新数据
 */
async function handleRefresh() {
  loading.value = true;
  try {
    await store.loadLogs({
      page: currentPage.value,
      size: pageSize.value,
    });
  } catch (error) {
    console.error('刷新失败:', error);
  } finally {
    loading.value = false;
  }
}

/**
 * 点击日志
 */
function handleLogClick(log: NotificationLog) {
  console.log('查看日志详情:', log);
  // TODO: 显示日志详情对话框
}

/**
 * 重试通知
 */
async function handleRetry(id: string) {
  try {
    await store.retryLog(id);
    // TODO: 显示成功提示
  } catch (error) {
    console.error('重试失败:', error);
    // TODO: 显示错误提示
  }
}

/**
 * 删除通知
 */
async function handleDelete(id: string) {
  // TODO: 显示确认对话框
  if (confirm('确定要删除这条通知记录吗？')) {
    try {
      await store.deleteLog(id);
      // TODO: 显示成功提示
    } catch (error) {
      console.error('删除失败:', error);
      // TODO: 显示错误提示
    }
  }
}

// ==================== 生命周期 ====================

onMounted(async () => {
  await handleRefresh();
});
</script>

<template>
  <div class="p-6 min-h-screen bg-gray-50 dark:bg-gray-900">
    <!-- 页面头部 -->
    <div class="mb-6">
      <div class="flex items-center justify-between">
        <div class="flex items-center gap-3">
          <Button variant="ghost" @click="$router.push('/settings/notifications')" class="flex-shrink-0">
            <component :is="ArrowLeft" class="w-4 h-4" />
          </Button>
          <div>
            <h1 class="text-2xl font-bold text-gray-900 dark:text-white">通知历史</h1>
            <p class="text-sm text-gray-500 dark:text-gray-400 mt-1">查看所有通知记录</p>
          </div>
        </div>
        <div class="flex space-x-3">
          <Button variant="outline" @click="$router.push('/notification-dashboard')" title="查看统计">
            <component :is="BarChart3" class="w-4 h-4" />
          </Button>
          <Button variant="outline" @click="handleRefresh" :loading="loading" title="刷新">
            <component :is="RefreshCw" class="w-4 h-4" />
          </Button>
          <Button variant="primary" @click="showFilterDialog = true" title="筛选">
            <component :is="Filter" class="w-4 h-4" />
          </Button>
        </div>
      </div>
    </div>

    <!-- 统计卡片 -->
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
      <Card>
        <div class="p-5">
          <div class="flex items-center justify-between">
            <div>
              <p class="text-sm text-gray-500 dark:text-gray-400">总通知数</p>
              <p class="text-2xl font-bold text-gray-900 dark:text-white mt-1">{{ store.logsTotal }}</p>
            </div>
            <div class="w-12 h-12 rounded-xl bg-blue-100 dark:bg-blue-900/30 flex items-center justify-center">
              <component :is="Bell" class="w-6 h-6 text-blue-600 dark:text-blue-400" />
            </div>
          </div>
        </div>
      </Card>

      <Card>
        <div class="p-5">
          <div class="flex items-center justify-between">
            <div>
              <p class="text-sm text-gray-500 dark:text-gray-400">成功发送</p>
              <p class="text-2xl font-bold text-green-600 dark:text-green-400 mt-1">
                {{ successCount }}
              </p>
            </div>
            <div class="w-12 h-12 rounded-xl bg-green-100 dark:bg-green-900/30 flex items-center justify-center">
              <component :is="CheckCircle" class="w-6 h-6 text-green-600 dark:text-green-400" />
            </div>
          </div>
        </div>
      </Card>

      <Card>
        <div class="p-5">
          <div class="flex items-center justify-between">
            <div>
              <p class="text-sm text-gray-500 dark:text-gray-400">发送失败</p>
              <p class="text-2xl font-bold text-red-600 dark:text-red-400 mt-1">
                {{ failureCount }}
              </p>
            </div>
            <div class="w-12 h-12 rounded-xl bg-red-100 dark:bg-red-900/30 flex items-center justify-center">
              <component :is="AlertCircle" class="w-6 h-6 text-red-600 dark:text-red-400" />
            </div>
          </div>
        </div>
      </Card>

      <Card>
        <div class="p-5">
          <div class="flex items-center justify-between">
            <div>
              <p class="text-sm text-gray-500 dark:text-gray-400">待发送</p>
              <p class="text-2xl font-bold text-orange-600 dark:text-orange-400 mt-1">
                {{ pendingCount }}
              </p>
            </div>
            <div class="w-12 h-12 rounded-xl bg-orange-100 dark:bg-orange-900/30 flex items-center justify-center">
              <component :is="Clock" class="w-6 h-6 text-orange-600 dark:text-orange-400" />
            </div>
          </div>
        </div>
      </Card>
    </div>

    <!-- 通知列表 -->
    <Card>
      <template #header>
        <h3 class="font-semibold">通知列表</h3>
      </template>

      <div v-if="loading" class="text-center py-12">
        <p class="text-gray-500 dark:text-gray-400">加载中...</p>
      </div>

      <div v-else-if="store.logs.length === 0" class="text-center py-12">
        <component :is="Inbox" class="w-16 h-16 text-gray-300 dark:text-gray-600 mx-auto mb-4" />
        <p class="text-gray-500 dark:text-gray-400">暂无通知记录</p>
      </div>

      <div v-else class="flex flex-col gap-4">
        <div
          v-for="log in store.logs"
          :key="log.id"
          class="p-4 border border-gray-200 dark:border-gray-700 rounded-lg cursor-pointer hover:border-blue-500 dark:hover:border-blue-400 hover:bg-gray-50 dark:hover:bg-gray-800 transition-all"
          @click="handleLogClick(log)"
        >
          <div class="flex items-start space-x-3">
            <!-- 图标 -->
            <div class="flex-shrink-0 w-10 h-10 flex items-center justify-center bg-gray-100 dark:bg-gray-800 rounded-lg">
              <component
                :is="getLogIcon(log.notificationType)"
                class="w-5 h-5"
                :class="getLogIconColor(log.status)"
              />
            </div>

            <!-- 内容 -->
            <div class="flex-1 min-w-0">
              <div class="flex items-center justify-between mb-1">
                <h4 class="font-medium text-gray-900 dark:text-white truncate">{{ log.title }}</h4>
                <Badge :color="getStatusColor(log.status)">
                  {{ getStatusText(log.status) }}
                </Badge>
              </div>
              <p class="text-sm text-gray-500 dark:text-gray-400 truncate mb-2">{{ log.body }}</p>
              <div class="flex items-center space-x-4 text-xs text-gray-400 dark:text-gray-500">
                <span>{{ getTypeLabel(log.notificationType) }}</span>
                <span>{{ formatTime(log.createdAt) }}</span>
                <Badge
                  :color="getPriorityColor(log.priority)"
                  size="sm"
                >
                  {{ log.priority }}
                </Badge>
              </div>
            </div>

            <!-- 操作按钮 -->
            <div class="flex gap-2">
              <Button
                v-if="log.status === 'Failed'"
                variant="ghost"
                size="sm"
                @click.stop="handleRetry(log.id)"
              >
                <component :is="RotateCw" class="w-4 h-4" />
              </Button>
              <Button
                variant="ghost"
                size="sm"
                @click.stop="handleDelete(log.id)"
              >
                <component :is="Trash2" class="w-4 h-4" />
              </Button>
            </div>
          </div>

          <!-- 错误信息 -->
          <div v-if="log.error" class="flex items-center mt-2 p-2 bg-red-50 dark:bg-red-900/20 rounded border border-red-200 dark:border-red-800">
            <component :is="AlertCircle" class="w-4 h-4 text-red-500 dark:text-red-400 mr-2" />
            <span class="text-sm text-red-600 dark:text-red-400">{{ log.error }}</span>
          </div>
        </div>
      </div>

      <!-- 分页 -->
      <div v-if="store.logsTotal > pageSize" class="pt-4 border-t border-gray-200 dark:border-gray-700">
        <!-- TODO: 添加分页组件 -->
        <p class="text-sm text-gray-500 dark:text-gray-400 text-center">
          显示 {{ store.logs.length }} / {{ store.logsTotal }} 条记录
        </p>
      </div>
    </Card>
  </div>
</template>