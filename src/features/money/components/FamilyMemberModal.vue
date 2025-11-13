<script setup lang="ts">
import { useFamilyMemberStore } from '@/stores/money';
import { toast } from '@/utils/toast';
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

// 预设颜色
const presetColors = [
  '#3b82f6',
  '#ef4444',
  '#10b981',
  '#f59e0b',
  '#8b5cf6',
  '#ec4899',
  '#06b6d4',
  '#84cc16',
  '#f97316',
  '#6366f1',
  '#14b8a6',
  '#eab308',
];

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
    form.name = props.member.name;
    form.role = props.member.role;
    form.isPrimary = props.member.isPrimary;
    form.userSerialNum = props.member.userSerialNum || '';
    form.avatar = props.member.avatar || '';
    form.colorTag = props.member.colorTag || '#3b82f6';
    form.permissions = props.member.permissions;
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
      // 创建成员
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
    }

    toast.success('成员保存成功');
    emit('save', savedMember);
  } catch (error: any) {
    toast.error(error.message || '保存失败');
  }
}

// 关闭对话框
function closeDialog() {
  emit('close');
}

// 生成随机颜色
function generateRandomColor() {
  const colors = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f'];
  let color = '#';
  for (let i = 0; i < 6; i++) {
    color += colors[Math.floor(Math.random() * colors.length)];
  }
  form.colorTag = color;
}
</script>

<template>
  <div class="modal-mask">
    <div class="modal-window">
      <div class="modal-header">
        <h3 class="modal-title">
          {{ props.member ? '编辑成员' : '添加成员' }}
        </h3>
        <button class="modal-close-btn" @click="closeDialog">
          <LucideX class="w-5 h-5" />
        </button>
      </div>

      <div class="modal-content">
        <form @submit.prevent="saveMember">
          <!-- 基本信息 -->
          <div class="form-section">
            <h4 class="section-title">
              基本信息
            </h4>

            <div class="form-row">
              <label class="form-label">姓名 *</label>
              <input
                v-model="form.name"
                type="text"
                class="form-input"
                placeholder="请输入成员姓名"
                required
              >
            </div>

            <div class="form-row">
              <label class="form-label">角色</label>
              <select v-model="form.role" class="form-select">
                <option value="Owner">
                  所有者
                </option>
                <option value="Admin">
                  管理员
                </option>
                <option value="Member">
                  成员
                </option>
                <option value="Viewer">
                  查看者
                </option>
              </select>
            </div>

            <div class="form-row">
              <label class="checkbox-label">
                <input v-model="form.isPrimary" type="checkbox" class="checkbox">
                <span>设为主要成员</span>
              </label>
            </div>

            <div class="form-row">
              <label class="form-label">关联用户ID</label>
              <input
                v-model="form.userSerialNum"
                type="text"
                class="form-input"
                placeholder="可选，关联已有用户"
              >
            </div>
          </div>

          <!-- 外观设置 -->
          <div class="form-section">
            <h4 class="section-title">
              外观设置
            </h4>

            <div class="form-row">
              <label class="form-label">头像URL</label>
              <input
                v-model="form.avatar"
                type="url"
                class="form-input"
                placeholder="可选，头像图片链接"
              >
            </div>

            <div class="form-row">
              <label class="form-label">标识颜色</label>
              <div class="color-picker-container">
                <input
                  v-model="form.colorTag"
                  type="color"
                  class="color-input"
                >
                <input
                  v-model="form.colorTag"
                  type="text"
                  class="color-text-input"
                  placeholder="#3b82f6"
                >
                <button
                  type="button"
                  class="random-color-btn"
                  @click="generateRandomColor"
                >
                  <LucideShuffle class="w-4 h-4" />
                </button>
              </div>

              <!-- 预设颜色 -->
              <div class="preset-colors">
                <button
                  v-for="color in presetColors"
                  :key="color"
                  type="button"
                  class="preset-color"
                  :style="{ backgroundColor: color }"
                  :class="{ active: form.colorTag === color }"
                  @click="form.colorTag = color"
                />
              </div>
            </div>

            <!-- 预览 -->
            <div class="form-row">
              <label class="form-label">预览</label>
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
            </div>
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
      </div>

      <!-- 操作按钮 -->
      <div class="modal-actions">
        <button type="button" class="btn-cancel" @click="closeDialog">
          取消
        </button>
        <button type="button" class="btn-save" @click="saveMember">
          保存
        </button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.modal-mask {
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background-color: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
}

