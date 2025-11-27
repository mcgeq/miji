<script setup lang="ts">
// 快捷键帮助系统组件
interface Shortcut {
  key: string;
  label: string;
}

interface Props {
  show: boolean;
  shortcuts: Shortcut[];
  isMobile?: boolean;
}

withDefaults(defineProps<Props>(), {
  isMobile: false,
});

const emit = defineEmits<{
  toggle: [];
  close: [];
}>();
</script>

<template>
  <div>
    <!-- 快捷键帮助提示框 - 左上角 -->
    <Transition
      enter-active-class="transition-all duration-200"
      leave-active-class="transition-all duration-200"
      enter-from-class="opacity-0 -translate-y-2"
      leave-to-class="opacity-0 -translate-y-2"
    >
      <div
        v-if="show"
        class="absolute top-2 left-2 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg p-3 shadow-lg z-[100] max-w-[200px]"
      >
        <div class="flex justify-between items-center mb-2 pb-2 border-b border-gray-200 dark:border-gray-700">
          <h4 class="m-0 text-sm font-semibold text-gray-900 dark:text-white">
            快捷键
          </h4>
          <button
            class="p-1 bg-transparent border-none cursor-pointer text-gray-600 dark:text-gray-400 opacity-60 hover:opacity-100 transition-opacity flex items-center justify-center"
            @click="emit('close')"
          >
            <LucideX :size="16" />
          </button>
        </div>
        <div class="flex flex-col gap-2">
          <div
            v-for="shortcut in shortcuts"
            :key="shortcut.key"
            class="flex items-center gap-2 text-xs"
          >
            <kbd class="min-w-6 px-1.5 py-0.5 text-xs font-semibold font-mono text-gray-900 dark:text-white bg-gray-100 dark:bg-gray-700 border border-gray-300 dark:border-gray-600 rounded text-center">
              {{ shortcut.key }}
            </kbd>
            <span class="text-gray-700 dark:text-gray-300">{{ shortcut.label }}</span>
          </div>
        </div>
      </div>
    </Transition>

    <!-- 快捷键切换按钮 - 右上角 -->
    <button
      v-if="!isMobile"
      class="absolute top-2 right-2 p-2 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg cursor-pointer transition-all flex items-center justify-center text-gray-700 dark:text-gray-300 opacity-70 hover:opacity-100 hover:bg-gray-50 dark:hover:bg-gray-700 hover:scale-105 z-10 shadow-sm hover:shadow-md"
      title="快捷键帮助 (?)"
      @click="emit('toggle')"
    >
      <LucideKeyboard :size="20" />
    </button>
  </div>
</template>
