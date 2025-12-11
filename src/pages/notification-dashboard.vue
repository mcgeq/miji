<script setup lang="ts">
  import {
    AlertCircle,
    ArrowLeft,
    ArrowRight,
    BarChart3,
    Bell,
    Check,
    CheckCircle,
    Clock,
    Inbox,
    Loader2,
    PieChart,
    RefreshCw,
    TrendingUp,
    XCircle,
  } from 'lucide-vue-next';
  import { type Component, computed, onMounted, ref } from 'vue';
  import { useRoute, useRouter } from 'vue-router';
  import Badge from '@/components/ui/Badge.vue';
  import Button from '@/components/ui/Button.vue';
  import Card from '@/components/ui/Card.vue';
  import { useNotificationStore } from '@/stores/notification';
  import {
    type NotificationDashboardData,
    NotificationPriorityColor,
    NotificationTypeLabel,
  } from '@/types/notification';

  definePage({
    meta: {
      title: '通知统计',
      requiresAuth: true,
    },
  });

  const router = useRouter();
  const route = useRoute();
  const store = useNotificationStore();
  const loading = ref(false);
  const selectedPeriod = ref<'7d' | '30d' | '90d'>('7d');

  // 返回按钮处理
  function handleGoBack() {
    // 如果是从设置页面来的，返回到设置页面的通知标签
    if (route.query.from === 'settings') {
      router.push({ path: '/settings', query: { tab: 'notifications' } });
    } else {
      router.push('/settings/notifications');
    }
  }

  const statistics = computed<NotificationDashboardData | null>(() => {
    if (!store.statistics) {
      return null;
    }
    return {
      ...store.statistics,
      growthRate: 0, // TODO: 计算增长率需要对比历史数据
      typeDistribution: Object.entries(store.statistics.byType).map(([type, count]) => ({
        type,
        count,
      })),
      priorityDistribution: Object.entries(store.statistics.byPriority).map(
        ([priority, count]) => ({ priority, count }),
      ),
      dailyTrend: [], // TODO: 后端添加每日趋势数据
      recentLogs: store.recentLogs,
    };
  });

  const successRate = computed(() => {
    if (!statistics.value || statistics.value.total === 0) return 0;
    return Math.round((statistics.value.success / statistics.value.total) * 100);
  });

  const failureRate = computed(() => {
    if (!statistics.value || statistics.value.total === 0) return 0;
    return Math.round((statistics.value.failed / statistics.value.total) * 100);
  });

  function getTypeColor(type: string): string {
    const colorMap: Record<string, string> = {
      TodoReminder: '#3b82f6',
      BillReminder: '#10b981',
      PeriodReminder: '#ec4899',
      OvulationReminder: '#f59e0b',
      PmsReminder: '#8b5cf6',
      SystemAlert: '#ef4444',
    };
    return colorMap[type] || '#6b7280';
  }

  function getTypeLabel(type: string): string {
    return NotificationTypeLabel[type as keyof typeof NotificationTypeLabel] || type;
  }

  function getPriorityColor(priority: string): string {
    return NotificationPriorityColor[priority as keyof typeof NotificationPriorityColor] || 'gray';
  }

  function getBarHeight(value: number): number {
    if (!statistics.value?.dailyTrend || statistics.value.dailyTrend.length === 0) return 0;
    const max = Math.max(
      ...statistics.value.dailyTrend.map((d: { success: number; failed: number }) =>
        Math.max(d.success, d.failed),
      ),
    );
    return max > 0 ? (value / max) * 100 : 0;
  }

  function formatDate(dateStr: string): string {
    const date = new Date(dateStr);
    return `${date.getMonth() + 1}/${date.getDate()}`;
  }

  function formatTime(dateStr: string): string {
    const date = new Date(dateStr);
    const now = new Date();
    const diff = now.getTime() - date.getTime();
    const minutes = Math.floor(diff / 60000);
    const hours = Math.floor(diff / 3600000);
    const days = Math.floor(diff / 86400000);

    if (minutes < 60) return `${minutes}分钟前`;
    if (hours < 24) return `${hours}小时前`;
    if (days < 7) return `${days}天前`;
    return date.toLocaleDateString('zh-CN');
  }

  function getStatusIcon(status: string) {
    const iconMap: Record<string, Component> = {
      Sent: Check,
      Failed: XCircle,
      Pending: Clock,
    };
    return iconMap[status] || Bell;
  }

  function getStatusText(status: string): string {
    const textMap: Record<string, string> = {
      Sent: '已发送',
      Failed: '失败',
      Pending: '待发送',
    };
    return textMap[status] || status;
  }

  function getStatusColor(status: string): string {
    const colorMap: Record<string, string> = {
      Sent: 'green',
      Failed: 'red',
      Pending: 'orange',
    };
    return colorMap[status] || 'gray';
  }

  async function handlePeriodChange() {
    loading.value = true;
    try {
      await store.loadStatistics(selectedPeriod.value);
    } catch (error) {
      console.error('加载统计数据失败:', error);
    } finally {
      loading.value = false;
    }
  }

  async function handleRefresh() {
    loading.value = true;
    try {
      await store.loadStatistics(selectedPeriod.value);
    } catch (error) {
      console.error('刷新统计数据失败:', error);
    } finally {
      loading.value = false;
    }
  }

  onMounted(async () => {
    loading.value = true;
    try {
      await store.loadStatistics(selectedPeriod.value);
    } catch (error) {
      console.error('加载统计数据失败:', error);
    } finally {
      loading.value = false;
    }
  });
