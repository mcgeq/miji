<script setup lang="ts">
  const props = defineProps<{ title: string; completed: boolean }>();

  const title = computed(() => props.title);
  const completed = computed(() => props.completed);

  // 设置最大显示字符数
  const MAX_DISPLAY_LENGTH = 30;

  // 计算显示的标题（截断后）
  const displayTitle = computed(() => {
    if (title.value.length <= MAX_DISPLAY_LENGTH) {
      return title.value;
    }
    return `${title.value.substring(0, MAX_DISPLAY_LENGTH)}...`;
  });

  // 判断是否需要显示tooltip
  const shouldShowTooltip = computed(() => title.value.length > MAX_DISPLAY_LENGTH);

  // 移动端长按显示完整内容
  const showFullTitle = ref(false);
  let longPressTimer: NodeJS.Timeout | null = null;

  function handleTouchStart() {
    if (!shouldShowTooltip.value) return;

    longPressTimer = setTimeout(() => {
      showFullTitle.value = true;
    }, 500); // 500ms长按
  }

  function handleTouchEnd() {
    if (longPressTimer) {
      clearTimeout(longPressTimer);
      longPressTimer = null;
    }
  }

  function handleTouchMove() {
    if (longPressTimer) {
      clearTimeout(longPressTimer);
      longPressTimer = null;
    }
  }

  function hideFullTitle() {
    showFullTitle.value = false;
  }

  // 点击处理（仅用于关闭全屏显示）
  function handleClick() {
    if (showFullTitle.value) {
      hideFullTitle();
    }
  }
</script>

<template>
  <div class="relative block flex-1 min-w-0 max-w-full overflow-hidden">
    <span
      class="text-[0.9375rem] leading-6 font-medium text-left block overflow-hidden text-ellipsis whitespace-nowrap text-base-content transition-all duration-200 tracking-tight max-w-full"
      :class="completed ? 'opacity-50 line-through' : ''"
      :title="shouldShowTooltip ? title : undefined"
      @click="shouldShowTooltip ? handleClick : undefined"
      @touchstart="handleTouchStart"
      @touchend="handleTouchEnd"
      @touchmove="handleTouchMove"
    >
      {{ displayTitle }}
    </span>

    <!-- 移动端全屏显示完整标题 -->
    <Teleport to="body">
      <div
        v-if="showFullTitle"
        class="fixed inset-0 bg-black/80 flex items-center justify-center z-[10001] p-8 md:p-4"
        @click="hideFullTitle"
      >
        <div
          class="bg-base-100 dark:bg-base-200 rounded-2xl p-8 md:p-6 max-w-[90%] md:max-w-[95%] max-h-[80%] shadow-2xl text-center"
        >
          <h3
            class="text-xl md:text-lg leading-7 md:leading-6 text-neutral dark:text-neutral m-0 mb-4 break-words"
          >
            {{ title }}
          </h3>
          <p class="text-sm text-neutral-content dark:text-neutral-content m-0">点击任意位置关闭</p>
        </div>
      </div>
    </Teleport>
  </div>
</template>
