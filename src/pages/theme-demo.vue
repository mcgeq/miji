<script setup lang="ts">
definePage({
  name: 'theme-demo',
  meta: {
    requiresAuth: false,
    layout: 'default',
  },
});
</script>

<template>
  <div class="theme-demo">
    <div class="demo-header">
      <h1>主题颜色演示</h1>
      <p>展示增强后的主题颜色系统</p>
    </div>

    <!-- 基础颜色展示 -->
    <section class="demo-section">
      <h2>基础颜色</h2>
      <div class="color-grid">
        <div class="color-item bg-primary">
          <span>Primary</span>
          <code>--color-primary</code>
        </div>
        <div class="color-item bg-secondary">
          <span>Secondary</span>
          <code>--color-secondary</code>
        </div>
        <div class="color-item bg-accent">
          <span>Accent</span>
          <code>--color-accent</code>
        </div>
        <div class="color-item bg-success">
          <span>Success</span>
          <code>--color-success</code>
        </div>
        <div class="color-item bg-warning">
          <span>Warning</span>
          <code>--color-warning</code>
        </div>
        <div class="color-item bg-error">
          <span>Error</span>
          <code>--color-error</code>
        </div>
        <div class="color-item bg-info">
          <span>Info</span>
          <code>--color-info</code>
        </div>
      </div>
    </section>

    <!-- 交互状态展示 -->
    <section class="demo-section">
      <h2>交互状态</h2>
      <div class="interactive-demo">
        <button class="interactive-primary">
          Primary Button
        </button>
        <button class="interactive-secondary">
          Secondary Button
        </button>
        <button class="status-success">
          Success Button
        </button>
        <button class="status-warning">
          Warning Button
        </button>
        <button class="status-error">
          Error Button
        </button>
        <button class="status-info">
          Info Button
        </button>
      </div>
    </section>

    <!-- 渐变展示 -->
    <section class="demo-section">
      <h2>渐变效果</h2>
      <div class="gradient-demo">
        <div class="gradient-primary">
          Primary Gradient
        </div>
        <div class="gradient-secondary">
          Secondary Gradient
        </div>
        <div class="gradient-accent">
          Accent Gradient
        </div>
      </div>
    </section>

    <!-- 阴影展示 -->
    <section class="demo-section">
      <h2>阴影效果</h2>
      <div class="shadow-demo">
        <div class="shadow-sm">
          Small Shadow
        </div>
        <div class="shadow-md">
          Medium Shadow
        </div>
        <div class="shadow-lg">
          Large Shadow
        </div>
      </div>
    </section>

    <!-- 文字颜色展示 -->
    <section class="demo-section">
      <h2>文字颜色</h2>
      <div class="text-demo">
        <p class="text-primary">
          Primary Text
        </p>
        <p class="text-secondary">
          Secondary Text
        </p>
        <p class="text-accent">
          Accent Text
        </p>
        <p class="text-success">
          Success Text
        </p>
        <p class="text-warning">
          Warning Text
        </p>
        <p class="text-error">
          Error Text
        </p>
        <p class="text-info">
          Info Text
        </p>
      </div>
    </section>

    <!-- 卡片展示 -->
    <section class="demo-section">
      <h2>卡片组件</h2>
      <div class="card-demo">
        <div class="card">
          <h3>基础卡片</h3>
          <p>这是一个使用新主题颜色的卡片组件</p>
          <button class="interactive-primary">
            操作按钮
          </button>
        </div>
        <div class="card border-primary">
          <h3>主色边框卡片</h3>
          <p>带有主色边框的卡片</p>
          <button class="interactive-secondary">
            次要按钮
          </button>
        </div>
        <div class="card border-accent">
          <h3>强调色边框卡片</h3>
          <p>带有强调色边框的卡片</p>
          <button class="status-success">
            成功按钮
          </button>
        </div>
      </div>
    </section>
  </div>
</template>

<style scoped>
.theme-demo {
  max-width: 1200px;
  margin: 0 auto;
  padding: 2rem;
  background-color: var(--color-base-100);
  color: var(--color-base-content);
}

.demo-header {
  text-align: center;
  margin-bottom: 3rem;
}

.demo-header h1 {
  font-size: 2.5rem;
  margin-bottom: 0.5rem;
  color: var(--color-primary);
}

.demo-header p {
  font-size: 1.2rem;
  color: var(--color-base-content);
  opacity: 0.8;
}

.demo-section {
  margin-bottom: 3rem;
}

.demo-section h2 {
  font-size: 1.8rem;
  margin-bottom: 1.5rem;
  color: var(--color-primary);
  border-bottom: 2px solid var(--color-primary);
  padding-bottom: 0.5rem;
}

.color-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 1rem;
}

.color-item {
  padding: 1.5rem;
  border-radius: 0.5rem;
  text-align: center;
  box-shadow: var(--shadow-md);
  transition: transform 0.2s ease;
}

.color-item:hover {
  transform: translateY(-2px);
}

.color-item span {
  display: block;
  font-weight: bold;
  font-size: 1.1rem;
  margin-bottom: 0.5rem;
}

.color-item code {
  font-family: 'Courier New', monospace;
  font-size: 0.9rem;
  opacity: 0.8;
}

.interactive-demo {
  display: flex;
  flex-wrap: wrap;
  gap: 1rem;
}

.interactive-demo button {
  padding: 0.75rem 1.5rem;
  border: none;
  border-radius: 0.5rem;
  font-size: 1rem;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s ease;
}

.gradient-demo {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 1rem;
}

.gradient-demo > div {
  padding: 2rem;
  border-radius: 0.5rem;
  text-align: center;
  font-weight: bold;
  color: white;
  box-shadow: var(--shadow-md);
}

.shadow-demo {
  display: flex;
  gap: 2rem;
  align-items: center;
}

.shadow-demo > div {
  padding: 2rem;
  background-color: var(--color-base-200);
  border-radius: 0.5rem;
  text-align: center;
  font-weight: bold;
}

.text-demo p {
  font-size: 1.2rem;
  margin-bottom: 0.5rem;
  font-weight: 500;
}

.card-demo {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
  gap: 1.5rem;
}

.card {
  background-color: var(--color-base-200);
  padding: 1.5rem;
  border-radius: 0.75rem;
  box-shadow: var(--shadow-md);
  border: 2px solid transparent;
  transition: all 0.2s ease;
}

.card:hover {
  transform: translateY(-2px);
  box-shadow: var(--shadow-lg);
}

.card h3 {
  margin-bottom: 1rem;
  color: var(--color-primary);
}

.card p {
  margin-bottom: 1.5rem;
  line-height: 1.6;
}

.card button {
  margin-right: 0.5rem;
}
</style>
