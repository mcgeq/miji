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
    <div class="modal-content max-w-sm">
      <div class="mb-4 flex items-center justify-between">
        <h4 class="text-lg font-semibold">
          {{ props.member ? '编辑成员' : '添加成员' }}
        </h4>
        <button class="text-gray-500 hover:text-gray-700" @click="closeModal">
          <LucideX class="h-5 w-5" />
        </button>
      </div>

      <form class="space-y-4" @submit.prevent="saveMember">
        <div class="space-y-3">
          <div>
            <label class="text-sm text-gray-700 font-medium mb-1 block">姓名</label>
            <input v-model="form.name" type="text" required class="modal-input-select w-full" placeholder="请输入成员姓名">
          </div>

          <div>
            <label class="text-sm text-gray-700 font-medium mb-1 block">角色</label>
            <select v-model="form.role" required class="modal-input-select w-full">
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

          <div>
            <label class="text-sm text-gray-700 font-medium mb-1 block">权限设置</label>
            <textarea
              v-model="form.permissions" rows="3" class="modal-input-select w-full"
              placeholder="权限描述（可选）"
            />
          </div>

          <div>
            <label class="flex items-center">
              <input v-model="form.isPrimary" type="checkbox" class="mr-2">
              <span class="text-sm text-gray-700 font-medium">设为主要成员</span>
            </label>
          </div>
        </div>

        <div class="pt-4 flex justify-center space-x-3">
          <button type="button" class="modal-btn-x" @click="closeModal">
            <LucideX class="wh-4" />
          </button>
          <button type="submit" class="modal-btn-check">
            <LucideCheck class="wh-4" />
          </button>
        </div>
      </form>
    </div>
  </div>
</template>
