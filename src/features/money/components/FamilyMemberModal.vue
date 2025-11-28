<script setup lang="ts">
import ColorSelector from '@/components/common/ColorSelector.vue';
import { Checkbox, FormRow, Input, Modal, Select } from '@/components/ui';
import FamilyMemberSelector from '@/components/ui/FamilyMemberSelector.vue';
import { useFamilyMemberStore } from '@/stores/money';
import { toast } from '@/utils/toast';
import { userPreferences } from '@/utils/userPreferences';
import type { SelectOption } from '@/components/ui';
import type { FamilyMember as SearchableFamilyMember } from '@/composables/useFamilyMemberSearch';
import type { FamilyMember, FamilyMemberCreate, FamilyMemberUpdate } from '@/schema/money';

interface Props {
  member?: FamilyMember | null;
  familyLedgerSerialNum: string;
}

const props = defineProps<Props>();
const emit = defineEmits<{
  close: [];
  save: [member: FamilyMember];
}>();

const memberStore = useFamilyMemberStore();
const isSubmitting = ref(false);

// 成员创建模式
const memberMode = ref<'select_member' | 'create_member'>('select_member');
const selectedExistingMember = ref<SearchableFamilyMember | null>(null);

// 表单数据
const form = reactive({
  name: '',
  role: 'Member' as FamilyMember['role'],
  isPrimary: false,
  userSerialNum: '',
  avatar: '',
  colorTag: '#3b82f6',
  permissions: '[]',
});

// 角色选项
const roleOptions = computed<SelectOption[]>(() => [
  { value: 'Owner', label: '所有者' },
  { value: 'Admin', label: '管理员' },
  { value: 'Member', label: '成员' },
  { value: 'Viewer', label: '观察者' },
]);

// 权限选项
const permissionOptions = [
  { key: 'transaction:add', label: '添加交易' },
  { key: 'transaction:edit', label: '编辑交易' },
  { key: 'transaction:delete', label: '删除交易' },
  { key: 'member:add', label: '添加成员' },
  { key: 'member:edit', label: '编辑成员' },
  { key: 'member:remove', label: '移除成员' },
  { key: 'split:create', label: '创建分摊' },
  { key: 'split:manage', label: '管理分摊规则' },
  { key: 'settlement:execute', label: '执行结算' },
  { key: 'stats:detailed', label: '查看详细统计' },
  { key: 'data:export', label: '导出数据' },
];

// 初始化表单
onMounted(() => {
  if (props.member) {
    // 编辑模式：填充现有成员数据
    form.name = props.member.name;
    form.role = props.member.role;
    form.isPrimary = props.member.isPrimary;
    form.userSerialNum = props.member.userSerialNum || '';
    form.avatar = props.member.avatar || '';
    form.colorTag = props.member.colorTag || '#3b82f6';
    form.permissions = props.member.permissions;
  } else {
    // 新增模式：默认使用选择成员模式
    memberMode.value = 'select_member';
  }
});

// 获取当前权限列表
const currentPermissions = computed(() => {
  try {
    return JSON.parse(form.permissions);
  } catch {
    return [];
  }
});

// 切换权限
function togglePermission(permission: string) {
  const permissions = [...currentPermissions.value];
  const index = permissions.indexOf(permission);

  if (index > -1) {
    permissions.splice(index, 1);
  } else {
    permissions.push(permission);
  }

  form.permissions = JSON.stringify(permissions);
}

// 角色变更时更新默认权限
watch(() => form.role, newRole => {
  let defaultPermissions: string[] = [];

  switch (newRole) {
    case 'Owner':
      // 所有者拥有所有权限（在代码中处理，不需要在这里设置）
      defaultPermissions = [];
      break;
    case 'Admin':
      defaultPermissions = [
        'transaction:add',
        'transaction:edit',
        'transaction:delete',
        'member:add',
        'member:edit',
        'split:create',
        'split:manage',
        'settlement:execute',
        'stats:detailed',
        'data:export',
      ];
      break;
    case 'Member':
      defaultPermissions = [
        'transaction:add',
        'transaction:edit',
        'split:create',
        'stats:detailed',
      ];
      break;
    case 'Viewer':
      defaultPermissions = [];
      break;
  }

  form.permissions = JSON.stringify(defaultPermissions);
});

// 验证表单
function validateForm(): boolean {
  if (!form.name.trim()) {
    toast.error('请输入成员姓名');
    return false;
  }

  if (form.name.length < 2 || form.name.length > 20) {
    toast.error('成员姓名长度应在2-20个字符之间');
    return false;
  }

  return true;
}

