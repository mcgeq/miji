<script setup lang="ts">
  import type { SelectOption } from '@/components/ui';
  import { Checkbox, FormRow, Input, Modal, Select, Textarea } from '@/components/ui';
  import type { FamilyMember, FamilyMemberCreate, FamilyMemberUpdate } from '@/schema/money';
  import { MemberUserRoleSchema } from '@/schema/userRole';
  import { useFamilyMemberStore } from '@/stores/money';
  import { Lg } from '@/utils/debugLog';
  import { toast } from '@/utils/toast';

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
    isPrimary: props.member?.isPrimary,
    permissions: props.member?.permissions || '',
    userSerialNum: props.member?.userSerialNum || null,
    avatar: props.member?.avatar || null,
    colorTag: props.member?.colorTag || null,
  });

  // 角色选项
  const roleOptions = computed<SelectOption[]>(() => [
    { value: 'Owner', label: '所有者' },
    { value: 'Admin', label: '管理员' },
    { value: 'User', label: '用户' },
    { value: 'Moderator', label: '协调员' },
    { value: 'Editor', label: '编辑者' },
    { value: 'Guest', label: '访客' },
  ]);

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
          isPrimary: form.isPrimary ?? false,
          permissions: form.permissions,
          userSerialNum: form.userSerialNum,
          avatar: form.avatar,
          colorTag: form.colorTag,
        };
        savedMember = await memberStore.createMember(createData);
        toast.success('成员创建成功');
      }

      emit('save', savedMember);
    } catch (error: unknown) {
      const errorMsg = props.member ? '更新成员失败' : '创建成员失败';
      const message = error instanceof Error ? error.message : errorMsg;
      toast.error(message);
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
  <Modal
    :open="true"
    :title="props.member ? '编辑成员' : '添加成员'"
    size="md"
    :confirm-loading="isSubmitting"
    @close="closeModal"
    @confirm="saveMember"
  >
    <form @submit.prevent="saveMember">
      <FormRow label="姓名" required>
        <Input v-model="form.name" type="text" placeholder="请输入成员姓名" />
      </FormRow>

      <FormRow label="角色" required>
        <Select v-model="form.role" :options="roleOptions" placeholder="请选择角色" />
      </FormRow>

      <FormRow full-width>
        <Textarea
          v-model="form.permissions"
          :rows="3"
          :max-length="200"
          placeholder="权限描述（可选）"
        />
      </FormRow>

      <div class="mb-3">
        <Checkbox v-model="form.isPrimary" label="设为主要成员" />
      </div>
    </form>
  </Modal>
</template>
