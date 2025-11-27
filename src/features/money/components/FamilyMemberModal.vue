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
      <div v-if="!props.member" class="form-section">
        <h4 class="section-title">
          添加方式
        </h4>

        <div class="mode-selector">
          <button
            type="button"
            class="mode-btn"
            :class="{ active: memberMode === 'select_member' }"
            @click="memberMode = 'select_member'"
          >
            <LucideUserCheck class="w-4 h-4" />
            选择已有成员
          </button>
          <button
            type="button"
            class="mode-btn"
            :class="{ active: memberMode === 'create_member' }"
            @click="memberMode = 'create_member'"
          >
            <LucideUserPlus class="w-4 h-4" />
            创建新成员
          </button>
        </div>
      </div>

      <!-- 成员选择模式 -->
      <div v-if="!props.member && memberMode === 'select_member'" class="form-section">
        <h4 class="section-title">
          选择成员
        </h4>

        <div class="form-row">
          <label class="form-label">搜索成员</label>
          <FamilyMemberSelector
            :selected-member="selectedExistingMember"
            placeholder="搜索家庭成员姓名或邮箱"
            :show-recent-members="true"
            :show-search-history="true"
            @select="handleMemberSelect"
            @clear="handleMemberClear"
          />
        </div>
      </div>

      <!-- 基本信息 -->
      <div v-if="props.member || memberMode === 'create_member'" class="form-section">
        <h4 class="section-title">
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
        <div v-if="selectedExistingMember" class="form-row">
          <label class="form-label">选择的成员</label>
          <div class="selected-member-info">
            <div class="member-avatar">
              <img
                v-if="selectedExistingMember.avatarUrl"
                :src="selectedExistingMember.avatarUrl"
                :alt="selectedExistingMember.name"
                class="avatar-image"
              >
              <div v-else class="avatar-placeholder" :style="{ backgroundColor: selectedExistingMember.color || '#3b82f6' }">
                {{ selectedExistingMember.name.charAt(0).toUpperCase() }}
              </div>
            </div>
            <div class="member-details">
              <div class="member-name">
                {{ selectedExistingMember.name }}
              </div>
              <div class="member-email">
                {{ selectedExistingMember.email || selectedExistingMember.phone || selectedExistingMember.serialNum }}
              </div>
            </div>
            <button
              type="button"
              class="clear-member-btn"
              @click="handleMemberClear"
            >
              <LucideX class="w-4 h-4" />
            </button>
          </div>
        </div>
      </div>

      <!-- 外观设置 -->
      <div class="form-section">
        <h4 class="section-title">
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
          <div class="member-preview">
            <div
              class="preview-avatar"
              :style="{ backgroundColor: form.colorTag }"
            >
              <img
                v-if="form.avatar"
                :src="form.avatar"
                :alt="form.name"
                class="preview-avatar-image"
              >
              <span v-else class="preview-avatar-text">
                {{ form.name.charAt(0).toUpperCase() || 'A' }}
              </span>
            </div>
            <span class="preview-name">{{ form.name || '成员姓名' }}</span>
          </div>
        </FormRow>
      </div>

      <!-- 权限设置 -->
      <div v-if="form.role !== 'Owner'" class="form-section">
        <h4 class="section-title">
          权限设置
        </h4>
        <p class="section-description">
          所有者拥有所有权限，无需单独设置
        </p>

        <div class="permissions-grid">
          <label
            v-for="option in permissionOptions"
            :key="option.key"
            class="permission-item"
          >
            <input
              type="checkbox"
              class="permission-checkbox"
              :checked="currentPermissions.includes(option.key)"
              @change="togglePermission(option.key)"
            >
            <span class="permission-label">{{ option.label }}</span>
          </label>
        </div>
      </div>
    </form>
  </Modal>
</template>

