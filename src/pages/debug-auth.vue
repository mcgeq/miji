<script setup lang="ts">
import { useAuthStore } from '@/stores/auth';
import { RolePermissions } from '@/types/auth';

definePage({
  name: 'debug-auth',
  meta: {
    requiresAuth: false, // 不需要权限，方便调试
    title: '权限调试',
  },
});

const authStore = useAuthStore();

// 获取所有信息
const debugInfo = computed(() => ({
  isAuthenticated: authStore.isAuthenticated,
  user: authStore.user,
  role: authStore.role,
  permissions: authStore.permissions,
  effectivePermissions: authStore.effectivePermissions,
  rolePermissions: RolePermissions[authStore.role] || [],
}));
</script>

<template>
  <div class="max-w-4xl mx-auto p-6">
    <h1 class="text-3xl font-bold mb-6">
      权限调试信息
    </h1>

    <!-- 认证状态 -->
    <div class="bg-white dark:bg-gray-800 p-6 rounded-lg shadow mb-6">
      <h2 class="text-xl font-semibold mb-4">
        认证状态
      </h2>
      <div class="space-y-2">
        <div>
          <span class="font-medium">是否登录:</span>
          <span :class="debugInfo.isAuthenticated ? 'text-green-600' : 'text-red-600'" class="ml-2">
            {{ debugInfo.isAuthenticated ? '✅ 已登录' : '❌ 未登录' }}
          </span>
        </div>
        <div v-if="debugInfo.user">
          <span class="font-medium">用户:</span>
          <span class="ml-2">{{ debugInfo.user.name }} ({{ debugInfo.user.email }})</span>
        </div>
      </div>
    </div>

    <!-- 角色信息 -->
    <div class="bg-white dark:bg-gray-800 p-6 rounded-lg shadow mb-6">
      <h2 class="text-xl font-semibold mb-4">
        角色信息
      </h2>
      <div class="space-y-2">
        <div>
          <span class="font-medium">当前角色:</span>
          <span class="ml-2 px-3 py-1 bg-blue-100 dark:bg-blue-900 text-blue-800 dark:text-blue-200 rounded">
            {{ debugInfo.role }}
          </span>
        </div>
        <div>
          <span class="font-medium">角色默认权限数量:</span>
          <span class="ml-2">{{ debugInfo.rolePermissions.length }} 个</span>
        </div>
      </div>
    </div>

    <!-- 权限信息 -->
    <div class="bg-white dark:bg-gray-800 p-6 rounded-lg shadow mb-6">
      <h2 class="text-xl font-semibold mb-4">
        权限信息
      </h2>
      <div class="space-y-4">
        <!-- 明确权限 -->
        <div>
          <div class="font-medium mb-2">
            明确授予的权限 ({{ debugInfo.permissions.length }} 个):
          </div>
          <div v-if="debugInfo.permissions.length > 0" class="flex flex-wrap gap-2">
            <span
              v-for="perm in debugInfo.permissions"
              :key="perm"
              class="px-2 py-1 bg-green-100 dark:bg-green-900 text-green-800 dark:text-green-200 rounded text-sm"
            >
              {{ perm }}
            </span>
          </div>
          <div v-else class="text-gray-500 dark:text-gray-400 italic">
            无明确授予的权限
          </div>
        </div>

        <!-- 有效权限 -->
        <div>
          <div class="font-medium mb-2">
            有效权限 ({{ debugInfo.effectivePermissions.length }} 个):
          </div>
          <div v-if="debugInfo.effectivePermissions.length > 0" class="flex flex-wrap gap-2">
            <span
              v-for="perm in debugInfo.effectivePermissions"
              :key="perm"
              class="px-2 py-1 bg-blue-100 dark:bg-blue-900 text-blue-800 dark:text-blue-200 rounded text-sm"
            >
              {{ perm }}
            </span>
          </div>
          <div v-else class="text-red-500 font-bold">
            ⚠️ 警告：没有任何有效权限！
          </div>
        </div>
      </div>
    </div>

    <!-- 原始数据 -->
    <div class="bg-white dark:bg-gray-800 p-6 rounded-lg shadow">
      <h2 class="text-xl font-semibold mb-4">
        原始数据 (JSON)
      </h2>
      <pre class="bg-gray-100 dark:bg-gray-900 p-4 rounded overflow-auto text-sm">{{ JSON.stringify(debugInfo, null, 2) }}</pre>
    </div>

    <!-- 操作按钮 -->
    <div class="mt-6 flex gap-4">
      <button
        class="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700"
        @click="$router.push('/money')"
      >
        测试访问 Money 页面
      </button>
      <button
        class="px-4 py-2 bg-green-600 text-white rounded hover:bg-green-700"
        @click="$router.push('/family-ledger')"
      >
        测试访问 Family Ledger 页面
      </button>
      <button
        class="px-4 py-2 bg-purple-600 text-white rounded hover:bg-purple-700"
        @click="$router.push('/settings')"
      >
        测试访问 Settings 页面
      </button>
    </div>
  </div>
</template>
