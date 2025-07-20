<script setup lang="ts">
import { AlertCircle, Clock, FileText, Globe, Mail, Phone, Save, User, X } from 'lucide-vue-next';
import ConfirmModal from '@/components/common/ConfirmModal.vue';
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
const showConfirmModal = ref(false);

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
  }
  else {
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
  }
  catch (error) {
    console.error('更新资料失败:', error);
    // 可以在这里添加错误提示
  }
  finally {
    isSubmitting.value = false;
  }
}

function handleClose() {
  if (isSubmitting.value)
    return;

  // 如果有未保存的更改，显示确认对话框
  if (isDirty.value) {
    showConfirmModal.value = true;
    return;
  }

  emit('close');
}

function handleConfirmClose() {
  showConfirmModal.value = false;
  emit('close');
}

function handleCancelClose() {
  showConfirmModal.value = false;
}

function handleOverlayClick(event: MouseEvent) {
  if (event.target === event.currentTarget) {
    handleClose();
  }
}

function handleInput(key: keyof FormData, value: string) {
  formData.value[key] = value;

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
  }
  else if (event.key === 'Enter' && (event.ctrlKey || event.metaKey)) {
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
  <Teleport to="body">
    <Transition
      name="modal-overlay"
      enter-active-class="duration-300 ease-out"
      enter-from-class="opacity-0"
      enter-to-class="opacity-100"
      leave-active-class="duration-200 ease-in"
      leave-from-class="opacity-100"
      leave-to-class="opacity-0"
    >
      <div
        v-if="isOpen"
        class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4 backdrop-blur-sm"
        @click="handleOverlayClick"
      >
        <Transition
          name="modal"
          enter-active-class="duration-300 ease-out"
          enter-from-class="scale-95 opacity-0"
          enter-to-class="scale-100 opacity-100"
          leave-active-class="duration-200 ease-in"
          leave-from-class="scale-100 opacity-100"
          leave-to-class="scale-95 opacity-0"
        >
          <div
            v-if="isOpen"
            class="max-h-[90vh] max-w-2xl modal-content w-full rounded-2xl bg-white shadow-2xl"
            role="dialog"
            aria-modal="true"
            aria-labelledby="modal-title"
          >
            <!-- Modal 头部 -->
            <div class="sticky top-0 z-10 border-b border-gray-200 rounded-t-2xl bg-white px-6 py-4">
              <div class="flex items-center justify-between">
                <div class="flex items-center gap-3">
                  <div class="rounded-lg bg-blue-100 p-2">
                    <User class="h-5 w-5 text-blue-600" />
                  </div>
                  <div>
                    <h2 id="modal-title" class="text-xl text-gray-900 font-bold">
                      编辑资料
                    </h2>
                    <p class="text-sm text-gray-500">
                      更新您的个人信息和偏好设置
                    </p>
                  </div>
                </div>
                <button
                  class="rounded-full p-2 text-gray-400 transition-colors hover:bg-gray-100 hover:text-gray-600 focus:outline-none focus:ring-2 focus:ring-blue-500/20"
                  :disabled="isSubmitting"
                  aria-label="关闭对话框"
                  @click="handleClose"
                >
                  <X class="h-5 w-5" />
                </button>
              </div>
            </div>

            <!-- 表单内容 -->
            <div class="modal-body p-6">
              <form class="space-y-8" @submit.prevent="handleSubmit">
                <!-- 基本信息 -->
                <section class="space-y-6">
                  <div class="flex items-center gap-2">
                    <User class="h-5 w-5 text-gray-600" />
                    <h3 class="text-lg text-gray-900 font-semibold">
                      基本信息
                    </h3>
                  </div>

                  <div class="grid grid-cols-1 gap-6 md:grid-cols-2">
                    <!-- 动态渲染基本信息字段 -->
                    <template v-for="field in FORM_FIELDS.slice(0, 4)" :key="field.key">
                      <div :class="field.type === 'textarea' ? 'md:col-span-2' : ''">
                        <label class="mb-2 block text-sm text-gray-700 font-medium">
                          {{ field.label }}
                          <span v-if="field.required" class="ml-1 text-red-500">*</span>
                        </label>

                        <!-- 文本输入框 -->
                        <div v-if="field.type === 'text' || field.type === 'email' || field.type === 'tel'" class="relative">
                          <component
                            :is="field.icon"
                            class="absolute left-3 top-1/2 h-4 w-4 text-gray-400 -translate-y-1/2"
                          />
                          <input
                            :ref="field.key === 'name' ? (el) => { nameInputRef = el as HTMLInputElement } : undefined"
                            :type="field.type"
                            :placeholder="field.placeholder"
                            :maxlength="field.maxLength"
                            :value="formData[field.key]"
                            :data-field="field.key"
                            class="w-full border border-gray-300 rounded-lg py-3 pl-10 pr-4 text-sm transition-colors focus:border-blue-500 disabled:bg-gray-50 disabled:text-gray-500 focus:outline-none focus:ring-2 focus:ring-blue-500/20"
                            :class="{ 'border-red-500 focus:border-red-500 focus:ring-red-500/20': errors[field.key] }"
                            @input="handleInput(field.key, ($event.target as HTMLInputElement).value)"
                            @blur="validateSingleField(field.key)"
                          >
                        </div>

                        <!-- 文本域 -->
                        <div v-else-if="field.type === 'textarea'" class="relative">
                          <component
                            :is="field.icon"
                            class="absolute left-3 top-3 h-4 w-4 text-gray-400"
                          />
                          <textarea
                            :placeholder="field.placeholder"
                            :maxlength="field.maxLength"
                            :rows="field.rows"
                            :value="formData[field.key]"
                            :data-field="field.key"
                            class="w-full resize-none border border-gray-300 rounded-lg py-3 pl-10 pr-4 text-sm transition-colors focus:border-blue-500 focus:outline-none focus:ring-2 focus:ring-blue-500/20"
                            :class="{ 'border-red-500 focus:border-red-500 focus:ring-red-500/20': errors[field.key] }"
                            @input="handleInput(field.key, ($event.target as HTMLTextAreaElement).value)"
                            @blur="validateSingleField(field.key)"
                          />
                        </div>

                        <!-- 错误信息和字符计数 -->
                        <div v-if="errors[field.key] || field.maxLength" class="mt-1 flex justify-between">
                          <p v-if="errors[field.key]" class="flex items-center gap-1 text-sm text-red-500">
                            <AlertCircle class="h-3 w-3" />
                            {{ errors[field.key] }}
                          </p>
                          <p
                            v-if="field.maxLength"
                            class="ml-auto text-sm"
                            :class="formData[field.key].length > field.maxLength * 0.8 ? 'text-amber-500' : 'text-gray-500'"
                          >
                            {{ formData[field.key].length }}/{{ field.maxLength }}
                          </p>
                        </div>
                      </div>
                    </template>
                  </div>
                </section>

                <!-- 偏好设置 -->
                <section class="space-y-6">
                  <div class="flex items-center gap-2">
                    <Globe class="h-5 w-5 text-gray-600" />
                    <h3 class="text-lg text-gray-900 font-semibold">
                      偏好设置
                    </h3>
                  </div>

                  <div class="grid grid-cols-1 gap-6 md:grid-cols-2">
                    <!-- 动态渲染偏好设置字段 -->
                    <template v-for="field in FORM_FIELDS.slice(4)" :key="field.key">
                      <div>
                        <label class="mb-2 block text-sm text-gray-700 font-medium">
                          {{ field.label }}
                        </label>
                        <div class="relative">
                          <component
                            :is="field.icon"
                            class="pointer-events-none absolute left-3 top-1/2 h-4 w-4 text-gray-400 -translate-y-1/2"
                          />
                          <select
                            :value="formData[field.key]"
                            :data-field="field.key"
                            class="w-full border border-gray-300 rounded-lg bg-white py-3 pl-10 pr-4 text-sm transition-colors focus:border-blue-500 focus:outline-none focus:ring-2 focus:ring-blue-500/20"
                            @change="handleInput(field.key, ($event.target as HTMLSelectElement).value)"
                          >
                            <option
                              v-for="option in field.options"
                              :key="option.value"
                              :value="option.value"
                            >
                              {{ option.label }}
                            </option>
                          </select>
                        </div>
                      </div>
                    </template>
                  </div>
                </section>
              </form>
            </div>

            <!-- 底部操作栏 -->
            <div class="sticky bottom-0 border-t border-gray-200 rounded-b-2xl bg-white px-6 py-4">
              <div class="flex flex-col gap-3 sm:flex-row-reverse sm:gap-3">
                <button
                  type="button"
                  :disabled="!canSubmit"
                  class="flex items-center justify-center gap-2 rounded-lg bg-blue-600 px-6 py-3 text-sm text-white font-medium transition-colors disabled:cursor-not-allowed disabled:bg-gray-300 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500/20"
                  @click="handleSubmit"
                >
                  <Save class="h-4 w-4" />
                  {{ isSubmitting ? '保存中...' : '保存更改' }}
                </button>
                <button
                  type="button"
                  :disabled="isSubmitting"
                  class="border border-gray-300 rounded-lg px-6 py-3 text-sm text-gray-700 font-medium transition-colors disabled:cursor-not-allowed hover:bg-gray-50 disabled:opacity-50 focus:outline-none focus:ring-2 focus:ring-gray-500/20"
                  @click="handleClose"
                >
                  取消
                </button>
              </div>

              <!-- 状态指示器 -->
              <div v-if="isDirty" class="mt-3 flex items-center gap-2 text-sm text-amber-600">
                <div class="h-2 w-2 rounded-full bg-amber-500" />
                有未保存的更改
              </div>
            </div>
          </div>
        </Transition>
      </div>
    </Transition>

    <!-- 确认关闭模态框 -->
    <ConfirmModal
      :visible="showConfirmModal"
      title="确认关闭"
      message="您有未保存的更改，确定要关闭吗？关闭后所有更改将丢失。"
      type="warning"
      confirm-text="确定关闭"
      cancel-text="继续编辑"
      confirm-button-type="warning"
      @confirm="handleConfirmClose"
      @cancel="handleCancelClose"
      @close="handleCancelClose"
    />
  </Teleport>
</template>

<style scoped>
/* 隐藏滚动条但保持滚动功能 */
.modal-content {
  overflow-y: auto;
  scrollbar-width: none;
  -ms-overflow-style: none;
}

.modal-content::-webkit-scrollbar {
  display: none;
}

.modal-body {
  max-height: calc(90vh - 140px); /* 减去头部和底部的高度 */
  overflow-y: auto;
  scrollbar-width: none;
  -ms-overflow-style: none;
}

.modal-body::-webkit-scrollbar {
  display: none;
}

/* 过渡动画优化 */
.modal-overlay-enter-active,
.modal-overlay-leave-active {
  transition: opacity 0.3s ease;
}

.modal-enter-active,
.modal-leave-active {
  transition: all 0.3s ease;
}

/* 焦点样式优化 */
input:focus,
textarea:focus,
select:focus {
  box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
}

/* 错误状态样式 */
.border-red-500:focus {
  box-shadow: 0 0 0 3px rgba(239, 68, 68, 0.1);
}
</style>
