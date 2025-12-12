<script setup lang="ts">
  import {
    ArrowRight,
    CheckCircle2,
    Clock,
    DollarSign,
    Eye,
    Inbox,
    RefreshCw,
    Search,
    TrendingDown,
    TrendingUp,
    Users,
  } from 'lucide-vue-next';
  import { useRouter } from 'vue-router';
  import Button from '@/components/ui/Button.vue';
  import { useMoneyAuth } from '@/composables/useMoneyAuth';
  import type { DebtRelation } from '@/services/money/debt';
  import { debtService } from '@/services/money/debt';
  import { handleApiError } from '@/utils/apiHelper';
  import { toast } from '@/utils/toast';

  // ==================== 接口定义 ====================

  interface Member {
    serialNum: string;
    name: string;
    color?: string;
  }

  interface DebtStatistics {
    totalDebt: number;
    totalCredit: number;
    debtCount: number;
    creditCount: number;
    memberCount: number;
    totalRelations: number;
  }

  type DebtStatusFilter = 'active' | 'settled' | 'cancelled' | 'all';

  interface DebtFilters {
    memberSerialNum: string;
    status: DebtStatusFilter;
  }

  // ==================== 状态管理 ====================

  const router = useRouter();

  // 数据
  const debtRelations = ref<DebtRelation[]>([]);
  const members = ref<Member[]>([]);
  const loading = ref(false);
  const syncing = ref(false);

  // 使用认证composable获取当前用户信息
  const { currentLedgerSerialNum, currentMemberSerialNum } = useMoneyAuth();

  // 筛选
  const filters = ref<DebtFilters>({
    memberSerialNum: '',
    status: 'all',
  });
  const searchQuery = ref('');
  const sortBy = ref('amount');

  // 分页
  const currentPage = ref(1);
  const pageSize = 20;

  // ==================== 计算属性 ====================

  // 统计信息
  const statistics = computed<DebtStatistics>(() => {
    const stats = {
      totalDebt: 0,
      totalCredit: 0,
      debtCount: 0,
      creditCount: 0,
      memberCount: 0,
      totalRelations: debtRelations.value.filter(r => r.status === 'active').length,
    };

    const memberSet = new Set<string>();

    debtRelations.value.forEach(relation => {
      if (relation.status !== 'active') return;

      memberSet.add(relation.debtorMemberSerialNum);
      memberSet.add(relation.creditorMemberSerialNum);

      // 我欠别人
      if (relation.debtorMemberSerialNum === currentMemberSerialNum.value) {
        stats.totalDebt += relation.amount;
        stats.debtCount++;
      }

      // 别人欠我
      if (relation.creditorMemberSerialNum === currentMemberSerialNum.value) {
        stats.totalCredit += relation.amount;
        stats.creditCount++;
      }
    });

    stats.memberCount = memberSet.size;

    return stats;
  });

  // 净额
  const netAmount = computed(() => statistics.value.totalCredit - statistics.value.totalDebt);

  const netAmountClass = computed(() => {
    if (netAmount.value > 0) return 'text-green-600';
    if (netAmount.value < 0) return 'text-red-600';
    return 'text-gray-600';
  });

  const netAmountText = computed(() => {
    const abs = Math.abs(netAmount.value);
    if (netAmount.value > 0) return `+¥${formatAmount(abs)}`;
    if (netAmount.value < 0) return `-¥${formatAmount(abs)}`;
    return '¥0.00';
  });

  const netAmountHint = computed(() => {
    if (netAmount.value > 0) return '净债权';
    if (netAmount.value < 0) return '净债务';
    return '已平衡';
  });

  // 筛选后的关系
  const filteredRelations = computed(() => {
    let result = [...debtRelations.value];

    // 筛选成员
    if (filters.value.memberSerialNum) {
      result = result.filter(
        r =>
          r.debtorMemberSerialNum === filters.value.memberSerialNum ||
          r.creditorMemberSerialNum === filters.value.memberSerialNum,
      );
    }

    // 筛选状态
    if (filters.value.status !== 'all') {
      result = result.filter(r => r.status === filters.value.status);
    }

    // 搜索
    if (searchQuery.value) {
      const query = searchQuery.value.toLowerCase();
      result = result.filter(
        r =>
          r.debtorMemberName.toLowerCase().includes(query) ||
          r.creditorMemberName.toLowerCase().includes(query),
      );
    }

    // 排序
    switch (sortBy.value) {
      case 'amount':
        result.sort((a, b) => b.amount - a.amount);
        break;
      case 'time':
        result.sort(
          (a, b) => new Date(b.lastCalculatedAt).getTime() - new Date(a.lastCalculatedAt).getTime(),
        );
        break;
      case 'member':
        result.sort((a, b) => a.debtorMemberName.localeCompare(b.debtorMemberName));
        break;
    }

    return result;
  });

  // 分页后的关系
  const paginatedRelations = computed(() => {
    const start = (currentPage.value - 1) * pageSize;
    const end = start + pageSize;
    return filteredRelations.value.slice(start, end);
  });

  const totalPages = computed(() => Math.ceil(filteredRelations.value.length / pageSize));

  // ==================== 方法 ====================

  // 加载债务关系数据
  async function loadData() {
    loading.value = true;
    try {
      const result = await debtService.listRelations({
        familyLedgerSerialNum: currentLedgerSerialNum.value,
        memberSerialNum: filters.value.memberSerialNum || undefined,
        status: filters.value.status === 'all' ? undefined : filters.value.status,
      });
      debtRelations.value = result.rows || [];

      // TODO: 从成员API获取成员列表
      // members.value = await memberService.listMembers(currentLedgerSerialNum.value);
    } catch (error) {
      handleApiError(error, '加载债务关系失败');
    } finally {
      loading.value = false;
    }
  }

  // 同步债务关系
  async function handleSync() {
    syncing.value = true;
    try {
      const count = await debtService.syncRelations(
        currentLedgerSerialNum.value,
        currentMemberSerialNum.value,
      );
      await loadData();
      toast.success(`同步成功，更新了 ${count} 条记录`);
    } catch (error) {
      handleApiError(error, '同步债务关系失败');
    } finally {
      syncing.value = false;
    }
  }

  // 发起结算
  function handleSettlement() {
    router.push('/money/settlement-suggestion');
  }

  // 查看详情
  function viewRelationDetail(relation: DebtRelation) {
    // eslint-disable-next-line no-console
    console.log('查看详情:', relation);
    // TODO: 打开详情弹窗或跳转
  }

  // 标记为已结算
  async function markAsSettled(relation: DebtRelation) {
    try {
      await debtService.markAsSettled(relation.serialNum);
      relation.status = 'settled';
      toast.success('已标记为结算');
    } catch (error) {
      handleApiError(error, '标记结算失败');
    }
  }

  // 获取边框颜色
  function getBorderColor(relation: DebtRelation) {
    if (relation.debtorMemberSerialNum === currentMemberSerialNum.value) {
      return 'border-l-red-500';
    }
    if (relation.creditorMemberSerialNum === currentMemberSerialNum.value) {
      return 'border-l-green-500';
    }
    return 'border-l-transparent';
  }

  // 获取成员颜色
  function getMemberColor(memberSerialNum: string) {
    const colors = [
      '#3b82f6',
      '#ef4444',
      '#10b981',
      '#f59e0b',
      '#8b5cf6',
      '#ec4899',
      '#14b8a6',
      '#f97316',
    ];
    const index = Number.parseInt(memberSerialNum.slice(-1), 16) % colors.length;
    return colors[index];
  }

  // 获取首字母
  function getInitials(name: string) {
    return name.charAt(0).toUpperCase();
  }

  // 格式化金额
  function formatAmount(amount: number) {
    return amount.toFixed(2);
  }

  // 格式化时间
  function formatTime(dateString: string) {
    const date = new Date(dateString);
    const now = new Date();
    const diff = now.getTime() - date.getTime();
    const days = Math.floor(diff / (1000 * 60 * 60 * 24));

    if (days === 0) return '今天';
    if (days === 1) return '昨天';
    if (days < 7) return `${days}天前`;
    return date.toLocaleDateString();
  }

  // 获取状态文本
  function getStatusText(status: string) {
    const statusMap: Record<string, string> = {
      active: '活跃',
      settled: '已结算',
      cancelled: '已取消',
    };
    return statusMap[status] || status;
  }

  // ==================== 生命周期 ====================

  onMounted(() => {
    loadData();
  });
