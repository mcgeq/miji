<script setup lang="ts">
import { Clock, FileText, Globe, Mail, Phone, Save, User } from 'lucide-vue-next';
import ConfirmDialog from '@/components/common/ConfirmDialogCompat.vue';
import { Input, Modal, Select, Textarea } from '@/components/ui';
import { useAuthStore } from '@/stores/auth';
import type { AuthUser } from '@/schema/user';

// ============= 类型定义 =============
interface Props {
  isOpen: boolean;
}

interface Emits {
  (e: 'close'): void;
  (e: 'update', data: Partial<AuthUser>): void;
}

// 扩展AuthUser类型以包含可能缺失的字段
interface ExtendedAuthUser extends AuthUser {
  phone?: string;
  bio?: string;
}

interface FormData {
  name: string;
  email: string;
  phone: string;
  bio: string;
  language: string;
  timezone: string;
}

interface ValidationRule {
  required?: boolean;
  pattern?: RegExp;
  maxLength?: number;
  minLength?: number;
  message?: string;
}

interface SelectOption {
  readonly value: string;
  readonly label: string;
}

interface FormField {
  key: keyof FormData;
  label: string;
  placeholder: string;
  type: 'text' | 'email' | 'tel' | 'textarea' | 'select';
  icon?: any;
  required?: boolean;
  maxLength?: number;
  rows?: number;
  options?: readonly SelectOption[];
  validation?: ValidationRule[];
}

// ============= Props & Emits =============
const props = defineProps<Props>();
const emit = defineEmits<Emits>();

// ============= Store =============
const authStore = useAuthStore();
const user = computed<ExtendedAuthUser | null>(() => authStore.user as ExtendedAuthUser | null);

// ============= 响应式数据 =============
const formData = ref<FormData>({
  name: '',
  email: '',
  phone: '',
  bio: '',
  language: 'zh-CN',
  timezone: 'Asia/Shanghai',
});

const errors = ref<Partial<Record<keyof FormData, string>>>({});
const isSubmitting = ref(false);
const isDirty = ref(false);
const nameInputRef = ref<HTMLInputElement>();
const showConfirmDialog = ref(false);

// ============= 常量配置 =============
const LANGUAGE_OPTIONS: readonly SelectOption[] = [
  { value: 'zh-CN', label: '简体中文' },
  { value: 'zh-TW', label: '繁体中文' },
  { value: 'en-US', label: 'English' },
  { value: 'ja-JP', label: '日本語' },
  { value: 'ko-KR', label: '한국어' },
];

const TIMEZONE_OPTIONS: readonly SelectOption[] = [
  { value: 'Asia/Shanghai', label: 'Asia/Shanghai (UTC+8)' },
  { value: 'Asia/Tokyo', label: 'Asia/Tokyo (UTC+9)' },
  { value: 'Asia/Seoul', label: 'Asia/Seoul (UTC+9)' },
  { value: 'America/New_York', label: 'America/New_York (UTC-5)' },
  { value: 'America/Los_Angeles', label: 'America/Los_Angeles (UTC-8)' },
  { value: 'Europe/London', label: 'Europe/London (UTC+0)' },
  { value: 'Europe/Paris', label: 'Europe/Paris (UTC+1)' },
];

// 表单字段配置
const FORM_FIELDS: FormField[] = [
  {
    key: 'name',
    label: '姓名',
    placeholder: '请输入姓名',
    type: 'text',
    icon: User,
    required: true,
    maxLength: 50,
    validation: [
      { required: true, message: '姓名不能为空' },
      { minLength: 2, message: '姓名至少需要2个字符' },
      { maxLength: 50, message: '姓名不能超过50个字符' },
    ],
  },
  {
    key: 'email',
    label: '邮箱地址',
    placeholder: '请输入邮箱地址',
    type: 'email',
    icon: Mail,
    required: true,
    validation: [
      { required: true, message: '邮箱不能为空' },
      { pattern: /^[^\s@]+@[^\s@][^\s.@]*\.[^\s@]+$/, message: '邮箱格式不正确' },
    ],
  },
  {
    key: 'phone',
    label: '手机号',
    placeholder: '请输入手机号',
    type: 'tel',
    icon: Phone,
    maxLength: 11,
    validation: [
      { pattern: /^1[3-9]\d{9}$/, message: '手机号格式不正确' },
    ],
  },
  {
    key: 'bio',
    label: '个人简介',
    placeholder: '请输入个人简介（选填）',
    type: 'textarea',
    icon: FileText,
    maxLength: 200,
    rows: 3,
    validation: [
      { maxLength: 200, message: '个人简介不能超过200字符' },
    ],
  },
  {
    key: 'language',
    label: '语言',
    placeholder: '',
    type: 'select',
    icon: Globe,
    options: LANGUAGE_OPTIONS,
  },
  {
    key: 'timezone',
    label: '时区',
    placeholder: '',
    type: 'select',
    icon: Clock,
    options: TIMEZONE_OPTIONS,
  },
];