</script>

<template>
  <div class="p-6 min-h-screen bg-gray-50 dark:bg-gray-900">
    <div class="mb-6">
      <div class="flex items-center justify-between">
        <div class="flex items-center gap-3">
          <Button variant="ghost" @click="handleGoBack" class="shrink-0">
            <component :is="ArrowLeft" class="w-4 h-4" />
          </Button>
          <div>
            <h1 class="text-2xl font-bold text-gray-900 dark:text-white">通知统计</h1>
            <p class="text-sm text-gray-500 dark:text-gray-400 mt-1">查看通知数据分析和趋势</p>
          </div>
        </div>
        <div class="flex items-center gap-3">
          <select
            v-model="selectedPeriod"
            class="px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-sm text-gray-900 dark:text-white"
            @change="handlePeriodChange"
          >
            <option value="7d">最近 7 天</option>
            <option value="30d">最近 30 天</option>
            <option value="90d">最近 90 天</option>
          </select>

          <Button variant="outline" @click="handleRefresh" :loading="loading" title="刷新">
            <component :is="RefreshCw" class="w-4 h-4" />
          </Button>
        </div>
      </div>
    </div>

    <div v-if="loading" class="py-10 px-5">
      <div class="text-center py-20">
        <component :is="Loader2" class="w-12 h-12 animate-spin text-blue-500 mx-auto mb-4" />
        <p class="text-gray-500 dark:text-gray-400">加载统计数据中...</p>
      </div>
    </div>

    <div v-else-if="statistics">
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-5">
        <Card>
          <div class="p-5">
            <div class="flex items-start justify-between">
              <div>
                <p class="text-sm text-gray-500 dark:text-gray-400 mb-2">总通知数</p>
                <p class="text-3xl font-bold text-gray-900 dark:text-white mb-1">
                  {{ statistics.total }}
                </p>
                <p class="flex items-center gap-1 text-xs text-green-600 mt-1">
                  <component :is="TrendingUp" class="w-4 h-4" />
                  <span>较上期 +{{ statistics.growthRate }}%</span>
                </p>
              </div>
              <div
                class="w-12 h-12 rounded-xl bg-blue-100 dark:bg-blue-900/30 flex items-center justify-center"
              >
                <component :is="Bell" class="w-6 h-6 text-blue-600 dark:text-blue-400" />
              </div>
            </div>
          </div>
        </Card>

        <Card>
          <div class="p-5">
            <div class="flex items-start justify-between">
              <div>
                <p class="text-sm text-gray-500 dark:text-gray-400 mb-2">成功发送</p>
                <p class="text-3xl font-bold text-gray-900 dark:text-white mb-1">
                  {{ statistics.success }}
                </p>
                <p class="text-xs text-gray-400 mt-1">成功率 {{ successRate }}%</p>
              </div>
              <div
                class="w-12 h-12 rounded-xl bg-green-100 dark:bg-green-900/30 flex items-center justify-center"
              >
                <component :is="CheckCircle" class="w-6 h-6 text-green-600 dark:text-green-400" />
              </div>
            </div>
          </div>
        </Card>

        <Card>
          <div class="p-5">
            <div class="flex items-start justify-between">
              <div>
                <p class="text-sm text-gray-500 dark:text-gray-400 mb-2">发送失败</p>
                <p class="text-3xl font-bold text-red-600 dark:text-red-400 mb-1">
                  {{ statistics.failed }}
                </p>
                <p class="text-xs text-gray-400 mt-1">失败率 {{ failureRate }}%</p>
              </div>
              <div
                class="w-12 h-12 rounded-xl bg-red-100 dark:bg-red-900/30 flex items-center justify-center"
              >
                <component :is="AlertCircle" class="w-6 h-6 text-red-600 dark:text-red-400" />
              </div>
            </div>
          </div>
        </Card>

        <Card>
          <div class="p-5">
            <div class="flex items-start justify-between">
              <div>
                <p class="text-sm text-gray-500 dark:text-gray-400 mb-2">待发送</p>
                <p class="text-3xl font-bold text-orange-600 dark:text-orange-400 mb-1">
                  {{ statistics.pending }}
                </p>
                <p class="text-xs text-gray-400 mt-1">队列中</p>
              </div>
              <div
                class="w-12 h-12 rounded-xl bg-orange-100 dark:bg-orange-900/30 flex items-center justify-center"
              >
                <component :is="Clock" class="w-6 h-6 text-orange-600 dark:text-orange-400" />
              </div>
            </div>
          </div>
        </Card>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-2 gap-5 mt-6">
        <Card>
          <template #header>
            <div class="flex items-center justify-between">
              <h3 class="font-semibold text-gray-900 dark:text-white">通知类型分布</h3>
              <component :is="PieChart" class="w-5 h-5 text-gray-400" />
            </div>
          </template>

          <div class="flex flex-col gap-4 py-4">
            <div
              v-for="type in statistics.typeDistribution"
              :key="type.type"
              class="flex flex-col gap-2"
            >
              <div class="flex justify-between items-center">
                <div class="flex items-center gap-2">
                  <div
                    class="w-3 h-3 rounded-full"
                    :style="{ backgroundColor: getTypeColor(type.type) }"
                  />
                  <span class="text-sm text-gray-700 dark:text-gray-300"
                    >{{ getTypeLabel(type.type) }}</span
                  >
                </div>
                <span class="text-sm font-semibold text-gray-900 dark:text-white"
                  >{{ type.count }}</span
                >
              </div>
              <div class="h-2 bg-gray-100 dark:bg-gray-700 rounded-full overflow-hidden">
                <div
                  class="h-full rounded-full transition-all duration-300"
                  :style="{ 
                    width: `${(type.count / statistics.total * 100)}%`,
                    backgroundColor: getTypeColor(type.type)
                  }"
                />
              </div>
              <div class="text-xs text-gray-500 dark:text-gray-400 text-right">
                {{ Math.round(type.count / statistics.total * 100) }}%
              </div>
            </div>
          </div>
        </Card>

        <Card>
          <template #header>
            <div class="flex items-center justify-between">
              <h3 class="font-semibold text-gray-900 dark:text-white">发送趋势</h3>
              <component :is="BarChart3" class="w-5 h-5 text-gray-400" />
            </div>
          </template>

          <div class="py-4">
            <div class="flex items-end justify-between h-48 gap-2 px-2 mb-4">
              <div
                v-for="(day, index) in statistics.dailyTrend"
                :key="index"
                class="flex-1 flex flex-col items-center gap-2"
              >
                <div class="flex gap-0.5 items-end h-44 w-full justify-center">
                  <div
                    class="w-3 bg-green-500 rounded-t transition-all duration-300"
                    :style="{ height: `${getBarHeight(day.success)}%` }"
                    :title="`成功: ${day.success}`"
                  />
                  <div
                    class="w-3 bg-red-500 rounded-t transition-all duration-300"
                    :style="{ height: `${getBarHeight(day.failed)}%` }"
                    :title="`失败: ${day.failed}`"
                  />
                </div>
                <div class="text-xs text-gray-500 dark:text-gray-400">
                  {{ formatDate(day.date) }}
                </div>
              </div>
            </div>
            <div
              class="flex justify-center gap-6 pt-4 border-t border-gray-200 dark:border-gray-700"
            >
              <div class="flex items-center gap-2 text-sm text-gray-600 dark:text-gray-400">
                <div class="w-4 h-2 bg-green-500 rounded" />
                <span>成功</span>
              </div>
              <div class="flex items-center gap-2 text-sm text-gray-600 dark:text-gray-400">
                <div class="w-4 h-2 bg-red-500 rounded" />
                <span>失败</span>
              </div>
            </div>
          </div>
        </Card>
      </div>

      <Card class="mt-6">
        <template #header>
          <h3 class="font-semibold text-gray-900 dark:text-white">优先级分布</h3>
        </template>

        <div class="flex flex-col gap-4 py-4">
          <div
            v-for="priority in statistics.priorityDistribution"
            :key="priority.priority"
            class="flex flex-col gap-2"
          >
            <div class="flex justify-between items-center">
              <Badge :color="getPriorityColor(priority.priority)">{{ priority.priority }}</Badge>
              <span class="text-sm font-semibold text-gray-900 dark:text-white"
                >{{ priority.count }}</span
              >
            </div>
            <div class="h-2 bg-gray-100 dark:bg-gray-700 rounded-full overflow-hidden">
              <div
                class="h-full rounded-full transition-all duration-300"
                :style="{ width: `${(priority.count / statistics.total * 100)}%` }"
                :class="{
                  'bg-red-500': priority.priority === 'Urgent',
                  'bg-orange-500': priority.priority === 'High',
                  'bg-blue-500': priority.priority === 'Normal',
                  'bg-gray-500': priority.priority === 'Low'
                }"
              />
            </div>
          </div>
        </div>
      </Card>

      <Card class="mt-6">
        <template #header>
          <div class="flex items-center justify-between">
            <h3 class="font-semibold text-gray-900 dark:text-white">最近活动</h3>
            <Button variant="ghost" size="sm" @click="$router.push('/notifications')">
              查看全部
              <component :is="ArrowRight" class="w-4 h-4 ml-1" />
            </Button>
          </div>
        </template>

        <div v-if="statistics.recentLogs && statistics.recentLogs.length > 0" class="flex flex-col">
          <div
            v-for="log in statistics.recentLogs"
            :key="log.id"
            class="flex items-center gap-3 px-4 py-4 border-b border-gray-100 dark:border-gray-700 last:border-b-0 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors"
          >
            <div
              class="w-9 h-9 rounded-lg flex items-center justify-center shrink-0"
              :class="{
                'bg-green-100 text-green-600 dark:bg-green-900/30 dark:text-green-400': log.status === 'Sent',
                'bg-red-100 text-red-600 dark:bg-red-900/30 dark:text-red-400': log.status === 'Failed',
                'bg-orange-100 text-orange-600 dark:bg-orange-900/30 dark:text-orange-400': log.status === 'Pending'
              }"
            >
              <component :is="getStatusIcon(log.status)" class="w-4 h-4" />
            </div>
            <div class="flex-1 min-w-0">
              <p class="text-sm font-medium text-gray-900 dark:text-white mb-1 truncate">
                {{ log.title }}
              </p>
              <p class="text-xs text-gray-400">
                <span>{{ getTypeLabel(log.notificationType) }}</span>
                <span class="mx-2">·</span>
                <span>{{ formatTime(log.createdAt) }}</span>
              </p>
            </div>
            <Badge :color="getStatusColor(log.status)">{{ getStatusText(log.status) }}</Badge>
          </div>
        </div>
        <div v-else class="text-center py-8 text-gray-500 dark:text-gray-400">暂无最近活动</div>
      </Card>
    </div>

    <div v-else class="py-10 px-5 text-center">
      <component :is="Inbox" class="w-16 h-16 text-gray-300 dark:text-gray-600 mx-auto mb-4" />
      <p class="text-gray-500 dark:text-gray-400">暂无统计数据</p>
    </div>
  </div>
</template>
