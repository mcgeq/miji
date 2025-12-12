<script setup lang="ts">
  import { Button, Card, Spinner } from '@/components/ui';
  import { usePermission } from '@/composables/usePermission';
  import type { FamilyMember } from '@/schema/money';
  import { useFamilyMemberStore } from '@/stores/money';
  import { toast } from '@/utils/toast';

  interface Props {
    familyLedgerSerialNum: string;
  }

  const props = defineProps<Props>();
  const emit = defineEmits<{
    editMember: [member: FamilyMember];
    addMember: [];
  }>();

  const memberStore = useFamilyMemberStore();
  const { canManageMembers, canRemoveMember } = usePermission();

  // 使用store状态
  const { members, loading, memberStats } = storeToRefs(memberStore);

  // 获取成员列表
  onMounted(() => {
    memberStore.setCurrentLedger(props.familyLedgerSerialNum);
    memberStore.fetchMembers(props.familyLedgerSerialNum);
    memberStore.refreshAllMemberStats();
  });

  // 获取角色显示名称
  function getRoleDisplayName(role: string): string {
    const roleNames = {
      Owner: '所有者',
      Admin: '管理员',
      Member: '成员',
      Viewer: '查看者',
    };
    return roleNames[role as keyof typeof roleNames] || role;
  }

  // 获取角色颜色
  function getRoleColor(role: string): string {
    const roleColors = {
      Owner: 'text-yellow-600 dark:text-yellow-400 bg-yellow-50 dark:bg-yellow-900/30',
      Admin: 'text-blue-600 dark:text-blue-400 bg-blue-50 dark:bg-blue-900/30',
      Member: 'text-green-600 dark:text-green-400 bg-green-50 dark:bg-green-900/30',
      Viewer: 'text-gray-600 dark:text-gray-400 bg-gray-50 dark:bg-gray-800',
    };
    return (
      roleColors[role as keyof typeof roleColors] ||
      'text-gray-600 dark:text-gray-400 bg-gray-50 dark:bg-gray-800'
    );
  }

  // 获取成员统计
  function getMemberStats(memberSerialNum: string) {
    return (
      memberStats.value[memberSerialNum] || {
        totalPaid: 0,
        totalOwed: 0,
        netBalance: 0,
        pendingSettlement: 0,
        transactionCount: 0,
        splitCount: 0,
      }
    );
  }

  // 格式化金额
  function formatAmount(amount: number): string {
    return amount.toFixed(2);
  }

  // 获取余额状态
  function getBalanceStatus(netBalance: number): { text: string; color: string } {
    if (netBalance > 0) {
      return { text: '债权', color: 'text-green-600 dark:text-green-400' };
    }
    if (netBalance < 0) {
      return { text: '债务', color: 'text-red-600 dark:text-red-400' };
    }
    return { text: '平衡', color: 'text-gray-600 dark:text-gray-400' };
  }

  // 移除成员
  async function removeMember(member: FamilyMember) {
    if (!canRemoveMember.value) {
      toast.error('您没有权限移除成员');
      return;
    }

    if (member.isPrimary) {
      toast.error('不能移除主要成员');
      return;
    }

    // TODO: 添加确认对话框
    // const confirmed = confirm(`确定要移除成员 ${member.name} 吗？`);
    // if (!confirmed) return;

    // 临时跳过确认，后续可以添加ConfirmModal
    console.warn('移除成员功能需要添加确认对话框');

    try {
      await memberStore.removeMember(member.serialNum);
      toast.success('成员移除成功');
    } catch (error: unknown) {
      const errorMessage = error instanceof Error ? error.message : '移除成员失败';
      toast.error(errorMessage);
    }
  }

  // 编辑成员
  function editMember(member: FamilyMember) {
    emit('editMember', member);
  }

  // 添加成员
  function addMember() {
    emit('addMember');
  }
</script>

