<script setup lang="ts">
import { DateUtils } from '@/utils/date';
import type { FamilyLedger } from '@/schema/money';

interface Props {
  ledgers: FamilyLedger[];
  loading: boolean;
}

const props = defineProps<Props>();
const emit = defineEmits<{
  enter: [ledger: FamilyLedger];
  edit: [ledger: FamilyLedger];
  delete: [serialNum: string];
}>();
const { ledgers, loading } = toRefs(props);

// 这些函数需要根据实际的数据结构来解析
function getAccountCount(accounts: string): number {
  try {
    return JSON.parse(accounts || '[]').length;
  } catch {
    return 0;
  }
}

function getTransactionCount(transactions: string): number {
  try {
    return JSON.parse(transactions || '[]').length;
  } catch {
    return 0;
  }
}

function getBudgetCount(budgets: string): number {
  try {
    return JSON.parse(budgets || '[]').length;
  } catch {
    return 0;
  }
}
</script>

<template>
  <div class="ledger-container">
    <div v-if="loading" class="loading-container">
      加载中...
    </div>

    <div v-else-if="ledgers.length === 0" class="empty-state-container">
      <div class="empty-state-icon">
        <LucideUsers class="wh-5" />
      </div>
      <div class="empty-state-text">
        暂无家庭账本
      </div>
    </div>

    <div v-else class="ledger-grid">
      <div v-for="ledger in ledgers" :key="ledger.serialNum" class="ledger-card">
        <!-- 账本头部信息 -->
        <div class="ledger-header">
          <div class="ledger-info">
            <h3 class="ledger-title">
              {{ ledger.name || ledger.description || '未命名账本' }}
            </h3>
            <div class="ledger-meta">
              <span>基础币种: {{ ledger.baseCurrency }}</span>
              <span class="meta-separator">|</span>
              <span>{{ ledger.memberCount || 0 }} 位成员</span>
            </div>
          </div>
          <!-- 操作按钮 -->
          <div class="ledger-actions">
            <button class="action-btn" title="进入账本" @click="emit('enter', ledger)">
              <LucideLogIn class="h-4 w-4" />
            </button>
            <button class="action-btn" title="编辑" @click="emit('edit', ledger)">
              <LucideEdit class="h-4 w-4" />
            </button>
            <button class="action-btn-danger" title="删除" @click="emit('delete', ledger.serialNum)">
              <LucideTrash class="h-4 w-4" />
            </button>
          </div>
        </div>

        <!-- 成员列表 -->
        <div class="members-section">
          <div class="members-title">
            成员
          </div>
          <div class="members-list">
            <!-- 暂时隐藏成员列表，因为数据结构不匹配 -->
            <div class="member-tag">
              <LucideUser class="member-icon member-icon-secondary" />
              <span>{{ ledger.memberCount || 0 }} 位成员</span>
            </div>
          </div>
        </div>

        <!-- 统计信息 -->
        <div class="stats-section">
          <div class="stat-item">
            <div class="stat-label">
              账户
            </div>
            <div class="stat-value">
              {{ getAccountCount(ledger.accounts) }}
            </div>
          </div>
          <div class="stat-item">
            <div class="stat-label">
              交易
            </div>
            <div class="stat-value">
              {{ getTransactionCount(ledger.transactions) }}
            </div>
          </div>
          <div class="stat-item">
            <div class="stat-label">
              预算
            </div>
            <div class="stat-value">
              {{ getBudgetCount(ledger.budgets) }}
            </div>
          </div>
        </div>

        <!-- 创建时间 -->
        <div class="created-time">
          <div class="created-time-text">
            创建于 {{ DateUtils.formatDate(ledger.createdAt) }}
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped lang="postcss">
/* Container */
.ledger-container {
  width: 100%;
  min-height: 300px;
  height: 100%;
}

/* Loading and Empty States */
.loading-container {
  color: #6b7280;
  display: flex;
  justify-content: center;
  align-items: center;
  height: 100%;
  min-height: 200px;
}

.empty-state-container {
  color: #9ca3af;
  display: flex;
  flex-direction: column;
  justify-content: center;
  align-items: center;
  height: 100%;
  min-height: 200px;
}

.empty-state-icon {
  font-size: 3.75rem;
  margin-bottom: 1rem;
  opacity: 0.5;
}

