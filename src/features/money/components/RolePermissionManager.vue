<script setup lang="ts">
  import { LucideCheck, LucideShield, LucideUser, LucideUserCog } from 'lucide-vue-next';
  import Badge from '@/components/ui/Badge.vue';
  import Button from '@/components/ui/Button.vue';
  import Card from '@/components/ui/Card.vue';
  import Checkbox from '@/components/ui/Checkbox.vue';
  import Input from '@/components/ui/Input.vue';
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
      permissions: ['transaction:view', 'split:view', 'settlement:view', 'stats:view'],
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
      permissions: [{ code: 'data:export', name: '导出数据', description: '可以导出账本数据' }],
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
  <div class="flex flex-col gap-8">
    <h3 class="text-2xl font-semibold text-gray-900 dark:text-white">角色与权限管理</h3>

    <!-- 预设角色 -->
    <Card padding="lg">
      <template #header>
        <div>
          <h4 class="text-lg font-semibold text-gray-900 dark:text-white mb-2">预设角色</h4>
          <p class="text-sm text-gray-600 dark:text-gray-400">
            系统提供四种预设角色，每种角色有不同的权限级别
          </p>
        </div>
      </template>

      <div class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-6">
        <div
          v-for="role in presetRoles"
          :key="role.name"
          class="p-6 bg-white dark:bg-gray-800 border-2 border-gray-200 dark:border-gray-700 rounded-xl transition-all hover:border-current hover:shadow-lg hover:-translate-y-1"
          :style="{ color: role.color }"
        >
          <div class="flex items-center gap-4 mb-4">
            <div
              class="w-12 h-12 rounded-xl flex items-center justify-center opacity-10"
              :style="{ backgroundColor: role.color }"
            >
              <component
                :is="role.icon"
                class="w-7 h-7 opacity-100"
                :style="{ color: role.color }"
              />
            </div>
            <div class="flex-1 min-w-0">
              <h5 class="text-lg font-semibold text-gray-900 dark:text-white mb-1">
                {{ role.displayName }}
              </h5>
              <Badge variant="default" size="sm">{{ role.name }}</Badge>
            </div>
          </div>

          <p class="text-sm text-gray-600 dark:text-gray-400 leading-relaxed mb-4">
            {{ role.description }}
          </p>

          <div class="pt-4 border-t border-gray-200 dark:border-gray-700">
            <div class="flex justify-between items-center mb-3">
              <span class="text-sm font-medium text-gray-700 dark:text-gray-300">权限列表</span>
              <span class="text-xs text-gray-500 dark:text-gray-400"
                >{{ role.permissions.length }}项</span
              >
            </div>
            <div class="grid grid-cols-1 gap-2">
              <div
                v-for="perm in role.permissions"
                :key="perm"
                class="flex items-center gap-2 text-sm text-gray-600 dark:text-gray-400"
              >
                <LucideCheck class="w-3.5 h-3.5 shrink-0" :style="{ color: role.color }" />
                <span class="truncate">{{ getPermissionName(perm) }}</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Card>

    <!-- 自定义权限配置（仅所有者可见） -->
    <Card v-if="isOwner" padding="lg" class="border-2 border-dashed">
      <template #header>
        <div>
          <h4 class="text-lg font-semibold text-gray-900 dark:text-white mb-2">自定义权限配置</h4>
          <p class="text-sm text-gray-600 dark:text-gray-400">
            创建自定义角色，为特定成员分配精确的权限组合
          </p>
        </div>
      </template>

      <div class="flex flex-col gap-6">
        <div class="max-w-md">
          <Input v-model="customRoleName" placeholder="角色名称" full-width />
        </div>

        <div class="flex flex-col gap-6">
          <div
            v-for="category in permissionCategories"
            :key="category.name"
            class="p-4 bg-gray-50 dark:bg-gray-900 rounded-lg"
          >
            <h5 class="text-base font-semibold text-gray-900 dark:text-white mb-4">
              {{ category.label }}
            </h5>

            <div class="flex flex-col gap-3">
              <Checkbox
                v-for="perm in category.permissions"
                :key="perm.code"
                v-model="selectedPermissions"
                :value="perm.code"
                :label="perm.name"
                :description="perm.description"
              />
            </div>
          </div>
        </div>

        <div
          class="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 pt-6 border-t border-gray-200 dark:border-gray-700"
        >
          <div class="text-sm text-gray-600 dark:text-gray-400">
            已选择 {{ selectedPermissions.length }}项权限
          </div>
          <Button variant="primary" @click="saveCustomRole">保存自定义角色</Button>
        </div>
      </div>
    </Card>

    <!-- 权限说明 -->
    <div class="p-8 bg-gray-50 dark:bg-gray-900 rounded-xl">
      <h4 class="text-lg font-semibold text-gray-900 dark:text-white mb-6">权限说明</h4>
      <div class="flex flex-col gap-4">
        <div class="flex items-start gap-4 p-4 bg-white dark:bg-gray-800 rounded-lg">
          <LucideShield class="w-6 h-6 shrink-0 text-amber-600 dark:text-amber-500" />
          <div class="text-sm leading-relaxed text-gray-700 dark:text-gray-300">
            <strong class="text-gray-900 dark:text-white"
              >所有者</strong
            >：拥有所有权限，包括删除账本和转移所有权
          </div>
        </div>
        <div class="flex items-start gap-4 p-4 bg-white dark:bg-gray-800 rounded-lg">
          <LucideUserCog class="w-6 h-6 shrink-0 text-blue-600 dark:text-blue-500" />
          <div class="text-sm leading-relaxed text-gray-700 dark:text-gray-300">
            <strong class="text-gray-900 dark:text-white"
              >管理员</strong
            >：可以管理交易和成员，但不能删除账本
          </div>
        </div>
        <div class="flex items-start gap-4 p-4 bg-white dark:bg-gray-800 rounded-lg">
          <LucideUser class="w-6 h-6 shrink-0 text-green-600 dark:text-green-500" />
          <div class="text-sm leading-relaxed text-gray-700 dark:text-gray-300">
            <strong class="text-gray-900 dark:text-white"
              >成员</strong
            >：可以添加和编辑自己的交易，查看统计信息
          </div>
        </div>
        <div class="flex items-start gap-4 p-4 bg-white dark:bg-gray-800 rounded-lg">
          <LucideUser class="w-6 h-6 shrink-0 text-gray-600 dark:text-gray-500" />
          <div class="text-sm leading-relaxed text-gray-700 dark:text-gray-300">
            <strong class="text-gray-900 dark:text-white"
              >查看者</strong
            >：只能查看交易和统计，不能进行任何修改
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
