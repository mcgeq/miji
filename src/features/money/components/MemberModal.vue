<script setup lang="ts">
import BaseModal from '@/components/common/BaseModal.vue';
import FormRow from '@/components/common/FormRow.vue';
import { MemberUserRoleSchema } from '@/schema/userRole';
import { useFamilyMemberStore } from '@/stores/money';
import { Lg } from '@/utils/debugLog';
import { toast } from '@/utils/toast';
import type { FamilyMember, FamilyMemberCreate, FamilyMemberUpdate } from '@/schema/money';

interface Props {
  member: FamilyMember | null;
}

const props = defineProps<Props>();
const emit = defineEmits(['close', 'save']);
const memberStore = useFamilyMemberStore();
const isSubmitting = ref(false);

// 表单数据（只包含用户可编辑的字段）
const form = reactive({
  name: props.member?.name || '',
  role: props.member?.role || MemberUserRoleSchema.enum.Viewer,
  isPrimary: props.member?.isPrimary || false,
  permissions: props.member?.permissions || '',
  userSerialNum: props.member?.userSerialNum || null,
  avatar: props.member?.avatar || null,
  colorTag: props.member?.colorTag || null,
});

function closeModal() {
  emit('close');
}

async function saveMember() {
  if (!form.name.trim()) {
    toast.error('请输入成员姓名');
    return;
  }

  isSubmitting.value = true;
  try {
    let savedMember: FamilyMember;

    if (props.member) {
      // 更新成员
      const updateData: FamilyMemberUpdate = {
        name: form.name,
        role: form.role,
        isPrimary: form.isPrimary,
        permissions: form.permissions,
        userSerialNum: form.userSerialNum,
        avatar: form.avatar,
        colorTag: form.colorTag,
      };
      savedMember = await memberStore.updateMember(props.member.serialNum, updateData);
      toast.success('成员更新成功');
    } else {
      // 创建成员
      const createData: FamilyMemberCreate = {
        name: form.name,
        role: form.role,
        isPrimary: form.isPrimary,
        permissions: form.permissions,
        userSerialNum: form.userSerialNum,
        avatar: form.avatar,
        colorTag: form.colorTag,
      };
      savedMember = await memberStore.createMember(createData);
      toast.success('成员创建成功');
    }

    emit('save', savedMember);
  } catch (error: any) {
    const errorMsg = props.member ? '更新成员失败' : '创建成员失败';
    toast.error(error.message || errorMsg);
    Lg.e('MemberModal', errorMsg, error);
  } finally {
    isSubmitting.value = false;
  }
}

// 监听 props 变化
watch(
  () => props.member,
  newVal => {
    if (newVal) {
      form.name = newVal.name;
      form.role = newVal.role;
      form.isPrimary = newVal.isPrimary;
      form.permissions = newVal.permissions;
      form.userSerialNum = newVal.userSerialNum ?? null;
      form.avatar = newVal.avatar ?? null;
      form.colorTag = newVal.colorTag ?? null;
    } else {
      form.name = '';
      form.role = MemberUserRoleSchema.enum.Viewer;
      form.isPrimary = false;
      form.permissions = '';
      form.userSerialNum = null;
      form.avatar = null;
      form.colorTag = null;
    }
  },
  { immediate: true },
);
</script>

<template>
  <BaseModal
    :title="props.member ? '编辑成员' : '添加成员'"
    size="md"
    :confirm-loading="isSubmitting"
    @close="closeModal"
    @confirm="saveMember"
  >
    <form @submit.prevent="saveMember">
      <FormRow label="姓名" required>
        <input
          v-model="form.name"
          v-has-value
          type="text"
          required
          class="modal-input-select w-full"
          placeholder="请输入成员姓名"
        >
      </FormRow>

      <FormRow label="角色" required>
        <select
          v-model="form.role"
          v-has-value
          required
          class="modal-input-select w-full"
        >
          <option value="">
            请选择角色
          </option>
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
      </FormRow>

      <FormRow label="权限设置" optional>
        <textarea
          v-model="form.permissions"
          rows="3"
          class="modal-input-select w-full"
          placeholder="权限描述（可选）"
        />
      </FormRow>

      <FormRow label="" optional>
        <label class="checkbox-label">
          <input v-model="form.isPrimary" type="checkbox" class="checkbox-input">
          <span class="checkbox-text">设为主要成员</span>
        </label>
      </FormRow>
    </form>
  </BaseModal>
</template>

<style scoped>
/* 复选框样式 */
.checkbox-label {
  display: flex;
  align-items: center;
  cursor: pointer;
}

.checkbox-input {
  margin-right: 0.5rem;
  cursor: pointer;
}

.checkbox-text {
  font-size: 0.875rem;
  color: var(--color-base-content);
  font-weight: 500;
}
</style>