<style scoped>
.modal-mask {
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background-color: oklch(0% 0 0 / 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
}

.modal-window {
  background: var(--color-base-100);
  border-radius: 12px;
  width: 90%;
  max-width: 520px;
  max-height: 90vh;
  overflow: hidden;
  display: flex;
  flex-direction: column;
  box-shadow: var(--shadow-lg);
  border: 1px solid var(--color-base-200);
}

.modal-header {
  padding: 1.25rem 1.5rem;
  border-bottom: 1px solid var(--color-base-200);
  display: flex;
  align-items: center;
  justify-content: space-between;
  background: var(--color-base-100);
}

.modal-title {
  font-size: 1.125rem;
  font-weight: 600;
  color: var(--color-base-content);
}

.modal-close-btn {
  color: var(--color-neutral);
  transition: color 0.2s;
  padding: 0.375rem;
  border-radius: 0.5rem;
  display: flex;
  align-items: center;
  justify-content: center;
}

.modal-close-btn:hover {
  color: var(--color-neutral-hover);
  background-color: var(--color-base-200);
}

.modal-content {
  flex: 1;
  overflow-y: auto;
  padding: 1.5rem;
  background: var(--color-base-100);

  /* 隐藏滚动条但保持滚动功能 */
  scrollbar-width: none; /* Firefox */
  -ms-overflow-style: none; /* Internet Explorer 10+ */
}

/* 隐藏 WebKit 浏览器滚动条 */
.modal-content::-webkit-scrollbar {
  display: none;
}

.form-section {
  margin-bottom: 1.5rem;
}

.section-title {
  font-size: 1rem;
  font-weight: 600;
  color: var(--color-base-content);
  margin-bottom: 0.75rem;
  padding-bottom: 0.5rem;
  border-bottom: 1px solid var(--color-base-200);
}

.section-description {
  font-size: 0.875rem;
  color: var(--color-neutral);
  margin-bottom: 1rem;
}

/* 保留已选成员信息的 form-row 样式 */
.form-row {
  margin-bottom: 1rem;
  display: flex;
  align-items: center;
  gap: 1rem;
}

.form-label {
  display: block;
  font-size: 0.875rem;
  font-weight: 500;
  color: var(--color-base-content);
  min-width: 6rem;
  flex-shrink: 0;
}

.member-preview {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 1rem;
  background-color: var(--color-base-200);
  border-radius: 0.75rem;
  border: 1px solid var(--color-base-200);
  flex: 1;
}

.preview-avatar {
  width: 2.5rem;
  height: 2.5rem;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
  font-weight: 600;
  position: relative;
  overflow: hidden;
  box-shadow: var(--shadow-sm);
}

.preview-avatar-image {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.preview-avatar-text {
  font-size: 1rem;
}

.preview-name {
  font-weight: 500;
  color: var(--color-base-content);
}

.permissions-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 0.5rem;
}

.permission-item {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.75rem;
  background-color: var(--color-base-200);
  border-radius: 0.5rem;
  cursor: pointer;
  transition: all 0.2s ease;
  border: 1px solid transparent;
}

.permission-item:hover {
  background-color: var(--color-base-300);
  border-color: var(--color-primary);
}

.permission-checkbox {
  width: 1.125rem;
  height: 1.125rem;
  accent-color: var(--color-primary);
}

.permission-label {
  font-size: 0.875rem;
  color: var(--color-base-content);
  font-weight: 500;
}

.modal-actions {
  padding-top: 1rem;
  display: flex;
  justify-content: center;
  gap: 0.75rem;
}

.btn-cancel {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 3rem;
  height: 3rem;
  border-radius: 50%;
  border: none;
  cursor: pointer;
  background-color: var(--color-neutral);
  color: var(--color-neutral-content);
  transition: all 0.2s ease;
}

.btn-cancel:hover {
  background-color: var(--color-neutral-content);
  color: var(--color-neutral);
}

.btn-save {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 3rem;
  height: 3rem;
  border-radius: 50%;
  border: none;
  cursor: pointer;
  background-color: var(--color-primary);
  color: var(--color-primary-content);
  transition: all 0.2s ease;
}

.btn-save:hover {
  background-color: var(--color-primary-content);
  color: var(--color-primary);
}

.icon-btn {
  width: 1.25rem;
  height: 1.25rem;
}

/* 成员模式选择器 */
.mode-selector {
  display: flex;
  gap: 0.75rem;
  padding: 0.25rem;
  background-color: var(--color-base-200);
  border-radius: 0.75rem;
}

.mode-btn {
  flex: 1;
  padding: 0.875rem 1rem;
  border: none;
  background-color: transparent;
  color: var(--color-neutral);
  border-radius: 0.5rem;
  font-size: 0.875rem;
  font-weight: 500;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  transition: all 0.2s ease;
  cursor: pointer;
}

.mode-btn:hover {
  color: var(--color-base-content);
  background-color: var(--color-base-300);
}

.mode-btn.active {
  background: var(--color-primary);
  color: var(--color-primary-content);
  box-shadow: var(--shadow-sm);
}

/* 已选择成员信息 */
.selected-member-info {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 1rem;
  background: oklch(from var(--color-primary) l c h / 0.1);
  border: 1px solid var(--color-primary);
  border-radius: 0.75rem;
  flex: 1;
}

.member-avatar {
  width: 2.5rem;
  height: 2.5rem;
  border-radius: 50%;
  overflow: hidden;
  flex-shrink: 0;
  box-shadow: var(--shadow-sm);
}

.avatar-image {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.avatar-placeholder {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
  font-weight: 600;
  font-size: 1rem;
}

.member-details {
  flex: 1;
  min-width: 0;
}

.member-name {
  font-weight: 600;
  color: var(--color-base-content);
  margin-bottom: 0.125rem;
}

.member-email {
  font-size: 0.75rem;
  color: var(--color-neutral);
}

.clear-member-btn {
  padding: 0.375rem;
  color: var(--color-neutral);
  transition: all 0.2s ease;
  flex-shrink: 0;
  border-radius: 0.5rem;
  display: flex;
  align-items: center;
  justify-content: center;
}

.clear-member-btn:hover {
  color: var(--color-error);
  background-color: var(--color-base-200);
}
</style>
