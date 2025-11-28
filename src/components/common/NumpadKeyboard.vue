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

// 获取按键样式类
function getKeyClass(key: string) {
  const baseClasses = [
    'aspect-square min-h-10',
    'flex items-center justify-center',
    'rounded-md font-medium text-lg',
    'transition-all duration-150 ease-out',
    'select-none cursor-pointer',
    'border',
  ];

  if (key === 'delete') {
    return [
      ...baseClasses,
      'bg-[light-dark(#f3f4f6,#374151)]',
      'border-[light-dark(#e5e7eb,#4b5563)]',
      'text-[light-dark(#374151,#f9fafb)]',
      'hover:bg-[var(--color-error)] hover:text-white hover:border-[var(--color-error)]',
      'active:bg-[var(--color-error)] active:scale-95',
    ].join(' ');
  }

  if (key === 'confirm') {
    return [
      ...baseClasses,
      'bg-[var(--color-primary)]',
      'border-[var(--color-primary)]',
      'text-white',
      'hover:opacity-90 hover:scale-[0.98]',
      'active:opacity-80 active:scale-95',
    ].join(' ');
  }

  return [
    ...baseClasses,
    'bg-[light-dark(#f9fafb,#374151)]',
    'border-[light-dark(#e5e7eb,#4b5563)]',
    'text-[light-dark(#111827,#f9fafb)]',
    'hover:bg-[light-dark(#e5e7eb,#4b5563)] hover:border-[var(--color-primary)]',
    'active:bg-[var(--color-primary)] active:text-white active:scale-95',
  ].join(' ');
}

// 点击外部关闭
function handleClickOutside(event: Event) {
  const target = event.target as HTMLElement;
  const keyboard = document.querySelector('[class*="bg-\\[light-dark"]');
  if (keyboard && !keyboard.contains(target)) {
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
      :style="keyboardStyle"
      class="bg-[light-dark(white,#1f2937)] border border-[light-dark(#e5e7eb,#374151)] rounded-lg shadow-lg p-2 flex flex-col gap-2"
      @click.stop
    >
      <!-- 当前输入值显示 -->
      <div
        v-if="activeType"
        class="flex items-center justify-between p-2 bg-[light-dark(#f9fafb,#111827)] rounded-md mb-1"
      >
        <span class="text-sm text-[light-dark(#6b7280,#9ca3af)]">{{ inputLabel }}</span>
        <span class="text-lg font-semibold text-[light-dark(#111827,#f9fafb)] min-w-8 text-right">
          {{ currentValue || '--' }}
        </span>
      </div>

      <!-- 数字键盘行 -->
      <div
        v-for="(row, rowIndex) in keys"
        :key="rowIndex"
        class="grid grid-cols-4 gap-2"
      >
        <button
          v-for="key in row.keys"
          :key="key"
          type="button"
          :class="getKeyClass(key)"
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