// ============= 计算属性 =============
const hasErrors = computed(() => Object.keys(errors.value).length > 0);
const canSubmit = computed(() => !hasErrors.value && isDirty.value && !isSubmitting.value);

// ============= 表单验证 =============
function validateField(field: FormField, value: string): string | null {
  if (!field.validation)
    return null;

  for (const rule of field.validation) {
    // 必填验证
    if (rule.required && !value.trim()) {
      return rule.message || `${field.label}不能为空`;
    }

    // 只有当有值时才进行其他验证
    if (value.trim()) {
      // 正则验证
      if (rule.pattern && !rule.pattern.test(value)) {
        return rule.message || `${field.label}格式不正确`;
      }

      // 长度验证
      if (rule.minLength && value.length < rule.minLength) {
        return rule.message || `${field.label}至少需要${rule.minLength}个字符`;
      }

      if (rule.maxLength && value.length > rule.maxLength) {
        return rule.message || `${field.label}不能超过${rule.maxLength}个字符`;
      }
    }
  }

  return null;
}

function validateForm(): boolean {
  const newErrors: Partial<Record<keyof FormData, string>> = {};

  FORM_FIELDS.forEach(field => {
    const error = validateField(field, formData.value[field.key]);
    if (error) {
      newErrors[field.key] = error;
    }
  });

  errors.value = newErrors;
  return Object.keys(newErrors).length === 0;
}

function validateSingleField(key: keyof FormData) {
  const field = FORM_FIELDS.find(f => f.key === key);
  if (!field)
    return;

  const error = validateField(field, formData.value[key]);
  if (error) {
    errors.value[key] = error;
  } else {
    delete errors.value[key];
  }
}

// ============= 表单处理 =============
function initializeForm() {
  if (!user.value)
    return;

  const initialData = {
    name: user.value.name || '',
    email: user.value.email || '',
    phone: user.value.phone || '',
    bio: user.value.bio || '',
    language: user.value.language || 'zh-CN',
    timezone: user.value.timezone || 'Asia/Shanghai',
  };

  formData.value = { ...initialData };
  errors.value = {};
  isDirty.value = false;
}

function checkIfDirty() {
  if (!user.value)
    return;

  const hasChanges = Object.keys(formData.value).some(key => {
    const formKey = key as keyof FormData;
    const currentValue = formData.value[formKey];
    // 安全地访问用户数据
    const originalValue = (user.value as any)?.[formKey] || '';
    return currentValue !== originalValue;
  });

  isDirty.value = hasChanges;
}

// ============= 事件处理 =============
async function handleSubmit() {
  if (!validateForm()) {
    // 聚焦到第一个错误字段
    const firstErrorField = Object.keys(errors.value)[0];
    const errorElement = document.querySelector(`[data-field="${firstErrorField}"]`) as HTMLElement;
    errorElement?.focus();
    return;
  }

  isSubmitting.value = true;

  try {
    // 模拟API调用延迟
    await new Promise(resolve => setTimeout(resolve, 1000));

    // 只发送有变化的字段
    const changedData: Partial<ExtendedAuthUser> = {};
    Object.keys(formData.value).forEach(key => {
      const formKey = key as keyof FormData;
      const currentValue = formData.value[formKey];
      const originalValue = (user.value as any)?.[formKey] || '';
      if (currentValue !== originalValue) {
        (changedData as any)[formKey] = currentValue;
      }
    });

    emit('update', changedData);
    emit('close');
  } catch (error) {
    console.error('更新资料失败:', error);
    // 可以在这里添加错误提示
  } finally {
    isSubmitting.value = false;
  }
}

function handleClose() {
  if (isSubmitting.value)
    return;

  // 如果有未保存的更改，显示确认对话框
  if (isDirty.value) {
    showConfirmDialog.value = true;
    return;
  }

  emit('close');
}

function handleConfirmClose() {
  showConfirmDialog.value = false;
  emit('close');
}

function handleCancelClose() {
  showConfirmDialog.value = false;
}

function handleInput(key: keyof FormData, value: string | number) {
  formData.value[key] = value as any;

  // 实时验证
  if (errors.value[key]) {
    validateSingleField(key);
  }

  // 检查是否有更改
  checkIfDirty();
}

// ============= 键盘事件处理 =============
function handleKeydown(event: KeyboardEvent) {
  if (event.key === 'Escape') {
    handleClose();
  } else if (event.key === 'Enter' && (event.ctrlKey || event.metaKey)) {
    handleSubmit();
  }
}

// ============= 生命周期 =============
watch(() => props.isOpen, async isOpen => {
  if (isOpen) {
    initializeForm();
    await nextTick();
    nameInputRef.value?.focus();
  }
});

// 监听表单数据变化
watch(formData, checkIfDirty, { deep: true });

onMounted(() => {
  document.addEventListener('keydown', handleKeydown);
});

