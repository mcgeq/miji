<script setup lang="ts">
  definePage({
    name: 'splashscreen',
    meta: {
      requiresAuth: false,
      layout: 'default',
    },
  });

  // 控制启动画面显示/隐藏
  const visible = ref(true);
  // 当前显示的状态提示
  const currentStatus = ref('');
  // 加载进度（0-100，可选）
  const progress = ref(0);
  // 状态数组（新增多个提示）
  const statuses = ref([
    '正在初始化核心模块...',
    '正在加载界面资源...',
    '正在优化体验配置...',
    '正在连接云服务...',
    '正在校验用户数据...',
    '应用马上就绪 🎉',
  ]);
  // 当前状态索引
  const currentIndex = ref(0);
  // 定时器（用于切换状态）
  let statusInterval: ReturnType<typeof setInterval> | null = null;
  // 进度条定时器（可选）
  let progressInterval: ReturnType<typeof setInterval> | null = null;

  // 生命周期：组件挂载后启动状态切换
  onMounted(() => {
    startStatusRotation();
    startProgressAnimation(); // 可选：启动进度条动画
  });

  // 生命周期：组件卸载前清理定时器
  onUnmounted(() => {
    stopStatusRotation();
    stopProgressAnimation(); // 可选：停止进度条动画
  });

  // 启动状态切换（关键逻辑）
  function startStatusRotation() {
    statusInterval = setInterval(() => {
      // 切换到下一个状态
      currentIndex.value = (currentIndex.value + 1) % statuses.value.length;
      currentStatus.value = statuses.value[currentIndex.value];

      // 当显示最后一个状态时，停止切换并触发关闭（可选）
      if (currentIndex.value === statuses.value.length - 1) {
        stopStatusRotation();
        // 可选：延迟后关闭启动画面（如 1 秒）
        setTimeout(() => {
          visible.value = false;
          // 触发关闭事件通知父组件（可选）
        }, 1000);
      }
    }, 1500); // 每个状态显示 1.5 秒（可调整）
  }

  // 启动进度条动画（可选，根据需求启用）
  function startProgressAnimation() {
    progressInterval = setInterval(() => {
      progress.value = Math.min(progress.value + 5, 100); // 每 50ms 增加 5%
      if (progress.value >= 100) {
        stopProgressAnimation();
      }
    }, 50);
  }

  // 停止状态切换
  function stopStatusRotation() {
    if (statusInterval) {
      clearInterval(statusInterval);
      statusInterval = null;
    }
  }

  // 停止进度条动画（可选）
  function stopProgressAnimation() {
    if (progressInterval) {
      clearInterval(progressInterval);
      progressInterval = null;
    }
  }
</script>

<template>
  <div v-show="visible" id="frontend-splashscreen">
    <div class="splash-container">
      <!-- 应用 Logo -->
      <div class="logo">M</div>
      <!-- 应用名称 -->
      <div class="app-name">MiJi</div>
      <!-- 动态加载提示（关键修改） -->
      <div class="loading-text">{{ currentStatus }}</div>
      <!-- 旋转加载图标 -->
      <div class="spinner" />
      <!-- 进度条（可选，根据需求保留或移除） -->
      <div class="progress-bar">
        <div class="progress-fill" :style="{ width: `${progress}%` }" />
      </div>
    </div>
  </div>
</template>

<style scoped>
  /* 保留原有样式，仅调整加载文本部分 */
  .loading-text {
    font-size: 0.9rem;
    opacity: 0.7;
    margin-bottom: 1rem;
    min-height: 1.2em; /* 避免文本切换时高度抖动 */
  }

  /* 可选：进度条样式优化 */
  .progress-bar {
    width: 200px;
    height: 4px;
    background: rgba(255, 255, 255, 0.3);
    border-radius: 2px;
    overflow: hidden;
    margin-top: 1rem;
  }

  .progress-fill {
    height: 100%;
    background: white;
    border-radius: 2px;
    transition: width 0.1s linear; /* 平滑过渡 */
  }
</style>
