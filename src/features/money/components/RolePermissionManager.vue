<script setup lang="ts">
import { LucideCheck, LucideShield, LucideUser, LucideUserCog } from 'lucide-vue-next';
import { usePermission } from '@/composables/usePermission';

const { isOwner } = usePermission();

// 预设角色定义
const presetRoles = [
  {
    name: 'Owner',
    displayName: '所有者',
    icon: LucideShield,
    description: '拥有账本的完全控制权，可以管理所有成员和设置',
    color: '#f59e0b',
    permissions: [
      'transaction:view',
      'transaction:add',
      'transaction:edit',
      'transaction:delete',
      'member:view',
      'member:add',
      'member:edit',
      'member:remove',
      'split:view',
      'split:create',
      'split:manage',
      'settlement:view',
      'settlement:execute',
      'stats:view',
      'stats:detailed',
      'settings:view',
      'settings:manage',
      'data:export',
    ],
  },
  {
    name: 'Admin',
    displayName: '管理员',
    icon: LucideUserCog,
    description: '可以管理交易和成员，但不能删除账本或修改关键设置',
    color: '#3b82f6',
    permissions: [
      'transaction:view',
      'transaction:add',
      'transaction:edit',
      'transaction:delete',
      'member:view',
      'member:add',
      'member:edit',
      'split:view',
      'split:create',
      'split:manage',
      'settlement:view',
      'settlement:execute',
      'stats:view',
      'stats:detailed',
      'settings:view',
      'data:export',
    ],
  },
  {
    name: 'Member',
    displayName: '成员',
    icon: LucideUser,
    description: '可以添加交易、查看统计，但不能管理其他成员',
    color: '#10b981',
    permissions: [
      'transaction:view',
      'transaction:add',
      'transaction:edit',
      'split:view',
      'split:create',
      'settlement:view',
      'stats:view',
      'settings:view',
    ],
  },
  {
    name: 'Viewer',
    displayName: '查看者',
    icon: LucideUser,
    description: '只能查看交易和统计，不能进行任何修改操作',
    color: '#6b7280',
    permissions: [
      'transaction:view',
      'split:view',
      'settlement:view',
      'stats:view',
    ],
  },
];

// 权限分类
const permissionCategories = [
  {
    name: 'transaction',
    label: '交易管理',
    permissions: [
      { code: 'transaction:view', name: '查看交易', description: '可以查看所有交易记录' },
      { code: 'transaction:add', name: '添加交易', description: '可以添加新的交易' },
      { code: 'transaction:edit', name: '编辑交易', description: '可以编辑现有交易' },
      { code: 'transaction:delete', name: '删除交易', description: '可以删除交易记录' },
    ],
  },
  {
    name: 'member',
    label: '成员管理',
    permissions: [
      { code: 'member:view', name: '查看成员', description: '可以查看成员列表和信息' },
      { code: 'member:add', name: '添加成员', description: '可以邀请新成员加入' },
      { code: 'member:edit', name: '编辑成员', description: '可以修改成员信息和角色' },
      { code: 'member:remove', name: '移除成员', description: '可以从账本中移除成员' },
    ],
  },
  {
    name: 'split',
    label: '分摊管理',
    permissions: [
      { code: 'split:view', name: '查看分摊', description: '可以查看分摊记录' },
      { code: 'split:create', name: '创建分摊', description: '可以创建新的分摊' },
      { code: 'split:manage', name: '管理分摊', description: '可以管理分摊规则和模板' },
    ],
  },
  {
    name: 'settlement',
    label: '结算管理',
    permissions: [
      { code: 'settlement:view', name: '查看结算', description: '可以查看结算记录和建议' },
      { code: 'settlement:execute', name: '执行结算', description: '可以执行结算操作' },
    ],
  },
  {
    name: 'stats',
    label: '统计报表',
    permissions: [
      { code: 'stats:view', name: '查看统计', description: '可以查看基础统计数据' },
      { code: 'stats:detailed', name: '详细统计', description: '可以查看详细的财务统计' },
    ],
  },
  {
    name: 'settings',
    label: '设置管理',
    permissions: [
      { code: 'settings:view', name: '查看设置', description: '可以查看账本设置' },
      { code: 'settings:manage', name: '管理设置', description: '可以修改账本设置' },
    ],
  },
  {
    name: 'data',
    label: '数据操作',
    permissions: [
      { code: 'data:export', name: '导出数据', description: '可以导出账本数据' },
    ],
  },
];

// 自定义权限（仅所有者可见）
const selectedPermissions = ref<string[]>([]);
const customRoleName = ref('自定义角色');

// 获取权限显示名称
function getPermissionName(code: string): string {
  for (const category of permissionCategories) {
    const perm = category.permissions.find(p => p.code === code);
    if (perm) return perm.name;
  }
  return code;
}

