<script setup lang="ts">
// 响应式容器组件，优化移动端体验
interface Props {
  maxWidth?: string;
  padding?: string;
  mobilePadding?: string;
}

const props = withDefaults(defineProps<Props>(), {
  maxWidth: '1200px',
  padding: '1rem',
  mobilePadding: '0.75rem',
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

// 动态样式
const containerStyle = computed(() => ({
  maxWidth: props.maxWidth,
  padding: isMobile.value ? props.mobilePadding : props.padding,
  margin: '0 auto',
}));
</script>

<template>
  <div
    class="responsive-container"
    :class="{
      'is-mobile': isMobile,
      'is-tablet': isTablet,
      'is-desktop': !isMobile && !isTablet,
    }"
    :style="containerStyle"
  >
    <slot :is-mobile="isMobile" :is-tablet="isTablet" />
  </div>
</template>

<style scoped>
.responsive-container {
  width: 100%;
  transition: padding 0.3s ease;
}

/* 移动端优化 */
.responsive-container.is-mobile {
  /* 移动端特定样式 */
}

.responsive-container.is-tablet {
  /* 平板端特定样式 */
}

.responsive-container.is-desktop {
  /* 桌面端特定样式 */
}
</style>
