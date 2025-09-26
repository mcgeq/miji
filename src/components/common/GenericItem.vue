<script lang="ts" setup generic="T extends { [key: string]: unknown }">
import { X } from 'lucide-vue-next';
import { computed } from 'vue';

const props = defineProps<{
  modelValue: T;
  readonly?: boolean;
  displayKey?: keyof T;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', val: T): void;
  (e: 'remove'): void;
}>();

const modelValue = computed({
  get: () => props.modelValue,
  set: (val: T) => emit('update:modelValue', val),
});

const keyToEdit = computed(() => props.displayKey ?? ('name' as keyof T));

const totalUsageCount = computed(() => {
  const usage = modelValue.value.usage;

  if (!usage || typeof usage !== 'object')
    return 0;

  return Object.values(usage).reduce((sum, entry) => {
    const count
      = typeof entry === 'object' && 'count' in entry ? Number(entry.count) : 0;
    return sum + (Number.isNaN(count) ? 0 : count);
  }, 0);
});

function onInput(event: Event) {
  const newValue = (event.target as HTMLInputElement).value;
  modelValue.value = {
    ...modelValue.value,
    [keyToEdit.value]: newValue,
  };
}
</script>

<template>
  <div class="usage-card">
    <!-- 计数徽章 -->
    <div class="usage-badge">
      {{ totalUsageCount }}
    </div>

    <!-- 输入框 -->
    <div class="usage-input-wrapper">
      <input
        :value="modelValue[keyToEdit]"
        class="usage-input"
        :readonly="readonly"
        :placeholder="String(keyToEdit)"
        :title="String(modelValue[keyToEdit])"
        @input="onInput"
      >
    </div>

    <!-- 删除按钮 -->
    <div class="usage-remove">
      <X
        class="usage-remove-btn"
        @click="$emit('remove')"
      />
    </div>
  </div>
</template>

<style scoped lang="postcss">
/* 外层卡片 */
.usage-card {
  margin-left: 0.5rem; /* ml-2 */
  padding: 0.75rem;    /* p-3 */
  border: 1px solid #E5E7EB; /* border-gray-200 */
  border-radius: 0.5rem;      /* rounded-lg */
  background-color: #FFFFFF;   /* bg-white */
  width: 6.5rem;               /* w-26 -> 26*0.25rem */
  box-shadow: 0 1px 3px rgba(0,0,0,0.1); /* shadow-md */
  position: relative;
  transition: box-shadow 0.2s;
}

.usage-card:hover {
  box-shadow: 0 4px 6px rgba(0,0,0,0.15); /* hover:shadow-lg */
}

/* 徽章 */
.usage-badge {
  font-size: 0.75rem;            /* text-xs */
  color: #FFFFFF;                /* text-white */
  font-weight: bold;             /* font-bold */
  border-radius: 9999px;         /* rounded-full */
  background-color: #3B82F6;     /* bg-blue-500 */
  display: flex;
  height: 1.5rem;                /* h-6 */
  width: 1.5rem;                 /* w-6 */
  align-items: center;           /* items-center */
  justify-content: center;       /* justify-center */
  position: absolute;
  left: -0.5rem;                 /* -left-2 */
  top: -0.5rem;                  /* -top-2 */
}

/* 输入框 */
.usage-input-wrapper {
  margin-bottom: 0; /* mb-0 */
}

.usage-input {
  color: #374151;                 /* text-gray-700 */
  padding: 0.5rem 0.75rem;        /* px-3 py-2 */
  border: 1px solid #D1D5DB;      /* border-gray-300 */
  border-radius: 0.375rem;        /* rounded-md */
  background-color: #F9FAFB;      /* bg-gray-50 */
  width: 5rem;                     /* w-20 */
  outline: none;
  transition: all 0.2s;
}

.usage-input:focus {
  border-color: transparent;
  box-shadow: 0 0 0 2px #3B82F6; /* focus:ring-2 focus:ring-blue-500 */
}

/* 删除按钮外层定位 */
.usage-remove {
  position: absolute;
  right: -0.5rem;  /* -right-2 */
  top: -0.5rem;    /* -top-2 */
}

/* 删除按钮样式 */
.usage-remove-btn {
  color: #EF4444;                 /* text-red-500 */
  border-radius: 9999px;          /* rounded-full */
  background-color: #FFFFFF;      /* bg-white */
  display: flex;
  height: 1.5rem;                 /* h-6 */
  width: 1.5rem;                  /* w-6 */
  cursor: pointer;
  align-items: center;            /* items-center */
  justify-content: center;        /* justify-center */
  transition: transform 0.2s, color 0.2s;
}

.usage-remove-btn:hover {
  color: #B91C1C;                 /* hover:text-red-700 */
  transform: scale(1.1);          /* hover:scale-110 */
}

/* 可选：深色模式兼容 */
@media (prefers-color-scheme: dark) {
  .usage-card {
    background-color: #1F2937;    /* gray-900 */
    border-color: #374151;        /* gray-700 */
    box-shadow: 0 1px 3px rgba(255,255,255,0.05);
  }
  .usage-input {
    background-color: #111827;    /* gray-800 */
    color: #F9FAFB;               /* text-white */
    border-color: #4B5563;        /* gray-600 */
  }
  .usage-input:focus {
    box-shadow: 0 0 0 2px #3B82F6; /* 保持focus颜色 */
  }
  .usage-badge {
    background-color: #3B82F6;     /* 蓝色徽章不变 */
  }
  .usage-remove-btn {
    background-color: #1F2937;     /* 深色背景 */
    color: #F87171;                 /* 红色 */
  }
}
</style>