// 保存自定义权限配置
async function saveCustomRole() {
  // TODO: 实现保存逻辑
  // eslint-disable-next-line no-console
  console.log('Saving custom role:', {
    name: customRoleName.value,
    permissions: selectedPermissions.value,
  });
}
</script>

<template>
  <div class="role-permission-manager">
    <h3 class="manager-title">
      角色与权限管理
    </h3>

    <!-- 预设角色 -->
    <section class="preset-roles-section">
      <h4 class="section-title">
        预设角色
      </h4>
      <p class="section-description">
        系统提供四种预设角色，每种角色有不同的权限级别
      </p>

      <div class="role-grid">
        <div
          v-for="role in presetRoles"
          :key="role.name"
          class="role-card"
          :style="{ '--role-color': role.color }"
        >
          <div class="role-header">
            <div class="role-icon-wrapper">
              <component :is="role.icon" class="role-icon" />
            </div>
            <div class="role-info">
              <h5 class="role-name">
                {{ role.displayName }}
              </h5>
              <span class="role-badge">{{ role.name }}</span>
            </div>
          </div>

          <p class="role-description">
            {{ role.description }}
          </p>

          <div class="role-permissions">
            <div class="permissions-header">
              <span class="permissions-label">权限列表</span>
              <span class="permissions-count">{{ role.permissions.length }} 项</span>
            </div>
            <div class="permissions-list">
              <div
                v-for="perm in role.permissions"
                :key="perm"
                class="permission-item"
              >
                <LucideCheck class="check-icon" />
                <span>{{ getPermissionName(perm) }}</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>

    <!-- 自定义权限配置（仅所有者可见） -->
    <section v-if="isOwner" class="custom-permissions-section">
      <h4 class="section-title">
        自定义权限配置
      </h4>
      <p class="section-description">
        创建自定义角色，为特定成员分配精确的权限组合
      </p>

      <div class="custom-role-editor">
        <div class="editor-header">
          <input
            v-model="customRoleName"
            type="text"
            placeholder="角色名称"
            class="role-name-input"
          >
        </div>

        <div class="permissions-editor">
          <div
            v-for="category in permissionCategories"
            :key="category.name"
            class="permission-category"
          >
            <h5 class="category-title">
              <span>{{ category.label }}</span>
            </h5>

            <div class="category-permissions">
              <label
                v-for="perm in category.permissions"
                :key="perm.code"
                class="permission-checkbox"
              >
                <input
                  v-model="selectedPermissions"
                  type="checkbox"
                  :value="perm.code"
                >
                <div class="permission-info">
                  <span class="permission-name">{{ perm.name }}</span>
                  <span class="permission-desc">{{ perm.description }}</span>
                </div>
              </label>
            </div>
          </div>
        </div>

        <div class="editor-actions">
          <div class="selected-count">
            已选择 {{ selectedPermissions.length }} 项权限
          </div>
          <button class="btn-save" @click="saveCustomRole">
            保存自定义角色
          </button>
        </div>
      </div>
    </section>

    <!-- 权限说明 -->
    <section class="permission-guide">
      <h4 class="section-title">
        权限说明
      </h4>
      <div class="guide-content">
        <div class="guide-item">
          <LucideShield class="guide-icon owner" />
          <div class="guide-text">
            <strong>所有者</strong>：拥有所有权限，包括删除账本和转移所有权
          </div>
        </div>
        <div class="guide-item">
          <LucideUserCog class="guide-icon admin" />
          <div class="guide-text">
            <strong>管理员</strong>：可以管理交易和成员，但不能删除账本
          </div>
        </div>
        <div class="guide-item">
          <LucideUser class="guide-icon member" />
          <div class="guide-text">
            <strong>成员</strong>：可以添加和编辑自己的交易，查看统计信息
          </div>
        </div>
        <div class="guide-item">
          <LucideUser class="guide-icon viewer" />
          <div class="guide-text">
            <strong>查看者</strong>：只能查看交易和统计，不能进行任何修改
          </div>
        </div>
      </div>
    </section>
  </div>
</template>

<style scoped>
.role-permission-manager {
  display: flex;
  flex-direction: column;
  gap: 2rem;
}

.manager-title {
  font-size: 1.5rem;
  font-weight: 600;
  margin: 0;
}

/* Section Styles */
.section-title {
  font-size: 1.125rem;
  font-weight: 600;
  margin: 0 0 0.5rem 0;
}

.section-description {
  color: var(--color-gray-600);
  font-size: 0.875rem;
  margin: 0 0 1.5rem 0;
}

/* Preset Roles */
.preset-roles-section {
  background: white;
  padding: 2rem;
  border-radius: 12px;
  box-shadow: var(--shadow-sm);
}

.role-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
  gap: 1.5rem;
}

.role-card {
  padding: 1.5rem;
  background: white;
  border: 2px solid var(--color-base-300);
  border-radius: 12px;
  transition: all 0.3s;
}

.role-card:hover {
  border-color: var(--role-color);
  box-shadow: var(--shadow-md);
  transform: translateY(-2px);
}

