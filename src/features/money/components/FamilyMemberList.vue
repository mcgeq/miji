<script setup lang="ts">
import { usePermission } from '@/composables/usePermission';
import { useFamilyMemberStore } from '@/stores/money';
import { toast } from '@/utils/toast';
import type { FamilyMember } from '@/schema/money';

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
    Owner: 'text-yellow-600 bg-yellow-50',
    Admin: 'text-blue-600 bg-blue-50',
    Member: 'text-green-600 bg-green-50',
    Viewer: 'text-gray-600 bg-gray-50',
  };
  return roleColors[role as keyof typeof roleColors] || 'text-gray-600 bg-gray-50';
}

// 获取成员统计
function getMemberStats(memberSerialNum: string) {
  return memberStats.value[memberSerialNum] || {
    totalPaid: 0,
    totalOwed: 0,
    netBalance: 0,
    pendingSettlement: 0,
    transactionCount: 0,
    splitCount: 0,
  };
}

// 格式化金额
function formatAmount(amount: number): string {
  return amount.toFixed(2);
}

// 获取余额状态
function getBalanceStatus(netBalance: number): { text: string; color: string } {
  if (netBalance > 0) {
    return { text: '债权', color: 'text-green-600' };
  } else if (netBalance < 0) {
    return { text: '债务', color: 'text-red-600' };
  } else {
    return { text: '平衡', color: 'text-gray-600' };
  }
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
  } catch (error: any) {
    toast.error(error.message || '移除成员失败');
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
  <div class="member-list-container">
    <!-- 头部 -->
    <div class="list-header">
      <h3 class="list-title">
        成员管理
      </h3>
      <button
        v-permission="'member:add'"
        class="add-btn"
        @click="addMember"
      >
        <LucidePlus class="w-4 h-4" />
        添加成员
      </button>
    </div>

    <!-- 加载状态 -->
    <div v-if="loading" class="loading-container">
      <div class="loading-spinner" />
      <span>加载中...</span>
    </div>

    <!-- 空状态 -->
    <div v-else-if="members.length === 0" class="empty-state">
      <LucideUsers class="empty-icon" />
      <p class="empty-text">
        暂无成员
      </p>
      <button
        v-if="canManageMembers"
        class="empty-action-btn"
        @click="addMember"
      >
        添加第一个成员
      </button>
    </div>

    <!-- 成员列表 -->
    <div v-else class="member-grid">
      <div
        v-for="member in members"
        :key="member.serialNum"
        class="member-card"
      >
        <!-- 成员头部信息 -->
        <div class="member-header">
          <div class="member-avatar">
            <img
              v-if="member.avatar"
              :src="member.avatar"
              :alt="member.name"
              class="avatar-image"
            >
            <div
              v-else
              class="avatar-placeholder"
              :style="{ backgroundColor: member.colorTag || '#e5e7eb' }"
            >
              {{ member.name.charAt(0).toUpperCase() }}
            </div>
          </div>

          <div class="member-info">
            <div class="member-name-row">
              <h4 class="member-name">
                {{ member.name }}
              </h4>
              <LucideCrown v-if="member.isPrimary" class="primary-icon" />
            </div>
            <div class="member-role-row">
              <span class="role-badge" :class="[getRoleColor(member.role)]">
                {{ getRoleDisplayName(member.role) }}
              </span>
            </div>
          </div>

          <!-- 操作按钮 -->
          <div class="member-actions">
            <button
              class="action-btn"
              title="编辑"
              @click="editMember(member)"
            >
              <LucideEdit class="w-4 h-4" />
            </button>
            <button
              v-if="!member.isPrimary"
              v-permission="'member:remove'"
              class="action-btn action-btn-danger"
              title="移除"
              @click="removeMember(member)"
            >
              <LucideTrash class="w-4 h-4" />
            </button>
          </div>
        </div>

        <!-- 财务统计 -->
        <div class="member-stats">
          <div class="stats-row">
            <div class="stat-item">
              <span class="stat-label">总支付</span>
              <span class="stat-value">¥{{ formatAmount(getMemberStats(member.serialNum).totalPaid) }}</span>
            </div>
            <div class="stat-item">
              <span class="stat-label">应分摊</span>
              <span class="stat-value">¥{{ formatAmount(getMemberStats(member.serialNum).totalOwed) }}</span>
            </div>
          </div>

          <div class="stats-row">
            <div class="stat-item">
              <span class="stat-label">净余额</span>
              <span class="stat-value" :class="[getBalanceStatus(getMemberStats(member.serialNum).netBalance).color]">
                ¥{{ formatAmount(Math.abs(getMemberStats(member.serialNum).netBalance)) }}
                <span class="balance-status">
                  ({{ getBalanceStatus(getMemberStats(member.serialNum).netBalance).text }})
                </span>
              </span>
            </div>
          </div>

          <div class="stats-row">
            <div class="stat-item">
              <span class="stat-label">交易数</span>
              <span class="stat-value">{{ getMemberStats(member.serialNum).transactionCount }}</span>
            </div>
            <div class="stat-item">
              <span class="stat-label">分摊数</span>
              <span class="stat-value">{{ getMemberStats(member.serialNum).splitCount }}</span>
            </div>
          </div>
        </div>

        <!-- 最后活跃时间 -->
        <div v-if="member.lastActiveAt" class="member-footer">
          <span class="last-active">
            最后活跃: {{ new Date(member.lastActiveAt).toLocaleDateString() }}
          </span>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.member-list-container {
  padding: 1rem;
}

.list-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 1.5rem;
}

