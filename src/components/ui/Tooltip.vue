<script setup lang="ts">
  /**
   * Tooltip - 工具提示组件
   *
   * 悬停触发的提示框
   * 支持多个位置和自定义样式，自动防止溢出
   */

  import { computed, nextTick, ref } from 'vue';

  interface Props {
    /** 提示内容 */
    content?: string;
    /** 位置（会自动调整避免溢出） */
    placement?: 'top' | 'bottom' | 'left' | 'right' | 'auto';
    /** 是否禁用 */
    disabled?: boolean;
    /** 延迟显示时间（毫秒） */
    delay?: number;
  }

  const props = withDefaults(defineProps<Props>(), {
    placement: 'auto',
    disabled: false,
    delay: 200,
  });

  const isVisible = ref(false);
  const actualPlacement = ref<'top' | 'bottom' | 'left' | 'right'>('top');
  const tooltipRef = ref<HTMLElement | null>(null);
  const triggerRef = ref<HTMLElement | null>(null);
  let timeoutId: number | null = null;

  // 计算最佳位置
  function calculatePlacement() {
    if (!triggerRef.value || props.placement !== 'auto') {
      actualPlacement.value = props.placement as 'top' | 'bottom' | 'left' | 'right';
      return;
    }

    const rect = triggerRef.value.getBoundingClientRect();
    const spaceTop = rect.top;
    const spaceBottom = window.innerHeight - rect.bottom;
    const spaceRight = window.innerWidth - rect.right;

    // 优先级: 下方 > 上方 > 右侧 > 左侧
    if (spaceBottom > 100) {
      actualPlacement.value = 'bottom';
    } else if (spaceTop > 100) {
      actualPlacement.value = 'top';
    } else if (spaceRight > 200) {
      actualPlacement.value = 'right';
    } else {
      actualPlacement.value = 'left';
    }
  }

  async function showTooltip() {
    if (props.disabled || !props.content) return;

    timeoutId = window.setTimeout(async () => {
      calculatePlacement();
      isVisible.value = true;
      await nextTick();
      adjustPosition();
    }, props.delay);
  }

  function hideTooltip() {
    if (timeoutId) {
      clearTimeout(timeoutId);
      timeoutId = null;
    }
    isVisible.value = false;
  }

  // 调整位置防止溢出
  function adjustPosition() {
    if (!tooltipRef.value) return;

    const rect = tooltipRef.value.getBoundingClientRect();
    const styles: Record<string, string> = {};

    // 防止左右溢出
    if (rect.left < 10) {
      styles.left = '10px';
      styles.transform = 'translateX(0)';
    } else if (rect.right > window.innerWidth - 10) {
      styles.right = '10px';
      styles.left = 'auto';
      styles.transform = 'translateX(0)';
    }

    Object.assign(tooltipRef.value.style, styles);
  }

  // 计算最大宽度
  const maxWidth = computed(() => {
    return `${Math.min(400, window.innerWidth - 40)}px`;
  });

  // 判断内容长度，短文本不换行
  const isShortText = computed(() => {
    return props.content ? props.content.length <= 30 : false;
  });
</script>

<template>
  <div
    ref="triggerRef"
    class="relative inline-block"
    @mouseenter="showTooltip"
    @mouseleave="hideTooltip"
  >
    <!-- 触发器内容 -->
    <slot />

    <!-- Tooltip 弹窗 -->
    <Transition
      enter-active-class="transition duration-150 ease-out"
      enter-from-class="opacity-0 scale-95"
      enter-to-class="opacity-100 scale-100"
      leave-active-class="transition duration-100 ease-in"
      leave-from-class="opacity-100 scale-100"
      leave-to-class="opacity-0 scale-95"
    >
      <div
        v-if="isVisible && content"
        ref="tooltipRef"
        class="absolute z-[9999] px-3 py-2.5 text-sm text-white rounded-lg shadow-xl pointer-events-none
               bg-gradient-to-br from-gray-800 to-gray-900 dark:from-gray-900 dark:to-black
               border border-gray-700/50 dark:border-gray-800/50
               backdrop-blur-sm"
        :class="[
          actualPlacement === 'top' && 'bottom-full left-1/2 -translate-x-1/2 mb-2',
          actualPlacement === 'bottom' && 'top-full left-1/2 -translate-x-1/2 mt-2',
          actualPlacement === 'left' && 'right-full top-1/2 -translate-y-1/2 mr-2',
          actualPlacement === 'right' && 'left-full top-1/2 -translate-y-1/2 ml-2',
        ]"
        :style="{ maxWidth: maxWidth, width: 'max-content' }"
      >
        <!-- 箭头 -->
        <div
          class="absolute w-2 h-2 bg-gradient-to-br from-gray-800 to-gray-900 dark:from-gray-900 dark:to-black transform rotate-45
                 border-gray-700/50 dark:border-gray-800/50"
          :class="[
            actualPlacement === 'top' && 'bottom-[-5px] left-1/2 -translate-x-1/2 border-r border-b',
            actualPlacement === 'bottom' && 'top-[-5px] left-1/2 -translate-x-1/2 border-l border-t',
            actualPlacement === 'left' && 'right-[-5px] top-1/2 -translate-y-1/2 border-t border-r',
            actualPlacement === 'right' && 'left-[-5px] top-1/2 -translate-y-1/2 border-b border-l',
          ]"
        />

        <!-- 内容 -->
        <div
          class="relative z-10 leading-relaxed"
          :style="{
            whiteSpace: isShortText ? 'nowrap' : 'normal',
            wordBreak: isShortText ? 'keep-all' : 'break-word'
          }"
        >
          <slot name="content">{{ content }}</slot>
        </div>
      </div>
    </Transition>
  </div>
</template>