onUnmounted(() => {
  document.removeEventListener('keydown', handleKeydown);
});
</script>

<template>
  <Modal
    :open="isOpen"
    size="lg"
    :show-footer="false"
    :close-on-overlay="false"
    @close="handleClose"
  >
    <template #header>
      <div class="flex items-center gap-3">
        <div class="w-10 h-10 rounded-full bg-blue-100 dark:bg-blue-900/30 flex items-center justify-center">
          <User class="w-5 h-5 text-blue-600 dark:text-blue-400" />
        </div>
        <div>
          <h2 class="text-xl font-semibold text-gray-900 dark:text-white">
            编辑资料
          </h2>
          <p class="text-sm text-gray-500 dark:text-gray-400 mt-0.5">
            更新您的个人信息和偏好设置
          </p>
        </div>
      </div>
    </template>

    <!-- 表单内容 -->
    <form @submit.prevent="handleSubmit">
      <!-- 基本信息 -->
      <section class="mb-6">
        <div class="flex items-center gap-2 mb-4">
          <User class="w-5 h-5 text-gray-600 dark:text-gray-400" />
          <h3 class="text-base font-semibold text-gray-900 dark:text-white">
            基本信息
          </h3>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <!-- 动态渲染基本信息字段 -->
          <template v-for="field in FORM_FIELDS.slice(0, 4)" :key="field.key">
            <div :class="field.type === 'textarea' ? 'md:col-span-2' : ''">
              <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1.5">
                {{ field.label }}
                <span v-if="field.required" class="text-red-500">*</span>
              </label>

              <!-- 文本输入框 -->
              <div v-if="field.type === 'text' || field.type === 'email' || field.type === 'tel'">
                <Input
                  :ref="field.key === 'name' ? (el) => { nameInputRef = el as HTMLInputElement } : undefined"
                  :model-value="formData[field.key]"
                  :type="field.type"
                  :placeholder="field.placeholder"
                  :max-length="field.maxLength"
                  :prefix-icon="field.icon"
                  :error="errors[field.key]"
                  full-width
                  @update:model-value="handleInput(field.key, $event)"
                  @blur="validateSingleField(field.key)"
                />
              </div>

              <!-- 文本域 -->
              <div v-else-if="field.type === 'textarea'">
                <Textarea
                  :model-value="formData[field.key]"
                  :placeholder="field.placeholder"
                  :max-length="field.maxLength"
                  :rows="field.rows"
                  :error="errors[field.key]"
                  @update:model-value="handleInput(field.key, $event)"
                  @blur="validateSingleField(field.key)"
                />
              </div>
            </div>
          </template>
        </div>
      </section>

      <!-- 偏好设置 -->
      <section class="mb-6">
        <div class="flex items-center gap-2 mb-4">
          <Globe class="w-5 h-5 text-gray-600 dark:text-gray-400" />
          <h3 class="text-base font-semibold text-gray-900 dark:text-white">
            偏好设置
          </h3>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <!-- 动态渲染偏好设置字段 -->
          <template v-for="field in FORM_FIELDS.slice(4)" :key="field.key">
            <div>
              <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1.5">
                {{ field.label }}
              </label>
              <Select
                :model-value="formData[field.key]"
                :options="(field.options as any) || []"
                full-width
                @update:model-value="(value) => handleInput(field.key, value as string)"
              />
            </div>
          </template>
        </div>
      </section>

      <!-- 底部操作栏 -->
      <div class="flex items-center justify-between pt-4 border-t border-gray-200 dark:border-gray-700">
        <div class="flex gap-3">
          <button
            type="button"
            :disabled="!canSubmit"
            class="flex items-center gap-2 px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            @click="handleSubmit"
          >
            <Save class="w-4 h-4" />
            {{ isSubmitting ? '保存中...' : '保存更改' }}
          </button>
          <button
            type="button"
            :disabled="isSubmitting"
            class="px-4 py-2 border border-gray-300 dark:border-gray-600 hover:bg-gray-50 dark:hover:bg-gray-700 rounded-lg disabled:opacity-50 transition-colors"
            @click="handleClose"
          >
            取消
          </button>
        </div>

        <!-- 状态指示器 -->
        <div v-if="isDirty" class="flex items-center gap-2 text-sm text-amber-600 dark:text-amber-400">
          <div class="w-2 h-2 rounded-full bg-amber-600 dark:bg-amber-400 animate-pulse" />
          有未保存的更改
        </div>
      </div>
    </form>
  </Modal>

  <!-- 确认关闭模态框 -->
  <ConfirmDialog
    v-model:visible="showConfirmDialog"
    title="确认关闭"
    message="您有未保存的更改，确定要关闭吗？关闭后所有更改将丢失。"
    type="warning"
    confirm-text="确定关闭"
    cancel-text="继续编辑"
    confirm-button-type="warning"
    @confirm="handleConfirmClose"
    @cancel="handleCancelClose"
  />
</template>
