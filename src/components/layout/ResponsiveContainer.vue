<script setup lang="ts">
  // 响应式容器组件，优化移动端体验
  interface Props {
    maxWidth?: 'sm' | 'md' | 'lg' | 'xl' | '2xl' | '4xl' | '5xl' | '6xl' | '7xl' | 'full';
  }

  const props = withDefaults(defineProps<Props>(), {
    maxWidth: '5xl', // 对应 1200px 左右
  });

  // 检测屏幕尺寸
  const isMobile = ref(false);
  const isTablet = ref(false);

  function updateScreenSize() {
    const width = window.innerWidth;
    isMobile.value = width < 768;
    isTablet.value = width >= 768 && width < 1024;
  }

  onMounted(() => {
    updateScreenSize();
    window.addEventListener('resize', updateScreenSize);
  });

  onUnmounted(() => {
    window.removeEventListener('resize', updateScreenSize);
  });

  // 最大宽度映射
  const maxWidthClass = computed(() => {
    const widthMap = {
      sm: 'max-w-sm',
      md: 'max-w-md',
      lg: 'max-w-lg',
      xl: 'max-w-xl',
      '2xl': 'max-w-2xl',
      '4xl': 'max-w-4xl',
      '5xl': 'max-w-5xl',
      '6xl': 'max-w-6xl',
      '7xl': 'max-w-7xl',
      full: 'max-w-full',
    };
    return widthMap[props.maxWidth];
  });
</script>

<template>
  <div
    class="w-full mx-auto p-3 sm:p-4 transition-all duration-300"
    :class="[
      maxWidthClass,
      {
        'is-mobile': isMobile,
        'is-tablet': isTablet,
        'is-desktop': !isMobile && !isTablet,
      },
    ]"
  >
    <slot :is-mobile="isMobile" :is-tablet="isTablet" />
  </div>
</template>