// 保存成员
async function saveMember() {
  if (!validateForm()) {
    return;
  }

  try {
    let savedMember: FamilyMember;

    if (props.member) {
      // 更新成员
      const updateData: FamilyMemberUpdate = {
        name: form.name,
        role: form.role,
        isPrimary: form.isPrimary,
        permissions: form.permissions,
        userSerialNum: form.userSerialNum || null,
        avatar: form.avatar || null,
        colorTag: form.colorTag,
      };
      savedMember = await memberStore.updateMember(props.member.serialNum, updateData);
    } else {
      // 创建成员前，先检查名称是否已存在
      // Checking if member name exists
      const { MoneyDb } = await import('@/services/money/money');
      const existingMembers = await MoneyDb.listFamilyMembers();
      const existingMember = existingMembers.find((m: FamilyMember) => m.name === form.name);

      if (existingMember) {
        // 成员已存在，直接使用
        // Member already exists, using existing
        savedMember = existingMember;
        toast.info(`成员 "${form.name}" 已存在，将使用现有成员`);
      } else {
        // 成员不存在，创建新成员
        // Creating new member
        const createData: FamilyMemberCreate = {
          name: form.name,
          role: form.role,
          isPrimary: form.isPrimary,
          permissions: form.permissions,
          userSerialNum: form.userSerialNum || null,
          avatar: form.avatar || null,
          colorTag: form.colorTag,
        };
        savedMember = await memberStore.createMember(createData);
        // Member created successfully
      }
    }

    toast.success('成员保存成功');
    emit('save', savedMember);
  } catch (error: any) {
    console.error('❌ Save member failed:', error);
    toast.error(error.message || '保存失败');
  }
}

// 关闭对话框
function closeDialog() {
  emit('close');
}

// 处理家庭成员选择
function handleMemberSelect(member: SearchableFamilyMember) {
  selectedExistingMember.value = member;
  // 自动填充表单信息
  form.name = member.name;
  form.userSerialNum = member.userId || '';
  form.avatar = member.avatarUrl || '';
  form.colorTag = member.color || '#3b82f6';
  // 记录成员选择历史
  userPreferences.addRecentSelection(member.serialNum);
  // 切换到基本信息编辑模式
  memberMode.value = 'create_member';
}

// 清除成员选择
function handleMemberClear() {
  selectedExistingMember.value = null;
  // 清空相关表单字段
  if (memberMode.value === 'select_member') {
    form.name = '';
    form.userSerialNum = '';
    form.avatar = '';
    form.colorTag = '#3b82f6';
  }
}
</script>