.empty-state-text {
  font-size: 1rem;
}

/* Ledger Grid */
.ledger-grid {
  gap: 1.25rem;
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
  width: 100%;
}

/* Ledger Card */
.ledger-card {
  padding: 1.25rem;
  transition: all 0.2s ease-in-out;
  border-radius: 0.5rem;
  background-color: white;
  border: 1px solid #e5e7eb;
  box-shadow: 0 1px 3px 0 rgba(0, 0, 0, 0.1), 0 1px 2px 0 rgba(0, 0, 0, 0.06);
}

.ledger-card:hover {
  box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
  transform: translateY(-1px);
}

/* Ledger Header */
.ledger-header {
  margin-bottom: 1rem;
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
}

.ledger-info {
  flex: 1;
}

.ledger-title {
  font-size: 1.125rem;
  color: #1f2937;
  font-weight: 600;
  margin-bottom: 0.25rem;
}

.ledger-meta {
  font-size: 0.875rem;
  color: #4b5563;
  display: flex;
  gap: 0.5rem;
  align-items: center;
}

.meta-separator {
  color: #9ca3af;
}

.ledger-actions {
  display: flex;
  gap: 0.375rem;
  align-items: center;
}

/* Action Buttons */
.action-btn {
  padding: 0.5rem;
  border-radius: 0.375rem;
  border: 1px solid #d1d5db;
  background-color: white;
  color: #374151;
  transition: all 0.2s ease-in-out;
  cursor: pointer;
}

.action-btn:hover {
  background-color: #f9fafb;
  border-color: #9ca3af;
}

.action-btn-danger {
  padding: 0.5rem;
  border-radius: 0.375rem;
  border: 1px solid #fca5a5;
  background-color: white;
  color: #dc2626;
  transition: all 0.2s ease-in-out;
  cursor: pointer;
}

.action-btn-danger:hover {
  background-color: #fef2f2;
  border-color: #f87171;
}

/* Members Section */
.members-section {
  margin-bottom: 1rem;
}

.members-title {
  font-size: 0.875rem;
  color: #374151;
  font-weight: 500;
  margin-bottom: 0.5rem;
}

.members-list {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
}

.member-tag {
  font-size: 0.75rem;
  padding: 0.25rem 0.5rem;
  border-radius: 9999px;
  background-color: #f3f4f6;
  display: flex;
  gap: 0.25rem;
  align-items: center;
}

.member-tag-more {
  color: #6b7280;
}

.member-icon {
  height: 0.75rem;
  width: 0.75rem;
}

.member-icon-primary {
  color: #d97706;
}

.member-icon-secondary {
  color: #6b7280;
}

.member-role {
  color: #6b7280;
}

/* Stats Section */
.stats-section {
  padding-top: 0.75rem;
  border-top: 1px solid #e5e7eb;
  gap: 0.75rem;
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
}

.stat-item {
  text-align: center;
}

.stat-label {
  font-size: 0.75rem;
  color: #6b7280;
}

.stat-value {
  font-size: 0.875rem;
  font-weight: 500;
}

/* Created Time */
.created-time {
  margin-top: 0.75rem;
  padding-top: 0.75rem;
  border-top: 1px solid #e5e7eb;
}

.created-time-text {
  font-size: 0.75rem;
  color: #6b7280;
}

/* 响应式设计 */
@media (max-width: 768px) {
  .ledger-grid {
    grid-template-columns: 1fr;
    gap: 1rem;
  }

  .ledger-card {
    padding: 1rem;
  }

  .ledger-title {
    font-size: 1rem;
  }

  .ledger-meta {
    font-size: 0.8rem;
  }

  .stats-section {
    gap: 0.5rem;
  }

  .stat-label {
    font-size: 0.7rem;
  }

  .stat-value {
    font-size: 0.8rem;
  }
}

@media (max-width: 480px) {
  .ledger-card {
    padding: 0.75rem;
  }

  .ledger-header {
    flex-direction: column;
    gap: 0.75rem;
    align-items: flex-start;
  }

  .ledger-actions {
    align-self: flex-end;
  }

  .members-list {
    gap: 0.375rem;
  }

  .member-tag {
    font-size: 0.7rem;
    padding: 0.2rem 0.4rem;
  }
}
</style>