.modal-window {
  background: white;
  border-radius: 8px;
  width: 90%;
  max-width: 500px;
  max-height: 90vh;
  overflow: hidden;
  display: flex;
  flex-direction: column;
}

.modal-header {
  padding: 1rem 1.5rem;
  border-bottom: 1px solid #e5e7eb;
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.modal-title {
  font-size: 1.125rem;
  font-weight: 600;
  color: #1f2937;
}

.modal-close-btn {
  color: #6b7280;
  transition: color 0.2s;
}

.modal-close-btn:hover {
  color: #374151;
}

.modal-content {
  flex: 1;
  overflow-y: auto;
  padding: 1.5rem;
}

.form-section {
  margin-bottom: 1.5rem;
}

.section-title {
  font-size: 1rem;
  font-weight: 600;
  color: #1f2937;
  margin-bottom: 0.75rem;
  padding-bottom: 0.5rem;
  border-bottom: 1px solid #e5e7eb;
}

.section-description {
  font-size: 0.875rem;
  color: #6b7280;
  margin-bottom: 1rem;
}

.form-row {
  margin-bottom: 1rem;
}

.form-label {
  display: block;
  font-size: 0.875rem;
  font-weight: 500;
  color: #374151;
  margin-bottom: 0.25rem;
}

.form-input, .form-select {
  width: 100%;
  padding: 0.5rem 0.75rem;
  border: 1px solid #d1d5db;
  border-radius: 0.375rem;
  font-size: 0.875rem;
}

.form-input:focus, .form-select:focus {
  outline: none;
  border-color: #3b82f6;
  box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
}

.checkbox-label {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  cursor: pointer;
}

.checkbox {
  width: 1rem;
  height: 1rem;
}

.color-picker-container {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.color-input {
  width: 3rem;
  height: 2.5rem;
  border: 1px solid #d1d5db;
  border-radius: 0.375rem;
  cursor: pointer;
}

.color-text-input {
  flex: 1;
  padding: 0.5rem 0.75rem;
  border: 1px solid #d1d5db;
  border-radius: 0.375rem;
  font-size: 0.875rem;
}

.random-color-btn {
  padding: 0.5rem;
  border: 1px solid #d1d5db;
  background-color: white;
  color: #6b7280;
  border-radius: 0.375rem;
  transition: all 0.2s;
}

.random-color-btn:hover {
  background-color: #f9fafb;
  border-color: #9ca3af;
}

.preset-colors {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  margin-top: 0.5rem;
}

.preset-color {
  width: 2rem;
  height: 2rem;
  border-radius: 50%;
  border: 2px solid transparent;
  cursor: pointer;
  transition: all 0.2s;
}

.preset-color:hover {
  transform: scale(1.1);
}

.preset-color.active {
  border-color: #1f2937;
  box-shadow: 0 0 0 2px white, 0 0 0 4px #1f2937;
}

.member-preview {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.75rem;
  background-color: #f9fafb;
  border-radius: 0.5rem;
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
  color: #1f2937;
}

.permissions-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 0.5rem;
}

.permission-item {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.5rem;
  background-color: #f9fafb;
  border-radius: 0.375rem;
  cursor: pointer;
  transition: background-color 0.2s;
}

.permission-item:hover {
  background-color: #f3f4f6;
}

.permission-checkbox {
  width: 1rem;
  height: 1rem;
}

.permission-label {
  font-size: 0.875rem;
  color: #374151;
}

.modal-actions {
  padding: 1rem 1.5rem;
  border-top: 1px solid #e5e7eb;
  display: flex;
  justify-content: flex-end;
  gap: 0.75rem;
}

.btn-cancel {
  padding: 0.5rem 1rem;
  border: 1px solid #d1d5db;
  background-color: white;
  color: #374151;
  border-radius: 0.375rem;
  font-size: 0.875rem;
  transition: all 0.2s;
}

.btn-cancel:hover {
  background-color: #f9fafb;
}

.btn-save {
  padding: 0.5rem 1rem;
  background-color: #3b82f6;
  color: white;
  border-radius: 0.375rem;
  font-size: 0.875rem;
  transition: background-color 0.2s;
}

.btn-save:hover {
  background-color: #2563eb;
}
</style>