<template>
  <Modal
    :open="true"
    :title="props.member ? '编辑成员' : '添加成员'"
    size="md"
    :confirm-loading="isSubmitting"
    @close="closeDialog"
    @confirm="saveMember"
  >
    <form @submit.prevent="saveMember">
      <!-- 成员模式选择 -->
      <div v-if="!props.member" class="mb-6">
        <h4 class="text-base font-semibold text-gray-900 dark:text-white mb-3 pb-2 border-b border-gray-200 dark:border-gray-700">
          添加方式
        </h4>

        <div class="flex gap-3 p-1 bg-gray-100 dark:bg-gray-800 rounded-xl">
          <button
            type="button"
            class="flex-1 py-3.5 px-4 border-none bg-transparent text-gray-600 dark:text-gray-400 rounded-lg text-sm font-medium flex items-center justify-center gap-2 transition-all cursor-pointer"
            :class="memberMode === 'select_member' ? 'bg-blue-600 text-white shadow-sm' : 'hover:text-gray-900 dark:hover:text-white hover:bg-gray-200 dark:hover:bg-gray-700'"
            @click="memberMode = 'select_member'"
          >
            <LucideUserCheck :size="16" />
            选择已有成员
          </button>
          <button
            type="button"
            class="flex-1 py-3.5 px-4 border-none bg-transparent text-gray-600 dark:text-gray-400 rounded-lg text-sm font-medium flex items-center justify-center gap-2 transition-all cursor-pointer"
            :class="memberMode === 'create_member' ? 'bg-blue-600 text-white shadow-sm' : 'hover:text-gray-900 dark:hover:text-white hover:bg-gray-200 dark:hover:bg-gray-700'"
            @click="memberMode = 'create_member'"
          >
            <LucideUserPlus :size="16" />
            创建新成员
          </button>
        </div>
      </div>

      <!-- 成员选择模式 -->
      <div v-if="!props.member && memberMode === 'select_member'" class="mb-6">
        <h4 class="text-base font-semibold text-gray-900 dark:text-white mb-3 pb-2 border-b border-gray-200 dark:border-gray-700">
          选择成员
        </h4>

        <div class="flex items-center gap-4">
          <label class="text-sm font-medium text-gray-900 dark:text-white min-w-[6rem] shrink-0">搜索成员</label>
          <FamilyMemberSelector
            :selected-member="selectedExistingMember"
            placeholder="搜索家庭成员姓名或邮箱"
            :show-recent-members="true"
            :show-search-history="true"
            class="flex-1"
            @select="handleMemberSelect"
            @clear="handleMemberClear"
          />
        </div>
      </div>

      <!-- 基本信息 -->
      <div v-if="props.member || memberMode === 'create_member'" class="mb-6">
        <h4 class="text-base font-semibold text-gray-900 dark:text-white mb-3 pb-2 border-b border-gray-200 dark:border-gray-700">
          基本信息
        </h4>

        <FormRow label="姓名" required>
          <Input
            v-model="form.name"
            type="text"
            placeholder="请输入姓名"
          />
        </FormRow>

        <FormRow label="角色" required>
          <Select
            v-model="form.role"
            :options="roleOptions"
            placeholder="请选择角色"
          />
        </FormRow>

        <div class="mb-3">
          <Checkbox
            v-model="form.isPrimary"
            label="设为主要成员"
          />
        </div>

        <!-- 关联成员信息显示 -->
        <div v-if="selectedExistingMember" class="mb-4 flex items-center gap-4">
          <label class="text-sm font-medium text-gray-900 dark:text-white min-w-[6rem] shrink-0">选择的成员</label>
          <div class="flex items-center gap-3 flex-1 p-4 bg-blue-50 dark:bg-blue-900/20 border border-blue-500 dark:border-blue-600 rounded-xl">
            <div class="w-10 h-10 rounded-full overflow-hidden shrink-0 shadow-sm">
              <img
                v-if="selectedExistingMember.avatarUrl"
                :src="selectedExistingMember.avatarUrl"
                :alt="selectedExistingMember.name"
                class="w-full h-full object-cover"
              >
              <div v-else class="w-full h-full flex items-center justify-center text-white font-semibold text-base" :style="{ backgroundColor: selectedExistingMember.color || '#3b82f6' }">
                {{ selectedExistingMember.name.charAt(0).toUpperCase() }}
              </div>
            </div>
            <div class="flex-1 min-w-0">
              <div class="font-semibold text-gray-900 dark:text-white mb-0.5">
                {{ selectedExistingMember.name }}
              </div>
              <div class="text-xs text-gray-600 dark:text-gray-400">
                {{ selectedExistingMember.email || selectedExistingMember.phone || selectedExistingMember.serialNum }}
              </div>
            </div>
            <button
              type="button"
              class="p-1.5 text-gray-600 dark:text-gray-400 transition-all shrink-0 rounded-lg flex items-center justify-center hover:text-red-600 dark:hover:text-red-400 hover:bg-gray-100 dark:hover:bg-gray-800"
              @click="handleMemberClear"
            >
              <LucideX :size="16" />
            </button>
          </div>
        </div>
      </div>

      <!-- 外观设置 -->
      <div class="mb-6">
        <h4 class="text-base font-semibold text-gray-900 dark:text-white mb-3 pb-2 border-b border-gray-200 dark:border-gray-700">
          外观设置
        </h4>

        <FormRow label="头像URL" optional>
          <Input
            v-model="form.avatar"
            type="url"
            placeholder="请输入头像URL（可选）"
          />
        </FormRow>

        <FormRow label="标识颜色" optional>
          <ColorSelector
            v-model="form.colorTag"
            width="full"
            :extended="true"
            :show-custom-color="true"
            :show-random-button="true"
          />
        </FormRow>

        <!-- 预览 -->
        <FormRow label="预览" optional>
          <div class="flex items-center gap-3 p-4 bg-gray-100 dark:bg-gray-800 rounded-xl border border-gray-200 dark:border-gray-700 flex-1">
            <div
              class="w-10 h-10 rounded-full flex items-center justify-center text-white font-semibold relative overflow-hidden shadow-sm"
              :style="{ backgroundColor: form.colorTag }"
            >
              <img
                v-if="form.avatar"
                :src="form.avatar"
                :alt="form.name"
                class="w-full h-full object-cover"
              >
              <span v-else class="text-base">
                {{ form.name.charAt(0).toUpperCase() || 'A' }}
              </span>
            </div>
            <span class="font-medium text-gray-900 dark:text-white">{{ form.name || '成员姓名' }}</span>
          </div>
        </FormRow>
      </div>

      <!-- 权限设置 -->
      <div v-if="form.role !== 'Owner'" class="mb-6">
        <h4 class="text-base font-semibold text-gray-900 dark:text-white mb-3 pb-2 border-b border-gray-200 dark:border-gray-700">
          权限设置
        </h4>
        <p class="text-sm text-gray-600 dark:text-gray-400 mb-4">
          所有者拥有所有权限，无需单独设置
        </p>

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-2">
          <label
            v-for="option in permissionOptions"
            :key="option.key"
            class="flex items-center gap-3 p-3 bg-gray-100 dark:bg-gray-800 rounded-lg cursor-pointer transition-all border border-transparent hover:bg-gray-200 dark:hover:bg-gray-700 hover:border-blue-500 dark:hover:border-blue-600"
          >
            <input
              type="checkbox"
              class="w-4.5 h-4.5 accent-blue-600 cursor-pointer"
              :checked="currentPermissions.includes(option.key)"
              @change="togglePermission(option.key)"
            >
            <span class="text-sm text-gray-900 dark:text-white font-medium">{{ option.label }}</span>
          </label>
        </div>
      </div>
    </form>
  </Modal>
</template>
