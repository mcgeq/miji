<script setup lang="ts">
import { Check, Delete } from 'lucide-vue-next';

defineOptions({
  inheritAttrs: false,
});

const props = withDefaults(defineProps<Props>(), {
  visible: false,
  position: () => ({ top: 0, left: 0, width: 200 }),
  currentValue: '',
  activeType: null,
});

const emit = defineEmits<{
  input: [value: string];
  delete: [];
  confirm: [];
  close: [];
}>();

interface Props {
  visible?: boolean;
  position?: { top: number; left: number; width: number };
  currentValue?: string;
  activeType?: 'hour' | 'minute' | 'second' | null;
}

// 键盘布局：一行4个，3行
// 第1行: 1, 2, 3, 4
// 第2行: 5, 6, 7, 8
// 第3行: 9, 0, delete, confirm (delete和confirm各占1个位置)
const keys = [
  { keys: ['1', '2', '3', '4'], layout: 'normal' },
  { keys: ['5', '6', '7', '8'], layout: 'normal' },
  { keys: ['9', '0', 'delete', 'confirm'], layout: 'normal' },
];

function handleKeyClick(value: string) {
  if (value === 'delete') {
    emit('delete');
  } else if (value === 'confirm') {
    emit('confirm');
  } else {
    emit('input', value);
  }
}

// 获取输入类型标签
const inputLabel = computed(() => {
  switch (props.activeType) {
    case 'hour':
      return '小时';
    case 'minute':
      return '分钟';
    case 'second':
      return '秒';
    default:
      return '';
  }
});

// 计算键盘位置
const keyboardStyle = computed(() => {
  if (!props.position) return {};

  const { top, left, width } = props.position;

  return {
    position: 'fixed' as const,
    top: `${top}px`,
    left: `${left}px`,
    width: `${width}px`,
    zIndex: 99999999, // 必须在 DateTimePanel (9999999) 和 Modal (999999) 之上
  };
});

// 点击外部关闭
function handleClickOutside(event: Event) {
  const target = event.target as HTMLElement;
  if (!target.closest('.numpad-keyboard')) {
    emit('close');
  }
}

onMounted(() => {
  document.addEventListener('click', handleClickOutside);
});

onUnmounted(() => {
  document.removeEventListener('click', handleClickOutside);
});
</script>

<template>
  <Teleport to="body">
    <div
      v-if="visible"
      class="numpad-keyboard"
      :style="keyboardStyle"
      @click.stop
    >
      <!-- 当前输入值显示 -->
      <div v-if="activeType" class="keyboard-preview">
        <span class="preview-label">{{ inputLabel }}</span>
        <span class="preview-value">{{ currentValue || '--' }}</span>
      </div>

      <!-- 数字键盘行 -->
      <div
        v-for="(row, rowIndex) in keys"
        :key="rowIndex"
        class="keyboard-row"
      >
        <button
          v-for="key in row.keys"
          :key="key"
          type="button"
          class="keyboard-key"
          :class="{ 'key-delete': key === 'delete', 'key-confirm': key === 'confirm' }"
          @click="handleKeyClick(key)"
        >
          <Delete v-if="key === 'delete'" :size="20" />
          <Check v-else-if="key === 'confirm'" :size="20" />
          <span v-else>{{ key }}</span>
        </button>
      </div>
    </div>
  </Teleport>
</template>

<style scoped>
.numpad-keyboard {
  background-color: var(--color-base-100);
  border: 1px solid var(--color-base-300);
  border-radius: 8px;
  box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
  padding: 0.5rem;
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.keyboard-row {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 0.5rem;
}

.keyboard-preview {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0.5rem;
  background-color: var(--color-base-200);
  border-radius: 6px;
  margin-bottom: 0.25rem;
}

.preview-label {
  font-size: 0.875rem;
  color: var(--color-base-content-soft);
}

.preview-value {
  font-size: 1.125rem;
  font-weight: 600;
  color: var(--color-base-content);
  min-width: 2rem;
  text-align: right;
}

.keyboard-key {
  aspect-ratio: 1;
  min-height: 2.5rem;
  border: 1px solid var(--color-base-300);
  border-radius: 6px;
  background-color: var(--color-base-200);
  color: var(--color-base-content);
  font-size: 1.125rem;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.15s ease;
  display: flex;
  align-items: center;
  justify-content: center;
  user-select: none;
}

.keyboard-key:hover {
  background-color: var(--color-base-300);
  border-color: var(--color-primary);
}

.keyboard-key:active {
  background-color: var(--color-primary);
  color: var(--color-primary-content);
  transform: scale(0.95);
}

.keyboard-key.key-delete {
  background-color: var(--color-base-300);
  display: flex;
  align-items: center;
  justify-content: center;
}

.keyboard-key.key-delete:hover {
  background-color: var(--color-error);
  color: var(--color-error-content);
}

.keyboard-key.key-delete:hover :deep(svg) {
  color: var(--color-error-content);
}

.keyboard-key.key-delete:active {
  background-color: var(--color-error);
  color: var(--color-error-content);
}

.keyboard-key.key-delete:active :deep(svg) {
  color: var(--color-error-content);
}

.keyboard-key.key-confirm {
  background-color: var(--color-primary);
  color: var(--color-primary-content);
  display: flex;
  align-items: center;
  justify-content: center;
}

.keyboard-key.key-confirm:hover {
  background-color: var(--color-primary);
  opacity: 0.9;
  transform: scale(0.98);
}

.keyboard-key.key-confirm:hover :deep(svg) {
  color: var(--color-primary-content);
}

.keyboard-key.key-confirm:active {
  background-color: var(--color-primary);
  opacity: 0.8;
  transform: scale(0.95);
}

.keyboard-key.key-confirm:active :deep(svg) {
  color: var(--color-primary-content);
}
</style>