</script>

<template>
  <div class="p-6 flex flex-col gap-6">
    <!-- 页面标题 -->
    <div class="flex flex-col md:flex-row md:items-start md:justify-between gap-4">
      <div class="flex-1">
        <h1 class="text-2xl font-bold text-gray-900 dark:text-gray-100">债务关系</h1>
        <p class="mt-1 text-sm text-gray-600 dark:text-gray-400">查看和管理成员间的债务关系</p>
      </div>
      <div class="flex items-center gap-3">
        <Button variant="secondary" @click="handleSync">
          <component :is="RefreshCw" :class="{ 'animate-spin': syncing }" class="w-4 h-4" />
          <span>同步债务</span>
        </Button>
        <Button variant="primary" @click="handleSettlement">
          <component :is="TrendingUp" class="w-4 h-4" />
          <span>发起结算</span>
        </Button>
      </div>
    </div>

    <!-- 统计卡片 -->
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
      <div
        class="bg-white dark:bg-gray-800 rounded-lg p-5 flex items-center gap-4 shadow-sm hover:shadow-md transition-shadow"
      >
        <div
          class="w-12 h-12 rounded-lg bg-red-100 dark:bg-red-900/30 text-red-600 dark:text-red-400 flex items-center justify-center"
        >
          <component :is="TrendingDown" class="w-6 h-6" />
        </div>
        <div class="flex-1">
          <div class="text-sm text-gray-600 dark:text-gray-400">我欠别人</div>
          <div class="text-2xl font-bold text-gray-900 dark:text-gray-100 mt-1">
            ¥{{ formatAmount(statistics.totalDebt) }}
          </div>
          <div class="text-xs text-gray-500 dark:text-gray-400 mt-1">
            {{ statistics.debtCount }}笔债务
          </div>
        </div>
      </div>

      <div
        class="bg-white dark:bg-gray-800 rounded-lg p-5 flex items-center gap-4 shadow-sm hover:shadow-md transition-shadow"
      >
        <div
          class="w-12 h-12 rounded-lg bg-green-100 dark:bg-green-900/30 text-green-600 dark:text-green-400 flex items-center justify-center"
        >
          <component :is="TrendingUp" class="w-6 h-6" />
        </div>
        <div class="flex-1">
          <div class="text-sm text-gray-600 dark:text-gray-400">别人欠我</div>
          <div class="text-2xl font-bold text-gray-900 dark:text-gray-100 mt-1">
            ¥{{ formatAmount(statistics.totalCredit) }}
          </div>
          <div class="text-xs text-gray-500 dark:text-gray-400 mt-1">
            {{ statistics.creditCount }}笔债权
          </div>
        </div>
      </div>

      <div
        class="bg-white dark:bg-gray-800 rounded-lg p-5 flex items-center gap-4 shadow-sm hover:shadow-md transition-shadow"
      >
        <div
          class="w-12 h-12 rounded-lg bg-blue-100 dark:bg-blue-900/30 text-blue-600 dark:text-blue-400 flex items-center justify-center"
        >
          <component :is="DollarSign" class="w-6 h-6" />
        </div>
        <div class="flex-1">
          <div class="text-sm text-gray-600 dark:text-gray-400">净额</div>
          <div class="text-2xl font-bold mt-1" :class="netAmountClass">{{ netAmountText }}</div>
          <div class="text-xs text-gray-500 dark:text-gray-400 mt-1">{{ netAmountHint }}</div>
        </div>
      </div>

      <div
        class="bg-white dark:bg-gray-800 rounded-lg p-5 flex items-center gap-4 shadow-sm hover:shadow-md transition-shadow"
      >
        <div
          class="w-12 h-12 rounded-lg bg-gray-100 dark:bg-gray-700 text-gray-600 dark:text-gray-400 flex items-center justify-center"
        >
          <component :is="Users" class="w-6 h-6" />
        </div>
        <div class="flex-1">
          <div class="text-sm text-gray-600 dark:text-gray-400">涉及成员</div>
          <div class="text-2xl font-bold text-gray-900 dark:text-gray-100 mt-1">
            {{ statistics.memberCount }}
          </div>
          <div class="text-xs text-gray-500 dark:text-gray-400 mt-1">
            {{ statistics.totalRelations }}条关系
          </div>
        </div>
      </div>
    </div>

    <!-- 筛选和操作栏 -->
    <div
      class="flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-4 bg-white dark:bg-gray-800 rounded-lg p-4 shadow-sm"
    >
      <div class="flex flex-col sm:flex-row items-stretch sm:items-center gap-3">
        <!-- 成员筛选 -->
        <select
          v-model="filters.memberSerialNum"
          class="px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg text-sm bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100 focus:outline-2 focus:outline-blue-600 focus:outline-offset-2 focus:border-transparent"
        >
          <option value="">全部成员</option>
          <option v-for="member in members" :key="member.serialNum" :value="member.serialNum">
            {{ member.name }}
          </option>
        </select>

        <!-- 状态筛选 -->
        <select
          v-model="filters.status"
          class="px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg text-sm bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100 focus:outline-2 focus:outline-blue-600 focus:outline-offset-2 focus:border-transparent"
        >
          <option value="all">全部状态</option>
          <option value="active">活跃</option>
          <option value="settled">已结算</option>
          <option value="cancelled">已取消</option>
        </select>

        <!-- 排序 -->
        <select
          v-model="sortBy"
          class="px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg text-sm bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100 focus:outline-2 focus:outline-blue-600 focus:outline-offset-2 focus:border-transparent"
        >
          <option value="amount">按金额</option>
          <option value="time">按时间</option>
          <option value="member">按成员</option>
        </select>
      </div>

      <div class="flex items-center gap-3">
        <div class="relative">
          <component
            :is="Search"
            class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400"
          />
          <input
            v-model="searchQuery"
            type="text"
            placeholder="搜索成员..."
            class="pl-10 pr-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg text-sm bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100 w-full sm:w-64 focus:outline-2 focus:outline-blue-600 focus:outline-offset-2 focus:border-transparent"
          />
        </div>
      </div>
    </div>

    <!-- 债务关系列表 -->
    <div v-if="loading" class="flex flex-col items-center justify-center py-20">
      <div
        class="w-12 h-12 border-4 border-blue-600 border-t-transparent rounded-full animate-spin"
      />
      <p class="mt-4 text-gray-600 dark:text-gray-400">加载中...</p>
    </div>

    <div
      v-else-if="filteredRelations.length === 0"
      class="flex flex-col items-center justify-center py-20 bg-white dark:bg-gray-800 rounded-lg"
    >
      <component :is="Inbox" class="w-16 h-16 text-gray-400 dark:text-gray-600" />
      <p class="mt-4 text-lg font-medium text-gray-900 dark:text-gray-100">暂无债务关系</p>
      <p class="mt-2 text-sm text-gray-600 dark:text-gray-400">分摆记录产生后会自动生成债务关系</p>
      <Button variant="primary" class="mt-4" @click="handleSync">
        <component :is="RefreshCw" class="w-4 h-4" />
        <span>同步债务关系</span>
      </Button>
    </div>

    <div v-else class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
      <!-- 债务关系卡片 -->
      <div
        v-for="relation in paginatedRelations"
        :key="relation.serialNum"
        class="bg-white dark:bg-gray-800 rounded-lg shadow-sm hover:shadow-md transition-shadow border-l-4"
        :class="[
          getBorderColor(relation),
          relation.status !== 'active' ? 'opacity-50' : '',
        ]"
      >
        <div
          class="p-4 flex items-center justify-between border-b border-gray-200 dark:border-gray-700"
        >
          <div class="flex items-center gap-2">
            <!-- 债务人头像 -->
            <div
              class="w-10 h-10 rounded-full flex items-center justify-center text-white font-bold text-sm"
              :style="{ backgroundColor: getMemberColor(relation.debtorMemberSerialNum) }"
            >
              {{ getInitials(relation.debtorMemberName) }}
            </div>

            <!-- 箭头 -->
            <div class="text-gray-400">
              <component :is="ArrowRight" class="w-5 h-5" />
            </div>

            <!-- 债权人头像 -->
            <div
              class="w-10 h-10 rounded-full flex items-center justify-center text-white font-bold text-sm"
              :style="{ backgroundColor: getMemberColor(relation.creditorMemberSerialNum) }"
            >
              {{ getInitials(relation.creditorMemberName) }}
            </div>
          </div>

          <div class="flex items-center gap-2">
            <button
              class="p-2 rounded-lg transition-colors text-gray-600 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-700 hover:text-gray-900 dark:hover:text-gray-100"
              title="查看详情"
              @click="viewRelationDetail(relation)"
            >
              <component :is="Eye" class="w-4 h-4" />
            </button>
            <button
              v-if="relation.status === 'active'"
              class="p-2 rounded-lg transition-colors text-gray-600 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-700 hover:text-gray-900 dark:hover:text-gray-100"
              title="标记为已结算"
              @click="markAsSettled(relation)"
            >
              <component :is="CheckCircle2" class="w-4 h-4" />
            </button>
          </div>
        </div>

        <div class="p-4 flex flex-col gap-3">
          <div class="text-sm text-gray-600 dark:text-gray-400">
            <span class="font-medium text-gray-900 dark:text-gray-100"
              >{{ relation.debtorMemberName }}</span
            >
            <span class="mx-1">欠</span>
            <span class="font-medium text-gray-900 dark:text-gray-100"
              >{{ relation.creditorMemberName }}</span
            >
          </div>

          <div class="flex items-baseline gap-2">
            <span class="text-2xl font-bold text-gray-900 dark:text-gray-100"
              >¥{{ formatAmount(relation.amount) }}</span
            >
            <span class="text-sm text-gray-500">{{ relation.currency }}</span>
          </div>

          <div class="flex items-center justify-between text-xs text-gray-500">
            <span class="flex items-center gap-1">
              <component :is="Clock" class="w-3 h-3" />
              {{ formatTime(relation.lastCalculatedAt) }}
            </span>
            <span
              class="px-2 py-1 rounded-full text-xs font-medium"
              :class="[
                relation.status === 'active' ? 'bg-blue-100 dark:bg-blue-900/30 text-blue-800 dark:text-blue-300'
                : relation.status === 'settled' ? 'bg-gray-100 dark:bg-gray-700 text-gray-700 dark:text-gray-300'
                  : 'bg-red-100 dark:bg-red-900/30 text-red-800 dark:text-red-300',
              ]"
            >
              {{ getStatusText(relation.status) }}
            </span>
          </div>
        </div>
      </div>
    </div>

    <!-- 分页 -->
    <div
      v-if="filteredRelations.length > pageSize"
      class="flex items-center justify-center gap-4 mt-6"
    >
      <button
        class="px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg text-sm bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100 transition-colors hover:bg-gray-50 dark:hover:bg-gray-700 disabled:opacity-50 disabled:cursor-not-allowed"
        :disabled="currentPage === 1"
        @click="currentPage--"
      >
        上一页
      </button>
      <span class="text-sm text-gray-600 dark:text-gray-400">
        第 {{ currentPage }}/ {{ totalPages }}页，共 {{ filteredRelations.length }}条
      </span>
      <button
        class="px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg text-sm bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100 transition-colors hover:bg-gray-50 dark:hover:bg-gray-700 disabled:opacity-50 disabled:cursor-not-allowed"
        :disabled="currentPage === totalPages"
        @click="currentPage++"
      >
        下一页
      </button>
    </div>
  </div>
</template>
