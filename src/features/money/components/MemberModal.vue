<template>
  <div class="modal-mask" style="z-index: 60;">
    <div class="modal-content max-w-sm">
      <div class="flex justify-between items-center mb-4">
        <h4 class="text-lg font-semibold">{{ props.member ? '编辑成员' : '添加成员' }}</h4>
        <button @click="closeModal" class="text-gray-500 hover:text-gray-700">
          <X class="w-5 h-5" />
        </button>
      </div>

      <form @submit.prevent="saveMember" class="space-y-4">
        <div class="space-y-3">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">姓名</label>
            <input
              v-model="form.name"
              type="text"
              required
              class="w-full modal-input-select"
              placeholder="请输入成员姓名"
            />
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">角色</label>
            <select v-model="form.role" required class="w-full modal-input-select">
              <option value="Owner">所有者</option>
              <option value="Admin">管理员</option>
              <option value="User">用户</option>
              <option value="Moderator">协调员</option>
              <option value="Editor">编辑者</option>
              <option value="Guest">访客</option>
            </select>
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">权限设置</label>
            <textarea
              v-model="form.permissions"
              rows="3"
              class="w-full modal-input-select"
              placeholder="权限描述（可选）"
            ></textarea>
          </div>

          <div>
            <label class="flex items-center">
              <input
                v-model="form.isPrimary"
                type="checkbox"
                class="mr-2"
              />
              <span class="text-sm font-medium text-gray-700">设为主要成员</span>
            </label>
          </div>
        </div>

        <div class="flex justify-center space-x-3 pt-4">
          <button type="button" @click="closeModal" class="modal-btn-x">
            <X class="wh-4" />
          </button>
          <button type="submit" class="modal-btn-check">
            <Check class="wh-4" />
          </button>
        </div>
      </form>
    </div>
  </div>
</template>

<script setup lang="ts">
import { Check, X } from 'lucide-vue-next';
import { uuid } from '@/utils/uuid';
import { getLocalISODateTimeWithOffset } from '@/utils/date';
import { UserRoleSchema } from '@/schema/userRole';
import { FamilyMember } from '@/schema/money';

interface Props {
  member: FamilyMember | null;
}

const props = defineProps<Props>();
const emit = defineEmits(['close', 'save']);

const defaultMember: FamilyMember = {
  serialNum: '',
  name: '',
  role: UserRoleSchema.enum.User,
  isPrimary: false,
  permissions: '',
  createdAt: getLocalISODateTimeWithOffset(),
  updatedAt: null,
};

const form = reactive<FamilyMember>({
  ...defaultMember,
  ...(props.member || {}),
});

const closeModal = () => {
  emit('close');
};

const saveMember = () => {
  const memberData: FamilyMember = {
    ...form,
    serialNum: props.member?.serialNum || uuid(38),
    createdAt: props.member?.createdAt || getLocalISODateTimeWithOffset(),
    updatedAt: getLocalISODateTimeWithOffset(),
  };
  emit('save', memberData);
};

// 监听 props 变化
watch(
  () => props.member,
  (newVal) => {
    if (newVal) {
      Object.assign(form, JSON.parse(JSON.stringify(newVal)));
    } else {
      Object.assign(form, JSON.parse(JSON.stringify(defaultMember)));
    }
  },
  { immediate: true, deep: true },
);
</script>
