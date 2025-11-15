<script setup lang="ts">
import { MemberUserRoleSchema } from '@/schema/userRole';
import { DateUtils } from '@/utils/date';
import { uuid } from '@/utils/uuid';
import type { FamilyMember } from '@/schema/money';

interface Props {
  member: FamilyMember | null;
}

const props = defineProps<Props>();
const emit = defineEmits(['close', 'save']);

const defaultMember: FamilyMember = {
  serialNum: '',
  name: '',
  role: MemberUserRoleSchema.enum.Viewer,
  isPrimary: false,
  permissions: '',
  userSerialNum: null,
  avatar: null,
  colorTag: null,
  totalPaid: 0,
  totalOwed: 0,
  netBalance: 0,
  transactionCount: 0,
  splitCount: 0,
  lastActiveAt: null,
  createdAt: DateUtils.getLocalISODateTimeWithOffset(),
  updatedAt: null,
};

const form = reactive<FamilyMember>({
  ...defaultMember,
  ...(props.member || {}),
});

function closeModal() {
  emit('close');
}

function saveMember() {
  const memberData: FamilyMember = {
    ...form,
    serialNum: props.member?.serialNum || uuid(38),
    createdAt: props.member?.createdAt || DateUtils.getLocalISODateTimeWithOffset(),
    updatedAt: DateUtils.getLocalISODateTimeWithOffset(),
  };
  emit('save', memberData);
}

// 监听 props 变化
watch(
  () => props.member,
  newVal => {
    if (newVal) {
      Object.assign(form, JSON.parse(JSON.stringify(newVal)));
    } else {
      Object.assign(form, JSON.parse(JSON.stringify(defaultMember)));
    }
  },
  { immediate: true, deep: true },
);
</script>

<template>
  <div class="modal-mask" style="z-index: 60;">
    <div class="modal-mask-window-money modal-content modal-content-sm">
      <div class="modal-header">
        <h4 class="modal-title">
          {{ props.member ? '编辑成员' : '添加成员' }}
        </h4>
        <button class="modal-close-btn" @click="closeModal">
          <LucideX class="modal-icon" />
        </button>
      </div>

      <form class="modal-form" @submit.prevent="saveMember">
        <div class="form-fields">
          <div class="form-field">
            <label class="form-label">姓名</label>
            <input v-model="form.name" type="text" required class="modal-input-select" placeholder="请输入成员姓名">
          </div>

          <div class="form-field">
            <label class="form-label">角色</label>
            <select v-model="form.role" required class="modal-input-select">
              <option value="Owner">
                所有者
              </option>
              <option value="Admin">
                管理员
              </option>
              <option value="User">
                用户
              </option>
              <option value="Moderator">
                协调员
              </option>
              <option value="Editor">
                编辑者
              </option>
              <option value="Guest">
                访客
              </option>
            </select>
          </div>

          <div class="form-field">
            <label class="form-label">权限设置</label>
            <textarea
              v-model="form.permissions" rows="3" class="modal-input-select"
              placeholder="权限描述（可选）"
            />
          </div>

          <div class="form-field">
            <label class="checkbox-label">
              <input v-model="form.isPrimary" type="checkbox" class="checkbox-input">
              <span class="checkbox-text">设为主要成员</span>
            </label>
          </div>
        </div>

        <div class="modal-actions">
          <button type="button" class="btn-close" @click="closeModal">
            <LucideX class="modal-icon" />
          </button>
          <button type="submit" class="btn-submit">
            <LucideCheck class="modal-icon" />
          </button>
        </div>
      </form>
    </div>
  </div>
</template>

<style scoped>
/* 模态框容器 */
.modal-content-sm {
  max-width: 24rem;
}

.modal-header {
  margin-bottom: 1rem;
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.modal-title {
  font-size: 1.125rem;
  font-weight: 600;
}

.modal-close-btn {
  color: #6b7280;
  transition: color 0.2s ease-in-out;
}

.modal-close-btn:hover {
  color: #374151;
}

.modal-icon {
  height: 1.25rem;
  width: 1.25rem;
}

/* 表单样式 */
.modal-form {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.form-fields {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.form-field {
  display: flex;
  flex-direction: column;
}

.form-label {
  font-size: 0.875rem;
  color: #374151;
  font-weight: 500;
  margin-bottom: 0.25rem;
  display: block;
}

/* 复选框样式 */
.checkbox-label {
  display: flex;
  align-items: center;
}

.checkbox-input {
  margin-right: 0.5rem;
}

.checkbox-text {
  font-size: 0.875rem;
  color: #374151;
  font-weight: 500;
}

/* 模态框操作按钮 */
.modal-actions {
  padding-top: 1rem;
  display: flex;
  justify-content: center;
  gap: 0.75rem;
}
</style>
