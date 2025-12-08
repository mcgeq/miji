<script setup lang="ts">
  const loadingTexts = ref([
    '初始化应用...',
    '加载核心模块...',
    '准备用户会话...',
    '完成最后检查...',
  ]);

  // 当前显示的提示文本索引
  const currentTextIndex = ref(0);
  // 修复：明确类型为 number | null（浏览器环境）
  const textInterval = ref<NodeJS.Timeout | number | null>(null);
  // 加载完成标志
  const isLoaded = ref(false);

  // 模拟加载过程（实际可根据初始化步骤调整）
  onMounted(() => {
    // 每 800ms 切换提示文本（赋值为 number 类型）
    textInterval.value = setInterval(() => {
      currentTextIndex.value = (currentTextIndex.value + 1) % loadingTexts.value.length;
    }, 800);

    // 模拟加载耗时（实际应与 main.ts 中的初始化流程同步）
    setTimeout(() => {
      isLoaded.value = true;
      // 清除定时器（仅当 textInterval.value 是有效 number 时）
      if (textInterval.value !== null) {
        clearInterval(textInterval.value);
        textInterval.value = null; // 可选：重置为 null
      }
    }, 3000); // 3 秒后完成加载（根据实际调整）
  });

  onUnmounted(() => {
    // 清理定时器（仅当 textInterval.value 是有效 number 时）
    if (textInterval.value !== null) {
      clearInterval(textInterval.value);
      textInterval.value = null; // 可选：重置为 null
    }
  });
</script>

<template>
  <div class="splash-screen">
    <!-- 加载状态提示（修正：使用 loadingTexts 数组） -->
    <div class="loading-tip">{{ loadingTexts[currentTextIndex] }}</div>
    <!-- 可选：动画效果 -->
    <div class="splash-animation">
      <div class="dot-flashing" />
    </div>
  </div>
</template>

<style scoped>
  .splash-screen {
    position: fixed;
    top: 0;
    left: 0;
    width: 100vw;
    height: 100vh;
    background: #ffffff;
    z-index: 9999;
    display: flex;
    flex-direction: column;
    justify-content: center;
    align-items: center;
    gap: 24px;
  }

  .loading-tip {
    font-size: 18px;
    color: #333;
    font-weight: 500;
  }

  .splash-animation {
    width: 80px;
    height: 40px;
    position: relative;
  }

  .dot-flashing {
    position: absolute;
    width: 10px;
    height: 10px;
    background-color: #007bff;
    border-radius: 5px;
    animation: dotFlashing 1.5s infinite linear;
    animation-delay: 0.5s;
  }

  .dot-flashing::before,
  .dot-flashing::after {
    content: "";
    display: inline-block;
    position: absolute;
    width: 10px;
    height: 10px;
    background-color: #007bff;
    border-radius: 5px;
  }

  .dot-flashing::before {
    left: -15px;
    animation: dotFlashing 1.5s infinite;
    animation-delay: 0s;
  }

  .dot-flashing::after {
    left: 15px;
    animation: dotFlashing 1.5s infinite;
    animation-delay: 1s;
  }

  @keyframes dotFlashing {
    0% {
      background-color: #007bff;
    }
    50%,
    100% {
      background-color: rgba(0, 123, 255, 0.2);
    }
  }
</style>