<template>
  <div class="p-4">
    <!-- 头部 -->
    <div class="flex items-center justify-between mb-6">
      <h3 class="text-xl font-semibold text-gray-900 dark:text-white">成员管理</h3>
      <Button v-permission="'member:add'" variant="primary" size="sm" @click="addMember">
        <LucidePlus :size="16" />
        <span class="ml-2">添加成员</span>
      </Button>
    </div>

    <!-- 加载状态 -->
    <div
      v-if="loading"
      class="flex items-center justify-center gap-2 py-8 text-gray-500 dark:text-gray-400"
    >
      <Spinner size="md" />
      <span>加载中...</span>
    </div>

    <!-- 空状态 -->
    <div
      v-else-if="members.length === 0"
      class="flex flex-col items-center justify-center py-12 text-gray-500 dark:text-gray-400"
    >
      <LucideUsers :size="48" class="opacity-50 mb-4" />
      <p class="text-base mb-4">暂无成员</p>
      <Button v-if="canManageMembers" variant="primary" size="sm" @click="addMember">
        添加第一个成员
      </Button>
    </div>

    <!-- 成员列表 -->
    <div v-else class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
      <Card v-for="member in members" :key="member.serialNum" padding="md" hoverable>
        <!-- 成员头部信息 -->
        <div class="flex items-start gap-3 mb-4">
          <div class="shrink-0">
            <img
              v-if="member.avatar"
              :src="member.avatar"
              :alt="member.name"
              class="w-10 h-10 rounded-full object-cover"
            />
            <div
              v-else
              class="w-10 h-10 rounded-full flex items-center justify-center text-white font-semibold text-base"
              :style="{ backgroundColor: member.colorTag || '#e5e7eb' }"
            >
              {{ member.name.charAt(0).toUpperCase() }}
            </div>
          </div>

          <div class="flex-1">
            <div class="flex items-center gap-2 mb-1">
              <h4 class="text-base font-semibold text-gray-900 dark:text-white">
                {{ member.name }}
              </h4>
              <LucideCrown v-if="member.isPrimary" :size="16" class="text-amber-500" />
            </div>
            <div class="flex items-center">
              <span
                class="px-2 py-0.5 rounded-full text-xs font-medium"
                :class="getRoleColor(member.role)"
              >
                {{ getRoleDisplayName(member.role) }}
              </span>
            </div>
          </div>

          <!-- 操作按钮 -->
          <div class="flex gap-1">
            <button
              class="p-1.5 border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-600 dark:text-gray-400 rounded transition-all hover:bg-gray-50 dark:hover:bg-gray-700 hover:border-gray-400 dark:hover:border-gray-500"
              title="编辑"
              @click="editMember(member)"
            >
              <LucideEdit :size="16" />
            </button>
            <button
              v-if="!member.isPrimary"
              v-permission="'member:remove'"
              class="p-1.5 border border-red-200 dark:border-red-900/50 bg-white dark:bg-gray-800 text-red-600 dark:text-red-400 rounded transition-all hover:bg-red-50 dark:hover:bg-red-900/20 hover:border-red-300 dark:hover:border-red-800"
              title="移除"
              @click="removeMember(member)"
            >
              <LucideTrash :size="16" />
            </button>
          </div>
        </div>

        <!-- 财务统计 -->
        <div class="border-t border-gray-200 dark:border-gray-700 pt-3 mb-3">
          <div class="flex justify-between mb-2">
            <div class="flex flex-col items-center flex-1">
              <span class="text-xs text-gray-500 dark:text-gray-400 mb-0.5">总支付</span>
              <span class="text-sm font-medium text-gray-900 dark:text-white"
                >¥{{ formatAmount(getMemberStats(member.serialNum).totalPaid) }}</span
              >
            </div>
            <div class="flex flex-col items-center flex-1">
              <span class="text-xs text-gray-500 dark:text-gray-400 mb-0.5">应分摊</span>
              <span class="text-sm font-medium text-gray-900 dark:text-white"
                >¥{{ formatAmount(getMemberStats(member.serialNum).totalOwed) }}</span
              >
            </div>
          </div>

          <div class="flex justify-between mb-2">
            <div class="flex flex-col items-center flex-1">
              <span class="text-xs text-gray-500 dark:text-gray-400 mb-0.5">净余额</span>
              <span
                class="text-sm font-medium"
                :class="getBalanceStatus(getMemberStats(member.serialNum).netBalance).color"
              >
                ¥{{ formatAmount(Math.abs(getMemberStats(member.serialNum).netBalance)) }}
                <span class="text-xs font-normal">
                  ({{ getBalanceStatus(getMemberStats(member.serialNum).netBalance).text }})
                </span>
              </span>
            </div>
          </div>

          <div class="flex justify-between">
            <div class="flex flex-col items-center flex-1">
              <span class="text-xs text-gray-500 dark:text-gray-400 mb-0.5">交易数</span>
              <span class="text-sm font-medium text-gray-900 dark:text-white"
                >{{ getMemberStats(member.serialNum).transactionCount }}</span
              >
            </div>
            <div class="flex flex-col items-center flex-1">
              <span class="text-xs text-gray-500 dark:text-gray-400 mb-0.5">分摊数</span>
              <span class="text-sm font-medium text-gray-900 dark:text-white"
                >{{ getMemberStats(member.serialNum).splitCount }}</span
              >
            </div>
          </div>
        </div>

        <!-- 最后活跃时间 -->
        <div
          v-if="member.lastActiveAt"
          class="border-t border-gray-200 dark:border-gray-700 pt-2 text-center"
        >
          <span class="text-xs text-gray-500 dark:text-gray-400">
            最后活跃: {{ new Date(member.lastActiveAt).toLocaleDateString() }}
          </span>
        </div>
      </Card>
    </div>
  </div>
</template>