.list-title {
  font-size: 1.25rem;
  font-weight: 600;
  color: #1f2937;
}

.add-btn {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.5rem 1rem;
  background-color: #3b82f6;
  color: white;
  border-radius: 0.375rem;
  font-size: 0.875rem;
  transition: background-color 0.2s;
}

.add-btn:hover {
  background-color: #2563eb;
}

.loading-container {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  padding: 2rem;
  color: #6b7280;
}

.loading-spinner {
  width: 1rem;
  height: 1rem;
  border: 2px solid #e5e7eb;
  border-top-color: #3b82f6;
  border-radius: 50%;
  animation: spin 1s linear infinite;
}

@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}

.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 3rem;
  color: #6b7280;
}

.empty-icon {
  width: 3rem;
  height: 3rem;
  margin-bottom: 1rem;
  opacity: 0.5;
}

.empty-text {
  font-size: 1rem;
  margin-bottom: 1rem;
}

.empty-action-btn {
  padding: 0.5rem 1rem;
  background-color: #3b82f6;
  color: white;
  border-radius: 0.375rem;
  font-size: 0.875rem;
}

.member-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
  gap: 1rem;
}

.member-card {
  background: white;
  border: 1px solid #e5e7eb;
  border-radius: 0.5rem;
  padding: 1rem;
  box-shadow: 0 1px 3px 0 rgba(0, 0, 0, 0.1);
  transition: box-shadow 0.2s;
}

.member-card:hover {
  box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
}

.member-header {
  display: flex;
  align-items: flex-start;
  gap: 0.75rem;
  margin-bottom: 1rem;
}

.member-avatar {
  flex-shrink: 0;
}

.avatar-image {
  width: 2.5rem;
  height: 2.5rem;
  border-radius: 50%;
  object-fit: cover;
}

.avatar-placeholder {
  width: 2.5rem;
  height: 2.5rem;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
  font-weight: 600;
  font-size: 1rem;
}

.member-info {
  flex: 1;
}

.member-name-row {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  margin-bottom: 0.25rem;
}

.member-name {
  font-size: 1rem;
  font-weight: 600;
  color: #1f2937;
}

.primary-icon {
  width: 1rem;
  height: 1rem;
  color: #f59e0b;
}

.member-role-row {
  display: flex;
  align-items: center;
}

.role-badge {
  padding: 0.125rem 0.5rem;
  border-radius: 9999px;
  font-size: 0.75rem;
  font-weight: 500;
}

.member-actions {
  display: flex;
  gap: 0.25rem;
}

.action-btn {
  padding: 0.375rem;
  border: 1px solid #d1d5db;
  background-color: white;
  color: #6b7280;
  border-radius: 0.25rem;
  transition: all 0.2s;
}

.action-btn:hover {
  background-color: #f9fafb;
  border-color: #9ca3af;
}

.action-btn-danger {
  border-color: #fca5a5;
  color: #dc2626;
}

.action-btn-danger:hover {
  background-color: #fef2f2;
  border-color: #f87171;
}

.member-stats {
  border-top: 1px solid #e5e7eb;
  padding-top: 0.75rem;
  margin-bottom: 0.75rem;
}

.stats-row {
  display: flex;
  justify-content: space-between;
  margin-bottom: 0.5rem;
}

.stats-row:last-child {
  margin-bottom: 0;
}

.stat-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  flex: 1;
}

.stat-label {
  font-size: 0.75rem;
  color: #6b7280;
  margin-bottom: 0.125rem;
}

.stat-value {
  font-size: 0.875rem;
  font-weight: 500;
  color: #1f2937;
}

.balance-status {
  font-size: 0.75rem;
  font-weight: normal;
}

.member-footer {
  border-top: 1px solid #e5e7eb;
  padding-top: 0.5rem;
  text-align: center;
}

.last-active {
  font-size: 0.75rem;
  color: #6b7280;
}
</style>
