<script lang="ts" setup generic="T extends { [key: string]: unknown }">
  import { X } from 'lucide-vue-next';

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

    if (!usage || typeof usage !== 'object') return 0;

    return Object.values(usage).reduce((sum, entry) => {
      const count = typeof entry === 'object' && 'count' in entry ? Number(entry.count) : 0;
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
  <div
    class="ml-2 p-3 border rounded-lg bg-[light-dark(white,#1f2937)] border-[light-dark(#e5e7eb,#374151)] w-26 shadow-md hover:shadow-lg relative transition-shadow max-sm:ml-1 max-sm:p-2 max-sm:w-22"
  >
    <!-- 计数徽章 -->
    <div
      class="absolute -left-2 -top-2 flex h-6 w-6 items-center justify-center text-xs text-white font-bold rounded-full bg-blue-500 max-sm:h-5 max-sm:w-5 max-sm:text-[0.625rem]"
    >
      {{ totalUsageCount }}
    </div>

    <!-- 输入框 -->
    <div class="mb-0">
      <input
        :value="modelValue[keyToEdit]"
        class="w-20 px-3 py-2 text-[light-dark(#374151,#f9fafb)] bg-[light-dark(#f9fafb,#111827)] border border-[light-dark(#d1d5db,#4b5563)] rounded-md outline-none transition-all focus:border-transparent focus:ring-2 focus:ring-blue-500 max-sm:w-18 max-sm:px-2 max-sm:py-1.5 max-sm:text-sm"
        :readonly="props.readonly"
        :placeholder="String(keyToEdit)"
        :title="String(modelValue[keyToEdit])"
        @input="onInput"
      />
    </div>

    <!-- 删除按钮 -->
    <div class="absolute -right-2 -top-2">
      <X
        class="flex h-6 w-6 items-center justify-center rounded-full bg-[light-dark(white,#1f2937)] text-[light-dark(#ef4444,#f87171)] cursor-pointer transition-all hover:text-[light-dark(#b91c1c,#dc2626)] hover:scale-110 max-sm:h-5 max-sm:w-5"
        @click="$emit('remove')"
      />
    </div>
  </div>
</template>
