<template>
  <Modal
    :open="visible"
    title="开启通知权限"
    :close-on-overlay="false"
    :show-confirm="false"
    :show-cancel="false"
    @close="visible = false"
  >
    <div class="permission-dialog-content">
      <!-- 图标 -->
      <div class="icon-wrapper">
        <component :is="Bell" class="w-16 h-16 text-blue-500" />
      </div>

      <!-- 说明文字 -->
      <div class="text-content">
        <h3 class="text-lg font-semibold mb-3">为什么需要通知权限？</h3>
        <ul class="space-y-2 text-sm text-gray-600">
          <li class="flex items-start">
            <component :is="CheckCircle" class="w-5 h-5 text-green-500 mr-2 mt-0.5 flex-shrink-0" />
            <span><strong>待办提醒</strong> - 不错过重要事项</span>
          </li>
          <li class="flex items-start">
            <component :is="CheckCircle" class="w-5 h-5 text-green-500 mr-2 mt-0.5 flex-shrink-0" />
            <span><strong>账单提醒</strong> - 避免逾期罚款</span>
          </li>
          <li class="flex items-start">
            <component :is="CheckCircle" class="w-5 h-5 text-green-500 mr-2 mt-0.5 flex-shrink-0" />
            <span><strong>健康提醒</strong> - 关注身体变化</span>
          </li>
        </ul>

        <div class="mt-4 p-3 bg-blue-50 rounded text-sm text-blue-700">
          <component :is="Info" class="w-4 h-4 inline mr-1" />
          您可以随时在设置中调整通知偏好
        </div>
      </div>

      <!-- 错误提示 -->
      <Alert v-if="error" type="error" class="mt-4">
        {{ error }}
      </Alert>
    </div>

    <template #footer>
      <div class="flex justify-end space-x-3">
        <Button @click="handleSkip" :disabled="requesting">
          稍后设置
        </Button>
        <Button @click="handleRequest" :loading="requesting">
          授予权限
        </Button>
      </div>
    </template>
  </Modal>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue';
import { useNotificationPermission } from '@/composables/useNotificationPermission';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import Alert from '@/components/ui/Alert.vue';
import { Bell, CheckCircle, Info } from 'lucide-vue-next';

// ==================== Props & Emits ====================

interface Props {
  modelValue: boolean;
}

interface Emits {
  (e: 'update:modelValue', value: boolean): void;
  (e: 'granted'): void;
  (e: 'denied'): void;
  (e: 'skip'): void;
}

const props = defineProps<Props>();
const emit = defineEmits<Emits>();

// ==================== Composables ====================

const {
  requestPermission,
  error: permissionError,
} = useNotificationPermission();

// ==================== 状态 ====================

const visible = ref(props.modelValue);
const requesting = ref(false);
const error = ref<string | null>(null);

// ==================== 监听 ====================

watch(
  () => props.modelValue,
  (val) => {
    visible.value = val;
    if (val) {
      // 对话框打开时清空错误
      error.value = null;
    }
  }
);

watch(visible, (val) => {
  emit('update:modelValue', val);
});

watch(permissionError, (err) => {
  error.value = err;
});

// ==================== 方法 ====================

/**
 * 请求权限
 */
async function handleRequest() {
  requesting.value = true;
  error.value = null;

  try {
    const granted = await requestPermission();

    if (granted) {
      emit('granted');
      visible.value = false;
    } else {
      error.value = '权限请求被拒绝。您可以稍后在系统设置中手动开启。';
      emit('denied');
    }
  } catch (err) {
    error.value = err instanceof Error ? err.message : '请求权限时发生错误';
  } finally {
    requesting.value = false;
  }
}

/**
 * 跳过设置
 */
function handleSkip() {
  emit('skip');
  visible.value = false;
}
</script>

<style scoped>
.permission-dialog-content {
  padding: 20px 0;
}

.icon-wrapper {
  display: flex;
  justify-content: center;
  margin-bottom: 24px;
}

.text-content ul {
  list-style: none;
  padding: 0;
}
</style>