.role-header {
  display: flex;
  align-items: center;
  gap: 1rem;
  margin-bottom: 1rem;
}

.role-icon-wrapper {
  width: 48px;
  height: 48px;
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--role-color);
  opacity: 0.1;
}

.role-icon {
  width: 28px;
  height: 28px;
  color: var(--role-color);
  opacity: 10;
}

.role-info {
  flex: 1;
}

.role-name {
  margin: 0 0 0.25rem 0;
  font-size: 1.125rem;
  font-weight: 600;
}

.role-badge {
  display: inline-block;
  padding: 0.25rem 0.75rem;
  background: var(--color-base-200);
  border-radius: 12px;
  font-size: 0.75rem;
  font-weight: 500;
  color: var(--color-gray-600);
}

.role-description {
  margin: 0 0 1rem 0;
  color: var(--color-gray-600);
  font-size: 0.875rem;
  line-height: 1.6;
}

.role-permissions {
  padding-top: 1rem;
  border-top: 1px solid var(--color-base-200);
}

.permissions-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 0.75rem;
}

.permissions-label {
  font-size: 0.875rem;
  font-weight: 500;
  color: var(--color-gray-700);
}

.permissions-count {
  font-size: 0.75rem;
  color: var(--color-gray-500);
}

.permissions-list {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 0.5rem;
}

.permission-item {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.875rem;
  color: var(--color-gray-600);
}

.check-icon {
  width: 14px;
  height: 14px;
  color: var(--role-color);
  flex-shrink: 0;
}

/* Custom Permissions */
.custom-permissions-section {
  background: white;
  padding: 2rem;
  border-radius: 12px;
  box-shadow: var(--shadow-sm);
  border: 2px dashed var(--color-base-300);
}

.custom-role-editor {
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
}

.role-name-input {
  width: 100%;
  max-width: 400px;
  padding: 0.75rem 1rem;
  border: 2px solid var(--color-base-300);
  border-radius: 8px;
  font-size: 1rem;
  transition: all 0.2s;
}

.role-name-input:focus {
  outline: none;
  border-color: var(--color-primary);
  box-shadow: 0 0 0 3px oklch(from var(--color-primary) l c h / 0.1);
}

.permissions-editor {
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
}

.permission-category {
  padding: 1rem;
  background: var(--color-base-100);
  border-radius: 8px;
}

.category-title {
  margin: 0 0 1rem 0;
  font-size: 1rem;
  font-weight: 600;
  color: var(--color-gray-900);
}

.category-permissions {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.permission-checkbox {
  display: flex;
  align-items: flex-start;
  gap: 0.75rem;
  padding: 0.75rem;
  background: white;
  border: 1px solid var(--color-base-300);
  border-radius: 6px;
  cursor: pointer;
  transition: all 0.2s;
}

.permission-checkbox:hover {
  border-color: var(--color-primary);
  background: oklch(from var(--color-primary) l c h / 0.02);
}

.permission-checkbox input[type="checkbox"] {
  margin-top: 0.125rem;
  cursor: pointer;
}

.permission-info {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
  flex: 1;
}

.permission-name {
  font-size: 0.875rem;
  font-weight: 500;
  color: var(--color-gray-900);
}

.permission-desc {
  font-size: 0.75rem;
  color: var(--color-gray-500);
}

.editor-actions {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding-top: 1rem;
  border-top: 1px solid var(--color-base-200);
}

.selected-count {
  font-size: 0.875rem;
  color: var(--color-gray-600);
}

.btn-save {
  padding: 0.75rem 1.5rem;
  background: var(--color-primary);
  color: white;
  border: none;
  border-radius: 8px;
  font-size: 0.875rem;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
}

.btn-save:hover {
  background: var(--color-primary-dark);
  transform: translateY(-1px);
  box-shadow: var(--shadow-md);
}

/* Permission Guide */
.permission-guide {
  background: var(--color-base-100);
  padding: 2rem;
  border-radius: 12px;
}

.guide-content {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.guide-item {
  display: flex;
  align-items: flex-start;
  gap: 1rem;
  padding: 1rem;
  background: white;
  border-radius: 8px;
}

.guide-icon {
  width: 24px;
  height: 24px;
  flex-shrink: 0;
}

.guide-icon.owner {
  color: #f59e0b;
}

.guide-icon.admin {
  color: #3b82f6;
}

.guide-icon.member {
  color: #10b981;
}

.guide-icon.viewer {
  color: #6b7280;
}

.guide-text {
  font-size: 0.875rem;
  line-height: 1.6;
}

.guide-text strong {
  color: var(--color-gray-900);
}

/* Responsive */
@media (max-width: 768px) {
  .role-grid {
    grid-template-columns: 1fr;
  }

  .permissions-list {
    grid-template-columns: 1fr;
  }

  .editor-actions {
    flex-direction: column;
    align-items: stretch;
    gap: 1rem;
  }

  .btn-save {
    width: 100%;
  }
}
</style>
